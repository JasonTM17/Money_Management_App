import type { Prisma } from '@prisma/client';
import type { FastifyInstance } from 'fastify';
import { serializeBigInts } from '../../lib/finance-serializers.js';

type SyncEntityType =
  | 'wallet'
  | 'category'
  | 'transaction'
  | 'budget'
  | 'savingGoal'
  | 'household'
  | 'sharedBudget'
  | 'entitlement';

type SyncOperation = 'create' | 'update' | 'delete';

type SyncRecord = {
  id: string;
  revision: bigint | number;
};

export async function recordSyncEvent(
  app: FastifyInstance,
  userId: string,
  entityType: SyncEntityType,
  operation: SyncOperation,
  record: SyncRecord,
) {
  const payload = serializeBigInts(record);
  await app.prisma.syncEvent.create({
    data: {
      userId,
      entityType,
      entityId: record.id,
      operation,
      revision: BigInt(payload.revision),
      payload: payload as Prisma.InputJsonValue,
    },
  });
}

export function serializeSyncEvent<T extends { payload: unknown }>(event: T) {
  return serializeBigInts(event);
}
