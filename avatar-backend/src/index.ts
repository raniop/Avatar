import Fastify from 'fastify';
import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import fastifyStatic from '@fastify/static';
import { Server } from 'socket.io';
import path from 'path';
import { getEnv } from './config/environment';
import { prisma } from './config/prisma';
import { authPlugin } from './plugins/auth';
import { authRoutes } from './routes/auth';
import { childrenRoutes } from './routes/children';
import { avatarRoutes } from './routes/avatars';
import { missionRoutes } from './routes/missions';
import { conversationRoutes } from './routes/conversations';
import { questionRoutes } from './routes/questions';
import { SessionManager } from './websocket/SessionManager';
import { registerConversationHandler } from './websocket/handlers/conversationHandler';
import { registerParentHandler } from './websocket/handlers/parentHandler';

async function buildApp() {
  const env = getEnv();

  const fastify = Fastify({
    logger: {
      level: env.NODE_ENV === 'development' ? 'info' : 'warn',
      transport:
        env.NODE_ENV === 'development'
          ? { target: 'pino-pretty', options: { colorize: true } }
          : undefined,
    },
  });

  // ── Plugins ──────────────────────────────────────
  await fastify.register(cors, {
    origin: env.CORS_ORIGIN,
    credentials: true,
  });

  await fastify.register(multipart, {
    limits: {
      fileSize: 10 * 1024 * 1024, // 10MB max for audio files
    },
  });

  await fastify.register(authPlugin);

  // ── Static files (audio uploads) ───────────────
  await fastify.register(fastifyStatic, {
    root: path.resolve(env.UPLOAD_DIR || './uploads'),
    prefix: '/uploads/',
    decorateReply: false,
  });

  // ── Health check ─────────────────────────────────
  fastify.get('/health', async () => {
    return { status: 'ok', timestamp: new Date().toISOString() };
  });

  // ── API Routes ───────────────────────────────────
  await fastify.register(authRoutes, { prefix: '/api/auth' });
  await fastify.register(childrenRoutes, { prefix: '/api/children' });
  await fastify.register(avatarRoutes, { prefix: '/api/avatars' });
  await fastify.register(missionRoutes, { prefix: '/api/missions' });
  await fastify.register(conversationRoutes, { prefix: '/api/conversations' });
  await fastify.register(questionRoutes, { prefix: '/api/questions' });

  // ── Global error handler ─────────────────────────
  fastify.setErrorHandler((error: Error & { statusCode?: number }, _request, reply) => {
    fastify.log.error(error);

    const statusCode = error.statusCode ?? 500;
    const message =
      statusCode === 500 && env.NODE_ENV === 'production'
        ? 'Internal Server Error'
        : error.message;

    reply.status(statusCode).send({
      error: true,
      statusCode,
      message,
    });
  });

  return fastify;
}

async function start() {
  const env = getEnv();
  const fastify = await buildApp();

  // Ensure Fastify is ready (creates the underlying http.Server)
  await fastify.ready();

  // ── Socket.io setup ──────────────────────────────
  // Attach Socket.IO directly to Fastify's internal HTTP server
  const io = new Server(fastify.server, {
    cors: {
      origin: '*',  // Allow all origins for mobile app connections
      credentials: true,
    },
    path: '/ws',
    transports: ['websocket', 'polling'],
    maxHttpBufferSize: 5 * 1024 * 1024, // 5 MB — voice messages can be large
  });

  // Expose Socket.IO instance on fastify so HTTP routes can emit events
  (fastify as any).io = io;

  const sessionManager = new SessionManager();

  // Register WebSocket handlers
  io.on('connection', (socket) => {
    fastify.log.info(`WebSocket client connected: ${socket.id}`);

    registerConversationHandler(io, socket, sessionManager);
    registerParentHandler(io, socket, sessionManager);

    socket.on('disconnect', (reason) => {
      fastify.log.info(`WebSocket client disconnected: ${socket.id} - ${reason}`);
      sessionManager.removeBySocketId(socket.id);
    });
  });

  // ── Graceful shutdown ────────────────────────────
  const gracefulShutdown = async (signal: string) => {
    fastify.log.info(`Received ${signal}. Shutting down gracefully...`);

    io.close();
    await fastify.close();
    await prisma.$disconnect();
    process.exit(0);
  };

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));

  // ── Start server ─────────────────────────────────
  try {
    await fastify.listen({ port: env.PORT, host: env.HOST });
    fastify.log.info(`Server listening on http://${env.HOST}:${env.PORT}`);
    fastify.log.info(`Socket.IO listening on path /ws`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
}

start();
