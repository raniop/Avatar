import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import prisma from '../../config/prisma';

const listMissionsQuery = z.object({
  age: z
    .string()
    .optional()
    .transform((val) => (val ? parseInt(val, 10) : undefined)),
  theme: z.string().optional(),
  interests: z.string().optional(),
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
        Querystring: { age?: string; theme?: string; interests?: string; locale?: string };
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

      const { age, theme, interests, locale } = parsed.data;
      const interestList = interests
        ? interests.split(',').map((s) => s.trim()).filter(Boolean)
        : [];

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
          interests: true,
          sortOrder: true,
        },
        orderBy: { sortOrder: 'asc' },
      });

      // Sort: missions with more matching interests first, then by sortOrder
      const sorted = interestList.length > 0
        ? [...missions].sort((a, b) => {
            const aCount = a.interests.filter((i) =>
              interestList.some((ci) => ci.toLowerCase() === i.toLowerCase()),
            ).length;
            const bCount = b.interests.filter((i) =>
              interestList.some((ci) => ci.toLowerCase() === i.toLowerCase()),
            ).length;
            if (bCount !== aCount) return bCount - aCount; // more matches first
            return a.sortOrder - b.sortOrder;
          })
        : missions;

      // Localize response
      const localizedMissions = sorted.map((m) => ({
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

  // ── Get adventure progress for a child ───────────
  fastify.get(
    '/progress/:childId',
    async (
      request: FastifyRequest<{
        Params: { childId: string };
      }>,
      reply: FastifyReply,
    ) => {
      const { childId } = request.params;

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

      const progress = await prisma.adventureProgress.findMany({
        where: { childId },
        select: {
          missionId: true,
          depth: true,
          starsEarned: true,
          collectibles: true,
          completedAt: true,
        },
      });

      const totalStars = progress.reduce((sum, p) => sum + p.starsEarned, 0);
      const allCollectibles = progress.flatMap((p) =>
        Array.isArray(p.collectibles) ? (p.collectibles as any[]) : [],
      );

      return reply.send({
        progress,
        totalStars,
        collectibles: allCollectibles,
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
