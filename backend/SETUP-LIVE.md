# Going live with eBay (production keyset)

Everything below is already wired. You only need to (1) paste your two eBay secrets into
`.env`, (2) run the backend, (3) point the app at it. **Never paste secrets into the app
or into chat — they live only in `backend/.env`, which is git-ignored.**

## What I set up for you
- Hardened eBay integration: OAuth token caching **+ auto-refresh on 401**, request
  **timeouts**, graceful sample fallback if eBay is unreachable.
- Safety: optional **API-key guard** (constant-time check), simple **rate limiting**
  (per-IP/minute), secrets never logged, `.env` git-ignored.
- `backend/.env` created with production config + a **freshly generated `API_KEY`**.
  Only `EBAY_CLIENT_ID` and `EBAY_CLIENT_SECRET` are blank — you paste those.
- App wired for live mode: `AppEnvironment.backendBaseURL` + optional `backendAPIKey`,
  and `LiveCardDataService` sends the key and the smart query variants.

## Steps

**1. Install Node 18.17+** (no Homebrew needed): download the LTS from <https://nodejs.org>.
Verify: `node -v`.

**2. Add your eBay secrets** — open `backend/.env` and replace the two placeholders:
```
EBAY_CLIENT_ID=PASTE_YOUR_EBAY_CLIENT_ID_HERE
EBAY_CLIENT_SECRET=PASTE_YOUR_EBAY_CLIENT_SECRET_HERE
```
(`API_KEY` is already generated; leave it.)

**3. Install + start:**
```bash
cd backend
npm install
npm run typecheck   # I couldn't run this here (no Node on the build machine) — confirm it's clean
npm run dev
```
On boot you should see: `[eBay production] active: LIVE, sold: sample`.

**4. Verify (copy your API key from `backend/.env`):**
```bash
curl -s localhost:8080/health
# → {"status":"ok","ebayEnv":"production","ebayActiveConfigured":true,"marketplaceInsightsEnabled":false,"apiKeyRequired":true}

curl -s -H "Authorization: Bearer PASTE_API_KEY_FROM_ENV" \
  "localhost:8080/search?q=Charizard%20VMAX" | python3 -m json.tool | head -40
# → real eBay ACTIVE listings; "meta":{"mode":"mixed", "sources":{"active":"eBay Browse API","sold":"Sample data"}}
```

**5. Connect the app** — in `OneTap/Data/CardDataService.swift` → `AppEnvironment`:
```swift
static let dataMode: DataMode = .live
static let backendAPIKey = "<paste the API_KEY from backend/.env>"
// backendBaseURL is already http://localhost:8080 (simulator).
```
- **Simulator:** `localhost:8080` works as-is.
- **Physical iPhone:** set `backendBaseURL` to your Mac's LAN IP (e.g. `http://192.168.1.50:8080`)
  and add an ATS dev exception (target ▸ Info ▸ *Allow Local Networking = YES*). Both the
  Mac and phone on the same Wi-Fi.

## Honest status with a standard production keyset
| | Status now |
|---|---|
| **Active listings** (Browse API) | ✅ **LIVE** with your keyset |
| **Sold/completed** (Marketplace Insights) | ⚠️ **Still sample** — Insights is a *separate* Limited Release approval. When granted, set `EBAY_MARKETPLACE_INSIGHTS_ENABLED=true` and implement `ebaySoldProvider.ts`. |
| Response `meta.mode` | `mixed` (live active + sample sold) |

## Before exposing the backend publicly (deploy)
- Deploy over **HTTPS** (Render / Railway / Fly / your VPS). Set env vars in the host's
  dashboard — **don't upload `.env`**.
- Keep `API_KEY` set (the app already sends it). Rotate it if it ever leaks.
- Point the app's `backendBaseURL` at the HTTPS URL.
- A key embedded in a shipped app is extractable — for a public launch, move to per-user
  auth or App Attest later. For now the API key + rate limit stop casual abuse.
