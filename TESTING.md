# OneTap — Testing & Polishing in Sample Mode

Everything you can do **right now, without eBay approval**, to make the app and backend
solid. Sample mode exercises the entire app and the entire backend pipeline except the
actual eBay network calls.

---

## 0. What changed to make testing easier (no new features)

- **Mode banner** in results now shows `SAMPLE / MIXED / LIVE` + the per-section source
  labels (driven by the backend's `meta.mode`). Honest at a glance.
- **Section headers** show their data source (e.g. "Sold · Sample data").
- **Debug screen** (DEBUG builds only): tap the 🐞 on the home screen → see config, run a
  one-tap **self-test** across every sample card, and ping the backend `/health`.
- **6 sample cards** now (was 3): UFC, F1, Pokémon, NBA (Luka), MLB (Trout), Soccer (Mbappé).
- **Empty state** suggests real cards you can tap.
- The app and backend share the **same sample set**, so they behave identically.

---

## 1. Quick local testing checklist

**SwiftUI app (sample mode — default):**
- [ ] `open OneTap.xcodeproj`, run on a simulator (⌘R)
- [ ] Search each of the 6 example cards → results render
- [ ] Mode banner shows **SAMPLE**
- [ ] Stats look right; sold & active sections populate
- [ ] Filters (Both/Sold/Active, Raw/Graded, Sort) work
- [ ] Tap a listing → detail → "Search on eBay" opens Safari
- [ ] Search gibberish → clean empty state with suggestions
- [ ] 🐞 → Run self-test → all green

**Node/Fastify backend (sample mode):**
- [ ] `npm install` succeeds
- [ ] `npm run dev` starts on :8080
- [ ] `GET /health` returns `ebayActiveConfigured:false`
- [ ] `GET /search?q=Charizard VMAX` returns sold+active+stats, `meta.mode:"sample"`
- [ ] `npm run typecheck` passes

---

## 2. Run & test the backend locally

### Install Node (no Homebrew needed)
Pick one:
- **Installer:** download the **LTS** from <https://nodejs.org> and run it. Verify: `node -v`.
- **nvm:** `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash`
  then restart the terminal and `nvm install --lts`.

### Start it
```bash
cd "backend"
npm install
cp .env.example .env        # works as-is on sample data
npm run dev                 # http://localhost:8080  (auto-reloads)
```

### Hit the endpoints
```bash
# Health
curl -s http://localhost:8080/health
# → {"status":"ok","ebayActiveConfigured":false,"marketplaceInsightsEnabled":false}

# Search (sample mode)
curl -s "http://localhost:8080/search?q=Charizard%20VMAX" | python3 -m json.tool | head -40

# Just the mode + sources (python3 is preinstalled on macOS):
curl -s "http://localhost:8080/search?q=Luka%20Doncic" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['meta']['mode'], d['meta']['sources'], len(d['sold']),'sold', len(d['active']),'active')"
# → sample {'active': 'Sample data', 'sold': 'Sample data'} 6 sold 4 active

# Validation + no-match behavior
curl -s "http://localhost:8080/search?q=x"            # → 400, query too short
curl -s "http://localhost:8080/search?q=zzzznope"     # → 200 with empty arrays
```

### Verify sample / mixed / live behavior
| You set in `.env` | `meta.mode` | Why |
|---|---|---|
| nothing | `sample` | no eBay keys → active+sold both sample |
| real `EBAY_CLIENT_ID/SECRET` | `mixed` | active = live eBay, sold = still sample |
| keys **+** Marketplace Insights (after approval) | `live` | both live |
| **wrong** eBay keys | `sample` | active fetch fails → **falls back** to sample, adds a `note` |

The wrong-keys test is worth doing now: put junk in `EBAY_CLIENT_ID`, restart, search —
you should still get a 200 with sample active data and a `meta.notes` entry explaining the
fallback. That proves the app never hard-fails when eBay is down.

---

## 3. Connect the app to the local backend

In [`OneTap/Data/CardDataService.swift`](OneTap/Data/CardDataService.swift) → `AppEnvironment`:

**Sample mode (default, no backend):**
```swift
static let dataMode: DataMode = .sample
```

**Live mode hitting your local backend:**
```swift
static let dataMode: DataMode = .live
static let backendBaseURL = URL(string: "http://localhost:8080")!
```

- **Simulator:** works as-is — ATS exempts `localhost`. Run the backend, run the app,
  search. The banner should now read **MIXED** (if you added eBay keys) or **SAMPLE**
  (backend with no keys), and the section sources update accordingly.
- **Physical iPhone:** use your Mac's LAN IP, e.g. `http://192.168.1.50:8080` (find it
  with `ipconfig getifaddr en0`), same Wi-Fi. Plain HTTP to a non-loopback host is blocked
  by App Transport Security, so add a dev exception: target ▸ **Info** ▸ add
  **App Transport Security Settings** ▸ **Allow Local Networking = YES**. Then run the app
  from Xcode onto the device.
