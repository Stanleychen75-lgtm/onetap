import Foundation

/// Development data source (Mode A).
///
/// Ranks the bundled sample cards with `SearchEngine` (via `SampleCardIndex`) and returns
/// the best match, or throws `.noResults` (the results screen then offers "did you mean"
/// suggestions). A small artificial delay simulates the network so loading states show.
///
/// The real data source (`LiveCardDataService`) uses the same `SearchEngine` to build
/// fallback query variants and rank merged results — the search brain is shared.
final class MockCardDataService: CardDataService {

    private let simulatedDelay: Duration

    init(simulatedDelay: Duration = .milliseconds(450)) {
        self.simulatedDelay = simulatedDelay
    }

    func search(query: String) async throws -> CardSearchResult {
        try? await Task.sleep(for: simulatedDelay)
        guard let result = SampleCardIndex.shared.search(query) else {
            throw DataError.noResults
        }
        return result
    }
}
