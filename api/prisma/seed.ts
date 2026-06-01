import { hashPassword } from '../src/lib/passwords-and-tokens.js';
import { createPrismaClient } from '../src/lib/prisma-client.js';

const databaseUrl =
  process.env.DATABASE_URL ??
  'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public';
const prisma = createPrismaClient(databaseUrl);

async function main() {
  const passwordHash = await hashPassword('cashflow-demo-local-only');
  const user = await prisma.user.upsert({
    where: { email: 'demo@cashflow.local' },
    update: { passwordHash },
    create: {
      email: 'demo@cashflow.local',
      passwordHash,
    },
  });

  await prisma.transaction.deleteMany({ where: { userId: user.id } });
  await prisma.budget.deleteMany({ where: { userId: user.id } });
  await prisma.savingGoal.deleteMany({ where: { userId: user.id } });
  await prisma.wallet.deleteMany({ where: { userId: user.id } });
  await prisma.category.deleteMany({ where: { userId: user.id } });

  const cashWallet = await prisma.wallet.create({
    data: {
      userId: user.id,
      name: 'Tiền mặt',
      type: 'cash',
      initialBalance: 2500000n,
    },
  });

  const bankWallet = await prisma.wallet.create({
    data: {
      userId: user.id,
      name: 'Ngân hàng',
      type: 'bank',
      initialBalance: 15000000n,
    },
  });

  const salary = await prisma.category.create({
    data: {
      userId: user.id,
      name: 'Lương',
      type: 'income',
      colorHex: 0x2563eb,
    },
  });

  const food = await prisma.category.create({
    data: {
      userId: user.id,
      name: 'Ăn uống',
      type: 'expense',
      colorHex: 0xef4444,
    },
  });

  const transfer = await prisma.category.create({
    data: {
      userId: user.id,
      name: 'Chuyển khoản',
      type: 'transfer',
      colorHex: 0x16a34a,
    },
  });

  await prisma.transaction.createMany({
    data: [
      {
        userId: user.id,
        walletId: bankWallet.id,
        categoryId: salary.id,
        type: 'income',
        amount: 18000000n,
        date: new Date('2026-05-01T02:00:00.000Z'),
        note: 'Lương tháng 5',
      },
      {
        userId: user.id,
        walletId: cashWallet.id,
        categoryId: food.id,
        type: 'expense',
        amount: 85000n,
        date: new Date('2026-05-05T12:00:00.000Z'),
        note: 'Cà phê và ăn trưa',
      },
      {
        userId: user.id,
        walletId: bankWallet.id,
        toWalletId: cashWallet.id,
        categoryId: transfer.id,
        type: 'transfer',
        amount: 1000000n,
        date: new Date('2026-05-10T03:00:00.000Z'),
        note: 'Rút tiền mặt',
      },
    ],
  });

  await prisma.budget.create({
    data: {
      userId: user.id,
      categoryId: food.id,
      month: new Date('2026-05-01T00:00:00.000Z'),
      limitAmount: 3000000n,
    },
  });

  await prisma.savingGoal.create({
    data: {
      userId: user.id,
      name: 'Quỹ khẩn cấp',
      targetAmount: 50000000n,
      savedAmount: 12000000n,
      deadline: new Date('2026-12-31T00:00:00.000Z'),
    },
  });
}

main()
  .finally(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    process.exit(1);
  });
