import http from 'node:http';

const port = Number(process.env.MOCK_AI_PROVIDER_PORT ?? 4567);
let chatCompletionRequests = 0;

const server = http.createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/__stats') {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ chatCompletionRequests }));
    return;
  }

  if (request.method === 'POST' && request.url === '/__reset') {
    chatCompletionRequests = 0;
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ chatCompletionRequests }));
    return;
  }

  if (request.method !== 'POST' || request.url !== '/v1/chat/completions') {
    response.writeHead(404, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ error: 'not_found' }));
    return;
  }

  chatCompletionRequests += 1;
  let body = '';
  request.setEncoding('utf8');
  for await (const chunk of request) body += chunk;

  let locale = 'vi';
  try {
    const parsed = JSON.parse(body);
    const userContent = parsed?.messages?.find((message) => message?.role === 'user')?.content;
    const userPayload = typeof userContent === 'string' ? JSON.parse(userContent) : userContent;
    locale = ['vi', 'en', 'ja'].includes(userPayload?.locale) ? userPayload.locale : 'vi';
  } catch {
    locale = 'vi';
  }

  const answers = {
    vi: 'Bạn đang có nền tảng theo dõi dòng tiền tốt. Hãy tiếp tục giữ quỹ dự phòng và rà soát nhóm chi tiêu lớn nhất.',
    en: 'Your cashflow tracking foundation is healthy. Keep an emergency buffer and review your largest spending category.',
    ja: 'キャッシュフロー管理の土台は良好です。緊急用資金を保ち、最も大きい支出カテゴリを見直してください。',
  };

  response.writeHead(200, { 'content-type': 'application/json' });
  response.end(JSON.stringify({
    choices: [
      {
        message: {
          content: JSON.stringify({
            answer: answers[locale],
            suggestions: ['Review top spending', 'Keep emergency fund', 'Set one budget alert'],
          }),
        },
      },
    ],
  }));
});

server.listen(port, '0.0.0.0', () => {
  console.log(`mock-openai-compatible-provider listening on ${port}`);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));
