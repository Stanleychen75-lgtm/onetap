import Foundation

/// A search the user has run. Identifiable/Hashable so it drives navigation and
/// recent-search persistence cleanly.
struct SearchQuery: Hashable, Codable, Identifiable {
    var text: String
    var id: String { text.lowercased() }

    var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { trimmed.count >= 2 }
}

/// Which listings to show.
enum ListingScope: String, CaseIterable, Identifiable {
    case both, sold, active
    var id: String { rawValue }
    var title: String {
        switch self {
        case .both:   return "Both"
        case .sold:   return "Sold"
        case .active: return "Active"
        }
    }
}

/// Raw vs graded filter.
enum CardTypeFilter: String, CaseIterable, Identifiable {
    case all, raw, graded
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all:    return "All"
        case .raw:    return "Raw"
        case .graded: return "Graded"
        }
    }

    func matches(_ listing: Listing) -> Bool {
        switch self {
        case .all:    return true
        case .raw:    return !listing.isGraded
        case .graded: return listing.isGraded
        }
    }
}

/// Sort order applied within each section.
enum SortOption: String, CaseIterable, Identifiable {
    case relevance, newest, priceHighToLow, priceLowToHigh
    var id: String { rawValue }
    var title: String {
        switch self {
        case .relevance:      return "Best match"
        case .newest:         return "Newest"
        case .priceHighToLow: return "Price: High → Low"
        case .priceLowToHigh: return "Price: Low → High"
        }
    }
    var shortTitle: String {
        switch self {
        case .relevance:      return "Best match"
        case .newest:         return "Newest"
        case .priceHighToLow: return "Price ↓"
        case .priceLowToHigh: return "Price ↑"
        }
    }
}

/// The full filter state for a results screen.
struct ResultFilters: Equatable {
    var scope: ListingScope = .both
    var cardType: CardTypeFilter = .all
    var sort: SortOption = .relevance

    /// Apply type filter + sort to a list of listings. Pure, testable.
    /// `query` powers the "Best match" relevance sort.
    func apply(to listings: [Listing], query: String) -> [Listing] {
        let filtered = listings.filter(cardType.matches)
        switch sort {
        case .priceHighToLow:
            return filtered.sorted { $0.price > $1.price }
        case .priceLowToHigh:
            return filtered.sorted { $0.price < $1.price }
        case .newest:
            return filtered.sorted { ($0.soldDate ?? .distantPast) > ($1.soldDate ?? .distantPast) }
        case .relevance:
            let nq = SearchEngine.normalize(query)
            return filtered
                .map { (listing: $0, score: SearchEngine.score(title: $0.title, nq)) }
                .sorted { $0.score > $1.score }
                .map(\.listing)
        }
    }
}