- Use the 🐞 **Debug screen → Ping /health** to confirm the device/simulator can reach the
  backend before debugging anything else.

> Tip: keep `dataMode = .sample` committed; flip to `.live` only while testing, so the app
> always builds-and-runs for anyone who opens it cold.

---

## 4. QA checklist (run through once per build)

**Search**
- [ ] Typing + return runs a search; <2 chars does nothing
- [ ] Example chips and recent searches run searches
- [ ] Recent searches persist across app relaunch

**Results render**
- [ ] Mode banner correct (SAMPLE/MIXED/LIVE) + source labels
- [ ] Each row: image/placeholder, title, price, condition badge, date (sold) / shipping
- [ ] Graded shows "PSA 10" style; raw shows condition text

**Stats**
- [ ] Average / median / low / high / count match the sold list
- [ ] "Lowest active ask" = cheapest active listing
- [ ] No sold data → "No recent sold data" (try Active-only filter)

**Sold / Active sections**
- [ ] Sold rows have dates; active rows don't
- [ ] Counts in headers match rows shown

**Filters**
- [ ] Both / Sold / Active toggles sections correctly
- [ ] Raw / Graded filters each section; empty-filter shows the inline note
- [ ] Sort: Newest / Price↑ / Price↓ reorder correctly

**Detail tap-through**
- [ ] Tap row → detail with big image, price, condition, date
- [ ] "Search this card on eBay" opens a real eBay search

**Empty / error / honesty**
- [ ] Gibberish search → clean empty state + suggestions
- [ ] Backend unreachable (live mode, server off) → honest error + Retry
- [ ] Sample mode is clearly labeled everywhere (banner + sources)

**Backend**
- [ ] `/health` ok; `/search` shape matches the app; `meta.mode` correct
- [ ] Wrong eBay keys → graceful sample fallback with a note
- [ ] `npm run typecheck` clean

---

## 5. What you can / can't test now

**Fully testable now (no eBay):**
- Entire app UX: search, results, stats, filters, detail, empty/error states, recents
- The whole backend pipeline: routing, providers, merging, stats, caching, fallback,
  source labeling, validation, mode flags — all of it except the real eBay HTTP call
- App ↔ backend integration in **sample** mode over local HTTP

**Cannot test until eBay:**
- Real **active** listings (needs eBay Browse keys → flips to `mixed`)
- Real **sold** listings (needs **Marketplace Insights** approval → flips to `live`)
- Real images, real prices, real tap-through item links

**The moment eBay approves you:**
1. Put your Production `EBAY_CLIENT_ID/SECRET` in `backend/.env`, restart → **active goes
   live immediately** (`mode: mixed`). Re-run the QA checklist against real data.
2. For sold: implement `EbaySoldProvider` (the stub documents the exact endpoint + scope),
   set `EBAY_MARKETPLACE_INSIGHTS_ENABLED=true` → **`mode: live`**.
3. Deploy the backend over HTTPS, point the app's `backendBaseURL` at it, ship.
