import { Server, Socket } from 'socket.io';
import { Prisma } from '@prisma/client';
import { SessionManager, ConversationSession } from '../SessionManager';
import { VoicePipeline } from '../../services/voice-pipeline/VoicePipeline';
import { ConversationEngine } from '../../services/conversation-engine/ConversationEngine';
import prisma from '../../config/prisma';

const voicePipeline = new VoicePipeline();
const conversationEngine = new ConversationEngine();

/**
 * Register WebSocket handlers for conversation events.
 *
 * Events handled:
 * - conversation:join - Join a conversation session
 * - conversation:voice - Send voice audio message
 * - conversation:text - Send text message
 * - conversation:leave - Leave a conversation session
 */
export function registerConversationHandler(
  io: Server,
  socket: Socket,
  sessionManager: SessionManager,
): void {
  // ── Join Conversation ────────────────────────────
  socket.on(
    'conversation:join',
    async (data: {
      conversationId: string;
      childId: string;
      parentUserId: string;
      locale?: string;
    }) => {
      try {
        const { conversationId, childId, parentUserId, locale } = data;

        // Verify conversation exists and is active
        const conversation = await prisma.conversation.findFirst({
          where: {
            id: conversationId,
            childId,
            child: { parentId: parentUserId },
            status: 'ACTIVE',
          },
        });

        if (!conversation) {
          socket.emit('conversation:error', {
            message: 'Active conversation not found',
          });
          return;
        }

        // Register the session
        const session: ConversationSession = {
          socketId: socket.id,
          conversationId,
          childId,
          parentUserId,
          locale: locale || conversation.locale,
          connectedAt: new Date(),
          lastActivityAt: new Date(),
          isParentMonitoring: false,
        };

        sessionManager.addSession(session);

        // Join a socket room for this conversation
        socket.join(`conversation:${conversationId}`);

        socket.emit('conversation:joined', {
          conversationId,
          status: 'connected',
        });

        console.log(
          `Socket ${socket.id} joined conversation ${conversationId}`,
        );
      } catch (error) {
        console.error('Error joining conversation:', error);
        socket.emit('conversation:error', {
          message: 'Failed to join conversation',
        });
      }
    },
  );

  // ── Voice Message ────────────────────────────────
  socket.on(
    'conversation:voice',
    async (data: { audioData: Buffer | ArrayBuffer | string }) => {
      try {
        const session = sessionManager.getBySocketId(socket.id);
        if (!session) {
          socket.emit('conversation:error', {
            message: 'Not connected to a conversation',
          });
          return;
        }

        sessionManager.updateActivity(socket.id);

        // Emit processing status
        socket.emit('conversation:processing', {
          status: 'transcribing',
        });

        // Load full conversation context
        const conversation = await prisma.conversation.findUnique({
          where: { id: session.conversationId },
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
          socket.emit('conversation:error', {
            message: 'Conversation not found',
          });
          return;
        }

        // Handle audio data from various sources:
        // - Native clients (iOS/Android) send base64 encoded string
        // - Buffer/ArrayBuffer from web clients
        console.log(`[Voice] Received audio data: type=${typeof data.audioData}, isBuffer=${Buffer.isBuffer(data.audioData)}, length=${typeof data.audioData === 'string' ? data.audioData.length : (Buffer.isBuffer(data.audioData) ? data.audioData.length : 'unknown')}`);

        let audioBuffer: Buffer;
        if (Buffer.isBuffer(data.audioData)) {
          audioBuffer = data.audioData;
        } else if (typeof data.audioData === 'string') {
          audioBuffer = Buffer.from(data.audioData, 'base64');
        } else {
          audioBuffer = Buffer.from(data.audioData);
        }

        console.log(`[Voice] Decoded audio buffer: ${audioBuffer.length} bytes, first4=${audioBuffer.subarray(0, 4).toString('ascii')}`);

        // Process through voice pipeline
        socket.emit('conversation:processing', {
          status: 'thinking',
        });

        const result = await voicePipeline.processVoiceMessage({
          audioBuffer,
          conversationId: session.conversationId,
          systemPrompt: conversation.systemPrompt,
          messageHistory: conversation.messages,
          child: conversation.child,
          avatar: conversation.child.avatar,
          parentQuestions: conversation.child.parentQuestions,
          locale: session.locale,
        });

        // Save messages to database
        const [childMsg, avatarMsg] = await Promise.all([
          prisma.message.create({
            data: {
              conversationId: session.conversationId,
              role: 'CHILD',
              textContent: result.childTranscript,
              audioDuration: result.childAudioDuration,
            },
          }),
          prisma.message.create({
            data: {
              conversationId: session.conversationId,
              role: 'AVATAR',
              textContent: result.avatarText,
              audioUrl: result.avatarAudioUrl,
              audioDuration: result.avatarAudioDuration,
              emotion: result.avatarEmotion,
              metadata: result.metadata
                ? (result.metadata as Prisma.InputJsonValue)
                : undefined,
            },
          }),
        ]);

        // Emit response to the child's device
        socket.emit('conversation:response', {
          childMessage: {
            id: childMsg.id,
            textContent: result.childTranscript,
            timestamp: childMsg.timestamp,
          },
          avatarMessage: {
            id: avatarMsg.id,
            textContent: result.avatarText,
            audioUrl: result.avatarAudioUrl,
            audioData: result.avatarAudioBuffer, // Binary audio for immediate playback
            emotion: result.avatarEmotion,
            timestamp: avatarMsg.timestamp,
          },
        });

        // Broadcast to parent monitoring room
        if (session.isParentMonitoring && session.parentSocketId) {
          io.to(session.parentSocketId).emit('parent:message_update', {
            conversationId: session.conversationId,
            childMessage: {
              id: childMsg.id,
              textContent: result.childTranscript,
              timestamp: childMsg.timestamp,
            },
            avatarMessage: {
              id: avatarMsg.id,
              textContent: result.avatarText,
              emotion: result.avatarEmotion,
              timestamp: avatarMsg.timestamp,
            },
            metadata: result.metadata,
          });
        }
      } catch (error) {
        console.error('[Voice] Error processing voice message:', error);
        socket.emit('conversation:error', {
          message: 'Failed to process voice message',
          detail: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    },
  );

  // ── Text Message ─────────────────────────────────
  socket.on(
    'conversation:text',
    async (data: { textContent: string }) => {
      try {
        const session = sessionManager.getBySocketId(socket.id);
        if (!session) {
          socket.emit('conversation:error', {
            message: 'Not connected to a conversation',
          });
          return;
        }

        sessionManager.updateActivity(socket.id);

        const { textContent } = data;

        if (!textContent?.trim()) {
          socket.emit('conversation:error', {
            message: 'Empty message',
          });
          return;
        }

        socket.emit('conversation:processing', {
          status: 'thinking',
        });

        // Load conversation context
        const conversation = await prisma.conversation.findUnique({
          where: { id: session.conversationId },
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
          socket.emit('conversation:error', {
            message: 'Conversation not found',
          });
          return;
        }

        // Save child message
        const childMsg = await prisma.message.create({
          data: {
            conversationId: session.conversationId,
            role: 'CHILD',
            textContent,
          },
        });

        // Process through conversation engine
        const avatarResponse =
          await conversationEngine.processChildMessage({
            conversationId: session.conversationId,
            childText: textContent,
            systemPrompt: conversation.systemPrompt,
            messageHistory: conversation.messages,
            child: conversation.child,
            avatar: conversation.child.avatar,
            parentQuestions: conversation.child.parentQuestions,
            locale: session.locale,
          });

        // Save avatar response
        const avatarMsg = await prisma.message.create({
          data: {
            conversationId: session.conversationId,
            role: 'AVATAR',
            textContent: avatarResponse.text,
            emotion: avatarResponse.emotion,
            metadata: avatarResponse.metadata
              ? (avatarResponse.metadata as Prisma.InputJsonValue)
              : undefined,
          },
        });

        // Emit response
        socket.emit('conversation:response', {
          childMessage: {
            id: childMsg.id,
            textContent: childMsg.textContent,
            timestamp: childMsg.timestamp,
          },
          avatarMessage: {
            id: avatarMsg.id,
            textContent: avatarResponse.text,
            emotion: avatarResponse.emotion,
            timestamp: avatarMsg.timestamp,
          },
        });

        // Broadcast to parent monitoring
        if (session.isParentMonitoring && session.parentSocketId) {
          io.to(session.parentSocketId).emit('parent:message_update', {
            conversationId: session.conversationId,
            childMessage: {
              id: childMsg.id,
              textContent: childMsg.textContent,
              timestamp: childMsg.timestamp,
            },
            avatarMessage: {
              id: avatarMsg.id,
              textContent: avatarResponse.text,
              emotion: avatarResponse.emotion,
              timestamp: avatarMsg.timestamp,
            },
            metadata: avatarResponse.metadata,
          });
        }
      } catch (error) {
        console.error('Error processing text message:', error);
        socket.emit('conversation:error', {
          message: 'Failed to process message',
        });
      }
    },
  );

  // ── Leave Conversation ───────────────────────────
  socket.on('conversation:leave', async () => {
    try {
      const session = sessionManager.getBySocketId(socket.id);
      if (!session) return;

      // Leave the socket room
      socket.leave(`conversation:${session.conversationId}`);

      // Clean up session
      sessionManager.removeBySocketId(socket.id);

      socket.emit('conversation:left', {
        conversationId: session.conversationId,
      });

      console.log(
        `Socket ${socket.id} left conversation ${session.conversationId}`,
      );
    } catch (error) {
      console.error('Error leaving conversation:', error);
    }
  });
}
