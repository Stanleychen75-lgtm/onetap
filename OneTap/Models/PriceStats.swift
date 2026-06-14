import Foundation

/// Aggregate stats for a search, computed from *sold* listings.
///
/// These are computed by us from whatever sold data we have — they are real math on
/// real (or sample) numbers, never invented. In sample mode the inputs are sample
/// listings, so the stats are honest summaries of the sample set.
struct PriceStats: Codable, Hashable {
    var salesCount: Int
    var averageSold: Double?
    var medianSold: Double?
    var minSold: Double?
    var maxSold: Double?
    var currencyCode: String

    var hasData: Bool { salesCount > 0 }

    var formattedAverage: String? { format(averageSold) }
    var formattedMedian: String? { format(medianSold) }
    var formattedRange: String? {
        guard let minSold, let maxSold else { return nil }
        return "\(Listing.currency(minSold, code: currencyCode)) – \(Listing.currency(maxSold, code: currencyCode))"
    }

    private func format(_ value: Double?) -> String? {
        guard let value else { return nil }
        return Listing.currency(value, code: currencyCode)
    }

    /// Build stats from a set of sold listings. Pure function — easy to unit test.
    static func from(soldListings: [Listing], currencyCode: String = "USD") -> PriceStats {
        let prices = soldListings.map(\.price).sorted()
        guard !prices.isEmpty else {
            return PriceStats(salesCount: 0, averageSold: nil, medianSold: nil,
                              minSold: nil, maxSold: nil, currencyCode: currencyCode)
        }
        let average = prices.reduce(0, +) / Double(prices.count)
        let median: Double
        let mid = prices.count / 2
        if prices.count % 2 == 0 {
            median = (prices[mid - 1] + prices[mid]) / 2
        } else {
            median = prices[mid]
        }
        return PriceStats(
            salesCount: prices.count,
            averageSold: average,
            medianSold: median,
            minSold: prices.first,
            maxSold: prices.last,
            currencyCode: currencyCode
        )
    }
}
