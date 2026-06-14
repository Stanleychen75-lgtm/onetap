import { config } from "../config";

/**
 * eBay OAuth — "client credentials" grant (application token).
 *
 * This is the token type the Browse API uses for guest search. It's minted from your
 * app's Client ID + Secret (server-side only — these NEVER ship in the iOS app) and is
 * valid ~2 hours, so we cache it in memory and refresh just before expiry.
 */
let cached: { token: string; expiresAt: number } | null = null;

/**
 * @param forceRefresh mint a new token even if the cached one looks valid (used to recover
 *        from a 401 if eBay invalidated the token early).
 */
export async function getEbayAppToken(forceRefresh = false): Promise<string> {
  if (!forceRefresh && cached && cached.expiresAt > Date.now() + 60_000) {
    return cached.token;
  }
  if (!config.ebay.clientId || !config.ebay.clientSecret) {
    throw new Error("eBay credentials are not configured.");
  }

  const basic = Buffer.from(
    `${config.ebay.clientId}:${config.ebay.clientSecret}`,
  ).toString("base64");

  const res = await fetch(`${config.ebay.apiBaseUrl}/identity/v1/oauth2/token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Authorization: `Basic ${basic}`,
    },
    body: new URLSearchParams({
      grant_type: "client_credentials",
      scope: "https://api.ebay.com/oauth/api_scope",
    }),
    signal: AbortSignal.timeout(config.requestTimeoutMs),
  });

  if (!res.ok) {
    // Note: the response body is eBay's error (e.g. invalid_client) — it never contains
    // your secret, so it's safe to surface for debugging.
    throw new Error(`eBay OAuth failed (${res.status}): ${await res.text()}`);
  }

  const json = (await res.json()) as { access_token: string; expires_in: number };
  cached = {
    token: json.access_token,
    expiresAt: Date.now() + json.expires_in * 1000,
  };
  return cached.token;
}
