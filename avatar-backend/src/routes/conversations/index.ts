import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import prisma from '../../config/prisma';
import { ConversationEngine } from '../../services/conversation-engine/ConversationEngine';
import { SummaryEngine } from '../../services/summary-engine/SummaryEngine';
import { VoicePipeline } from '../../services/voice-pipeline/VoicePipeline';

const createConversationSchema = z.object({
  childId: z.string().uuid('Invalid child ID'),
  missionId: z.string().uuid('Invalid mission ID').optional(),
  locale: z.enum(['en', 'he']).default('en'),
});

const sendMessageSchema = z.object({
  textContent: z.string().min(1, 'Message cannot be empty').max(2000),
});

const parentInterventionSchema = z.object({
  textContent: z.string().min(1, 'Message cannot be empty').max(1000),
});

type CreateConversationBody = z.infer<typeof createConversationSchema>;
type SendMessageBody = z.infer<typeof sendMessageSchema>;
type ParentInterventionBody = z.infer<typeof parentInterventionSchema>;

export async function conversationRoutes(fastify: FastifyInstance) {
  // All conversation routes require authentication
  fastify.addHook('onRequest', fastify.authenticate);

  const conversationEngine = new ConversationEngine();
  const summaryEngine = new SummaryEngine();
  const voicePipeline = new VoicePipeline();

  // ── Create conversation ──────────────────────────
  fastify.post(
    '/',
    async (
      request: FastifyRequest<{ Body: CreateConversationBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = createConversationSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const { childId, missionId, locale } = parsed.data;

      // Verify child belongs to user
      const child = await prisma.child.findFirst({
        where: { id: childId, parentId: request.user.userId },
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

      // Load mission if provided
      let mission = null;
      if (missionId) {
        mission = await prisma.missionTemplate.findUnique({
          where: { id: missionId },
        });
        if (!mission) {
          return reply.status(404).send({
            error: true,
            statusCode: 404,
            message: 'Mission not found',
          });
        }
      }

      // Build system prompt
      const systemPrompt = conversationEngine.buildSystemPrompt({
        child,
        avatar: child.avatar,
        mission,
        parentQuestions: child.parentQuestions,
        locale,
      });

      // Create conversation
      const conversation = await prisma.conversation.create({
        data: {
          childId,
          missionId: missionId || null,
          locale,
          systemPrompt,
          status: 'ACTIVE',
        },
      });

      // Generate a fast template-based opening message (no AI call needed for greetings)
      const avatarName = child.avatar?.name || 'Buddy';
      const openingMessage = generateFastOpeningMessage(child.name, avatarName, mission, locale);

      // Run TTS and DB save in parallel to minimize wait time
      let openingAudioUrl: string | null = null;
      let openingAudioDuration: number | null = null;
      let openingAudioBuffer: Buffer | null = null;

      const ttsPromise = (async () => {
        try {
          console.log(`[TTS] Generating opening audio for: "${openingMessage.text.substring(0, 60)}...", voiceId=${child.avatar?.voiceId || 'default'}, age=${child.age}`);
          const ttsResult = await voicePipeline.generateAvatarAudio(
            openingMessage.text,
            child.avatar?.voiceId || undefined,
            child.age,
          );
          openingAudioUrl = ttsResult.audioUrl;
          openingAudioDuration = ttsResult.audioDuration;
          openingAudioBuffer = ttsResult.audioBuffer;
          console.log(`[TTS] Opening audio OK: url=${openingAudioUrl}, duration=${openingAudioDuration}s, bufferSize=${openingAudioBuffer.length}`);
        } catch (ttsError: any) {
          console.error('[TTS] Failed to generate opening TTS:', ttsError?.message || ttsError);
          // Continue without audio -- text will still appear
        }
      })();

      // Save the opening message (without audio URL initially)
      const dbSavePromise = prisma.message.create({
        data: {
          conversationId: conversation.id,
          role: 'AVATAR',
          textContent: openingMessage.text,
          emotion: openingMessage.emotion,
        },
      });

      // Wait for both TTS and DB save to complete in parallel
      const [, avatarMessage] = await Promise.all([ttsPromise, dbSavePromise]);

      // Update the message with audio URL if TTS succeeded
      if (openingAudioUrl) {
        await prisma.message.update({
          where: { id: avatarMessage.id },
          data: { audioUrl: openingAudioUrl, audioDuration: openingAudioDuration },
        });
      }

      return reply.status(201).send({
        conversation: {
          id: conversation.id,
          childId: conversation.childId,
          missionId: conversation.missionId,
          status: conversation.status,
          locale: conversation.locale,
          startedAt: conversation.startedAt,
        },
        openingMessage: {
          id: avatarMessage.id,
          role: avatarMessage.role,
          textContent: avatarMessage.textContent,
          emotion: avatarMessage.emotion,
          audioUrl: openingAudioUrl,
          audioData: openingAudioBuffer ? openingAudioBuffer.toString('base64') : null,
          timestamp: avatarMessage.timestamp,
        },
      });
    },
  );

  // ── Send text message ────────────────────────────
  fastify.post(
    '/:conversationId/messages',
    async (
      request: FastifyRequest<{
        Params: { conversationId: string };
        Body: SendMessageBody;
      }>,
      reply: FastifyReply,
    ) => {
      const { conversationId } = request.params;

      const parsed = sendMessageSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      // Verify conversation ownership and status
      const conversation = await prisma.conversation.findFirst({
        where: {
          id: conversationId,
          child: { parentId: request.user.userId },
          status: 'ACTIVE',
        },
        include: {
          child: {
            include: {
              avatar: true,
              parentQuestions: {
                where: { isActive: true },
                orderBy: { priority: 'desc' },
              },
            },
          },
          messages: {
            orderBy: { timestamp: 'asc' },
            take: 50, // Context window
          },
        },
      });

      if (!conversation) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Active conversation not found',
        });
      }

      const { textContent } = parsed.data;

      // Save child's message
      const childMessage = await prisma.message.create({
        data: {
          conversationId,
          role: 'CHILD',
          textContent,
        },
      });

      // Process through conversation engine
      const avatarResponse = await conversationEngine.processChildMessage({
        conversationId,
        childText: textContent,
        systemPrompt: conversation.systemPrompt,
        messageHistory: conversation.messages,
        child: conversation.child,
        avatar: conversation.child.avatar,
        parentQuestions: conversation.child.parentQuestions,
        locale: conversation.locale,
      });

      // Save avatar response
      const avatarMessage = await prisma.message.create({
        data: {
          conversationId,
          role: 'AVATAR',
          textContent: avatarResponse.text,
          emotion: avatarResponse.emotion,
          metadata: avatarResponse.metadata
            ? (avatarResponse.metadata as Prisma.InputJsonValue)
            : undefined,
        },
      });

      return reply.send({
        childMessage: {
          id: childMessage.id,
          role: childMessage.role,
          textContent: childMessage.textContent,
          timestamp: childMessage.timestamp,
        },
        avatarMessage: {
          id: avatarMessage.id,
          role: avatarMessage.role,
          textContent: avatarMessage.textContent,
          emotion: avatarMessage.emotion,
          timestamp: avatarMessage.timestamp,
        },
      });
    },
  );

  // ── Send voice message ───────────────────────────
  fastify.post(
    '/:conversationId/voice',
    async (
      request: FastifyRequest<{ Params: { conversationId: string } }>,
      reply: FastifyReply,
    ) => {
      const { conversationId } = request.params;

      // Verify conversation ownership and status
      const conversation = await prisma.conversation.findFirst({
        where: {
          id: conversationId,
          child: { parentId: request.user.userId },
          status: 'ACTIVE',
        },
        include: {
          child: {
            include: {
              avatar: true,
              parentQuestions: {
                where: { isActive: true },
                orderBy: { priority: 'desc' },
              },
            },
          },
          messages: {
            orderBy: { timestamp: 'asc' },
            take: 50,
          },
        },
      });

      if (!conversation) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Active conversation not found',
        });
      }

      // Get uploaded audio file
      const data = await request.file();
      if (!data) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'No audio file provided',
        });
      }

      const audioBuffer = await data.toBuffer();

      // Process through voice pipeline
      const result = await voicePipeline.processVoiceMessage({
        audioBuffer,
        conversationId,
        systemPrompt: conversation.systemPrompt,
        messageHistory: conversation.messages,
        child: conversation.child,
        avatar: conversation.child.avatar,
        parentQuestions: conversation.child.parentQuestions,
        locale: conversation.locale,
      });

      // Save child's transcribed message
      const childMessage = await prisma.message.create({
        data: {
          conversationId,
          role: 'CHILD',
          textContent: result.childTranscript,
          audioDuration: result.childAudioDuration,
        },
      });

      // Save avatar response
      const avatarMessage = await prisma.message.create({
        data: {
          conversationId,
          role: 'AVATAR',
          textContent: result.avatarText,
          audioUrl: result.avatarAudioUrl,
          audioDuration: result.avatarAudioDuration,
          emotion: result.avatarEmotion,
        },
      });

      return reply.send({
        childMessage: {
          id: childMessage.id,
          role: childMessage.role,
          textContent: childMessage.textContent,
          timestamp: childMessage.timestamp,
        },
        avatarMessage: {
          id: avatarMessage.id,
          role: avatarMessage.role,
          textContent: avatarMessage.textContent,
          audioUrl: avatarMessage.audioUrl,
          emotion: avatarMessage.emotion,
          timestamp: avatarMessage.timestamp,
        },
      });
    },
  );

  // ── Parent intervention ──────────────────────────
  fastify.post(
    '/:conversationId/intervene',
    async (
      request: FastifyRequest<{
        Params: { conversationId: string };
        Body: ParentInterventionBody;
      }>,
      reply: FastifyReply,
    ) => {
      const { conversationId } = request.params;

      const parsed = parentInterventionSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      // Verify conversation ownership
      const conversation = await prisma.conversation.findFirst({
        where: {
          id: conversationId,
          child: { parentId: request.user.userId },
          status: 'ACTIVE',
        },
      });

      if (!conversation) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Active conversation not found',
        });
      }

      const { textContent } = parsed.data;

      // Save parent intervention message
      const interventionMessage = await prisma.message.create({
        data: {
          conversationId,
          role: 'PARENT_INTERVENTION',
          textContent,
          isParentIntervention: true,
        },
      });

      return reply.send({
        message: {
          id: interventionMessage.id,
          role: interventionMessage.role,
          textContent: interventionMessage.textContent,
          isParentIntervention: true,
          timestamp: interventionMessage.timestamp,
        },
      });
    },
  );

  // ── End conversation ─────────────────────────────
  fastify.post(
    '/:conversationId/end',
    async (
      request: FastifyRequest<{ Params: { conversationId: string } }>,
      reply: FastifyReply,
    ) => {
      const { conversationId } = request.params;

      // Verify conversation ownership
      const conversation = await prisma.conversation.findFirst({
        where: {
          id: conversationId,
          child: { parentId: request.user.userId },
          status: 'ACTIVE',
        },
        include: {
          messages: { orderBy: { timestamp: 'asc' } },
          child: {
            include: {
              avatar: true,
              parentQuestions: {
                where: { isActive: true },
              },
            },
          },
        },
      });

      if (!conversation) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Active conversation not found',
        });
      }

      const now = new Date();
      const durationSeconds = Math.round(
        (now.getTime() - conversation.startedAt.getTime()) / 1000,
      );

      // Update conversation status
      const updatedConversation = await prisma.conversation.update({
        where: { id: conversationId },
        data: {
          status: 'COMPLETED',
          endedAt: now,
          durationSeconds,
        },
      });

      // Generate summary asynchronously (don't block response)
      summaryEngine
        .generateSummary({
          conversationId,
          messages: conversation.messages,
          child: conversation.child,
          parentQuestions: conversation.child.parentQuestions,
          locale: conversation.locale,
        })
        .catch((err) => {
          fastify.log.error(err, 'Failed to generate conversation summary');
        });

      return reply.send({
        conversation: {
          id: updatedConversation.id,
          status: updatedConversation.status,
          endedAt: updatedConversation.endedAt,
          durationSeconds: updatedConversation.durationSeconds,
        },
      });
    },
  );

  // ── List conversations ───────────────────────────
  fastify.get(
    '/child/:childId',
    async (
      request: FastifyRequest<{
        Params: { childId: string };
        Querystring: { limit?: string; offset?: string };
      }>,
      reply: FastifyReply,
    ) => {
      const { childId } = request.params;
      const limit = Math.min(parseInt(request.query.limit || '20', 10), 100);
      const offset = parseInt(request.query.offset || '0', 10);

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

      const [conversations, total] = await Promise.all([
        prisma.conversation.findMany({
          where: { childId },
          select: {
            id: true,
            missionId: true,
            status: true,
            locale: true,
            startedAt: true,
            endedAt: true,
            durationSeconds: true,
            mission: {
              select: {
                theme: true,
                titleEn: true,
                titleHe: true,
              },
            },
            summary: {
              select: {
                briefSummary: true,
                moodAssessment: true,
                engagementLevel: true,
              },
            },
            _count: {
              select: { messages: true },
            },
          },
          orderBy: { startedAt: 'desc' },
          take: limit,
          skip: offset,
        }),
        prisma.conversation.count({ where: { childId } }),
      ]);

      return reply.send({
        conversations,
        pagination: { total, limit, offset },
      });
    },
  );

  // ── Get conversation transcript ──────────────────
  fastify.get(
    '/:conversationId/transcript',
    async (
      request: FastifyRequest<{ Params: { conversationId: string } }>,
      reply: FastifyReply,
    ) => {
      const { conversationId } = request.params;

      // Verify ownership
      const conversation = await prisma.conversation.findFirst({
        where: {
          id: conversationId,
          child: { parentId: request.user.userId },
        },
        include: {
          messages: {
            orderBy: { timestamp: 'asc' },
            select: {
              id: true,
              conversationId: true,
              role: true,
              textContent: true,
              audioUrl: true,
              emotion: true,
              isParentIntervention: true,
              timestamp: true,
              audioDuration: true,
            },
          },
          mission: {
            select: {
              theme: true,
              titleEn: true,
              titleHe: true,
            },
          },
        },
      });

      if (!conversation) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Conversation not found',
        });
      }

      return reply.send({
        conversation: {
          id: conversation.id,
          status: conversation.status,
          locale: conversation.locale,
          startedAt: conversation.startedAt,
          endedAt: conversation.endedAt,
          durationSeconds: conversation.durationSeconds,
          mission: conversation.mission,
        },
        messages: conversation.messages,
      });
    },
  );

  // ── Get conversation summary ─────────────────────
  fastify.get(
    '/:conversationId/summary',
    async (
      request: FastifyRequest<{ Params: { conversationId: string } }>,
      reply: FastifyReply,
    ) => {
      const { conversationId } = request.params;

      // Verify ownership
      const conversation = await prisma.conversation.findFirst({
        where: {
          id: conversationId,
          child: { parentId: request.user.userId },
        },
        include: {
          summary: true,
        },
      });

      if (!conversation) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Conversation not found',
        });
      }

      if (!conversation.summary) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Summary not yet available',
        });
      }

      return reply.send({ summary: conversation.summary });
    },
  );
}

