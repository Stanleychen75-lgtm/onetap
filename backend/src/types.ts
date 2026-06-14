// These types mirror the iOS app's Swift `Codable` models exactly.
// The JSON this backend emits is decoded directly into `CardSearchResult` on the app
// side, so the field names and shapes here ARE the API contract — keep them in sync.

export type ListingKind = "sold" | "active";
export type MarketplaceName = "eBay" | "Other";

/** Mirrors Swift `CardCondition`. All fields optional: raw cards vs graded slabs. */
export interface CardCondition {
  rawDescription?: string;   // e.g. "Near Mint" (raw cards)
  gradingCompany?: string;   // e.g. "PSA", "BGS", "CGC" (graded slabs)
  grade?: number;            // e.g. 10, 9.5
}

/** Mirrors Swift `Listing`. */
export interface Listing {
  id: string;
  title: string;
  kind: ListingKind;
  price: number;
  currencyCode: string;
  soldDate?: string;         // ISO-8601 (e.g. "2026-05-28T00:00:00Z"); present for sold only
  condition?: CardCondition;
  marketplace: MarketplaceName;
  imageURL?: string;
  listingURL?: string;
  shippingPrice?: number;
}

/** Mirrors Swift `PriceStats`. Computed from sold listings; nulls when no sold data. */
export interface PriceStats {
  salesCount: number;
  averageSold: number | null;
  medianSold: number | null;
  minSold: number | null;
  maxSold: number | null;
  currencyCode: string;
}

/**
 * Extra metadata the app currently ignores (Swift `Codable` skips unknown keys), but
 * which is ready for the app to read later — e.g. to drive the "Sample data" banner
 * from `meta.mode` instead of a hardcoded flag.
 */
export interface SearchMeta {
  mode: "sample" | "live" | "mixed";
  sources: { active: string; sold: string };
  live: { active: boolean; sold: boolean };
  cached: boolean;
  notes: string[];
}

/** The single response shape for GET /search. Mirrors Swift `CardSearchResult` + `meta`. */
export interface CardSearchResult {
  query: string;
  sold: Listing[];
  active: Listing[];
  stats: PriceStats;
  meta: SearchMeta;
}
