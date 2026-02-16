import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import prisma from '../../config/prisma';

const createAvatarSchema = z.object({
  childId: z.string().uuid('Invalid child ID'),
  name: z.string().min(1, 'Name is required').max(50),
  skinTone: z.string().min(1),
  hairStyle: z.string().min(1),
  hairColor: z.string().min(1),
  eyeColor: z.string().min(1),
  outfit: z.string().min(1),
  accessories: z.array(z.string()).default([]),
  voiceId: z.string().optional(),
  personalityTraits: z.array(z.string()).default([]),
});

const updateAvatarSchema = z.object({
  name: z.string().min(1).max(50).optional(),
  skinTone: z.string().min(1).optional(),
  hairStyle: z.string().min(1).optional(),
  hairColor: z.string().min(1).optional(),
  eyeColor: z.string().min(1).optional(),
  outfit: z.string().min(1).optional(),
  accessories: z.array(z.string()).optional(),
  voiceId: z.string().optional().nullable(),
  personalityTraits: z.array(z.string()).optional(),
});

type CreateAvatarBody = z.infer<typeof createAvatarSchema>;
type UpdateAvatarBody = z.infer<typeof updateAvatarSchema>;

export async function avatarRoutes(fastify: FastifyInstance) {
  // All avatar routes require authentication
  fastify.addHook('onRequest', fastify.authenticate);

  // ── Get avatar by child ID ───────────────────────
  fastify.get(
    '/child/:childId',
    async (
      request: FastifyRequest<{ Params: { childId: string } }>,
      reply: FastifyReply,
    ) => {
      const { childId } = request.params;

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

      const avatar = await prisma.avatar.findUnique({
        where: { childId },
      });

      if (!avatar) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Avatar not found for this child',
        });
      }

      return reply.send({ avatar });
    },
  );

  // ── Create avatar ────────────────────────────────
  fastify.post(
    '/',
    async (
      request: FastifyRequest<{ Body: CreateAvatarBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = createAvatarSchema.safeParse(request.body);
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

      // Check if avatar already exists
      const existingAvatar = await prisma.avatar.findUnique({
        where: { childId: data.childId },
      });

      if (existingAvatar) {
        return reply.status(409).send({
          error: true,
          statusCode: 409,
          message: 'An avatar already exists for this child. Use PUT to update.',
        });
      }

      const avatar = await prisma.avatar.create({
        data: {
          childId: data.childId,
          name: data.name,
          skinTone: data.skinTone,
          hairStyle: data.hairStyle,
          hairColor: data.hairColor,
          eyeColor: data.eyeColor,
          outfit: data.outfit,
          accessories: data.accessories,
          voiceId: data.voiceId,
          personalityTraits: data.personalityTraits,
        },
      });

      return reply.status(201).send({ avatar });
    },
  );

  // ── Update avatar ────────────────────────────────
  fastify.put(
    '/:avatarId',
    async (
      request: FastifyRequest<{
        Params: { avatarId: string };
        Body: UpdateAvatarBody;
      }>,
      reply: FastifyReply,
    ) => {
      const { avatarId } = request.params;

      // Verify ownership through child relationship
      const existingAvatar = await prisma.avatar.findUnique({
        where: { id: avatarId },
        include: { child: { select: { parentId: true } } },
      });

      if (!existingAvatar || existingAvatar.child.parentId !== request.user.userId) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Avatar not found',
        });
      }

      const parsed = updateAvatarSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const data = parsed.data;

      const avatar = await prisma.avatar.update({
        where: { id: avatarId },
        data: {
          ...(data.name !== undefined && { name: data.name }),
          ...(data.skinTone !== undefined && { skinTone: data.skinTone }),
          ...(data.hairStyle !== undefined && { hairStyle: data.hairStyle }),
          ...(data.hairColor !== undefined && { hairColor: data.hairColor }),
          ...(data.eyeColor !== undefined && { eyeColor: data.eyeColor }),
          ...(data.outfit !== undefined && { outfit: data.outfit }),
          ...(data.accessories !== undefined && { accessories: data.accessories }),
          ...(data.voiceId !== undefined && { voiceId: data.voiceId }),
          ...(data.personalityTraits !== undefined && {
            personalityTraits: data.personalityTraits,
          }),
        },
      });

      return reply.send({ avatar });
    },
  );

  // ── Set avatar name (upsert — creates minimal avatar if none exists) ──
  fastify.patch(
    '/child/:childId/name',
    async (
      request: FastifyRequest<{
        Params: { childId: string };
        Body: { name: string; voiceId?: string };
      }>,
      reply: FastifyReply,
    ) => {
      const { childId } = request.params;
      const { name, voiceId } = request.body;

      if (!name || typeof name !== 'string' || name.length > 50) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Name is required (max 50 chars)',
        });
      }

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

      // Upsert: update name (and voiceId if provided) if avatar exists, create minimal one if not
      const avatar = await prisma.avatar.upsert({
        where: { childId },
        update: { name, ...(voiceId !== undefined && { voiceId }) },
        create: {
          childId,
          name,
          skinTone: 'default',
          hairStyle: 'default',
          hairColor: 'default',
          eyeColor: 'default',
          outfit: 'default',
          ...(voiceId !== undefined && { voiceId }),
        },
      });

      return reply.send({ avatar });
    },
  );
}
