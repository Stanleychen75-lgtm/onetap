import Foundation

/// Everything the results screen needs for one search: the sold set, the active set,
/// and the computed stats. This is the single object a `CardDataService` returns,
/// which keeps the UI completely decoupled from where the data came from.
struct CardSearchResult: Codable, Hashable {
    var query: String
    /// The resolved card this result represents (e.g. "Victor Wembanyama — 2023 Prizm
    /// Rookie" for the query "wemby"). Optional so minimal responses still decode.
    var cardName: String?
    var sold: [Listing]
    var active: [Listing]
    var stats: PriceStats
    /// Where the data came from (sample/mixed/live + source labels). Optional so a
    /// minimal backend response without it still decodes.
    var meta: SearchMeta?

    var isEmpty: Bool { sold.isEmpty && active.isEmpty }

    init(query: String, cardName: String? = nil, sold: [Listing], active: [Listing],
         stats: PriceStats? = nil, meta: SearchMeta? = nil) {
        self.query = query
        self.cardName = cardName
        self.sold = sold
        self.active = active
        // Stats are derived from sold listings unless explicitly provided (e.g. by a
        // backend that computed them server-side).
        self.stats = stats ?? PriceStats.from(
            soldListings: sold,
            currencyCode: sold.first?.currencyCode ?? active.first?.currencyCode ?? "USD"
        )
        self.meta = meta
    }
}
