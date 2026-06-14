import Foundation

/// An example search shown on the home screen to get beginners started instantly.
struct ExampleSearch: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let query: String

    /// The full set of cards that exist in sample data — used by the home screen
    /// (first few), the empty-state suggestions, and the debug self-test.
    static let defaults: [ExampleSearch] = [
        ExampleSearch(label: "Israel Adesanya Prizm UFC", icon: "figure.boxing",
                      query: "Israel Adesanya Prizm UFC"),
        ExampleSearch(label: "Lewis Hamilton Topps Chrome", icon: "flag.checkered",
                      query: "Lewis Hamilton Topps Chrome F1"),
        ExampleSearch(label: "Charizard VMAX Champion's Path", icon: "sparkles",
                      query: "Charizard VMAX Champion's Path"),
        ExampleSearch(label: "Luka Dončić Prizm Rookie", icon: "basketball",
                      query: "Luka Doncic Prizm Rookie"),
        ExampleSearch(label: "Mike Trout Topps Update Rookie", icon: "baseball",
                      query: "Mike Trout Topps Update Rookie"),
        ExampleSearch(label: "Kylian Mbappé Prizm World Cup", icon: "soccerball",
                      query: "Kylian Mbappe Prizm World Cup"),
    ]
}

/// A browsable category / sport shown on the home screen. Tapping it runs a search.
struct HomeCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let query: String
}

/// Owns the home screen's state: the search box, recent searches (persisted locally),
/// browse categories, and the curated examples. No accounts, no backend — just UserDefaults.
@MainActor
final class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var recentSearches: [String] = []

    let exampleSearches = ExampleSearch.defaults

    /// Specific hot cards for quick discovery — all resolve in the sample catalog.
    let trending: [HomeCategory] = [
        HomeCategory(name: "Wembanyama", icon: "basketball", query: "Victor Wembanyama"),
        HomeCategory(name: "Verstappen", icon: "flag.checkered", query: "Max Verstappen"),
        HomeCategory(name: "Jordan", icon: "basketball", query: "Michael Jordan"),
        HomeCategory(name: "Charizard", icon: "sparkles", query: "Charizard"),
        HomeCategory(name: "Mahomes", icon: "football", query: "Patrick Mahomes"),
        HomeCategory(name: "Mbappé", icon: "soccerball", query: "Mbappe"),
    ]

    /// Headline categories on the home screen.
    let mostPopular: [HomeCategory] = [
        HomeCategory(name: "Pokémon", icon: "sparkles", query: "Pokemon"),
        HomeCategory(name: "Soccer", icon: "soccerball", query: "Soccer"),
        HomeCategory(name: "NBA", icon: "basketball", query: "NBA"),
    ]

    /// Secondary categories / sports.
    let moreCategories: [HomeCategory] = [
        HomeCategory(name: "F1", icon: "flag.checkered", query: "F1"),
        HomeCategory(name: "UFC", icon: "figure.boxing", query: "UFC"),
        HomeCategory(name: "Baseball", icon: "baseball", query: "Baseball"),
        HomeCategory(name: "NFL", icon: "football", query: "NFL"),
        HomeCategory(name: "TCG", icon: "rectangle.on.rectangle.angled", query: "TCG"),
    ]

    private let recentsKey = "recent_searches_v1"
    private let maxRecents = 8

    init() { loadRecents() }

    /// Build a valid query from text (defaults to the current box). Returns nil if too short.
    func makeQuery(from text: String? = nil) -> SearchQuery? {
        let query = SearchQuery(text: text ?? searchText)
        return query.isValid ? query : nil
    }

    func recordSearch(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > maxRecents {
            recentSearches = Array(recentSearches.prefix(maxRecents))
        }
        saveRecents()
    }

    func clearRecents() {
        recentSearches = []
        saveRecents()
    }

    // MARK: - Persistence

    private func loadRecents() {
        guard let data = UserDefaults.standard.data(forKey: recentsKey),
              let saved = try? JSONDecoder().decode([String].self, from: data) else { return }
        recentSearches = saved
    }

    private func saveRecents() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: recentsKey)
        }
    }
}
