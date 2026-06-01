import { z } from 'zod';

export const idParamSchema = z.object({
  id: z.string().uuid(),
});

export const walletSchema = z.object({
  name: z.string().trim().min(1),
  type: z.enum(['cash', 'bank', 'eWallet', 'creditCard']),
  initialBalance: z.number().int().nonnegative(),
});

export const walletPatchSchema = walletSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

export const categorySchema = z.object({
  name: z.string().trim().min(1),
  type: z.enum(['income', 'expense', 'transfer']),
  colorHex: z.number().int(),
});

export const categoryPatchSchema = categorySchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

export const transactionSchema = z.object({
  walletId: z.string().uuid(),
  toWalletId: z.string().uuid().nullable().optional(),
  categoryId: z.string().uuid(),
  type: z.enum(['income', 'expense', 'transfer']),
  amount: z.number().int().positive(),
  date: z.string().datetime(),
  note: z.string(),
  isRecurring: z.boolean(),
});

export const transactionPatchSchema = transactionSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

export const transactionQuerySchema = z.object({
  month: z.string().date().optional(),
});

export const budgetSchema = z.object({
  categoryId: z.string().uuid(),
  month: z.string().date(),
  limitAmount: z.number().int().positive(),
});

export const budgetPatchSchema = budgetSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

export const savingGoalSchema = z.object({
  name: z.string().trim().min(1),
  targetAmount: z.number().int().positive(),
  savedAmount: z.number().int().nonnegative(),
  deadline: z.string().date(),
});

export const savingGoalPatchSchema = savingGoalSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);
