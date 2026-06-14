import type { Listing } from "../types";
import type { SoldListingsProvider } from "./types";

/**
 * LIVE sold listings via eBay **Marketplace Insights API** — STUB (not yet implemented).
 *
 * ⚠️ Honest status: Marketplace Insights is a **Limited Release**. You must apply and be
 * approved by eBay before you can call it. Until then, sold data stays on sample data
 * (MockSoldProvider). This class exists so the seam is ready: once approved, implement
 * `fetchSold` and flip `EBAY_MARKETPLACE_INSIGHTS_ENABLED=true`.
 *
 * When you implement it:
 *   • Endpoint: GET {apiBaseUrl}/buy/marketplace_insights/v1_beta/item_sales/search?q=...
 *   • OAuth scope: https://api.ebay.com/oauth/api_scope/buy.marketplace.insights
 *     (request this scope in getEbayAppToken — it's separate from the Browse scope)
 *   • Map each `itemSales` entry → Listing with kind:"sold" and
 *     soldDate = entry.lastSoldDate, price = entry.lastSoldPrice.value.
 *
 * Because the factory only selects this provider when the flag is on, and the search
 * service falls back to sample on error, throwing here degrades gracefully.
 */
export class EbaySoldProvider implements SoldListingsProvider {
  readonly source = "eBay Marketplace Insights API";
  readonly live = true;

  async fetchSold(_query: string): Promise<Listing[]> {
    throw new Error(
      "Marketplace Insights not implemented — requires eBay Limited Release approval. " +
        "Keep EBAY_MARKETPLACE_INSIGHTS_ENABLED=false to use sample sold data.",
    );
  }
}
