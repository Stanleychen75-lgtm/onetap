import type { Listing } from "../types";

/** Source of currently-for-sale listings. */
export interface ActiveListingsProvider {
  /** Human label shown in the response, e.g. "eBay Browse API" or "Sample data". */
  readonly source: string;
  /** Whether this provider returns real marketplace data (vs sample). */
  readonly live: boolean;
  fetchActive(query: string): Promise<Listing[]>;
}

/** Source of completed/sold listings. */
export interface SoldListingsProvider {
  readonly source: string;
  readonly live: boolean;
  fetchSold(query: string): Promise<Listing[]>;
}
