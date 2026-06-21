import { config } from "./config";
import { TtlCache } from "./cache";
import { computeStats } from "./stats";
import type { CardSearchResult, Listing, SearchMeta } from "./types";
import { normalize, variants as variantsFor, score, type NormalizedQuery } from "./searchEngine";
import {
  makeActiveProvider,
  makeSoldProvider,
  SampleActiveProvider,
  MockSoldProvider,
} from "./providers";

// Providers are stateless — build them once.
const activeProvider = makeActiveProvider();
const soldProvider = makeSoldProvider();
const sampleActiveFallback = new SampleActiveProvider();
const mockSoldFallback = new MockSoldProvider();

const cache = new TtlCache<CardSearchResult>(config.cacheTtlSeconds * 1000, config.cacheMaxEntries);
const SOLD_LIMIT = 24;
// Upper bound on query variants fanned out per request. Actual eBay Browse calls are at most
// MAX_VARIANTS × cardCategoryIds.length (early-exit once the pool fills), so the per-request
// provider fan-out stays small and bounded regardless of client input.
const MAX_VARIANTS = 6;

/**
 * Minimal server-side logger (structurally compatible with Fastify's `req.log`). The route
 * passes its request logger in so upstream/eBay error detail is recorded server-side instead
 * of being echoed to clients via meta.notes (see catch blocks below).
 */
interface RequestLogger {
  error(obj: unknown, msg?: string): void;
}

// Light, card-aware ranking nudge: among equally-relevant titles, prefer ones with collector
// signals (grade, rookie, numbered, year, popular set/parallel terms). The category fence
// already guarantees results are cards — this is a quality tiebreak, NOT a filter, so it
// never hides anything.
const CARD_SIGNALS =
  /\b(psa|bgs|cgc|sgc|rookie|rc|auto|patch|refractor|prizm|holo|sapphire|numbered|1st\s*ed(?:ition)?)\b|#?\d{1,3}\/\d{1,4}|\b(?:19|20)\d{2}\b/i;
function cardSignalBoost(title: string): number {
  return CARD_SIGNALS.test(title) ? 0.5 : 0;
}

/**
 * Layered fallback + merge + dedupe + rank.
 *
 * For a LIVE provider (eBay) we try query variants in order (full → important tokens →
 * name → surname), merging results and stopping once we have enough — this is the recall
 * boost that makes "Max Verstappen" or "Verstappen auto" return browsable results. For a
 * SAMPLE provider we only use the primary query (sample data is grouped per card, so
 * fanning out would mix unrelated cards). Everything is ranked by `SearchEngine.score`.
 */
async function gather(
  fetchFn: (q: string) => Promise<Listing[]>,
  tries: string[],
  nq: NormalizedQuery,
  limit: number,
  live: boolean,
): Promise<Listing[]> {
  const queries = live ? tries : tries.slice(0, 1);
  const byId = new Map<string, Listing>();
  let firstError: unknown = null;

  for (let i = 0; i < queries.length; i++) {
    try {
      const batch = await fetchFn(queries[i]);
      for (const listing of batch) if (!byId.has(listing.id)) byId.set(listing.id, listing);
    } catch (err) {
      if (i === 0) firstError = err;   // primary variant failed
    }
    if (byId.size >= limit) break;     // enough recall — stop fanning out
  }

  // If the primary query errored and we got nothing, let the caller fall back to sample.
  if (byId.size === 0 && firstError) throw firstError;

  return [...byId.values()]
    .sort(
      (a, b) =>
        (score(b.title, nq) + cardSignalBoost(b.title)) -
        (score(a.title, nq) + cardSignalBoost(a.title)),
    )
    .slice(0, limit);
}

export async function runSearch(rawQuery: string, providedVariants?: string[], marketplaceId?: string, logger?: RequestLogger): Promise<CardSearchResult> {
  const query = rawQuery.trim();
  // Marketplace is part of the cache key — US (USD) and GB (GBP) results must not be shared.
  const cacheKey = `${marketplaceId ?? config.ebay.marketplaceId}:${query.toLowerCase()}`;

  const cached = cache.get(cacheKey);
  if (cached) {
    return { ...cached, meta: { ...cached.meta, cached: true } };
  }

  const nq = normalize(query);
  // Variants are derived server-side from the query (see /search — client-supplied variants
  // are no longer trusted, so they can't poison the cache or amplify provider calls). The
  // optional `providedVariants` arg is kept for internal callers/tests but is capped + filtered.
  const planned = (providedVariants?.length ? providedVariants : variantsFor(nq))
    .filter((v) => v.length >= 2)
    .slice(0, MAX_VARIANTS);
  const tries = planned.length ? planned : [query];

  const notes: string[] = [];

  // ── Active (variant fallback + merge + dedupe + rank, sample fallback on error) ──
  let active: Listing[] = [];
  let activeSource = activeProvider.source;
  let activeLive = activeProvider.live;
  try {
    // Build the FULL ranked pool (up to activeMaxResults). The /search route paginates this
    // cached pool into pages of config.activeLimit — so "load more" costs zero extra eBay calls.
    active = await gather((q) => activeProvider.fetchActive(q, marketplaceId), tries, nq, config.activeMaxResults, activeProvider.live);
  } catch (err) {
    // Keep upstream detail in SERVER logs only; the client-facing note stays generic so raw
    // eBay error text is never echoed back on the /search response (defense-in-depth).
    logger?.error({ err }, "Active: live fetch failed — serving sample data");
    notes.push("Active: live fetch failed — served sample data instead.");
    active = await gather((q) => sampleActiveFallback.fetchActive(q), tries, nq, config.activeMaxResults, false);
    activeSource = "Sample data (eBay unavailable)";
    activeLive = false;
  }

  // ── Sold ─────────────────────────────────────────────────────────────────────
  let sold: Listing[] = [];
  let soldSource = soldProvider.source;
  let soldLive = soldProvider.live;
  try {
    sold = await gather((q) => soldProvider.fetchSold(q), tries, nq, SOLD_LIMIT, soldProvider.live);
  } catch (err) {
    logger?.error({ err }, "Sold: live provider unavailable — serving sample data");
    notes.push("Sold: live provider unavailable — served sample data instead.");
    sold = await gather((q) => mockSoldFallback.fetchSold(q), tries, nq, SOLD_LIMIT, false);
    soldSource = "Sample data";
    soldLive = false;
  }
  if (!soldLive) {
    notes.push("Sold listings are sample data — eBay Marketplace Insights requires approval (Limited Release).");
  }

  const stats = computeStats(sold);
  const mode: SearchMeta["mode"] =
    activeLive && soldLive ? "live" : !activeLive && !soldLive ? "sample" : "mixed";

  const result: CardSearchResult = {
    query,
    sold,
    active,
    stats,
    meta: {
      mode,
      sources: { active: activeSource, sold: soldSource },
      live: { active: activeLive, sold: soldLive },
      cached: false,
      notes,
    },
  };

  cache.set(cacheKey, result);
  return result;
}
