import type { Listing } from "../types";
import type { SoldListingsProvider } from "./types";
import { matchDataset } from "../data/sampleData";

/**
 * Sold listings from sample data — the default sold provider today.
 *
 * This is intentionally the default: real eBay sold history is NOT freely available
 * (see EbaySoldProvider). When you get Marketplace Insights access, swap this out via
 * the factory in ./index.ts — nothing else changes.
 */
export class MockSoldProvider implements SoldListingsProvider {
  readonly source = "Sample data";
  readonly live = false;

  async fetchSold(query: string): Promise<Listing[]> {
    return matchDataset(query)?.sold ?? [];
  }
}
