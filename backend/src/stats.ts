import type { Listing, PriceStats } from "./types";

const round2 = (n: number): number => Math.round(n * 100) / 100;

/** Compute the value summary from sold listings. Pure function — real math, never faked. */
export function computeStats(sold: Listing[]): PriceStats {
  const currencyCode = sold[0]?.currencyCode ?? "USD";
  if (sold.length === 0) {
    return {
      salesCount: 0,
      averageSold: null,
      medianSold: null,
      minSold: null,
      maxSold: null,
      currencyCode,
    };
  }

  const prices = sold.map((s) => s.price).sort((a, b) => a - b);
  const sum = prices.reduce((a, b) => a + b, 0);
  const mid = Math.floor(prices.length / 2);
  const median =
    prices.length % 2 === 1 ? prices[mid] : (prices[mid - 1] + prices[mid]) / 2;

  return {
    salesCount: prices.length,
    averageSold: round2(sum / prices.length),
    medianSold: round2(median),
    minSold: prices[0],
    maxSold: prices[prices.length - 1],
    currencyCode,
  };
}
