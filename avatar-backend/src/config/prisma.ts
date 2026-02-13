import { PrismaClient } from '@prisma/client';
import { isDev } from './environment';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ||
  new PrismaClient({
    log: isDev() ? ['query', 'warn', 'error'] : ['error'],
  });

if (isDev()) {
  globalForPrisma.prisma = prisma;
}

export default prisma;
