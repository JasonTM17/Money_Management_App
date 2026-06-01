import { createHmac, createHash, timingSafeEqual } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest, serviceUnavailable } from '../../lib/api-error.js';
import { serializeBigInts } from '../../lib/finance-serializers.js';
import { InMemoryRateLimiter, rateLimitKey } from '../../lib/rate-limiter.js';
import { parseBody } from '../../lib/validation.js';
import { requireAuth } from '../auth/auth-context.js';

const iapVerifySchema = z.object({
  provider: z.enum(['apple', 'google']),
  productId: z.string().trim().min(1),
  purchaseToken: z.string().trim().min(8),
  providerSubscriptionId: z.string().trim().min(1).optional(),
});

const sepayOrderSchema = z.object({
  plan: z.string().trim().min(1).default('premium_monthly'),
  amount: z.number().int().positive(),
  currency: z.literal('VND').default('VND'),
  idempotencyKey: z.string().trim().min(1).max(120),
});

const sepayWebhookSchema = z.object({
  providerOrderId: z.string().trim().min(1),
  status: z.enum(['paid', 'expired', 'cancelled']),
  amount: z.number().int().positive().optional(),
  paidAt: z.string().datetime().optional(),
});

export async function registerPaymentRoutes(app: FastifyInstance) {
  const paymentLimiter = new InMemoryRateLimiter({
    windowMs: 60_000,
    maxAttempts: 30,
    message: 'Too many payment requests',
  });

  app.post('/v1/iap/verify', async (request) => {
    const auth = requireAuth(request);
    paymentLimiter.check(rateLimitKey(request, 'iap-verify', auth.sub));
    const input = parseBody(iapVerifySchema, request.body);
    if (iapVerificationMode() !== 'mock') {
      throw serviceUnavailable(
        'iap_verification_unconfigured',
        'Store purchase verification is not configured',
      );
    }

    const providerSubscriptionId =
      input.providerSubscriptionId ??
      createHash('sha256')
        .update(`${input.provider}:${input.productId}:${input.purchaseToken}`)
        .digest('hex');
    const currentPeriodEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    const entitlement = await app.prisma.entitlement.upsert({
      where: {
        provider_providerSubscriptionId: {
          provider: input.provider,
          providerSubscriptionId,
        },
      },
      create: {
        userId: auth.sub,
        plan: input.productId,
        provider: input.provider,
        providerSubscriptionId,
        status: 'active',
        currentPeriodEnd,
      },
      update: {
        userId: auth.sub,
        plan: input.productId,
        status: 'active',
        currentPeriodEnd,
      },
    });

    return { verified: true, entitlement: serializeBigInts(entitlement) };
  });

  app.post('/v1/payments/sepay/orders', async (request, reply) => {
    const auth = requireAuth(request);
    paymentLimiter.check(rateLimitKey(request, 'sepay-order', auth.sub));
    const input = parseBody(sepayOrderSchema, request.body);
    if (!sepayEnabled()) {
      throw serviceUnavailable(
        'sepay_disabled',
        'SePay orders are disabled for this distribution channel',
      );
    }

    const existingOrder = await app.prisma.paymentOrder.findUnique({
      where: {
        userId_idempotencyKey: {
          userId: auth.sub,
          idempotencyKey: input.idempotencyKey,
        },
      },
    });
    if (existingOrder) return serializeBigInts(existingOrder);

    const order = await app.prisma.paymentOrder.create({
      data: {
        userId: auth.sub,
        provider: 'sepay',
        amount: BigInt(input.amount),
        currency: input.currency,
        idempotencyKey: input.idempotencyKey,
        metadata: { plan: input.plan },
      },
    });
    const providerOrderId = `sepay_${order.id}`;
    const checkoutUrl = buildSePayCheckoutUrl(providerOrderId, input.amount);
    const updatedOrder = await app.prisma.paymentOrder.update({
      where: { id: order.id },
      data: { providerOrderId, checkoutUrl },
    });

    return reply.status(201).send(serializeBigInts(updatedOrder));
  });

  app.post('/v1/payments/sepay/webhook', async (request) => {
    paymentLimiter.check(rateLimitKey(request, 'sepay-webhook'));
    assertSePaySignature(request.headers['x-sepay-signature'], request.rawBody ?? '{}');
    const input = parseBody(sepayWebhookSchema, request.body);
    const order = await app.prisma.paymentOrder.findFirst({
      where: { provider: 'sepay', providerOrderId: input.providerOrderId },
    });
    if (!order) throw badRequest('payment_order_not_found', 'Payment order not found');

    const orderUpdate = resolveSePayOrderUpdate(order, input);
    const updatedOrder = orderUpdate
      ? await app.prisma.paymentOrder.update({
          where: { id: order.id },
          data: orderUpdate,
        })
      : order;

    if (orderUpdate?.status === 'paid') {
      const metadata = order.metadata as { plan?: string } | null;
      await app.prisma.entitlement.upsert({
        where: {
          provider_providerSubscriptionId: {
            provider: 'sepay',
            providerSubscriptionId: input.providerOrderId,
          },
        },
        create: {
          userId: order.userId,
          plan: metadata?.plan ?? 'premium_monthly',
          provider: 'sepay',
          providerSubscriptionId: input.providerOrderId,
          status: 'active',
          currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        },
        update: {
          status: 'active',
          currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        },
      });
    }

    return { received: true, order: serializeBigInts(updatedOrder) };
  });
}

