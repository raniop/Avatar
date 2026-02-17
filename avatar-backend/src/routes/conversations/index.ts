import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { randomUUID } from 'crypto';
import { Prisma } from '@prisma/client';
import prisma from '../../config/prisma';
import { ConversationEngine } from '../../services/conversation-engine/ConversationEngine';
import { SummaryEngine } from '../../services/summary-engine/SummaryEngine';
import { VoicePipeline } from '../../services/voice-pipeline/VoicePipeline';
import { NotificationService } from '../../services/notifications/NotificationService';

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
  const notificationService = new NotificationService();

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
      const t0 = Date.now();

      // Load child and mission in parallel to cut latency
      const [child, mission] = await Promise.all([
        prisma.child.findFirst({
          where: { id: childId, parentId: request.user.userId },
          include: {
            avatar: true,
            parentQuestions: {
              where: { isActive: true },
              orderBy: { priority: 'desc' },
            },
            parentGuidance: {
              where: { isActive: true },
            },
          },
        }),
        missionId
          ? prisma.missionTemplate.findUnique({ where: { id: missionId } })
          : Promise.resolve(null),
      ]);
      console.log(`[TIMING] Child+Mission DB: ${Date.now() - t0}ms`);

      if (!child) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Child not found',
        });
      }

      if (missionId && !mission) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'Mission not found',
        });
      }

      // Build system prompt (sync, fast)
      const systemPrompt = conversationEngine.buildSystemPrompt({
        child,
        avatar: child.avatar,
        mission,
        parentQuestions: child.parentQuestions,
        parentGuidance: child.parentGuidance,
        locale,
      });

      // Generate opening message
      const avatarName = child.avatar?.name && child.avatar.name !== 'default'
        ? child.avatar.name
        : undefined;

      // For mission-based conversations, use Claude to generate adventure-formatted opening
      // This ensures the first message in history has the correct JSON format
      let openingText: string;
      let openingEmotion: string;
      let initialAdventure: any = null;

      if (mission) {
        // Generate opening with adventure structure via Claude
        const adventureOpening = await conversationEngine.generateOpeningMessage({
          conversationId: '', // not created yet, but not used by the method
          child,
          avatar: child.avatar,
          mission,
          locale,
          systemPrompt,
        });

        openingText = adventureOpening.text;
        openingEmotion = adventureOpening.emotion || 'excited';

        // If Claude returned adventure state, use it; otherwise build a default
        if (adventureOpening.adventure) {
          initialAdventure = adventureOpening.adventure;
        } else {
          const gameType = getGameTypeForTheme(mission.theme);
          initialAdventure = {
            sceneIndex: 0,
            sceneName: locale === 'he' ? 'ההתחלה' : 'The Beginning',
            sceneEmojis: getThemeEmojis(mission.theme),
            interactionType: 'miniGame' as const,
            choices: null,
            miniGame: { type: gameType, round: 1 },
            starsEarned: 0,
            isSceneComplete: false,
            isAdventureComplete: false,
            collectible: null,
          };
        }
      } else {
        const fastOpening = generateFastOpeningMessage(child.name, avatarName, null, locale);
        openingText = fastOpening.text;
        openingEmotion = fastOpening.emotion;
      }

      // Store the opening message as adventure JSON in DB so Claude sees the format in history
      const openingTextForDB = mission && initialAdventure
        ? JSON.stringify({ text: openingText, emotion: openingEmotion, adventure: initialAdventure })
        : openingText;

      // Create conversation + opening message in a single transaction for speed
      const t1 = Date.now();
      const conversationId = randomUUID();
      const [conversation, avatarMessage] = await prisma.$transaction([
        prisma.conversation.create({
          data: {
            id: conversationId,
            childId,
            missionId: missionId || null,
            locale,
            systemPrompt,
            status: 'ACTIVE',
          },
        }),
        prisma.message.create({
          data: {
            conversationId,
            role: 'AVATAR',
            textContent: openingTextForDB,
            emotion: openingEmotion,
          },
        }),
      ]);
      console.log(`[TIMING] Conversation+Message DB: ${Date.now() - t1}ms (total: ${Date.now() - t0}ms)`);

      // Return immediately with text — TTS will be sent via WebSocket later
      reply.status(201).send({
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
          textContent: openingText,
          emotion: openingEmotion,
          audioUrl: null,
          audioData: null,
          timestamp: avatarMessage.timestamp,
          adventure: initialAdventure,
        },
      });

      // Fire-and-forget: notify parent that child started playing
      notificationService
        .notifyChildStartedPlaying(
          request.user.userId,
          child.name,
          conversation.id,
          locale,
        )
        .catch((err: any) => console.error('[FCM] Failed to send push notification:', err));

      // Fire-and-forget: generate TTS in background and emit via WebSocket
      // The client will receive audio via the conversation:audio event after joining the room
      const conversationRoom = `conversation:${conversation.id}`;
      (async () => {
        try {
          console.log(`[TTS] Generating opening audio in background for: "${openingText.substring(0, 60)}..."`);
          const ttsResult = await voicePipeline.generateAvatarAudio(
            openingText,
            child.avatar?.voiceId || undefined,
            child.age,
            locale,
          );
          console.log(`[TTS] Opening audio OK: url=${ttsResult.audioUrl}, duration=${ttsResult.audioDuration}s, bufferSize=${ttsResult.audioBuffer.length}`);

          // Update DB with audio info
          await prisma.message.update({
            where: { id: avatarMessage.id },
            data: { audioUrl: ttsResult.audioUrl, audioDuration: ttsResult.audioDuration },
          });

          // Emit audio to the conversation room via Socket.IO
          const audioBase64 = ttsResult.audioBuffer.toString('base64');
          console.log(`[TTS] Emitting opening AUDIO to room ${conversationRoom}, size=${audioBase64.length}`);
          fastify.server;  // ensure server is available
          // Access io from the fastify server's Socket.IO instance
          const io = (fastify as any).io;
          if (io) {
            io.to(conversationRoom).emit('conversation:audio', {
              messageId: avatarMessage.id,
              audioData: audioBase64,
              audioUrl: ttsResult.audioUrl,
            });
          } else {
            console.warn('[TTS] Socket.IO not available on fastify, audio not emitted');
          }
        } catch (ttsError: any) {
          console.error('[TTS] Failed to generate opening TTS:', ttsError?.message || ttsError);
        }
      })();

      return;
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
              parentGuidance: {
                where: { isActive: true },
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
        parentGuidance: conversation.child.parentGuidance,
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
              parentGuidance: {
                where: { isActive: true },
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
        parentGuidance: conversation.child.parentGuidance,
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

// ── Theme emoji mapping for initial adventure state ───────────────

function getThemeEmojis(theme: string): string[] {
  const themeEmojis: Record<string, string[]> = {
    superhero_training: ['🦸', '💪', '⚡', '🌟'],
    space_adventure: ['🚀', '🌍', '⭐', '🌙'],
    cooking_adventure: ['👨‍🍳', '🍳', '🎂', '🍕'],
    underwater_explorer: ['🌊', '🐠', '🐚', '🦈'],
    magical_forest: ['🌲', '🍄', '🦋', '✨'],
    dinosaur_world: ['🦕', '🌋', '🥚', '🦴'],
    pirate_treasure_hunt: ['🏴‍☠️', '🗺️', '💰', '⚓'],
    fairy_tale_kingdom: ['🏰', '👑', '🧚', '🌈'],
    animal_rescue: ['🐾', '🏥', '❤️', '🐕'],
    rainbow_land: ['🌈', '☁️', '🦄', '🎨'],
    music_studio: ['🎵', '🎸', '🎹', '🎤'],
    dance_party: ['💃', '🪩', '🎶', '✨'],
    sports_champion: ['🏆', '⚽', '🥇', '🏃'],
    singing_star: ['🎤', '⭐', '🎵', '🎶'],
    animal_hospital: ['🏥', '🐾', '💊', '❤️'],
  };
  return themeEmojis[theme] || ['✨', '🌟', '🎯', '🎪'];
}

// ── Theme → Game type mapping (must match iOS GameThemeConfig) ────

function getGameTypeForTheme(theme: string): 'catch' | 'match' | 'sort' | 'sequence' {
  const mapping: Record<string, 'catch' | 'match' | 'sort' | 'sequence'> = {
    sports_champion: 'catch',
    space_adventure: 'catch',
    underwater_explorer: 'catch',
    magical_forest: 'match',
    dinosaur_world: 'match',
    pirate_treasure_hunt: 'match',
    cooking_adventure: 'sort',
    animal_rescue: 'sort',
    rainbow_land: 'sort',
    animal_hospital: 'sort',
    fairy_tale_kingdom: 'sequence',
    superhero_training: 'sequence',
    music_studio: 'sequence',
    dance_party: 'sequence',
    singing_star: 'sequence',
  };
  return mapping[theme] || 'catch';
}

// ── Fast opening message templates (no AI call needed) ────────────

interface OpeningResult {
  text: string;
  emotion: string;
}

function generateFastOpeningMessage(
  childName: string,
  avatarName: string | undefined,
  mission: { titleHe: string; titleEn: string; theme: string } | null,
  locale: string,
): OpeningResult {
  const isHebrew = locale === 'he';
  // If the child gave their avatar a name, use "Hi childName! I'm avatarName!" style
  const intro = avatarName
    ? (isHebrew ? `היי ${childName}! זה אני, ${avatarName}!` : `Hey ${childName}! It's me, ${avatarName}!`)
    : (isHebrew ? `היי ${childName}!` : `Hey ${childName}!`);

  if (mission) {
    const missionTitle = isHebrew ? mission.titleHe : mission.titleEn;
    const heTemplates = [
      `${intro} היום יוצאים להרפתקה מיוחדת - ${missionTitle}! מוכן?`,
      `${intro} יש לנו משימה מדהימה היום - ${missionTitle}! בוא נתחיל!`,
      `${intro} מוכן ל${missionTitle}? זו הולכת להיות הרפתקה מטורפת!`,
    ];
    const enTemplates = [
      `${intro} Today we're going on a special adventure - ${missionTitle}! Ready?`,
      `${intro} We have an amazing mission today - ${missionTitle}! Let's go!`,
      `${intro} Ready for ${missionTitle}? This is going to be an awesome adventure!`,
    ];
    const templates = isHebrew ? heTemplates : enTemplates;
    return {
      text: templates[Math.floor(Math.random() * templates.length)],
      emotion: 'excited',
    };
  } else {
    const heTemplates = [
      `${intro} כל כך שמח לראות אותך! מה קורה היום?`,
      `${intro} ספר לי, מה הדבר הכי מגניב שקרה לך היום?`,
      `${intro} איזה כיף שבאת! על מה נדבר היום?`,
    ];
    const enTemplates = [
      `${intro} So happy to see you! What's up today?`,
      `${intro} Tell me, what's the coolest thing that happened to you today?`,
      `${intro} So glad you're here! What shall we talk about today?`,
    ];
    const templates = isHebrew ? heTemplates : enTemplates;
    return {
      text: templates[Math.floor(Math.random() * templates.length)],
      emotion: 'happy',
    };
  }
}