// ── Fast opening message templates (no AI call needed) ────────────

interface OpeningResult {
  text: string;
  emotion: string;
}

function generateFastOpeningMessage(
  childName: string,
  avatarName: string,
  mission: { titleHe: string; titleEn: string; theme: string } | null,
  locale: string,
): OpeningResult {
  const isHebrew = locale === 'he';

  if (mission) {
    const missionTitle = isHebrew ? mission.titleHe : mission.titleEn;
    // Mission-based greetings
    const heTemplates = [
      `היי ${childName}! זה אני, ${avatarName}! היום יוצאים להרפתקה מיוחדת - ${missionTitle}! מוכנים?`,
      `${childName}! כל כך שמחתי שבאת! יש לנו משימה מדהימה היום - ${missionTitle}! בוא נתחיל!`,
      `שלום ${childName}! ${avatarName} כאן! מוכנים ל${missionTitle}? זו הולכת להיות הרפתקה מטורפת!`,
    ];
    const enTemplates = [
      `Hey ${childName}! It's me, ${avatarName}! Today we're going on a special adventure - ${missionTitle}! Ready?`,
      `${childName}! I'm so happy you're here! We have an amazing mission today - ${missionTitle}! Let's go!`,
      `Hi ${childName}! ${avatarName} here! Ready for ${missionTitle}? This is going to be an awesome adventure!`,
    ];
    const templates = isHebrew ? heTemplates : enTemplates;
    return {
      text: templates[Math.floor(Math.random() * templates.length)],
      emotion: 'excited',
    };
  } else {
    // Free-form greetings
    const heTemplates = [
      `היי ${childName}! זה אני, ${avatarName}! כל כך שמח לראות אותך! מה קורה היום?`,
      `שלום ${childName}! ${avatarName} כאן! ספר לי, מה הדבר הכי מגניב שקרה לך היום?`,
      `${childName}! איזה כיף שבאת! אני ${avatarName}. על מה נדבר היום?`,
    ];
    const enTemplates = [
      `Hey ${childName}! It's me, ${avatarName}! So happy to see you! What's up today?`,
      `Hi ${childName}! ${avatarName} here! Tell me, what's the coolest thing that happened to you today?`,
      `${childName}! So glad you're here! I'm ${avatarName}. What shall we talk about today?`,
    ];
    const templates = isHebrew ? heTemplates : enTemplates;
    return {
      text: templates[Math.floor(Math.random() * templates.length)],
      emotion: 'happy',
    };
  }
}
