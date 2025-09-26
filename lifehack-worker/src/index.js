export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Hello route for quick sanity check
    if (url.pathname === '/' || url.pathname === '/hello') {
      return new Response('Hello from Cloudflare Workers 🚀', {
        headers: { 'content-type': 'text/plain' },
      });
    }

    if (url.pathname === '/oauth/start') {
      // GitHub OAuth start: redirect to GitHub authorize with state and callback
      const state = [...crypto.getRandomValues(new Uint8Array(16))].map(x => x.toString(16).padStart(2, '0')).join('');
      const redirectUri = `${url.origin}/oauth/callback`;
      const auth = new URL('https://github.com/login/oauth/authorize');
      auth.searchParams.set('client_id', env.GITHUB_CLIENT_ID);
      auth.searchParams.set('redirect_uri', redirectUri);
      auth.searchParams.set('scope', 'read:user');
      auth.searchParams.set('state', state);
      const resp = Response.redirect(auth.toString(), 302);
      resp.headers.set('Set-Cookie', `oauth_state=${state}; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=600`);
      return resp;
    }

    if (url.pathname === '/oauth/callback') {
      const code = url.searchParams.get('code');
      const state = url.searchParams.get('state');
      const cookie = request.headers.get('Cookie') || '';
      const match = cookie.match(/(?:^|; )oauth_state=([^;]+)/);
      const savedState = match ? decodeURIComponent(match[1]) : null;
      if (!code || !state || !savedState || state !== savedState) {
        return new Response('Invalid OAuth state', { status: 400 });
      }
      const redirectUri = `${url.origin}/oauth/callback`;
      // Exchange code for token
      const tokenResp = await fetch('https://github.com/login/oauth/access_token', {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'accept': 'application/json' },
        body: JSON.stringify({
          client_id: env.GITHUB_CLIENT_ID,
          client_secret: env.GITHUB_CLIENT_SECRET,
          code,
          redirect_uri: redirectUri,
        }),
      });
      if (!tokenResp.ok) {
        const txt = await tokenResp.text();
        return new Response(`Token exchange failed: ${txt}`, { status: 500 });
      }
      const data = await tokenResp.json();
      const accessToken = data.access_token;
      if (!accessToken) {
        return new Response('No access token', { status: 500 });
      }
      // Redirect back to app with token (consider issuing your own JWT instead)
      const appUrl = `lifehackapp://oauth?token=${encodeURIComponent(accessToken)}`;
      const resp = Response.redirect(appUrl, 302);
      resp.headers.append('Set-Cookie', 'oauth_state=; Max-Age=0; Path=/; HttpOnly; Secure; SameSite=Lax');
      return resp;
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
