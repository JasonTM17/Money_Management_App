import { createHmac } from 'node:crypto';
import { createServer } from 'node:http';
import { describe, expect, it, vi } from 'vitest';
import { buildApp } from '../../app.js';
import { createAccessToken } from '../../lib/session-tokens.js';

function snapshotEnv(keys: string[]) {
  const snapshot = new Map(keys.map((key) => [key, process.env[key]]));
  return () => {
    for (const key of keys) {
      const value = snapshot.get(key);
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  };
}

describe('AI analysis route', () => {
  it('requires bearer auth', async () => {
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/ai/analysis',
        payload: { question: 'Phân tích chi tiêu tháng này', locale: 'vi' },
      });

      expect(response.statusCode).toBe(401);
      expect(response.json()).toEqual({
        code: 'unauthorized',
        message: 'Authentication required',
      });
    } finally {
      await app.close();
    }
  });

  it('returns unavailable when n8n workflow is not configured', async () => {
    const restoreEnv = snapshotEnv(['N8N_CHATBOT_WEBHOOK_URL', 'N8N_CHATBOT_WEBHOOK_SECRET']);
    delete process.env.N8N_CHATBOT_WEBHOOK_URL;
    delete process.env.N8N_CHATBOT_WEBHOOK_SECRET;
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });
    const token = createAccessToken({
      sub: '00000000-0000-4000-8000-000000000001',
      email: 'demo@cashflow.local',
    });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/ai/analysis',
        headers: { authorization: `Bearer ${token}` },
        payload: { question: 'Phân tích chi tiêu tháng này', locale: 'vi' },
      });

      expect(response.statusCode).toBe(503);
      expect(response.json()).toEqual({
        code: 'ai_analysis_unconfigured',
        message: 'AI analysis workflow is not configured',
      });
    } finally {
      restoreEnv();
      await app.close();
    }
  });

  it('rejects invalid payloads before calling n8n', async () => {
    const restoreEnv = snapshotEnv(['N8N_CHATBOT_WEBHOOK_URL', 'N8N_CHATBOT_WEBHOOK_SECRET']);
    process.env.N8N_CHATBOT_WEBHOOK_URL = 'http://127.0.0.1:1/webhook/cashflow-ai-analysis';
    process.env.N8N_CHATBOT_WEBHOOK_SECRET = 'test-webhook-secret';
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });
    const token = createAccessToken({
      sub: '00000000-0000-4000-8000-000000000001',
      email: 'demo@cashflow.local',
    });

    try {
      const emptyQuestion = await app.inject({
        method: 'POST',
        url: '/v1/ai/analysis',
        headers: { authorization: `Bearer ${token}` },
        payload: { question: '   ', locale: 'vi' },
      });
      const invalidLocale = await app.inject({
        method: 'POST',
        url: '/v1/ai/analysis',
        headers: { authorization: `Bearer ${token}` },
        payload: { question: 'Phân tích chi tiêu tháng này', locale: 'fr' },
      });

      expect(emptyQuestion.statusCode).toBe(400);
      expect(emptyQuestion.json()).toMatchObject({
        code: 'validation_failed',
        message: 'Request validation failed',
      });
      expect(invalidLocale.statusCode).toBe(400);
      expect(invalidLocale.json()).toMatchObject({
        code: 'validation_failed',
        message: 'Request validation failed',
      });
    } finally {
      restoreEnv();
      await app.close();
    }
  });

  it('sends signed requests to the configured n8n webhook', async () => {
    const restoreEnv = snapshotEnv(['N8N_CHATBOT_WEBHOOK_URL', 'N8N_CHATBOT_WEBHOOK_SECRET']);
    const secret = 'test-webhook-secret';
    let receivedBody = '';
    let receivedSignature = '';
    const server = createServer((request, response) => {
      request.setEncoding('utf8');
      request.on('data', (chunk) => {
        receivedBody += chunk;
      });
      request.on('end', () => {
        receivedSignature = String(request.headers['x-cashflow-signature-sha256'] ?? '');
        response.setHeader('content-type', 'application/json');
        response.end(JSON.stringify({
          answer: 'Bạn đang chi tiêu ổn định.',
          suggestions: ['Theo dõi ăn uống', 'Giữ quỹ dự phòng', 'Xem lại ví tiền mặt', 'Theo dõi hóa đơn', 'Tối ưu mục tiêu'],
        }));
      });
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const address = server.address();
    if (!address || typeof address === 'string') throw new Error('Test server did not start');
    process.env.N8N_CHATBOT_WEBHOOK_URL = `http://127.0.0.1:${address.port}/webhook/cashflow-ai-analysis`;
    process.env.N8N_CHATBOT_WEBHOOK_SECRET = secret;
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });
    const token = createAccessToken({
      sub: '00000000-0000-4000-8000-000000000001',
      email: 'demo@cashflow.local',
    });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/ai/analysis',
        headers: { authorization: `Bearer ${token}` },
        payload: { question: 'Phân tích chi tiêu tháng này', locale: 'vi' },
      });

      expect(response.statusCode).toBe(200);
      expect(response.json()).toEqual({
        answer: 'Bạn đang chi tiêu ổn định.',
        suggestions: ['Theo dõi ăn uống', 'Giữ quỹ dự phòng', 'Xem lại ví tiền mặt', 'Theo dõi hóa đơn', 'Tối ưu mục tiêu'],
      });
      expect(receivedSignature).toBe(
        createHmac('sha256', secret).update(receivedBody).digest('hex'),
      );
      expect(JSON.parse(receivedBody)).toEqual({
        question: 'Phân tích chi tiêu tháng này',
        locale: 'vi',
      });
    } finally {
      restoreEnv();
      await app.close();
      await new Promise<void>((resolve, reject) => {
        server.close((error) => error ? reject(error) : resolve());
      });
    }
  });

  it('maps n8n timeout to a stable error', async () => {
    vi.useFakeTimers();
    const restoreEnv = snapshotEnv(['N8N_CHATBOT_WEBHOOK_URL', 'N8N_CHATBOT_WEBHOOK_SECRET']);
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation((_input, init) => new Promise((_resolve, reject) => {
      init?.signal?.addEventListener('abort', () => {
        const error = new Error('aborted');
        error.name = 'AbortError';
        reject(error);
      });
    }));
    process.env.N8N_CHATBOT_WEBHOOK_URL = 'http://127.0.0.1:1/webhook/cashflow-ai-analysis';
    process.env.N8N_CHATBOT_WEBHOOK_SECRET = 'test-webhook-secret';
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });
    const token = createAccessToken({
      sub: '00000000-0000-4000-8000-000000000001',
      email: 'demo@cashflow.local',
    });

    try {
      const responsePromise = app.inject({
        method: 'POST',
        url: '/v1/ai/analysis',
        headers: { authorization: `Bearer ${token}` },
        payload: { question: 'Phân tích chi tiêu tháng này', locale: 'vi' },
      });
      await vi.advanceTimersByTimeAsync(10000);
      const response = await responsePromise;

      expect(response.statusCode).toBe(503);
      expect(response.json()).toEqual({
        code: 'ai_analysis_timeout',
        message: 'AI analysis workflow timed out',
      });
    } finally {
      fetchSpy.mockRestore();
      vi.useRealTimers();
      restoreEnv();
      await app.close();
    }
  });

  it('rejects invalid n8n responses with a stable error', async () => {
    const restoreEnv = snapshotEnv(['N8N_CHATBOT_WEBHOOK_URL', 'N8N_CHATBOT_WEBHOOK_SECRET']);
    const server = createServer((_request, response) => {
      response.setHeader('content-type', 'application/json');
      response.end(JSON.stringify({ suggestions: ['Thiếu câu trả lời'] }));
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const address = server.address();
    if (!address || typeof address === 'string') throw new Error('Test server did not start');
    process.env.N8N_CHATBOT_WEBHOOK_URL = `http://127.0.0.1:${address.port}/webhook/cashflow-ai-analysis`;
    process.env.N8N_CHATBOT_WEBHOOK_SECRET = 'test-webhook-secret';
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });
    const token = createAccessToken({
      sub: '00000000-0000-4000-8000-000000000001',
      email: 'demo@cashflow.local',
    });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/ai/analysis',
        headers: { authorization: `Bearer ${token}` },
        payload: { question: 'Phân tích chi tiêu tháng này', locale: 'vi' },
      });

      expect(response.statusCode).toBe(503);
      expect(response.json()).toEqual({
        code: 'ai_analysis_invalid_response',
        message: 'AI analysis workflow returned an invalid response',
      });
    } finally {
      restoreEnv();
      await app.close();
      await new Promise<void>((resolve, reject) => {
        server.close((error) => error ? reject(error) : resolve());
      });
    }
  });

  it('rejects malformed n8n JSON with a stable error', async () => {
    const restoreEnv = snapshotEnv(['N8N_CHATBOT_WEBHOOK_URL', 'N8N_CHATBOT_WEBHOOK_SECRET']);
    const server = createServer((_request, response) => {
      response.setHeader('content-type', 'application/json');
      response.end('{not-json');
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const address = server.address();
    if (!address || typeof address === 'string') throw new Error('Test server did not start');
    process.env.N8N_CHATBOT_WEBHOOK_URL = `http://127.0.0.1:${address.port}/webhook/cashflow-ai-analysis`;
    process.env.N8N_CHATBOT_WEBHOOK_SECRET = 'test-webhook-secret';
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });
    const token = createAccessToken({
      sub: '00000000-0000-4000-8000-000000000001',
      email: 'demo@cashflow.local',
    });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/ai/analysis',
        headers: { authorization: `Bearer ${token}` },
        payload: { question: 'Phân tích chi tiêu tháng này', locale: 'vi' },
      });

      expect(response.statusCode).toBe(503);
      expect(response.json()).toEqual({
        code: 'ai_analysis_invalid_response',
        message: 'AI analysis workflow returned an invalid response',
      });
    } finally {
      restoreEnv();
      await app.close();
      await new Promise<void>((resolve, reject) => {
        server.close((error) => error ? reject(error) : resolve());
      });
    }
  });
});
