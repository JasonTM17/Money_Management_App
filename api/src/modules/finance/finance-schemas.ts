import { z } from 'zod';

function isFirstDayDateOnly(value: string) {
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.getUTCDate() === 1;
}

function savedAmountDoesNotExceedTarget(value: {
  targetAmount?: number;
  savedAmount?: number;
}) {
  return (
    value.targetAmount === undefined ||
    value.savedAmount === undefined ||
    value.savedAmount <= value.targetAmount
  );
}

function transferTargetShapeIsValid(value: {
  type?: 'income' | 'expense' | 'transfer';
  toWalletId?: string | null;
}) {
  return (
    value.type === undefined ||
    value.type === 'transfer' ||
    value.toWalletId === undefined ||
    value.toWalletId === null
  );
}

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

const transactionBaseSchema = z.object({
  walletId: z.string().uuid(),
  toWalletId: z.string().uuid().nullable().optional(),
  categoryId: z.string().uuid(),
  type: z.enum(['income', 'expense', 'transfer']),
  amount: z.number().int().positive(),
  date: z.string().datetime(),
  note: z.string(),
  isRecurring: z.boolean(),
});

export const transactionSchema = transactionBaseSchema.refine(
  transferTargetShapeIsValid,
  'Income and expense transactions cannot have a transfer target',
);

export const transactionPatchSchema = transactionBaseSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
).refine(
  transferTargetShapeIsValid,
  'Income and expense transactions cannot have a transfer target',
);

export const transactionQuerySchema = z.object({
  month: z.string().date().optional(),
});

const budgetBaseSchema = z.object({
  categoryId: z.string().uuid(),
  month: z.string().date().refine(
    isFirstDayDateOnly,
    'Budget month must be the first day of the month',
  ),
  limitAmount: z.number().int().positive(),
});

export const budgetSchema = budgetBaseSchema;

export const budgetPatchSchema = budgetBaseSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

const savingGoalBaseSchema = z.object({
  name: z.string().trim().min(1),
  targetAmount: z.number().int().positive(),
  savedAmount: z.number().int().nonnegative(),
  deadline: z.string().date(),
});

export const savingGoalSchema = savingGoalBaseSchema.refine(
  savedAmountDoesNotExceedTarget,
  'Saved amount must not exceed target amount',
);

export const savingGoalPatchSchema = savingGoalBaseSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
).refine(
  savedAmountDoesNotExceedTarget,
  'Saved amount must not exceed target amount',
);