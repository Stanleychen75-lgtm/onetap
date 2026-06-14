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
 * LIVE active listings via eBay Browse API.
 * GET /buy/browse/v1/item_summary/search?q=...&limit=...
 * Docs: https://developer.ebay.com/api-docs/buy/browse/resources/item_summary/methods/search
 */
export class EbayActiveProvider implements ActiveListingsProvider {
  readonly source = "eBay Browse API";
  readonly live = true;

  async fetchActive(query: string): Promise<Listing[]> {
    let token = await getEbayAppToken();
    let res = await this.call(query, token);

    // Token expired/invalidated early → refresh once and retry.
    if (res.status === 401) {
      token = await getEbayAppToken(true);
      res = await this.call(query, token);
    }

    if (!res.ok) {
      throw new Error(`eBay Browse API failed (${res.status}): ${await res.text()}`);
    }

    const data = (await res.json()) as EbayBrowseResponse;
    return (data.itemSummaries ?? []).map((item) => this.toListing(item));
  }

  private call(query: string, token: string): Promise<Response> {
    const url = new URL(`${config.ebay.apiBaseUrl}/buy/browse/v1/item_summary/search`);
    url.searchParams.set("q", query);
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
