import { Server, Socket } from 'socket.io';
import { SessionManager } from '../SessionManager';
import prisma from '../../config/prisma';

/**
 * Register WebSocket handlers for parent monitoring and intervention.
 *
 * Events handled:
 * - parent:monitor - Start monitoring a child's active conversation
 * - parent:intervene - Send an intervention message to the conversation
 * - parent:stop_monitor - Stop monitoring a conversation
 */
export function registerParentHandler(
  io: Server,
  socket: Socket,
  sessionManager: SessionManager,
): void {
  // ── Start Monitoring ─────────────────────────────
  socket.on(
    'parent:monitor',
    async (data: { parentUserId: string; conversationId: string }) => {
      try {
        const { parentUserId, conversationId } = data;

        // Verify the conversation belongs to this parent's child
        const conversation = await prisma.conversation.findFirst({
          where: {
            id: conversationId,
            child: { parentId: parentUserId },
            status: 'ACTIVE',
          },
          include: {
            messages: {
              orderBy: { timestamp: 'asc' },
              select: {
                id: true,
                role: true,
                textContent: true,
                emotion: true,
                isParentIntervention: true,
                timestamp: true,
              },
            },
            child: {
              select: {
                name: true,
                avatar: {
                  select: { name: true },
                },
              },
            },
          },
        });

        if (!conversation) {
          socket.emit('parent:error', {
            message: 'Active conversation not found',
          });
          return;
        }

        // Register parent socket
        sessionManager.addParentSocket(parentUserId, socket.id);

        // Link parent monitoring to the conversation session
        sessionManager.setParentMonitoring(conversationId, socket.id);

        // Join the parent monitoring room
        socket.join(`parent:${conversationId}`);

        // Send current conversation state
        socket.emit('parent:monitor_started', {
          conversationId,
          childName: conversation.child.name,
          avatarName: conversation.child.avatar?.name || 'Buddy',
          messageCount: conversation.messages.length,
          messages: conversation.messages,
        });

        console.log(
          `Parent ${parentUserId} started monitoring conversation ${conversationId}`,
        );
      } catch (error) {
        console.error('Error starting parent monitoring:', error);
        socket.emit('parent:error', {
          message: 'Failed to start monitoring',
        });
      }
    },
  );

  // ── Parent Intervention ──────────────────────────
  socket.on(
    'parent:intervene',
    async (data: {
      parentUserId: string;
      conversationId: string;
      textContent: string;
    }) => {
      try {
        const { parentUserId, conversationId, textContent } = data;

        if (!textContent?.trim()) {
          socket.emit('parent:error', {
            message: 'Intervention message cannot be empty',
          });
          return;
        }

        // Verify ownership
        const conversation = await prisma.conversation.findFirst({
          where: {
            id: conversationId,
            child: { parentId: parentUserId },
            status: 'ACTIVE',
          },
        });

        if (!conversation) {
          socket.emit('parent:error', {
            message: 'Active conversation not found',
          });
          return;
        }

        // Save the intervention message
        const interventionMessage = await prisma.message.create({
          data: {
            conversationId,
            role: 'PARENT_INTERVENTION',
            textContent: textContent.trim(),
            isParentIntervention: true,
          },
        });

        // Notify the conversation session about the intervention
        const conversationSession =
          sessionManager.getByConversationId(conversationId);

        if (conversationSession) {
          // Send to the child's device connection
          io.to(conversationSession.socketId).emit(
            'conversation:parent_intervention',
            {
              id: interventionMessage.id,
              textContent: interventionMessage.textContent,
              timestamp: interventionMessage.timestamp,
            },
          );
        }

        // Confirm to parent
        socket.emit('parent:intervention_sent', {
          id: interventionMessage.id,
          textContent: interventionMessage.textContent,
          timestamp: interventionMessage.timestamp,
          conversationId,
        });

        console.log(
          `Parent ${parentUserId} sent intervention to conversation ${conversationId}`,
        );
      } catch (error) {
        console.error('Error sending parent intervention:', error);
        socket.emit('parent:error', {
          message: 'Failed to send intervention',
        });
      }
    },
  );

  // ── Parent Guidance (stealth instruction to avatar) ─
  socket.on(
    'parent:guidance',
    async (data: {
      parentUserId: string;
      conversationId: string;
      instruction: string;
    }) => {
      try {
        const { parentUserId, conversationId, instruction } = data;

        if (!instruction?.trim()) {
          socket.emit('parent:error', {
            message: 'Guidance instruction cannot be empty',
          });
          return;
        }

        // Verify ownership
        const conversation = await prisma.conversation.findFirst({
          where: {
            id: conversationId,
            child: { parentId: parentUserId },
            status: 'ACTIVE',
          },
        });

        if (!conversation) {
          socket.emit('parent:error', {
            message: 'Active conversation not found',
          });
          return;
        }

        // Append instruction to conversation's contextWindow.runtimeGuidance
        const currentContext = (conversation.contextWindow as any) || {};
        const existingGuidance = currentContext.runtimeGuidance || [];
        const updatedGuidance = [...existingGuidance, instruction.trim()];

        await prisma.conversation.update({
          where: { id: conversationId },
          data: {
            contextWindow: {
              ...currentContext,
              runtimeGuidance: updatedGuidance,
            },
          },
        });

        // Confirm to parent
        socket.emit('parent:guidance_saved', {
          conversationId,
          instruction: instruction.trim(),
          totalGuidance: updatedGuidance.length,
        });

        console.log(
          `Parent ${parentUserId} sent guidance to conversation ${conversationId}: "${instruction.trim().substring(0, 50)}..."`,
        );
      } catch (error) {
        console.error('Error sending parent guidance:', error);
        socket.emit('parent:error', {
          message: 'Failed to send guidance',
        });
      }
    },
  );

  // ── End Conversation (Parent-initiated) ──────────
  socket.on(
    'parent:end_conversation',
    async (data: {
      parentUserId: string;
      conversationId: string;
    }) => {
      try {
        const { parentUserId, conversationId } = data;

        // Verify ownership
        const conversation = await prisma.conversation.findFirst({
          where: {
            id: conversationId,
            child: { parentId: parentUserId },
            status: 'ACTIVE',
          },
        });

        if (!conversation) {
          socket.emit('parent:error', {
            message: 'Active conversation not found',
          });
          return;
        }

        const now = new Date();
        const durationSeconds = Math.round(
          (now.getTime() - conversation.startedAt.getTime()) / 1000,
        );

        // End the conversation
        await prisma.conversation.update({
          where: { id: conversationId },
          data: {
            status: 'COMPLETED',
            endedAt: now,
            durationSeconds,
          },
        });

        // Notify the conversation session
        const conversationSession =
          sessionManager.getByConversationId(conversationId);

        if (conversationSession) {
          io.to(conversationSession.socketId).emit(
            'conversation:ended_by_parent',
            {
              conversationId,
              endedAt: now.toISOString(),
            },
          );
        }

        // Confirm to parent
        socket.emit('parent:conversation_ended', {
          conversationId,
          endedAt: now.toISOString(),
          durationSeconds,
        });

        // Clean up sessions
        if (conversationSession) {
          sessionManager.removeBySocketId(conversationSession.socketId);
        }

        console.log(
          `Parent ${parentUserId} ended conversation ${conversationId}`,
        );
      } catch (error) {
        console.error('Error ending conversation:', error);
        socket.emit('parent:error', {
          message: 'Failed to end conversation',
        });
      }
    },
  );

  // ── Stop Monitoring ──────────────────────────────
  socket.on(
    'parent:stop_monitor',
    async (data: { conversationId: string }) => {
      try {
        const { conversationId } = data;

        // Leave the monitoring room
        socket.leave(`parent:${conversationId}`);

        socket.emit('parent:monitor_stopped', {
          conversationId,
        });

        console.log(
          `Socket ${socket.id} stopped monitoring conversation ${conversationId}`,
        );
      } catch (error) {
        console.error('Error stopping monitoring:', error);
      }
    },
  );

  // ── Get Active Sessions ──────────────────────────
  socket.on(
    'parent:get_active_sessions',
    async (data: { parentUserId: string }) => {
      try {
        const { parentUserId } = data;

        // Get all active conversations for this parent's children
        const activeConversations = await prisma.conversation.findMany({
          where: {
            child: { parentId: parentUserId },
            status: 'ACTIVE',
          },
          select: {
            id: true,
            startedAt: true,
            locale: true,
            child: {
              select: {
                id: true,
                name: true,
                avatar: {
                  select: { name: true },
                },
              },
            },
            _count: {
              select: { messages: true },
            },
          },
        });

        socket.emit('parent:active_sessions', {
          sessions: activeConversations.map((c) => ({
            conversationId: c.id,
            childId: c.child.id,
            childName: c.child.name,
            avatarName: c.child.avatar?.name || 'Buddy',
            startedAt: c.startedAt,
            messageCount: c._count.messages,
          })),
        });
      } catch (error) {
        console.error('Error getting active sessions:', error);
        socket.emit('parent:error', {
          message: 'Failed to get active sessions',
        });
      }
    },
  );
}
