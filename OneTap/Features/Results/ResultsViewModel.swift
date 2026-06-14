import Foundation

/// Drives the results screen: fetches via the injected `CardDataService`, holds the
/// load state, and applies the active filters to produce the lists the view renders.
@MainActor
final class ResultsViewModel: ObservableObject {

    enum LoadState {
        case loading
        case loaded(CardSearchResult)
        case empty
        case failed(DataError)
    }

    @Published private(set) var state: LoadState = .loading
    @Published private(set) var didYouMean: [String] = []
    @Published private(set) var relatedMatches: [String] = []
    @Published var filters = ResultFilters()

    let query: String
    private let service: CardDataService

    init(query: String, service: CardDataService = AppEnvironment.makeCardDataService()) {
        self.query = query
        self.service = service
    }

    var result: CardSearchResult? {
        if case .loaded(let result) = state { return result }
        return nil
    }

    /// Title shown in the nav bar — the resolved card name when we have one, else the query.
    var navTitle: String { result?.cardName ?? query }

    /// Broad result = matched several cards (kept as a list, not one resolved card).
    var isBroad: Bool {
        result != nil && result?.cardName == nil && AppEnvironment.isSampleMode
    }

    // MARK: - Data honesty
    //
    // The backend tags each side live/sample via `meta.live`. We must NEVER present sample
    // SOLD data as if it were real sold comps. So:
    //   • verified sold (meta.live.sold == true) → show sold listings + the sold average.
    //   • pure sample demo (meta.mode == .sample) → show the demo data (the banner says so).
    //   • live/mixed with sample sold → HIDE the sample sold and show an honest
    //     "no verified sold comps" card with an "Open sold on eBay" action instead.

    var meta: SearchMeta? { result?.meta }
    var soldIsVerified: Bool { meta?.live.sold == true }
    var activeIsVerified: Bool { meta?.live.active == true }
    /// Everything is sample (local demo, or eBay was unreachable) — clearly bannered.
    var isPureSample: Bool { (meta?.mode ?? .sample) == .sample }
    /// True when we're suppressing unverified sample sold rather than faking comps.
    var soldUnavailable: Bool { result != nil && !isPureSample && !soldIsVerified }
    /// Sold is safe to show only when it's verified-real or an explicit sample demo.
    private var showsSold: Bool { soldIsVerified || isPureSample }

    /// The flat, 130point-style list. Sold is included ONLY when verified-real or an explicit
    /// sample demo — never unverified sample sold masquerading as real comps.
    var listings: [Listing] {
        guard let result else { return [] }
        let scoped: [Listing]
        switch filters.scope {
        case .both:   scoped = result.active + (showsSold ? result.sold : [])
        case .sold:   scoped = showsSold ? result.sold : []
        case .active: scoped = result.active
        }
        return filters.apply(to: scoped, query: query)
    }

    var lowestActivePrice: Double? {
        result?.active.map(\.price).min()
    }

    func load() async {
        state = .loading
        didYouMean = []
        relatedMatches = []
        do {
            let result = try await service.search(query: query)
            if result.isEmpty {
                state = .empty
                didYouMean = suggestions()
            } else {
                state = .loaded(result)
                relatedMatches = AppEnvironment.isSampleMode
                    ? SampleCardIndex.shared.relatedNames(for: query, excluding: result.cardName)
                    : []
            }
        } catch let error as DataError {
            // "No results" is an empty state (with suggestions), not an error.
            if error.isNoResults {
                state = .empty
                didYouMean = suggestions()
            } else {
                state = .failed(error)
            }
        } catch {
            state = .failed(.network(underlying: error))
        }
    }

    /// Closest sample card names for a missed query (sample mode only). Live eBay returns
    /// its own broad results, so it doesn't need local suggestions.
    private func suggestions() -> [String] {
        AppEnvironment.isSampleMode ? SampleCardIndex.shared.suggestions(for: query) : []
    }
}
