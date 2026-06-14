import Foundation

/// One searchable card in sample mode.
struct SampleCard {
    let name: String
    let sold: [Listing]
    let active: [Listing]
    let haystack: [String]   // strings the engine scores the query against
}

/// Loads the sample cards once and ranks them with `SearchEngine`. Used by the mock data
/// service for results and by the results screen for "did you mean" suggestions.
final class SampleCardIndex {
    static let shared = SampleCardIndex()

    let cards: [SampleCard]
    private init() { cards = Self.load() }

    /// A card must clear this (≈ one strong name/surname match) to be returned.
    private static let matchFloor = 2.0
    /// Lower band that powers "did you mean" suggestions (partial/typo overlap).
    private static let suggestFloor = 1.2

    /// Result for a query. **Broad** queries (a bare name/category that matches several
    /// cards comparably) merge listings across those matches — they stay broad, not
    /// collapsed into one exact variant. **Specific** queries return the single best card.
    func search(_ query: String) -> CardSearchResult? {
        let nq = SearchEngine.normalize(query)
        guard nq.isUsable else { return nil }
        let ranked = rank(nq)
        guard let top = ranked.first, top.score >= Self.matchFloor else { return nil }

        let second = ranked.count > 1 ? ranked[1].score : 0
        // Broad when the top match isn't clearly dominant and a runner-up also qualifies.
        let isBroad = second >= Self.matchFloor && top.score < second * 1.5

        if isBroad {
            let matches = ranked.filter { $0.score >= max(Self.matchFloor, top.score * 0.6) }.prefix(6)
            return CardSearchResult(
                query: query,
                cardName: nil,                                  // nil = broad (no single resolved card)
                sold: matches.flatMap { $0.card.sold },
                active: matches.flatMap { $0.card.active },
                meta: .sample
            )
        }
        return CardSearchResult(query: query, cardName: top.card.name,
                                sold: top.card.sold, active: top.card.active, meta: .sample)
    }

    /// Closest card names for a query that didn't clear the match floor.
    func suggestions(for query: String) -> [String] {
        let nq = SearchEngine.normalize(query)
        guard nq.isUsable else { return [] }
        return rank(nq)
            .filter { $0.score >= Self.suggestFloor && $0.score < Self.matchFloor }
            .prefix(3)
            .map(\.card.name)
    }

    /// Other cards that also match (for "other matches" discovery), excluding the best.
    func relatedNames(for query: String, excluding name: String?) -> [String] {
        let nq = SearchEngine.normalize(query)
        guard nq.isUsable else { return [] }
        return rank(nq)
            .filter { $0.score >= Self.matchFloor && $0.card.name != name }
            .prefix(4)
            .map(\.card.name)
    }

    private func rank(_ nq: NormalizedQuery) -> [(card: SampleCard, score: Double)] {
        cards
            .map { card in (card, card.haystack.map { SearchEngine.score(title: $0, nq) }.max() ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    // MARK: - Loading

    private struct Dataset: Decodable {
        let name: String
        let keywords: [String]
        let sold: [Listing]
        let active: [Listing]
    }

    private static func load() -> [SampleCard] {
        loadDatasets().map { ds in
            SampleCard(
                name: ds.name,
                sold: ds.sold,
                active: ds.active,
                haystack: ds.keywords + [ds.name] + ds.sold.map(\.title) + ds.active.map(\.title)
            )
        }
    }

    private static func loadDatasets() -> [Dataset] {
        guard let url = Bundle.main.url(forResource: "sample_data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ sample_data.json not found in bundle. Add it to the app target. Using fallback.")
            return [fallback]
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode([Dataset].self, from: data)
        } catch {
            print("⚠️ Failed to decode sample_data.json: \(error). Using fallback.")
            return [fallback]
        }
    }

    private static let fallback = Dataset(
        name: "Sample Card",
        keywords: ["sample", "charizard", "pokemon"],
        sold: [Listing(id: "fb-s", title: "Sample Card — add sample_data.json to your target",
                       kind: .sold, price: 100, currencyCode: "USD",
                       soldDate: Date(timeIntervalSince1970: 1_770_000_000),
                       condition: CardCondition(gradingCompany: "PSA", grade: 10),
                       marketplace: .ebay, imageURL: nil, listingURL: nil, shippingPrice: 0)],
        active: [Listing(id: "fb-a", title: "Sample Card — currently listed",
                         kind: .active, price: 120, currencyCode: "USD", soldDate: nil,
                         condition: CardCondition(rawDescription: "Near Mint"),
                         marketplace: .ebay, imageURL: nil, listingURL: nil, shippingPrice: 4.99)]
    )
}
