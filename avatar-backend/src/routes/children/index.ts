import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import prisma from '../../config/prisma';

const createChildSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  age: z.number().int().min(2).max(12),
  birthday: z.string().datetime().optional(),
  gender: z.string().optional(),
  interests: z.array(z.string()).default([]),
  developmentGoals: z.array(z.string()).default([]),
  locale: z.enum(['en', 'he']).default('en'),
});

const updateChildSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  age: z.number().int().min(2).max(12).optional(),
  birthday: z.string().datetime().optional().nullable(),
  gender: z.string().optional().nullable(),
  interests: z.array(z.string()).optional(),
  developmentGoals: z.array(z.string()).optional(),
  locale: z.enum(['en', 'he']).optional(),
});

type CreateChildBody = z.infer<typeof createChildSchema>;
type UpdateChildBody = z.infer<typeof updateChildSchema>;

export async function childrenRoutes(fastify: FastifyInstance) {
  // All children routes require authentication
  fastify.addHook('onRequest', fastify.authenticate);

  // ── List children ────────────────────────────────
  fastify.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const children = await prisma.child.findMany({
      where: { parentId: request.user.userId },
      include: {
        avatar: {
          select: {
            id: true,
            name: true,
            skinTone: true,
            hairStyle: true,
            hairColor: true,
            eyeColor: true,
            outfit: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    return reply.send({ children });
  });

  // ── Get single child ─────────────────────────────
  fastify.get(
    '/:childId',
    async (
      request: FastifyRequest<{ Params: { childId: string } }>,
      reply: FastifyReply,
    ) => {
      const { childId } = request.params;

      const child = await prisma.child.findFirst({
        where: {
          id: childId,
          parentId: request.user.userId,
        },
        include: {
          avatar: true,
          parentQuestions: {
            where: { isActive: true },
            orderBy: { priority: 'desc' },
          },
        },
      });

      if (!child) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Child not found',
        });
      }

      return reply.send({ child });
    },
  );

  // ── Create child ─────────────────────────────────
  fastify.post(
    '/',
    async (
      request: FastifyRequest<{ Body: CreateChildBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = createChildSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const data = parsed.data;

      const child = await prisma.child.create({
        data: {
          parentId: request.user.userId,
          name: data.name,
          age: data.age,
          birthday: data.birthday ? new Date(data.birthday) : null,
          gender: data.gender,
          interests: data.interests,
          developmentGoals: data.developmentGoals,
          locale: data.locale,
        },
        include: {
          avatar: true,
        },
      });

      return reply.status(201).send({ child });
    },
  );

  // ── Update child ─────────────────────────────────
  fastify.put(
    '/:childId',
    async (
      request: FastifyRequest<{
        Params: { childId: string };
        Body: UpdateChildBody;
      }>,
      reply: FastifyReply,
    ) => {
      const { childId } = request.params;

      // Verify ownership
      const existing = await prisma.child.findFirst({
        where: { id: childId, parentId: request.user.userId },
      });

      if (!existing) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Child not found',
        });
      }

      const parsed = updateChildSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const data = parsed.data;

      const child = await prisma.child.update({
        where: { id: childId },
        data: {
          ...(data.name !== undefined && { name: data.name }),
          ...(data.age !== undefined && { age: data.age }),
          ...(data.birthday !== undefined && {
            birthday: data.birthday ? new Date(data.birthday) : null,
          }),
          ...(data.gender !== undefined && { gender: data.gender }),
          ...(data.interests !== undefined && { interests: data.interests }),
          ...(data.developmentGoals !== undefined && {
            developmentGoals: data.developmentGoals,
          }),
          ...(data.locale !== undefined && { locale: data.locale }),
        },
        include: { avatar: true },
      });

      return reply.send({ child });
    },
  );

  // ── Delete child ─────────────────────────────────
  fastify.delete(
    '/:childId',
    async (
      request: FastifyRequest<{ Params: { childId: string } }>,
      reply: FastifyReply,
    ) => {
      const { childId } = request.params;

      // Verify ownership
      const existing = await prisma.child.findFirst({
        where: { id: childId, parentId: request.user.userId },
      });

      if (!existing) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Child not found',
        });
      }

      await prisma.child.delete({ where: { id: childId } });

      return reply.status(204).send();
    },
  );
}
