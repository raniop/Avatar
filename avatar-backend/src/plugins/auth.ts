import fp from 'fastify-plugin';
import fjwt from '@fastify/jwt';
import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { getEnv } from '../config/environment';

// Extend Fastify types for JWT user payload
declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: { userId: string; email: string };
    user: { userId: string; email: string };
  }
}

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
}

async function authPluginCallback(fastify: FastifyInstance) {
  const env = getEnv();

  await fastify.register(fjwt, {
    secret: env.JWT_SECRET,
    sign: {
      expiresIn: '24h',
    },
  });

  // Decorator for protected routes
  fastify.decorate(
    'authenticate',
    async function (request: FastifyRequest, reply: FastifyReply) {
      try {
        await request.jwtVerify();
      } catch (err) {
        reply.status(401).send({
          error: true,
          statusCode: 401,
          message: 'Unauthorized: Invalid or expired token',
        });
      }
    },
  );
}

export const authPlugin = fp(authPluginCallback, {
  name: 'auth-plugin',
});
