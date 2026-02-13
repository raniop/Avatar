import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import prisma from '../../config/prisma';

const createQuestionSchema = z.object({
  childId: z.string().uuid('Invalid child ID'),
  questionText: z.string().min(1, 'Question text is required').max(500),
  topic: z.string().max(100).optional(),
  priority: z.number().int().min(0).max(10).default(0),
  isRecurring: z.boolean().default(false),
});

const updateQuestionSchema = z.object({
  questionText: z.string().min(1).max(500).optional(),
  topic: z.string().max(100).optional().nullable(),
  priority: z.number().int().min(0).max(10).optional(),
  isActive: z.boolean().optional(),
  isRecurring: z.boolean().optional(),
});

type CreateQuestionBody = z.infer<typeof createQuestionSchema>;
type UpdateQuestionBody = z.infer<typeof updateQuestionSchema>;

export async function questionRoutes(fastify: FastifyInstance) {
  // All question routes require authentication
  fastify.addHook('onRequest', fastify.authenticate);

  // ── List questions for a child ───────────────────
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

      const questions = await prisma.parentQuestion.findMany({
        where: {
          childId,
          ...(activeOnly && { isActive: true }),
        },
        orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
      });

      return reply.send({ questions });
    },
  );

  // ── Get single question ──────────────────────────
  fastify.get(
    '/:questionId',
    async (
      request: FastifyRequest<{ Params: { questionId: string } }>,
      reply: FastifyReply,
    ) => {
      const { questionId } = request.params;

      const question = await prisma.parentQuestion.findFirst({
        where: {
          id: questionId,
          child: { parentId: request.user.userId },
        },
      });

      if (!question) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Question not found',
        });
      }

      return reply.send({ question });
    },
  );

  // ── Create question ──────────────────────────────
  fastify.post(
    '/',
    async (
      request: FastifyRequest<{ Body: CreateQuestionBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = createQuestionSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const data = parsed.data;

      // Verify child belongs to user
      const child = await prisma.child.findFirst({
        where: { id: data.childId, parentId: request.user.userId },
      });

      if (!child) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Child not found',
        });
      }

      const question = await prisma.parentQuestion.create({
        data: {
          childId: data.childId,
          questionText: data.questionText,
          topic: data.topic,
          priority: data.priority,
          isRecurring: data.isRecurring,
        },
      });

      return reply.status(201).send({ question });
    },
  );

  // ── Update question ──────────────────────────────
  fastify.put(
    '/:questionId',
    async (
      request: FastifyRequest<{
        Params: { questionId: string };
        Body: UpdateQuestionBody;
      }>,
      reply: FastifyReply,
    ) => {
      const { questionId } = request.params;

      // Verify ownership
      const existing = await prisma.parentQuestion.findFirst({
        where: {
          id: questionId,
          child: { parentId: request.user.userId },
        },
      });

      if (!existing) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Question not found',
        });
      }

      const parsed = updateQuestionSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const data = parsed.data;

      const question = await prisma.parentQuestion.update({
        where: { id: questionId },
        data: {
          ...(data.questionText !== undefined && {
            questionText: data.questionText,
          }),
          ...(data.topic !== undefined && { topic: data.topic }),
          ...(data.priority !== undefined && { priority: data.priority }),
          ...(data.isActive !== undefined && { isActive: data.isActive }),
          ...(data.isRecurring !== undefined && {
            isRecurring: data.isRecurring,
          }),
        },
      });

      return reply.send({ question });
    },
  );

  // ── Delete question ──────────────────────────────
  fastify.delete(
    '/:questionId',
    async (
      request: FastifyRequest<{ Params: { questionId: string } }>,
      reply: FastifyReply,
    ) => {
      const { questionId } = request.params;

      // Verify ownership
      const existing = await prisma.parentQuestion.findFirst({
        where: {
          id: questionId,
          child: { parentId: request.user.userId },
        },
      });

      if (!existing) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Question not found',
        });
      }

      await prisma.parentQuestion.delete({ where: { id: questionId } });

      return reply.status(204).send();
    },
  );
}
