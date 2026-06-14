import { config } from "../config";
import type { Listing } from "../types";
import type { ActiveListingsProvider } from "./types";
import { getEbayAppToken } from "./ebayAuth";
import { parseCondition } from "./conditionParser";

// Minimal shape of the fields we read from the eBay Browse API response.
interface EbayItemSummary {
  itemId: string;
  title?: string;
  price?: { value?: string; currency?: string };
  condition?: string;
  image?: { imageUrl?: string };
  thumbnailImages?: { imageUrl?: string }[];
  itemWebUrl?: string;
  shippingOptions?: { shippingCost?: { value?: string } }[];
}
interface EbayBrowseResponse {
  itemSummaries?: EbayItemSummary[];
  total?: number;
}

/**
 * LIVE active listings via eBay Browse API, fenced to trading-card categories.
 * GET /buy/browse/v1/item_summary/search?q=...&category_ids=...&limit=...
 * Docs: https://developer.ebay.com/api-docs/buy/browse/resources/item_summary/methods/search
 */
export class EbayActiveProvider implements ActiveListingsProvider {
  readonly source = "eBay Browse API";
  readonly live = true;

  async fetchActive(query: string): Promise<Listing[]> {
    // Trading-card fence: eBay Browse allows only ONE category_id per request, so we query
    // each configured card category in PARALLEL and merge — keeping results card-only at
    // roughly one call's latency. If no categories are configured, fall back to a single
    // unfenced call (search all of eBay).
    const categories = config.ebay.cardCategoryIds.length
      ? config.ebay.cardCategoryIds
      : [undefined];

    let token = await getEbayAppToken();
    let refreshed = false;

    const fetchCategory = async (categoryId?: string): Promise<Response> => {
      let res = await this.call(query, token, categoryId);
      // Token expired/invalidated early → refresh ONCE (shared across the parallel calls).
      if (res.status === 401 && !refreshed) {
        refreshed = true;
        token = await getEbayAppToken(true);
        res = await this.call(query, token, categoryId);
      }
      return res;
    };

    const responses = await Promise.all(categories.map((c) => fetchCategory(c)));

    const byId = new Map<string, Listing>();
    let firstError: string | null = null;
    for (const res of responses) {
      if (!res.ok) {
        if (firstError === null) firstError = `${res.status}: ${await res.text()}`;
        continue;
      }
      const data = (await res.json()) as EbayBrowseResponse;
      for (const item of data.itemSummaries ?? []) {
        if (!byId.has(item.itemId)) byId.set(item.itemId, this.toListing(item));
      }
    }

    // Only fail (→ sample fallback in searchService) if EVERY category request failed.
    if (byId.size === 0 && firstError) {
      throw new Error(`eBay Browse API failed (${firstError})`);
    }
    return [...byId.values()];
  }

  private call(query: string, token: string, categoryId?: string): Promise<Response> {
    const url = new URL(`${config.ebay.apiBaseUrl}/buy/browse/v1/item_summary/search`);
    url.searchParams.set("q", query);
    if (categoryId) url.searchParams.set("category_ids", categoryId); // ← trading-card fence
    url.searchParams.set("limit", String(config.activeLimit));
    return fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        "X-EBAY-C-MARKETPLACE-ID": config.ebay.marketplaceId,
        Accept: "application/json",
      },
      signal: AbortSignal.timeout(config.requestTimeoutMs),
    });
  }

  private toListing(item: EbayItemSummary): Listing {
    const price = Number(item.price?.value ?? "0");
    const shipping = item.shippingOptions?.[0]?.shippingCost?.value;

    const listing: Listing = {
      id: item.itemId,
      title: item.title ?? "Untitled listing",
      kind: "active",
      price: Number.isFinite(price) ? price : 0,
      currencyCode: item.price?.currency ?? "USD",
      condition: parseCondition(item.title ?? "", item.condition),
      marketplace: "eBay",
      imageURL: item.image?.imageUrl ?? item.thumbnailImages?.[0]?.imageUrl,
      listingURL: item.itemWebUrl,
    };
    if (shipping !== undefined) {
      const s = Number(shipping);
      if (Number.isFinite(s)) listing.shippingPrice = s;
    }
    return listing;
  }
}
