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

app.get("/health", async () => ({
  status: "ok",
  ebayEnv: config.ebay.env,
  ebayActiveConfigured: isEbayConfigured(),
  marketplaceInsightsEnabled: config.ebay.marketplaceInsightsEnabled,
  apiKeyRequired: Boolean(config.apiKey),
}));

app.get("/search", async (req, reply) => {
  const params = req.query as { q?: string; variants?: string };
  const q = (params.q ?? "").trim();
  if (q.length < 2) {
    return reply.code(400).send({ error: "Query parameter 'q' must be at least 2 characters." });
  }
  const variants = params.variants
    ? params.variants.split("|").map((s) => s.trim()).filter(Boolean)
    : undefined;
  try {
    return await runSearch(q, variants);
  } catch (err) {
    req.log.error(err);
    return reply.code(502).send({
      error: "Search failed",
      detail: err instanceof Error ? err.message : String(err),
    });
  }
});

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
