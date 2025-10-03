# Lifehack Proxy (Cloudflare Workers)

This is a minimal OpenAI proxy you can deploy to Cloudflare Workers. It holds your OpenAI API key server‑side and exposes endpoints the iOS app can call using an app access token.

## Endpoints
- GET /oauth/start → Begin auth flow (stub: returns a redirect to lifehackapp://oauth?token=DEMO). Replace with Sign in with Apple or GitHub OAuth.
- POST /v1/chat/completions → Proxies to OpenAI with server key. Supports `stream: true`.

## Deploy (quick start)
1. Install Wrangler
   npm i -g wrangler
2. Init
   wrangler init --site false
3. Set secret (server OpenAI key)
   wrangler secret put OPENAI_API_KEY
4. Publish
   wrangler deploy

Then set the deployed URL in the app: Settings → Coach Engine → Managed Proxy → Login/Configure.

## Notes
- This is a starter. Add proper OAuth, token verification, rate limiting, and logging as needed.
