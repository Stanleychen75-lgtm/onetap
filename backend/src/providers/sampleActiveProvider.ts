import type { Listing } from "../types";
import type { ActiveListingsProvider } from "./types";
import { matchDataset } from "../data/sampleData";

/** Sample active listings — used when eBay isn't configured, and as a fallback when a
 *  live eBay fetch fails. */
export class SampleActiveProvider implements ActiveListingsProvider {
  readonly source = "Sample data";
  readonly live = false;

  async fetchActive(query: string): Promise<Listing[]> {
    return matchDataset(query)?.active ?? [];
  }
}
