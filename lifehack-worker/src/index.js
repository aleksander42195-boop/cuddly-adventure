export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === '/oauth/start') {
      // TODO: Replace with real OAuth. For now, redirect back to app with a demo token.
      return Response.redirect('lifehackapp://oauth?token=DEMO_TOKEN', 302);
    }

    if (url.pathname === '/v1/chat/completions' && request.method === 'POST') {
      // Validate app access token
      const auth = request.headers.get('authorization') || '';
      if (!auth.startsWith('Bearer ')) {
        return new Response(JSON.stringify({ error: 'missing bearer' }), {
          status: 401,
          headers: { 'content-type': 'application/json' },
        });
      }
      const body = await request.json();
      const upstream = 'https://api.openai.com/v1/chat/completions';
      const streaming = body.stream === true;

      const resp = await fetch(upstream, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'authorization': `Bearer ${env.OPENAI_API_KEY}`,
        },
        body: JSON.stringify(body),
      });

      if (!streaming) {
        const text = await resp.text();
        return new Response(text, { status: resp.status, headers: { 'content-type': 'application/json' } });
      }

      // Stream SSE back to client
      const { readable, writable } = new TransformStream();
      const writer = writable.getWriter();
      const encoder = new TextEncoder();
      const decoder = new TextDecoder();

      (async () => {
        try {
          if (!resp.body) throw new Error('no body');
          const reader = resp.body.getReader();
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            const chunk = decoder.decode(value);
            await writer.write(encoder.encode(chunk));
          }
          await writer.close();
        } catch (e) {
          await writer.abort(e);
        }
      })();

      return new Response(readable, {
        status: resp.status,
        headers: { 'content-type': 'text/event-stream' },
      });
    }

    return new Response(JSON.stringify({ error: 'Not found' }), {
      status: 404,
      headers: { 'content-type': 'application/json' },
    });
  },
};
