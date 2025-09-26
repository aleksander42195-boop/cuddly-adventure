export interface Env {
  OPENAI_API_KEY: string;
}

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/oauth/start') {
      // TODO: Implement real OAuth (Sign in with Apple/GitHub). For now, return a demo token callback.
      return Response.redirect('lifehackapp://oauth?token=DEMO_TOKEN', 302);
    }

    if (url.pathname === '/v1/chat/completions' && request.method === 'POST') {
      // In production, validate app access token from Authorization: Bearer <token>
      const auth = request.headers.get('authorization') || '';
      if (!auth.startsWith('Bearer ')) return jsonResponse(401, { error: 'missing bearer' });
      // TODO: verify token (JWT or session lookup)
      const body = await request.json();

      const upstream = new URL('https://api.openai.com/v1/chat/completions');
      const streaming = body.stream === true;
      const init: RequestInit = {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'authorization': `Bearer ${env.OPENAI_API_KEY}`,
        },
        body: JSON.stringify(body),
      };

      const resp = await fetch(upstream, init);
      if (!streaming) {
        const text = await resp.text();
        return new Response(text, { status: resp.status, headers: { 'content-type': 'application/json' } });
      }
      // Stream back as SSE lines
      const { readable, writable } = new TransformStream();
      const writer = writable.getWriter();
      const encoder = new TextEncoder();
      (async () => {
        try {
          if (!resp.body) throw new Error('no body');
          const reader = resp.body.getReader();
          const decoder = new TextDecoder();
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            const chunk = decoder.decode(value);
            await writer.write(encoder.encode(chunk));
          }
          await writer.close();
        } catch (e) {
          await writer.abort(e as any);
        }
      })();
      return new Response(readable, {
        status: resp.status,
        headers: { 'content-type': 'text/event-stream' },
      });
    }

    return jsonResponse(404, { error: 'Not found' });
  },
};
