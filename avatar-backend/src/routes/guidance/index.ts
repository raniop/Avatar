import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import prisma from '../../config/prisma';

const createGuidanceSchema = z.object({
  childId: z.string().uuid('Invalid child ID'),
  instruction: z.string().min(1, 'Instruction is required').max(1000),
});

const updateGuidanceSchema = z.object({
  instruction: z.string().min(1).max(1000).optional(),
  isActive: z.boolean().optional(),
});

type CreateGuidanceBody = z.infer<typeof createGuidanceSchema>;
type UpdateGuidanceBody = z.infer<typeof updateGuidanceSchema>;

export async function guidanceRoutes(fastify: FastifyInstance) {
  // All guidance routes require authentication
  fastify.addHook('onRequest', fastify.authenticate);

  // ── List guidance for a child ──────────────────
  fastify.get(
    '/child/:childId',
    async (
      request: FastifyRequest<{
        Params: { childId: string };
        Querystring: { activeOnly?: string };
      }>,
      reply: FastifyReply,
    ) => {
      const { childId } = request.params;
      const activeOnly = request.query.activeOnly !== 'false';

      // Verify child belongs to user
      const child = await prisma.child.findFirst({
        where: { id: childId, parentId: request.user.userId },
      });

      if (!child) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Child not found',
        });
      }

      const guidance = await prisma.parentGuidance.findMany({
        where: {
          childId,
          ...(activeOnly && { isActive: true }),
        },
        orderBy: { createdAt: 'desc' },
      });

      return reply.send({ guidance });
    },
  );

  // ── Create guidance ────────────────────────────
  fastify.post(
    '/',
    async (
      request: FastifyRequest<{ Body: CreateGuidanceBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = createGuidanceSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const { childId, instruction } = parsed.data;

      // Verify child belongs to user
      const child = await prisma.child.findFirst({
        where: { id: childId, parentId: request.user.userId },
      });

      if (!child) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Child not found',
        });
      }

      const guidance = await prisma.parentGuidance.create({
        data: {
          childId,
          instruction,
        },
      });

      return reply.status(201).send({ guidance });
    },
  );

  // ── Update guidance ────────────────────────────
  fastify.put(
    '/:guidanceId',
    async (
      request: FastifyRequest<{
        Params: { guidanceId: string };
        Body: UpdateGuidanceBody;
      }>,
      reply: FastifyReply,
    ) => {
      const { guidanceId } = request.params;

      // Verify ownership
      const existing = await prisma.parentGuidance.findFirst({
        where: {
          id: guidanceId,
          child: { parentId: request.user.userId },
        },
      });

      if (!existing) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Guidance not found',
        });
      }

      const parsed = updateGuidanceSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const data = parsed.data;

      const guidance = await prisma.parentGuidance.update({
        where: { id: guidanceId },
        data: {
          ...(data.instruction !== undefined && { instruction: data.instruction }),
          ...(data.isActive !== undefined && { isActive: data.isActive }),
        },
      });

      return reply.send({ guidance });
    },
  );

  // ── Delete guidance ────────────────────────────
  fastify.delete(
    '/:guidanceId',
    async (
      request: FastifyRequest<{ Params: { guidanceId: string } }>,
      reply: FastifyReply,
    ) => {
      const { guidanceId } = request.params;

      // Verify ownership
      const existing = await prisma.parentGuidance.findFirst({
        where: {
          id: guidanceId,
          child: { parentId: request.user.userId },
        },
      });

      if (!existing) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Guidance not found',
        });
      }

      await prisma.parentGuidance.delete({ where: { id: guidanceId } });

      return reply.status(204).send();
    },
  );
}
