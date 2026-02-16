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

// Keep the database connection warm to avoid cold-start latency (~3s).
// Runs a trivial query every 4 minutes so the connection pool stays alive.
const WARMUP_INTERVAL_MS = 4 * 60 * 1000;
setInterval(() => {
  prisma.$queryRaw`SELECT 1`.catch(() => {});
}, WARMUP_INTERVAL_MS);

// Eagerly connect on import so the first real query doesn't pay the cost.
prisma.$connect().catch(() => {});

export default prisma;
