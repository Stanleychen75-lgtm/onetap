# OneTap Backend

The smallest practical backend for the OneTap iOS app. One endpoint, `GET /search?q=`,
returns sold + active listings + computed stats in the exact JSON shape the app decodes.

- **Active listings:** live via eBay **Browse API** (when you add keys).
- **Sold listings:** **sample data** today — real eBay sold history (Marketplace Insights)
  is a Limited Release that requires eBay approval. The seam to plug it in is ready.
- **Stack:** Node.js + TypeScript + Fastify. Zero HTTP-client deps (native `fetch`).

---

## What is live now vs. mocked

| | Source today | When it goes live |
|---|---|---|
| **Active listings** | Sample data (no keys) → **eBay Browse API** the moment you add `EBAY_CLIENT_ID/SECRET` | Now — just add keys |
| **Sold listings** | Sample data | After eBay approves you for **Marketplace Insights**, then implement `EbaySoldProvider` + set `EBAY_MARKETPLACE_INSIGHTS_ENABLED=true` |
| **Stats** | Computed from whatever sold data is present (real math) | Always live |

The response's `meta.mode` tells you which you got: `sample`, `mixed`, or `live`.

---

## Setup

Requires **Node 18.17+**.

```bash
cd backend
npm install
cp .env.example .env      # works as-is on sample data; add eBay keys when ready
npm run dev               # http://localhost:8080  (auto-reloads)
```

`npm run typecheck` runs the TypeScript compiler with no emit.

### Add eBay (active listings go live)
1. Create a developer account at https://developer.ebay.com and make an app keyset.
2. Put the **Production** App ID (Client ID) + Cert ID (Client Secret) in `.env`.
3. Restart. `/health` will show `"ebayActiveConfigured": true` and active listings come
   from eBay. Secrets stay server-side — they never touch the app.

---

## Endpoints

### `GET /health`
```json
{ "status": "ok", "ebayActiveConfigured": false, "marketplaceInsightsEnabled": false }
```

### `GET /search?q=<text>`
`q` must be ≥ 2 chars (else `400`). Example: `GET /search?q=Charizard%20VMAX`

```jsonc
{
  "query": "Charizard VMAX",
  "sold":   [ /* Listing[] — kind:"sold", includes soldDate */ ],
  "active": [ /* Listing[] — kind:"active" */ ],
  "stats":  { "salesCount": 6, "averageSold": 75.67, "medianSold": 65,
              "minSold": 38, "maxSold": 145, "currencyCode": "USD" },
  "meta": {                                  // the app ignores this for now
    "mode": "sample",                        // sample | mixed | live
    "sources": { "active": "Sample data", "sold": "Sample data" },
    "live":    { "active": false, "sold": false },
    "cached":  false,
    "notes":   ["Sold listings are sample data — Marketplace Insights requires approval."]
  }
}
```

`Listing` shape: `id, title, kind, price, currencyCode, soldDate?, condition?, marketplace, imageURL?, listingURL?, shippingPrice?` — identical to the app's Swift model.

---

## Architecture

```
GET /search ─▶ searchService.runSearch(q)
                 ├─ ActiveListingsProvider   (eBay Browse  | Sample, with fallback)
                 ├─ SoldListingsProvider      (Marketplace Insights stub | Sample)
                 ├─ computeStats(sold)        (real average/median/min/max)
                 └─ TtlCache                  (in-memory, 5 min)
```

```
src/
├─ index.ts              Fastify server: /health, /search, optional API-key guard
├─ config.ts             env loading (+ tiny .env reader, no dep)
├─ searchService.ts      merges providers → CardSearchResult, fallback + source labels
├─ stats.ts              computeStats()
├─ cache.ts              TtlCache
├─ types.ts              mirrors the app's Swift models (the contract)
├─ data/sampleData.ts    UFC / F1 / Pokémon datasets + query matcher
└─ providers/
   ├─ types.ts                  ActiveListingsProvider / SoldListingsProvider
   ├─ ebayAuth.ts               OAuth client-credentials token (cached)
   ├─ ebayActiveProvider.ts     eBay Browse API (LIVE)
   ├─ sampleActiveProvider.ts   sample fallback
   ├─ mockSoldProvider.ts       sample sold (default)
   ├─ ebaySoldProvider.ts       Marketplace Insights stub (needs approval)
   └─ index.ts                  provider factory (the one swap point)
```

Swapping data sources = editing `providers/index.ts`. Nothing in the routes/UI changes.

---

## Connect the iOS app

In [`OneTap/Data/CardDataService.swift`](../OneTap/Data/CardDataService.swift), change two lines in `AppEnvironment`:

```swift
static let dataMode: DataMode = .live
static let backendBaseURL = URL(string: "http://localhost:8080")!   // simulator
```

- **Simulator:** `http://localhost:8080` works as-is — ATS exempts loopback.
- **Physical device:** use your Mac's LAN IP (e.g. `http://192.168.1.50:8080`, same Wi-Fi).
  Plain HTTP to a non-loopback host is blocked by App Transport Security, so for device
  testing add an ATS dev exception (target ▸ Info ▸ add `App Transport Security Settings`
  ▸ `Allow Local Networking = YES`), or put the backend behind HTTPS.

Run the backend (`npm run dev`), then build & run the app. The app already knows how to
call `GET /search?q=` and decode this response — no app code beyond those two lines.

> Note: this backend was not executed in the authoring environment (no Node installed
> there). The JSON contract was verified by decoding a representative response through
> the app's real Swift models. Run `npm install && npm run dev` to start it.

---

## What to build after this

1. **Get eBay keys** → active goes live immediately.
2. **Apply for Marketplace Insights** → implement `EbaySoldProvider`, flip the flag.
3. **Deploy** (Render/Railway/Fly/your VPS) over HTTPS; set env vars there, ship no `.env`.
4. **Persist a cache** (Redis) and add light rate-limiting if you make `/search` public.
5. **Price history**: store sold results over time → power the app's future chart.
