# Deploying the OneTap backend (so the app works on mobile data, for everyone)

## Why this exists

Today the app talks to the backend running on **your Mac** (`http://10.0.130.233:8080`).
That only works while your Mac is on and the phone is on the same Wi‑Fi. A Cloudflare
**quick tunnel** can expose your Mac to the internet for testing, but the URL changes every
run and it depends on your Mac staying awake.

For real use — App Store users on 4G/5G — the backend has to live on a **always-on, public
HTTPS URL** that doesn't depend on your laptop. That's what this guide sets up. The backend
is already host‑ready (`config.ts` reads `PORT`/`HOST` from the environment, real env vars
override `.env`, and `HOST` defaults to `0.0.0.0`). A `Dockerfile` is included.

The end state: a stable URL like `https://onetap-backend.onrender.com`. You paste it **once**
into the app (Debug → Backend URL → "Use this URL"), or we make it the built-in default, and
the app works on any network without you touching tunnels again.

---

## Recommended: Render (free, no credit card)

Render builds from a Git repo and gives a stable HTTPS URL. Best "just works" starting point.

**One-time prerequisite — put the code on GitHub:**
```bash
cd "/Users/stanleychen/Desktop/one tap"
git init && git add . && git commit -m "OneTap"
# create an empty repo on github.com, then:
git remote add origin https://github.com/<you>/onetap.git
git push -u origin main
```
> The repo root has the iOS app; the backend is in `/backend`. Render's "Root Directory"
> setting (below) points it at `backend`.

**Deploy:**
1. Sign in at **render.com** (free, no card).
2. **New → Web Service** → connect your GitHub repo.
3. Settings:
   - **Root Directory:** `backend`
   - **Runtime:** Docker  *(it auto-detects `backend/Dockerfile`)*
   - **Instance type:** Free
4. **Environment variables** (Advanced → Add):
   | Key | Value |
   |---|---|
   | `EBAY_CLIENT_ID` | your eBay App ID |
   | `EBAY_CLIENT_SECRET` | your eBay Cert ID |
   | `EBAY_ENV` | `production` |
   | `API_KEY` | a long random string you make up (see Security below) |
   | `EBAY_MARKETPLACE_INSIGHTS_ENABLED` | `false` |
   *(Do NOT set `PORT` — Render injects it. `HOST` is already `0.0.0.0`.)*
5. **Create Web Service.** First build takes a few minutes. When live you'll get a URL like
   `https://onetap-backend.onrender.com`.
6. Verify in a browser: `https://onetap-backend.onrender.com/health` → `{"status":"ok",...}`.
7. In the app: Debug → **Backend URL** → paste that URL → **Use this URL**.

**Caveat:** Render's free tier **sleeps after ~15 min idle**, so the first request after a
nap takes ~30–50s (then it's fast). Fine for testing/early users. To remove cold starts,
upgrade to Render's cheapest paid instance (~$7/mo) or use Fly.io.

---

## Alternative: Fly.io (no cold starts, needs a card on file)

Deploys straight from this folder's `Dockerfile` — no GitHub needed.
```bash
brew install flyctl            # or: curl -L https://fly.io/install.sh | sh
cd "/Users/stanleychen/Desktop/one tap/backend"
fly launch --no-deploy         # name it e.g. onetap-backend; it writes fly.toml
fly secrets set EBAY_CLIENT_ID=… EBAY_CLIENT_SECRET=… EBAY_ENV=production API_KEY=… EBAY_MARKETPLACE_INSIGHTS_ENABLED=false
fly deploy
```
Gives `https://onetap-backend.fly.dev`. Set internal port 8080 when asked.

Railway (railway.app) is a third option — same idea, deploy from repo, set the env vars.

---

## Security: turn the API key back on for a public backend

Locally we run **open** (`API_KEY=` empty) for convenience. A public URL must NOT be open, or
anyone could find it and burn your eBay API quota. So:

1. Set `API_KEY` on the host to a long random string (e.g. `openssl rand -hex 24`).
2. Put the **same** string in the app: `OneTap/Data/CardDataService.swift` →
   `static let backendAPIKey = "…"`. (Embedding it in the app is fine for now; rotate before a
   real public launch — a determined user can extract it from any shipped binary.)
3. The app already sends it as `Authorization: Bearer …` when `backendAPIKey` is non‑empty.

---

## What's still sample after deploying

Deploying does NOT make **sold** data real. Active listings are live (eBay Browse); sold comps
remain sample until you're approved for eBay **Marketplace Insights** (Limited Release). The
app already labels this honestly (it hides sample sold and offers "See sold on eBay"). Once you
have Insights, wire a real sold provider and set `EBAY_MARKETPLACE_INSIGHTS_ENABLED=true`.
