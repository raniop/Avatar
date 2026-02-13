/**
 * SessionManager tracks active conversation sessions connected via WebSocket.
 *
 * It maps socket connections to conversation sessions, enabling real-time
 * voice messaging and parent monitoring.
 */

export interface ConversationSession {
  socketId: string;
  conversationId: string;
  childId: string;
  parentUserId: string;
  locale: string;
  connectedAt: Date;
  lastActivityAt: Date;
  isParentMonitoring: boolean;
  parentSocketId?: string;
}

export class SessionManager {
  // Map socketId -> session
  private sessions: Map<string, ConversationSession> = new Map();

  // Map conversationId -> socketId (for quick lookup)
  private conversationIndex: Map<string, string> = new Map();

  // Map parentUserId -> Set<socketId> (for parent monitoring)
  private parentSockets: Map<string, Set<string>> = new Map();

  /**
   * Register a new conversation session.
   */
  addSession(session: ConversationSession): void {
    this.sessions.set(session.socketId, session);
    this.conversationIndex.set(session.conversationId, session.socketId);
  }

  /**
   * Get session by socket ID.
   */
  getBySocketId(socketId: string): ConversationSession | undefined {
    return this.sessions.get(socketId);
  }

  /**
   * Get session by conversation ID.
   */
  getByConversationId(
    conversationId: string,
  ): ConversationSession | undefined {
    const socketId = this.conversationIndex.get(conversationId);
    if (!socketId) return undefined;
    return this.sessions.get(socketId);
  }

  /**
   * Update the last activity timestamp for a session.
   */
  updateActivity(socketId: string): void {
    const session = this.sessions.get(socketId);
    if (session) {
      session.lastActivityAt = new Date();
    }
  }

  /**
   * Remove a session by socket ID.
   */
  removeBySocketId(socketId: string): void {
    const session = this.sessions.get(socketId);
    if (session) {
      this.conversationIndex.delete(session.conversationId);
      this.sessions.delete(socketId);
    }

    // Also remove from parent sockets if it was a parent connection
    for (const [parentId, sockets] of this.parentSockets) {
      if (sockets.has(socketId)) {
        sockets.delete(socketId);
        if (sockets.size === 0) {
          this.parentSockets.delete(parentId);
        }
        break;
      }
    }
  }

  /**
   * Register a parent socket for monitoring.
   */
  addParentSocket(parentUserId: string, socketId: string): void {
    if (!this.parentSockets.has(parentUserId)) {
      this.parentSockets.set(parentUserId, new Set());
    }
    this.parentSockets.get(parentUserId)!.add(socketId);
  }

  /**
   * Get all socket IDs for a parent (for broadcasting).
   */
  getParentSocketIds(parentUserId: string): string[] {
    const sockets = this.parentSockets.get(parentUserId);
    return sockets ? Array.from(sockets) : [];
  }

  /**
   * Set parent monitoring for a conversation session.
   */
  setParentMonitoring(
    conversationId: string,
    parentSocketId: string,
  ): boolean {
    const session = this.getByConversationId(conversationId);
    if (!session) return false;

    session.isParentMonitoring = true;
    session.parentSocketId = parentSocketId;
    return true;
  }

  /**
   * Get all active sessions (for admin/debugging).
   */
  getAllSessions(): ConversationSession[] {
    return Array.from(this.sessions.values());
  }

  /**
   * Get count of active sessions.
   */
  getActiveCount(): number {
    return this.sessions.size;
  }

  /**
   * Clean up stale sessions (no activity for more than 30 minutes).
   */
  cleanupStaleSessions(maxIdleMinutes: number = 30): string[] {
    const now = new Date();
    const staleIds: string[] = [];

    for (const [socketId, session] of this.sessions) {
      const idleMs = now.getTime() - session.lastActivityAt.getTime();
      const idleMinutes = idleMs / (1000 * 60);

      if (idleMinutes > maxIdleMinutes) {
        staleIds.push(socketId);
      }
    }

    for (const socketId of staleIds) {
      this.removeBySocketId(socketId);
    }

    return staleIds;
  }
}
