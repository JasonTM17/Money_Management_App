import { z } from 'zod';

export const idParamSchema = z.object({ id: z.string().uuid() });
export const inviteParamSchema = z.object({ inviteId: z.string().uuid() });
export const memberParamSchema = z.object({
  householdId: z.string().uuid(),
  memberId: z.string().uuid(),
});
export const sharedBudgetParamSchema = z.object({
  householdId: z.string().uuid(),
  budgetId: z.string().uuid(),
});

export const householdSchema = z.object({
  name: z.string().trim().min(1),
});

export const inviteSchema = z.object({
  email: z.string().email().transform((value) => value.trim().toLowerCase()),
  expiresInDays: z.number().int().positive().max(30).default(7),
});

export const acceptInviteSchema = z.object({
  token: z.string().trim().min(1),
});

export const sharedBudgetSchema = z.object({
  name: z.string().trim().min(1),
  categoryId: z.string().uuid().nullable().optional(),
  month: z.string().date(),
  limitAmount: z.number().int().positive(),
});

export const sharedBudgetPatchSchema = sharedBudgetSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);
