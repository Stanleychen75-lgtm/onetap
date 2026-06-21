import Fastify from "fastify";
import { timingSafeEqual } from "node:crypto";
import { config, isEbayConfigured } from "./config";
import { runSearch } from "./searchService";

const app = Fastify({ logger: true });

// ── Simple in-memory rate limit (fixed window / IP) — protects your eBay quota from
//    abuse without a dependency. Swap for @fastify/rate-limit + Redis at real scale. ──
const hits = new Map<string, { count: number; resetAt: number }>();
function isRateLimited(ip: string): boolean {
  const now = Date.now();
  const entry = hits.get(ip);
  if (!entry || entry.resetAt < now) {
    hits.set(ip, { count: 1, resetAt: now + 60_000 });
    return false;
  }
  entry.count += 1;
  return entry.count > config.rateLimitPerMinute;
}

/** Constant-time string compare so the API key can't be guessed via timing. */
function secureEquals(a: string, b: string): boolean {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  return ab.length === bb.length && timingSafeEqual(ab, bb);
}

app.addHook("onRequest", async (req, reply) => {
  if (req.url.startsWith("/health")) return;

  if (isRateLimited(req.ip)) {
    return reply.code(429).send({ error: "Too many requests — slow down." });
  }

  // Optional shared-secret guard between the app and this backend. Enforced only when
  // API_KEY is set. Keeps your eBay quota from being burned by the public.
  if (config.apiKey) {
    const header = req.headers.authorization ?? "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : "";
    if (!secureEquals(token, config.apiKey)) {
      return reply.code(401).send({ error: "Unauthorized" });
    }
  }
});

// Public, unauthenticated liveness probe — kept minimal so it discloses no configuration
// (eBay status, marketplace flags, whether auth is required) to anonymous callers.
app.get("/health", async () => ({ status: "ok" }));

function toInt(v: string | undefined, fallback: number): number {
  const n = Number.parseInt(v ?? "", 10);
  return Number.isFinite(n) ? n : fallback;
}

app.get("/search", async (req, reply) => {
  const params = req.query as {
    q?: string; marketplace?: string; page?: string; pageSize?: string;
  };
  const q = (params.q ?? "").trim();
  if (q.length < 2) {
    return reply.code(400).send({ error: "Query parameter 'q' must be at least 2 characters." });
  }
  // Variants are NOT taken from the client — runSearch derives them server-side from `q`.
  // (Trusting client variants let a caller poison the shared cache and fan out extra eBay calls.)
  // Validate the optional marketplace against the allowlist; fall back to the default.
  const marketplace = config.ebay.supportedMarketplaces.includes(params.marketplace ?? "")
    ? params.marketplace
    : config.ebay.marketplaceId;
  // Pagination over the cached, ranked active pool. page is 1-based; pageSize is clamped to
  // the server's page size so a client can't request the whole pool in one shot.
  const page = Math.max(1, toInt(params.page, 1));
  const pageSize = Math.min(config.activeLimit, Math.max(1, toInt(params.pageSize, config.activeLimit)));
  try {
    const result = await runSearch(q, undefined, marketplace, req.log);
    const activeTotal = result.active.length;
    const start = (page - 1) * pageSize;
    const window = result.active.slice(start, start + pageSize);
    // Slice only the active window; sold/stats are unchanged (the app reads them from page 1).
    return {
      ...result,
      active: window,
      meta: { ...result.meta, activeTotal, hasMore: start + pageSize < activeTotal },
    };
  } catch (err) {
    // Full detail stays in server logs; never echo upstream/internal error text to clients.
    req.log.error(err);
    return reply.code(502).send({ error: "Search failed. Please try again." });
  }
});

// Fail closed: refuse to start an UNAUTHENTICATED server unless it's explicitly allowed.
// This makes "open public backend" an intentional opt-in, not an accident of a missing env var.
// Local dev: set ALLOW_UNAUTHENTICATED=1 in backend/.env. Production: set a strong API_KEY.
if (!config.apiKey && !config.allowUnauthenticated) {
  app.log.fatal(
    "Refusing to start without API_KEY. Set API_KEY to require auth on /search, " +
      "or set ALLOW_UNAUTHENTICATED=1 for local-only development.",
  );
  process.exit(1);
}

app
  .listen({ port: config.port, host: config.host })
  .then(() => {
    const soldLive = config.ebay.marketplaceInsightsEnabled && isEbayConfigured();
    app.log.info(
      `OneTap backend ready on http://localhost:${config.port}  ` +
        `[eBay ${config.ebay.env}] active: ${isEbayConfigured() ? "LIVE" : "sample"}, ` +
        `sold: ${soldLive ? "LIVE" : "sample"}`,
    );
    if (!isEbayConfigured()) {
      app.log.warn("EBAY_CLIENT_ID / EBAY_CLIENT_SECRET not set — active listings are sample data.");
    }
    if (!config.apiKey && config.host !== "127.0.0.1") {
      app.log.warn("API_KEY not set — /search is OPEN. Set API_KEY before exposing this backend publicly.");
    }
  })
  .catch((err) => {
    app.log.error(err);
    process.exit(1);
  });
