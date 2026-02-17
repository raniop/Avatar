import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import prisma from '../../config/prisma';

const registerTokenSchema = z.object({
  token: z.string().min(1, 'Token is required'),
  platform: z.enum(['ios', 'android', 'web']).default('ios'),
  role: z.enum(['parent', 'child']).default('parent'),
});

const unregisterTokenSchema = z.object({
  token: z.string().min(1, 'Token is required'),
});

type RegisterTokenBody = z.infer<typeof registerTokenSchema>;
type UnregisterTokenBody = z.infer<typeof unregisterTokenSchema>;

export async function deviceRoutes(fastify: FastifyInstance) {
  // All device routes require authentication
  fastify.addHook('onRequest', fastify.authenticate);

  // ── Register / update device token ─────────────
  fastify.post(
    '/token',
    async (
      request: FastifyRequest<{ Body: RegisterTokenBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = registerTokenSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const { token, platform, role } = parsed.data;

      // Upsert: if token exists, update userId/role/isActive
      const deviceToken = await prisma.deviceToken.upsert({
        where: { token },
        update: {
          userId: request.user.userId,
          platform,
          role,
          isActive: true,
        },
        create: {
          userId: request.user.userId,
          token,
          platform,
          role,
        },
      });

      return reply.status(200).send({
        deviceToken: {
          id: deviceToken.id,
          token: deviceToken.token,
          platform: deviceToken.platform,
          role: deviceToken.role,
          isActive: deviceToken.isActive,
        },
      });
    },
  );

  // ── Unregister device token ────────────────────
  fastify.delete(
    '/token',
    async (
      request: FastifyRequest<{ Body: UnregisterTokenBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = unregisterTokenSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const { token } = parsed.data;

      // Soft-delete: set isActive = false
      await prisma.deviceToken.updateMany({
        where: {
          token,
          userId: request.user.userId,
        },
        data: { isActive: false },
      });

      return reply.status(204).send();
    },
  );
}