type SePayOrderState = {
  status: 'pending' | 'paid' | 'expired' | 'cancelled';
  amount: bigint;
  paidAt: Date | null;
};

type SePayWebhookInput = z.infer<typeof sepayWebhookSchema>;

export function resolveSePayOrderUpdate(order: SePayOrderState, input: SePayWebhookInput) {
  if (input.amount !== undefined && order.amount !== BigInt(input.amount)) {
    throw badRequest('payment_amount_mismatch', 'Webhook amount does not match the payment order');
  }
  if (order.status === 'paid') {
    return null;
  }
  return {
    status: input.status,
    paidAt: input.status === 'paid' ? new Date(input.paidAt ?? Date.now()) : null,
  };
}
function buildSePayCheckoutUrl(providerOrderId: string, amount: number) {
  const baseUrl = process.env.SEPAY_CHECKOUT_BASE_URL;
  if (!baseUrl) return null;
  const url = new URL(baseUrl);
  url.searchParams.set('order_id', providerOrderId);
  url.searchParams.set('amount', String(amount));
  return url.toString();
}

function assertSePaySignature(header: string | string[] | undefined, rawBody: string) {
  const webhookSecret = process.env.SEPAY_WEBHOOK_SECRET;
  if (!webhookSecret) {
    throw serviceUnavailable(
      'sepay_webhook_unconfigured',
      'SePay webhook secret is not configured',
    );
  }
  const signature = Array.isArray(header) ? header[0] : header;
  if (!signature || !/^[a-f0-9]{64}$/i.test(signature)) {
    throw badRequest('invalid_sepay_signature', 'Invalid SePay webhook signature');
  }
  const expected = createHmac('sha256', webhookSecret).update(rawBody).digest('hex');
  const receivedBuffer = Buffer.from(signature, 'hex');
  const expectedBuffer = Buffer.from(expected, 'hex');
  if (
    receivedBuffer.length !== expectedBuffer.length ||
    !timingSafeEqual(receivedBuffer, expectedBuffer)
  ) {
    throw badRequest('invalid_sepay_signature', 'Invalid SePay webhook signature');
  }
}

function iapVerificationMode() {
  return process.env.IAP_VERIFICATION_MODE ?? 'disabled';
}

function sepayEnabled() {
  return process.env.SEPAY_ENABLED === 'true';
}
