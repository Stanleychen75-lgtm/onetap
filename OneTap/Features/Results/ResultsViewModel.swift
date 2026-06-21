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

    /// Pagination: active listings accumulated across pages, and whether a "load more" is
    /// available / in flight. Sold listings come from page 1 only and don't paginate.
    @Published private(set) var canLoadMore = false
    @Published private(set) var isLoadingMore = false
    private var pagedActive: [Listing] = []
    private var page = 1

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
        case .both:   scoped = pagedActive + (showsSold ? result.sold : [])
        case .sold:   scoped = showsSold ? result.sold : []
        case .active: scoped = pagedActive
        }
        return filters.apply(to: scoped, query: query)
    }

    var lowestActivePrice: Double? {
        pagedActive.map(\.price).min()
    }

    func load() async {
        state = .loading
        didYouMean = []
        relatedMatches = []
        page = 1
        pagedActive = []
        canLoadMore = false
        do {
            let result = try await service.search(query: query, page: 1)
            if result.isEmpty {
                state = .empty
                didYouMean = suggestions()
            } else {
                pagedActive = result.active
                canLoadMore = result.meta?.hasMore == true
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

    /// Fetch the next page and append its active listings (deduped by id). On any error we
    /// simply stop offering "load more" and keep what's already shown — never break the screen.
    func loadMore() async {
        guard canLoadMore, !isLoadingMore, case .loaded = state else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let next = try await service.search(query: query, page: page + 1)
            page += 1
            let seen = Set(pagedActive.map(\.id))
            pagedActive.append(contentsOf: next.active.filter { !seen.contains($0.id) })
            canLoadMore = next.meta?.hasMore == true
        } catch {
            canLoadMore = false
        }
    }

    /// Closest sample card names for a missed query (sample mode only). Live eBay returns
    /// its own broad results, so it doesn't need local suggestions.
    private func suggestions() -> [String] {
        AppEnvironment.isSampleMode ? SampleCardIndex.shared.suggestions(for: query) : []
    }
}
