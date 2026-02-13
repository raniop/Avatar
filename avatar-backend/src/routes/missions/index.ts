import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import prisma from '../../config/prisma';

const listMissionsQuery = z.object({
  age: z
    .string()
    .optional()
    .transform((val) => (val ? parseInt(val, 10) : undefined)),
  theme: z.string().optional(),
  locale: z.enum(['en', 'he']).default('en'),
});

export async function missionRoutes(fastify: FastifyInstance) {
  // All mission routes require authentication
  fastify.addHook('onRequest', fastify.authenticate);

  // ── List missions ────────────────────────────────
  fastify.get(
    '/',
    async (
      request: FastifyRequest<{
        Querystring: { age?: string; theme?: string; locale?: string };
      }>,
      reply: FastifyReply,
    ) => {
      const parsed = listMissionsQuery.safeParse(request.query);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Invalid query parameters',
        });
      }

      const { age, theme, locale } = parsed.data;

      const missions = await prisma.missionTemplate.findMany({
        where: {
          isActive: true,
          ...(age !== undefined && {
            ageRangeMin: { lte: age },
            ageRangeMax: { gte: age },
          }),
          ...(theme && { theme }),
        },
        select: {
          id: true,
          theme: true,
          titleEn: true,
          titleHe: true,
          descriptionEn: true,
          descriptionHe: true,
          ageRangeMin: true,
          ageRangeMax: true,
          durationMinutes: true,
          sceneryAssetKey: true,
          avatarCostumeKey: true,
          sortOrder: true,
        },
        orderBy: { sortOrder: 'asc' },
      });

      // Localize response
      const localizedMissions = missions.map((m) => ({
        id: m.id,
        theme: m.theme,
        title: locale === 'he' ? m.titleHe : m.titleEn,
        description: locale === 'he' ? m.descriptionHe : m.descriptionEn,
        ageRangeMin: m.ageRangeMin,
        ageRangeMax: m.ageRangeMax,
        durationMinutes: m.durationMinutes,
        sceneryAssetKey: m.sceneryAssetKey,
        avatarCostumeKey: m.avatarCostumeKey,
        sortOrder: m.sortOrder,
      }));

      return reply.send({ missions: localizedMissions });
    },
  );

  // ── Get single mission ───────────────────────────
  fastify.get(
    '/:missionId',
    async (
      request: FastifyRequest<{
        Params: { missionId: string };
        Querystring: { locale?: string };
      }>,
      reply: FastifyReply,
    ) => {
      const { missionId } = request.params;
      const locale = request.query.locale || 'en';

      const mission = await prisma.missionTemplate.findUnique({
        where: { id: missionId },
      });

      if (!mission) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Mission not found',
        });
      }

      return reply.send({
        mission: {
          id: mission.id,
          theme: mission.theme,
          title: locale === 'he' ? mission.titleHe : mission.titleEn,
          description:
            locale === 'he' ? mission.descriptionHe : mission.descriptionEn,
          narrativePrompt: mission.narrativePrompt,
          ageRangeMin: mission.ageRangeMin,
          ageRangeMax: mission.ageRangeMax,
          durationMinutes: mission.durationMinutes,
          sceneryAssetKey: mission.sceneryAssetKey,
          avatarCostumeKey: mission.avatarCostumeKey,
        },
      });
    },
  );

  // ── Get daily mission for a child ────────────────
  fastify.get(
    '/daily/:childId',
    async (
      request: FastifyRequest<{
        Params: { childId: string };
        Querystring: { locale?: string };
      }>,
      reply: FastifyReply,
    ) => {
      const { childId } = request.params;
      const locale = request.query.locale || 'en';

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

      // Get today's completed conversations to avoid repeats
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);

      const todaysConversations = await prisma.conversation.findMany({
        where: {
          childId,
          startedAt: { gte: todayStart },
          missionId: { not: null },
        },
        select: { missionId: true },
      });

      const completedMissionIds = todaysConversations
        .map((c) => c.missionId)
        .filter((id): id is string => id !== null);

      // Find a mission matching child's age that hasn't been done today
      const mission = await prisma.missionTemplate.findFirst({
        where: {
          isActive: true,
          ageRangeMin: { lte: child.age },
          ageRangeMax: { gte: child.age },
          ...(completedMissionIds.length > 0 && {
            id: { notIn: completedMissionIds },
          }),
        },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      });

      if (!mission) {
        return reply.send({
          mission: null,
          message: 'No new missions available today',
        });
      }

      return reply.send({
        mission: {
          id: mission.id,
          theme: mission.theme,
          title: locale === 'he' ? mission.titleHe : mission.titleEn,
          description:
            locale === 'he' ? mission.descriptionHe : mission.descriptionEn,
          durationMinutes: mission.durationMinutes,
          sceneryAssetKey: mission.sceneryAssetKey,
          avatarCostumeKey: mission.avatarCostumeKey,
        },
      });
    },
  );
}
