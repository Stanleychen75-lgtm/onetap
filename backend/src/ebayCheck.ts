import { config, isEbayConfigured } from "./config";
import { getEbayAppToken } from "./providers/ebayAuth";

/**
 * One-command eBay diagnostic:  npm run ebay:check
 *
 * Runs the EXACT two steps the live backend depends on, in order, and tells you which
 * one (if any) fails — so you can tell a credentials problem apart from a Browse-access
 * problem without guessing.
 *
 *   STEP 1  Mint an OAuth application token (client_credentials grant).
 *   STEP 2  Call the Browse API once with that token.
 *
 * It NEVER prints your secret. It prints only lengths and the PRD/SBX environment marker,
 * which is enough to catch the most common mistake: mixing a Sandbox and a Production half.
 */

/** "PRODUCTION" / "SANDBOX" / "unknown" from an App ID or Cert ID, without revealing it. */
function marker(value: string): string {
  if (value.includes("PRD")) return "PRODUCTION";
  if (value.includes("SBX")) return "SANDBOX";
  return "unknown";
}

async function main(): Promise<void> {
  console.log(`eBay environment : ${config.ebay.env}  →  ${config.ebay.apiBaseUrl}`);
  console.log(`Marketplace      : ${config.ebay.marketplaceId}\n`);

  if (!isEbayConfigured()) {
    console.error("❌ EBAY_CLIENT_ID / EBAY_CLIENT_SECRET are not set in backend/.env — nothing to test.");
    console.error("   App ID  → EBAY_CLIENT_ID");
    console.error("   Cert ID → EBAY_CLIENT_SECRET");
    process.exit(1);
  }

  // ── Same-keyset sanity check (no secret characters printed) ──────────────────────
  const id = config.ebay.clientId!;
  const secret = config.ebay.clientSecret!;
  console.log(`App ID  : length ${id.length}, looks like ${marker(id)}`);
  console.log(`Cert ID : length ${secret.length}, looks like ${marker(secret)}, ` +
    `${secret.startsWith("PRD-") || secret.startsWith("SBX-") ? "format OK" : "⚠ unexpected format"}`);
  if (marker(id) !== marker(secret)) {
    console.error(
      `\n⚠ App ID and Cert ID look like DIFFERENT environments. They must BOTH be the\n` +
      `  Production halves of the SAME keyset. Re-copy both from the same row in the portal.`,
    );
  }

  // ── STEP 1 — mint the application token (exactly what the backend does) ──────────
  let token: string;
  try {
    token = await getEbayAppToken(true);
    console.log(`\n✅ STEP 1 — OAuth token minted (length ${token.length}).`);
    console.log(`   → Your App ID + Cert ID are a valid, activated Production keyset.`);
  } catch (err) {
    console.error(`\n❌ STEP 1 — OAuth token request FAILED.`);
    console.error(`   ${err instanceof Error ? err.message : String(err)}`);
    console.error(
      `\n   You never got a token, so this is NOT a Browse-access problem — it's the\n` +
      `   credentials/keyset themselves. Most likely: the two halves aren't from the same\n` +
      `   Production keyset, OR a brand-new keyset hasn't finished activating (can take a\n` +
      `   day or two). 'unauthorized_client' / 'invalid_client' both land here.`,
    );
    process.exit(1);
  }

  // ── STEP 2 — call Browse once to prove API access (not just the token) ───────────
  const url = new URL(`${config.ebay.apiBaseUrl}/buy/browse/v1/item_summary/search`);
  url.searchParams.set("q", "charizard");
  url.searchParams.set("limit", "1");
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      "X-EBAY-C-MARKETPLACE-ID": config.ebay.marketplaceId,
      Accept: "application/json",
    },
    signal: AbortSignal.timeout(config.requestTimeoutMs),
  });
  const body = await res.text();

  if (res.ok) {
    let total: unknown = "?";
    try { total = (JSON.parse(body) as { total?: number }).total ?? "?"; } catch { /* keep ? */ }
    console.log(`\n✅ STEP 2 — Browse API search OK (HTTP ${res.status}; ~${total} live results for "charizard").`);
    console.log(`\n🎉 Live Browse is fully working end-to-end.`);
    console.log(`   Flip the app to live:  OneTap/Data/CardDataService.swift → AppEnvironment.dataMode = .live`);
    return;
  }

  console.error(`\n❌ STEP 2 — Browse API call FAILED (HTTP ${res.status}).`);
  console.error(`   ${body}`);
  console.error(
    `\n   The TOKEN works, but this keyset can't call Browse yet. This is the real\n` +
    `   "Browse/Buy access" gate (a 403 here, not 'unauthorized_client'). Request Buy API\n` +
    `   access for your Production app, or wait for a just-granted keyset to propagate.`,
  );
  process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
