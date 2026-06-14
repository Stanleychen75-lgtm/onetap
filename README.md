# OneTap — Card Price Check (v1)

A clean, fast, mobile-first iOS app for checking what a trading card is selling for.
Search a card → see **sold** listings, **active** listings, and a **value summary**
(average / median / range). Built to feel premium and stay simple, with a data layer
designed so real marketplace data can be swapped in without touching the UI.

> **Status:** v1 MVP. Runs today on **sample data**. The architecture is production-shaped
> so you can connect a real backend later with a one-line change.

---

## 1. Honest note on eBay data (read this first)

This is the part most "card price" tutorials gloss over. The truth:

| Data you want | Realistic access | Notes |
|---|---|---|
| **Active / current listings** | ✅ Possible | eBay **Browse API** (Buy APIs). Needs an eBay developer account + OAuth app tokens. Higher rate limits need production approval. |
| **Sold / completed listings** | ⚠️ Restricted | The modern source is eBay's **Marketplace Insights API**, which is a **Limited Release** — you must **apply and be approved**. The old Finding API (`findCompletedItems`) is deprecated and not reliable to build on. |
| **Unrestricted free sold data** | ❌ Not real | There is no free, public, client-side API that hands you unlimited eBay sold history. Anyone claiming otherwise is usually scraping (against eBay's ToS, fragile, and risky for an App Store app). |

**What this means for the app:**

- You should **not** call eBay directly from the iOS app. API secrets can't live in an
  App Store binary, and OAuth/approvals belong server-side.
- The honest architecture is **app → your backend → eBay (or another provider)**.
  Your backend holds the keys, does OAuth, caches results, and computes stats.
- Until you have that backend + eBay approval, the app runs on **sample data** and says
  so, clearly, in the UI (the little "Sample data" banner). It never pretends.

This is exactly how tools like 130point appear to operate: a server aggregates and
caches marketplace data; the client is just a clean reader.

---

## 2. Recommended stack — SwiftUI (native)

**Chosen: SwiftUI + Swift, MVVM, zero third-party dependencies.**

Why over React Native / Expo:

- The app is lists, search, and detail views — SwiftUI's exact sweet spot.
- Native feel, performance, and animations ("premium, hobby-native, fast").
- No JS bridge, no dependency churn, first-party tooling (Xcode), App Store-ready.
- Async/await + `URLSession` cover all networking; `AsyncImage` covers images. No pods.

React Native would only win if you needed **Android on day one** or had an existing JS
team. For a focused, premium iOS price-checker, native is simpler and more reliable.

- **Min iOS:** 17.0 · **Language:** Swift 5 mode · **UI:** SwiftUI · **Arch:** MVVM + Repository

---

## 3. Architecture

```
        UI (SwiftUI Views)                ViewModels (@MainActor)            Data layer
 ┌───────────────────────────┐     ┌───────────────────────────┐     ┌──────────────────────────┐
 │ SearchView                │────▶│ SearchViewModel           │     │ CardDataService (protocol)│
 │ ResultsView               │────▶│ ResultsViewModel ─────────┼────▶│  ├─ MockCardDataService   │ (A) sample JSON
 │ ListingDetailView         │     │   • load() async          │     │  ├─ LiveCardDataService   │ (B) your backend
 │ + reusable components     │     │   • filters/sort          │     │  └─ (future provider)     │ (C) later
 └───────────────────────────┘     └───────────────────────────┘     └──────────────────────────┘
                                                                        returns → CardSearchResult
                                                                        (sold[] + active[] + stats)
```

- **Views** know nothing about where data comes from. They render a `CardSearchResult`.
- **ViewModels** own state (loading/loaded/empty/error), filters, and call the service.
- **`CardDataService`** is the single seam. Swapping data sources = one line in `AppEnvironment`.
- **Stats are computed**, not invented (`PriceStats.from(soldListings:)`).

Everything is modular and ready to extend: a future **stats module**, **price history**,
or **saved searches** slots in without reshaping the app.

---

## 4. Data layer — three honest modes

Set the mode in `OneTap/Data/CardDataService.swift`:

```swift
enum AppEnvironment {
    static let dataMode: DataMode = .sample   // 👈 .sample (now) → .live (later)
    static let backendBaseURL = URL(string: "https://api.example.com")!
}
```

- **A. Sample mode (`.sample`) — default today.** `MockCardDataService` loads
  `OneTap/Data/sample_data.json`, matches your query, and computes real stats. A small
  delay simulates the network so loading states are exercised.
- **B. Production mode (`.live`).** `LiveCardDataService` calls
  `GET {backendBaseURL}/search?q=...` and decodes a `CardSearchResult`. The networking is
  complete — point it at your backend and the whole app works on live data, no UI changes.
  (It throws a clear "not connected yet" error if the placeholder host is still set, which
  the UI shows honestly.)
- **C. Future mode.** A better provider is just another `CardDataService` + another
  `DataMode` case. Nothing else changes.

**Your future backend just needs to return this JSON shape** (same as `sample_data.json`
per card, plus optional pre-computed `stats`):

```json
{ "query": "...", "sold": [ /* Listing */ ], "active": [ /* Listing */ ] }
```

---

## 5. Project structure

```
OneTap/
├─ App/                OneTapApp.swift               (@main)
├─ Models/             Listing, PriceStats, SearchModels, CardSearchResult
├─ Data/               CardDataService (protocol + AppEnvironment),
│                      MockCardDataService, LiveCardDataService, sample_data.json
├─ DesignSystem/       Theme.swift (colors/spacing/type)
│  └─ Components/      SearchField, ListingRowView, StatsSummaryView, FilterBarView,
│                      SectionHeaderView, Badges, AsyncCardImage, StateViews
├─ Features/
│  ├─ Search/          SearchView + SearchViewModel
│  ├─ Results/         ResultsView + ResultsViewModel
│  └─ Detail/          ListingDetailView
└─ Assets.xcassets/    AccentColor, AppIcon (placeholder)
```

---

## 6. Setup & run

**Requirements:** macOS + Xcode 16 or newer.

```bash
open "OneTap.xcodeproj"
```

Then in Xcode: pick an iPhone simulator (e.g. iPhone 17) and press **⌘R**.

Or from the command line:

```bash
xcodebuild -project OneTap.xcodeproj -scheme OneTap \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Try the three example searches on the home screen, or type "Adesanya", "Hamilton",
or "Charizard".

> **App Store note:** add a real 1024×1024 app icon (the `AppIcon` asset is currently a
> placeholder) and set your own bundle identifier + signing team before submitting.

---

## 7. Sample / demo data

`OneTap/Data/sample_data.json` ships six realistic datasets, each with **sold + active**
listings (raw and graded) so the value summary and filters are fully exercised:

- 🥊 **UFC** — 2021 Panini Prizm UFC Israel Adesanya
- 🏎️ **F1** — 2020 Topps Chrome Formula 1 Lewis Hamilton (Rookie)
- ⚡ **Pokémon** — Charizard VMAX (Champion's Path 074/073)
- 🏀 **NBA** — 2018-19 Panini Prizm Luka Dončić (Rookie)
- ⚾ **MLB** — 2011 Topps Update Mike Trout (Rookie)
- ⚽ **Soccer** — 2018 Panini Prizm World Cup Kylian Mbappé (Rookie)

The results screen shows a **mode banner** (sample/mixed/live) and per-section source
labels. A DEBUG-only **developer screen** (🐞 on the home screen) runs a one-tap self-test
across all sample cards and can ping the backend `/health`. See **[TESTING.md](TESTING.md)**
for the full local-testing + QA playbook.

Images are intentionally placeholders (no broken links offline); the tap-through opens a
**real eBay search** for that exact card (sold filter for sold listings) — honest about
what we can actually offer in sample mode.

---

## 8. Roadmap — what to build after v1

**Near term (UI already scaffolded for these):**
1. **Average / median sold price** — done as computed stats; surface trends next.
2. **Quantity sold** — already shown; add a "sales velocity" (sold per week).
3. **Price history chart** — add `Charts` view fed by sold listings grouped by week.
4. **Better filters** — date range, price range, sold-within-N-days, exclude lots.

**Backend / data:**
5. **Stand up your backend** (`/search?q=`), then flip `dataMode = .live`.
6. **eBay integration** — Browse API (active) now; apply for Marketplace Insights (sold).
7. **Caching & rate-limit handling** server-side; pre-compute stats.
8. **More marketplaces** — add new `Marketplace` cases + provider implementations.

**App:**
9. **Saved searches / watchlist**, then sync, then accounts — in that order, only when needed.

---

## 9. Deliberately NOT in v1

Accounts · collection tracking · selling · grading ROI · forums · accessories ·
AI price prediction · watchlists · notifications · admin tools.

Kept out on purpose to ship the best possible **price-checking** first version.
