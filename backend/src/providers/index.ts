import { config, isEbayConfigured } from "../config";
import type { ActiveListingsProvider, SoldListingsProvider } from "./types";
import { EbayActiveProvider } from "./ebayActiveProvider";
import { SampleActiveProvider } from "./sampleActiveProvider";
import { MockSoldProvider } from "./mockSoldProvider";
import { EbaySoldProvider } from "./ebaySoldProvider";

/**
 * Provider factory — the ONE place that decides where data comes from.
 *
 * • Active: live eBay Browse if credentials exist, else sample.
 * • Sold:   live Marketplace Insights only if explicitly enabled AND credentialed,
 *           else sample (the honest default — see EbaySoldProvider).
 */
export function makeActiveProvider(): ActiveListingsProvider {
  return isEbayConfigured() ? new EbayActiveProvider() : new SampleActiveProvider();
}

export function makeSoldProvider(): SoldListingsProvider {
  return config.ebay.marketplaceInsightsEnabled && isEbayConfigured()
    ? new EbaySoldProvider()
    : new MockSoldProvider();
}

export { SampleActiveProvider, MockSoldProvider };
