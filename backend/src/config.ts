import { existsSync, readFileSync } from "node:fs";

/**
 * Minimal .env loader — no dependency. Real environment variables always win over the
 * file, so this is safe in production (where you set real env vars and ship no .env).
 */
function loadDotEnv(path = ".env"): void {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = value;
  }
}
loadDotEnv();

const env = process.env;
const num = (v: string | undefined, fallback: number): number => {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
};
const bool = (v: string | undefined, fallback: boolean): boolean =>
  v === undefined ? fallback : ["1", "true", "yes", "on"].includes(v.toLowerCase());

export const config = {
  port: num(env.PORT, 8080),
  host: env.HOST ?? "0.0.0.0",
  apiKey: env.API_KEY || null,
  // Safety interlock: the server refuses to start without an API_KEY unless this is
  // explicitly set. Prevents accidentally deploying an OPEN public backend (which would
  // let anyone burn the eBay quota). Local dev sets ALLOW_UNAUTHENTICATED=1 in .env.
  allowUnauthenticated: bool(env.ALLOW_UNAUTHENTICATED, false),
  cacheTtlSeconds: num(env.CACHE_TTL_SECONDS, 300),
  // Hard cap on cached search entries so the in-memory cache can't grow without bound.
  cacheMaxEntries: num(env.CACHE_MAX_ENTRIES, 500),
  // Page size: how many active listings the first /search response returns, and how many
  // each "load more" page adds. (Was 12 — raised so broad queries surface a full first page.)
  activeLimit: num(env.ACTIVE_LISTINGS_LIMIT, 50),
  // Ceiling on the full ranked active pool that /search builds once, caches, and paginates
  // over. Must be >= the max total the app pages to (>=130). eBay Browse allows <=200/request.
  activeMaxResults: num(env.ACTIVE_MAX_RESULTS, 150),
  requestTimeoutMs: num(env.REQUEST_TIMEOUT_MS, 8000),
  rateLimitPerMinute: num(env.RATE_LIMIT_PER_MINUTE, 60),
  ebay: {
    clientId: env.EBAY_CLIENT_ID || null,
    clientSecret: env.EBAY_CLIENT_SECRET || null,
    marketplaceId: env.EBAY_MARKETPLACE_ID || "EBAY_US",
    env: env.EBAY_ENV === "sandbox" ? "sandbox" : "production",
    apiBaseUrl:
      env.EBAY_ENV === "sandbox" ? "https://api.sandbox.ebay.com" : "https://api.ebay.com",
    marketplaceInsightsEnabled: bool(env.EBAY_MARKETPLACE_INSIGHTS_ENABLED, false),
    // Trading-card category fence (v1.1). Browse allows only ONE category_id per request,
    // so the active provider queries each in parallel and merges. IDs confirmed via eBay's
    // Taxonomy API (EBAY_US tree):
    //   261328 = Trading Card Singles (sports), 183454 = CCG Individual Cards (Pokémon/MTG/YGO).
    // Override with CARD_CATEGORY_IDS (comma-separated) — toggle-ready for a future category
    // picker. Set to empty to disable the fence (search all of eBay again).
    cardCategoryIds: (env.CARD_CATEGORY_IDS ?? "261328,183454")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean),
    // Marketplaces the app may switch between. Each returns its own listings in its native
    // currency (no FX conversion) and shares the same card category IDs (verified live).
    // Used to validate the per-request `marketplace` param; anything else → marketplaceId.
    supportedMarketplaces: ["EBAY_US", "EBAY_GB", "EBAY_AU", "EBAY_CA", "EBAY_DE"],
  },
};

/** True when we have eBay app credentials, i.e. active listings can be live. */
export function isEbayConfigured(): boolean {
  return Boolean(config.ebay.clientId && config.ebay.clientSecret);
}
