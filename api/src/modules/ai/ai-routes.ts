import { createHmac } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { ApiError, serviceUnavailable } from '../../lib/api-error.js';
import { parseBody } from '../../lib/validation.js';
import { requireAuth } from '../auth/auth-context.js';

const analysisRequestSchema = z.object({
  question: z.string().trim().min(1).max(800),
  locale: z.enum(['vi', 'en', 'ja']).default('vi'),
});

export async function registerAiRoutes(app: FastifyInstance) {
  app.post('/v1/ai/analysis', async (request) => {
    requireAuth(request);
    const input = parseBody(analysisRequestSchema, request.body);
    const webhookUrl = process.env.N8N_CHATBOT_WEBHOOK_URL;
    const webhookSecret = process.env.N8N_CHATBOT_WEBHOOK_SECRET;
    if (!webhookUrl || !webhookSecret) {
      throw serviceUnavailable(
        'ai_analysis_unconfigured',
        'AI analysis workflow is not configured',
      );
    }

    const body = JSON.stringify({
      question: input.question,
      locale: input.locale,
    });
    const signature = createHmac('sha256', webhookSecret).update(body).digest('hex');
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);

    try {
      const response = await fetch(webhookUrl, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-cashflow-signature-sha256': signature,
        },
        body,
        signal: controller.signal,
      });
      if (!response.ok) {
        throw serviceUnavailable(
          'ai_analysis_unavailable',
          'AI analysis workflow is unavailable',
        );
      }
      let result: unknown;
      try {
        result = await response.json() as unknown;
      } catch {
        throw serviceUnavailable(
          'ai_analysis_invalid_response',
          'AI analysis workflow returned an invalid response',
        );
      }

      const parsed = z.object({
        answer: z.string().trim().min(1),
        suggestions: z.array(z.string().trim().min(1)).min(3).max(5),
      }).safeParse(result);
      if (!parsed.success) {
        throw serviceUnavailable(
          'ai_analysis_invalid_response',
          'AI analysis workflow returned an invalid response',
        );
      }
      return {
        answer: parsed.data.answer,
        suggestions: parsed.data.suggestions.slice(0, 5),
      };
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        throw serviceUnavailable('ai_analysis_timeout', 'AI analysis workflow timed out');
      }
      if (error instanceof ApiError) {
        throw error;
      }
      throw serviceUnavailable('ai_analysis_unavailable', 'AI analysis workflow is unavailable');
    } finally {
      clearTimeout(timeout);
    }
  });
}
