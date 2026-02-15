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

        // Capture conversation room name upfront — if the socket disconnects during
        // processing, we can still emit the response to the room (the client will
        // reconnect and re-join this room).
        const conversationRoom = `conversation:${session.conversationId}`;
        const conversationId = session.conversationId;
        const locale = session.locale;

        sessionManager.updateActivity(socket.id);

        // Emit processing status to the room (so reconnected clients see it too)
        io.to(conversationRoom).emit('conversation:processing', {
          status: 'transcribing',
        });

        // Load full conversation context
        const conversation = await prisma.conversation.findUnique({
          where: { id: conversationId },
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
        io.to(conversationRoom).emit('conversation:processing', {
          status: 'thinking',
        });

        const result = await voicePipeline.processVoiceMessage({
          audioBuffer,
          conversationId,
          systemPrompt: conversation.systemPrompt,
          messageHistory: conversation.messages,
          child: conversation.child,
          avatar: conversation.child.avatar,
          parentQuestions: conversation.child.parentQuestions,
          locale,
        });

        // Save messages to database
        const [childMsg, avatarMsg] = await Promise.all([
          prisma.message.create({
            data: {
              conversationId,
              role: 'CHILD',
              textContent: result.childTranscript,
              audioDuration: result.childAudioDuration,
            },
          }),
          prisma.message.create({
            data: {
              conversationId,
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

        // Emit response to the conversation ROOM (not individual socket).
        // This way if the original socket disconnected and a new one reconnected
        // and re-joined the room, it will still receive the response.
        // Send audio as base64 string (not raw Buffer) for our native WebSocket client
        const voiceAudioBase64 = result.avatarAudioBuffer
          ? result.avatarAudioBuffer.toString('base64')
          : null;
        console.log(`[Voice] Emitting response to room ${conversationRoom}, hasAudio=${!!voiceAudioBase64}`);
        io.to(conversationRoom).emit('conversation:response', {
          childMessage: {
            id: childMsg.id,
            textContent: result.childTranscript,
            timestamp: childMsg.timestamp,
          },
          avatarMessage: {
            id: avatarMsg.id,
            textContent: result.avatarText,
            audioUrl: result.avatarAudioUrl,
            audioData: voiceAudioBase64, // Base64 encoded audio for immediate playback
            emotion: result.avatarEmotion,
            timestamp: avatarMsg.timestamp,
          },
        });

        // Broadcast to parent monitoring room
        const currentSession = sessionManager.getBySocketId(socket.id) || session;
        if (currentSession.isParentMonitoring && currentSession.parentSocketId) {
          io.to(currentSession.parentSocketId).emit('parent:message_update', {
            conversationId,
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
        // Try to emit error to room in case socket disconnected
        try {
          socket.emit('conversation:error', {
            message: 'Failed to process voice message',
            detail: error instanceof Error ? error.message : 'Unknown error',
          });
        } catch {
          // Socket may be dead, ignore
        }
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

        const conversationRoom = `conversation:${session.conversationId}`;
        const conversationId = session.conversationId;
        const locale = session.locale;

        sessionManager.updateActivity(socket.id);

        const { textContent } = data;

        if (!textContent?.trim()) {
          socket.emit('conversation:error', {
            message: 'Empty message',
          });
          return;
        }

        io.to(conversationRoom).emit('conversation:processing', {
          status: 'thinking',
        });

        // Load conversation context
        const conversation = await prisma.conversation.findUnique({
          where: { id: conversationId },
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
            conversationId,
            role: 'CHILD',
            textContent,
          },
        });

        // Process through conversation engine
        const avatarResponse =
          await conversationEngine.processChildMessage({
            conversationId,
            childText: textContent,
            systemPrompt: conversation.systemPrompt,
            messageHistory: conversation.messages,
            child: conversation.child,
            avatar: conversation.child.avatar,
            parentQuestions: conversation.child.parentQuestions,
            locale,
          });

        // Generate TTS audio for the avatar response (in parallel with DB save)
        const ttsPromise = voicePipeline.generateAvatarAudio(
          avatarResponse.text,
          conversation.child.avatar?.voiceId || undefined,
          conversation.child.age,
        ).catch((err) => {
          console.error('[Text] TTS generation failed:', err);
          return null;
        });

        // Save avatar response to DB (in parallel with TTS)
        const [ttsResult, avatarMsg] = await Promise.all([
          ttsPromise,
          prisma.message.create({
            data: {
              conversationId,
              role: 'AVATAR',
              textContent: avatarResponse.text,
              audioUrl: undefined, // Will update after TTS
              emotion: avatarResponse.emotion,
              metadata: avatarResponse.metadata
                ? (avatarResponse.metadata as Prisma.InputJsonValue)
                : undefined,
            },
          }),
        ]);

        // Update DB with audio URL if TTS succeeded
        if (ttsResult?.audioUrl) {
          await prisma.message.update({
            where: { id: avatarMsg.id },
            data: {
              audioUrl: ttsResult.audioUrl,
              audioDuration: ttsResult.audioDuration,
            },
          });
        }

        // Emit response to the conversation room (include audio data as base64 for immediate playback)
        const audioDataBase64 = ttsResult?.audioBuffer
          ? ttsResult.audioBuffer.toString('base64')
          : null;
        console.log(`[Text] Emitting response to room ${conversationRoom}, hasAudio=${!!audioDataBase64}, audioSize=${audioDataBase64?.length || 0}`);
        io.to(conversationRoom).emit('conversation:response', {
          childMessage: {
            id: childMsg.id,
            textContent: childMsg.textContent,
            timestamp: childMsg.timestamp,
          },
          avatarMessage: {
            id: avatarMsg.id,
            textContent: avatarResponse.text,
            audioUrl: ttsResult?.audioUrl || null,
            audioData: audioDataBase64,
            emotion: avatarResponse.emotion,
            timestamp: avatarMsg.timestamp,
          },
        });

        // Broadcast to parent monitoring
        const currentSession = sessionManager.getBySocketId(socket.id) || session;
        if (currentSession.isParentMonitoring && currentSession.parentSocketId) {
          io.to(currentSession.parentSocketId).emit('parent:message_update', {
            conversationId,
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
        try {
          socket.emit('conversation:error', {
            message: 'Failed to process message',
          });
        } catch {
          // Socket may be dead, ignore
        }
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
