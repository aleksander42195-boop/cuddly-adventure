# lifehack-worker

This Cloudflare Worker powers the managed proxy and GitHub OAuth for the app. It is already deployed to:

- workers.dev: https://lifehack-worker.aleksander42195.workers.dev
- zone route (intended): lifehack.no/*

workers_dev is intentionally kept enabled while DNS migrates so you always have a working URL.

## DNS: point lifehack.no to Cloudflare

To serve lifehack.no/* from this Worker, the domain must be on your Cloudflare account and Cloudflare must be the authoritative DNS for the zone.

1) Add the zone
   - Cloudflare Dashboard → Add a site → `lifehack.no` → Free plan is fine.
   - Cloudflare shows two nameservers like `alice.ns.cloudflare.com`, `bob.ns.cloudflare.com`.

2) Update nameservers at the registrar
   - In your registrar’s control panel (currently the domain uses `ns1.hyp.net`, `ns2.hyp.net`, `ns3.hyp.net`), replace them with the two Cloudflare nameservers from step 1.
   - DNS propagation usually completes within minutes to a couple of hours.

3) Create a proxied DNS record for the apex (recommended)
   - DNS tab for `lifehack.no` → Add record:
     - Type: A, Name: `@`, Content: `192.0.2.1` (placeholder TEST-NET-1), Proxy: ON (orange cloud)
   - This record is never reached by clients because the Worker Route intercepts requests first, but the proxied record ensures the hostname is active and proxied through Cloudflare.

4) Route is already configured in `wrangler.toml`

```toml
routes = [
  { pattern = "lifehack.no/*", zone_name = "lifehack.no" }
]
workers_dev = true
```

No extra deploy steps are needed after DNS is on Cloudflare. The route will start serving once nameserver changes have propagated.

## Verification

Use these checks after nameservers have moved to Cloudflare:

- Nameservers now Cloudflare:
  - `dig +short NS lifehack.no` → should return two `*.ns.cloudflare.com` names.
- Hostname resolves (Cloudflare returns any IP for the proxied apex):
  - `dig +short lifehack.no`
- HTTP(S) works and Worker responds:
  - `curl -sS https://lifehack.no/hello` → `Hello from Cloudflare Workers 🚀`

You can continue to use workers.dev during migration:

- `curl -sS https://lifehack-worker.aleksander42195.workers.dev/hello`

## Secrets (OpenAI)

Set the Worker secret once to enable the proxy to call OpenAI:

```bash
cd lifehack-worker
npx -y wrangler@4.40.2 secret put OPENAI_API_KEY
# Paste your key when prompted
```

## Deploy

From this folder:

```bash
npx -y wrangler@4.40.2 deploy
```

This uses `wrangler.toml` and keeps both the workers.dev URL and the `lifehack.no/*` route.

## Troubleshooting

- `curl https://lifehack.no/hello` fails:
  - Ensure nameservers are Cloudflare (`dig +short NS lifehack.no` → `*.ns.cloudflare.com`).
  - Ensure there is a proxied DNS record for the apex (`@`) in the DNS tab (orange cloud ON).
  - Wait for propagation (try again in ~10–30 minutes).

- 404 at lifehack.no but workers.dev works:
  - Check the `routes` entry in `wrangler.toml` and redeploy.

- 5xx errors:
  - Check Cloudflare Status and Worker logs (`wrangler tail`).

