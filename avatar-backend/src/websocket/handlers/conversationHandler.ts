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

        // Process through voice pipeline: STT → Claude → TTS
        // We split this into phases to send text ASAP, then audio later
        io.to(conversationRoom).emit('conversation:processing', {
          status: 'thinking',
        });

        // ── Phase 1: STT ──────────────────────────────
        const transcription = await voicePipeline.transcribe(audioBuffer, locale);
        console.log(`[Voice] Transcription: "${transcription.text}" (${transcription.duration}s)`);

        if (!transcription.text.trim()) {
          // No speech detected — send a gentle fallback
          const fallbackText = locale === 'he'
            ? 'לא שמעתי טוב. אתה יכול לומר את זה שוב?'
            : "I didn't quite hear that. Can you say it again?";

          const fallbackAudio = await voicePipeline.generateAvatarAudio(
            fallbackText,
            conversation.child.avatar?.voiceId || undefined,
            conversation.child.age,
          );

          const avatarMsg = await prisma.message.create({
            data: {
              conversationId,
              role: 'AVATAR',
              textContent: fallbackText,
              audioUrl: fallbackAudio.audioUrl,
              audioDuration: fallbackAudio.audioDuration,
              emotion: 'curious',
            },
          });

          const audioBase64 = fallbackAudio.audioBuffer.toString('base64');
          io.to(conversationRoom).emit('conversation:response', {
            childMessage: null,
            avatarMessage: {
              id: avatarMsg.id,
              textContent: fallbackText,
              audioUrl: fallbackAudio.audioUrl,
              audioData: audioBase64,
              emotion: 'curious',
              timestamp: avatarMsg.timestamp,
            },
          });
          return;
        }

        // ── Phase 2: Claude AI ────────────────────────
        const avatarResponse = await conversationEngine.processChildMessage({
          conversationId,
          childText: transcription.text,
          systemPrompt: conversation.systemPrompt,
          messageHistory: conversation.messages,
          child: conversation.child,
          avatar: conversation.child.avatar,
          parentQuestions: conversation.child.parentQuestions,
          locale,
        });

        // ── Phase 3: Emit TEXT immediately (don't wait for TTS) ──
        // Save child + avatar messages to DB
        const childMsgPromise = prisma.message.create({
          data: {
            conversationId,
            role: 'CHILD',
            textContent: transcription.text,
            audioDuration: transcription.duration,
          },
        });

        const avatarMsgPromise = prisma.message.create({
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

        const [childMsg, avatarMsg] = await Promise.all([childMsgPromise, avatarMsgPromise]);

        // Send text response RIGHT NOW — client shows text immediately
        console.log(`[Voice] Emitting TEXT response to room ${conversationRoom}`);
        io.to(conversationRoom).emit('conversation:response', {
          childMessage: {
            id: childMsg.id,
            textContent: transcription.text,
            timestamp: childMsg.timestamp,
          },
          avatarMessage: {
            id: avatarMsg.id,
            textContent: avatarResponse.text,
            audioUrl: null,  // Audio comes later
            audioData: null, // Audio comes later
            emotion: avatarResponse.emotion,
            timestamp: avatarMsg.timestamp,
          },
        });

        // ── Phase 4: Generate TTS and send audio separately ──
        try {
          const speechResult = await voicePipeline.generateAvatarAudio(
            avatarResponse.text,
            conversation.child.avatar?.voiceId || undefined,
            conversation.child.age,
          );

          // Update DB with audio URL
          await prisma.message.update({
            where: { id: avatarMsg.id },
            data: {
              audioUrl: speechResult.audioUrl,
              audioDuration: speechResult.audioDuration,
            },
          });

          // Send audio to client
          const audioBase64 = speechResult.audioBuffer.toString('base64');
          console.log(`[Voice] Emitting AUDIO to room ${conversationRoom}, size=${audioBase64.length}`);
          io.to(conversationRoom).emit('conversation:audio', {
            messageId: avatarMsg.id,
            audioData: audioBase64,
            audioUrl: speechResult.audioUrl,
          });
        } catch (ttsErr) {
          console.error('[Voice] TTS generation failed:', ttsErr);
        }

        // Broadcast to parent monitoring room
        const currentSession = sessionManager.getBySocketId(socket.id) || session;
        if (currentSession.isParentMonitoring && currentSession.parentSocketId) {
          io.to(currentSession.parentSocketId).emit('parent:message_update', {
            conversationId,
            childMessage: {
              id: childMsg.id,
              textContent: transcription.text,
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

        // Save avatar message to DB immediately (without audio)
        const avatarMsg = await prisma.message.create({
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

        // Emit TEXT response immediately — client shows text right away
        console.log(`[Text] Emitting TEXT response to room ${conversationRoom}`);
        io.to(conversationRoom).emit('conversation:response', {
          childMessage: {
            id: childMsg.id,
            textContent: childMsg.textContent,
            timestamp: childMsg.timestamp,
          },
          avatarMessage: {
            id: avatarMsg.id,
            textContent: avatarResponse.text,
            audioUrl: null,
            audioData: null,
            emotion: avatarResponse.emotion,
            timestamp: avatarMsg.timestamp,
          },
        });

        // Generate TTS audio and send it separately
        try {
          const ttsResult = await voicePipeline.generateAvatarAudio(
            avatarResponse.text,
            conversation.child.avatar?.voiceId || undefined,
            conversation.child.age,
          );

          // Update DB with audio info
          await prisma.message.update({
            where: { id: avatarMsg.id },
            data: {
              audioUrl: ttsResult.audioUrl,
              audioDuration: ttsResult.audioDuration,
            },
          });

          // Send audio to client
          const audioBase64 = ttsResult.audioBuffer.toString('base64');
          console.log(`[Text] Emitting AUDIO to room ${conversationRoom}, size=${audioBase64.length}`);
          io.to(conversationRoom).emit('conversation:audio', {
            messageId: avatarMsg.id,
            audioData: audioBase64,
            audioUrl: ttsResult.audioUrl,
          });
        } catch (ttsErr) {
          console.error('[Text] TTS generation failed:', ttsErr);
        }

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
