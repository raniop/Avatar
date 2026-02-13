import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import bcrypt from 'bcrypt';
import { z } from 'zod';
import prisma from '../../config/prisma';
import { firebaseAuth } from '../../config/firebase';

const registerSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  displayName: z.string().min(1, 'Display name is required').max(100),
  locale: z.enum(['en', 'he']).default('en'),
});

const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

type RegisterBody = z.infer<typeof registerSchema>;
type LoginBody = z.infer<typeof loginSchema>;
type RefreshBody = z.infer<typeof refreshSchema>;

const firebaseAuthSchema = z.object({
  idToken: z.string().min(1, 'Firebase ID token is required'),
  displayName: z.string().min(1).max(100).default('User'),
});

type FirebaseAuthBody = z.infer<typeof firebaseAuthSchema>;

const SALT_ROUNDS = 12;

export async function authRoutes(fastify: FastifyInstance) {
  // ── Firebase Auth (Apple / Google / Email) ────────
  fastify.post(
    '/firebase',
    async (
      request: FastifyRequest<{ Body: FirebaseAuthBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = firebaseAuthSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const { idToken, displayName } = parsed.data;

      try {
        // Verify the Firebase ID token
        const decodedToken = await firebaseAuth.verifyIdToken(idToken);
        const { uid, email } = decodedToken;

        if (!email) {
          return reply.status(400).send({
            error: true,
            statusCode: 400,
            message: 'Email is required from Firebase auth',
          });
        }

        // Find or create user by Firebase UID
        let user = await prisma.user.findUnique({
          where: { firebaseUid: uid },
        });

        if (!user) {
          // Check if a user with this email already exists (e.g., registered via email/password)
          user = await prisma.user.findUnique({
            where: { email },
          });

          if (user) {
            // Link Firebase UID to existing user
            user = await prisma.user.update({
              where: { id: user.id },
              data: { firebaseUid: uid },
            });
          } else {
            // Create new user
            user = await prisma.user.create({
              data: {
                firebaseUid: uid,
                email,
                displayName: displayName || decodedToken.name || 'User',
                locale: 'en',
              },
            });
          }
        }

        // Generate our own JWT for backend API auth
        const accessToken = fastify.jwt.sign(
          { userId: user.id, email: user.email },
          { expiresIn: '24h' },
        );

        return reply.send({
          user: {
            id: user.id,
            email: user.email,
            displayName: user.displayName,
            locale: user.locale,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
          },
          accessToken,
        });
      } catch (err: any) {
        console.error('Firebase auth error:', err.message);
        return reply.status(401).send({
          error: true,
          statusCode: 401,
          message: 'Invalid Firebase ID token',
        });
      }
    },
  );

  // ── Register ─────────────────────────────────────
  fastify.post(
    '/register',
    async (
      request: FastifyRequest<{ Body: RegisterBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = registerSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const { email, password, displayName, locale } = parsed.data;

      // Check if user already exists
      const existingUser = await prisma.user.findUnique({ where: { email } });
      if (existingUser) {
        return reply.status(409).send({
          error: true,
          statusCode: 409,
          message: 'An account with this email already exists',
        });
      }

      // Hash password
      const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

      // Create user
      const user = await prisma.user.create({
        data: {
          email,
          passwordHash,
          displayName,
          locale,
        },
        select: {
          id: true,
          email: true,
          displayName: true,
          locale: true,
          createdAt: true,
        },
      });

      // Generate tokens
      const accessToken = fastify.jwt.sign(
        { userId: user.id, email: user.email },
        { expiresIn: '24h' },
      );

      const refreshToken = fastify.jwt.sign(
        { userId: user.id, email: user.email, type: 'refresh' },
        { expiresIn: '30d' },
      );

      return reply.status(201).send({
        user,
        accessToken,
        refreshToken,
      });
    },
  );

  // ── Login ────────────────────────────────────────
  fastify.post(
    '/login',
    async (
      request: FastifyRequest<{ Body: LoginBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = loginSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const { email, password } = parsed.data;

      // Find user
      const user = await prisma.user.findUnique({ where: { email } });
      if (!user) {
        return reply.status(401).send({
          error: true,
          statusCode: 401,
          message: 'Invalid email or password',
        });
      }

      // Verify password (passwordHash may be null for social login users)
      if (!user.passwordHash) {
        return reply.status(401).send({
          error: true,
          statusCode: 401,
          message: 'This account uses social login. Please sign in with Apple or Google.',
        });
      }
      const isValid = await bcrypt.compare(password, user.passwordHash);
      if (!isValid) {
        return reply.status(401).send({
          error: true,
          statusCode: 401,
          message: 'Invalid email or password',
        });
      }

      // Generate tokens
      const accessToken = fastify.jwt.sign(
        { userId: user.id, email: user.email },
        { expiresIn: '24h' },
      );

      const refreshToken = fastify.jwt.sign(
        { userId: user.id, email: user.email, type: 'refresh' },
        { expiresIn: '30d' },
      );

      return reply.send({
        user: {
          id: user.id,
          email: user.email,
          displayName: user.displayName,
          locale: user.locale,
          createdAt: user.createdAt,
        },
        accessToken,
        refreshToken,
      });
    },
  );

  // ── Refresh Token ────────────────────────────────
  fastify.post(
    '/refresh',
    async (
      request: FastifyRequest<{ Body: RefreshBody }>,
      reply: FastifyReply,
    ) => {
      const parsed = refreshSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: true,
          statusCode: 400,
          message: 'Validation failed',
          details: parsed.error.flatten().fieldErrors,
        });
      }

      const { refreshToken } = parsed.data;

      try {
        const decoded = fastify.jwt.verify<{
          userId: string;
          email: string;
          type: string;
        }>(refreshToken);

        if (decoded.type !== 'refresh') {
          return reply.status(401).send({
            error: true,
            statusCode: 401,
            message: 'Invalid refresh token',
          });
        }

        // Verify user still exists
        const user = await prisma.user.findUnique({
          where: { id: decoded.userId },
        });

        if (!user) {
          return reply.status(401).send({
            error: true,
            statusCode: 401,
            message: 'User not found',
          });
        }

        // Issue new tokens
        const newAccessToken = fastify.jwt.sign(
          { userId: user.id, email: user.email },
          { expiresIn: '24h' },
        );

        const newRefreshToken = fastify.jwt.sign(
          { userId: user.id, email: user.email, type: 'refresh' },
          { expiresIn: '30d' },
        );

        return reply.send({
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        });
      } catch {
        return reply.status(401).send({
          error: true,
          statusCode: 401,
          message: 'Invalid or expired refresh token',
        });
      }
    },
  );

  // ── Get Current User ─────────────────────────────
  fastify.get(
    '/me',
    { onRequest: [fastify.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const user = await prisma.user.findUnique({
        where: { id: request.user.userId },
        select: {
          id: true,
          email: true,
          displayName: true,
          locale: true,
          createdAt: true,
          updatedAt: true,
        },
      });

      if (!user) {
        return reply.status(404).send({
          error: true,
          statusCode: 404,
          message: 'User not found',
        });
      }

      return reply.send({ user });
    },
  );
}
