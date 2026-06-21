import Foundation

/// Metadata about *where* a search result came from. Produced by the backend (and by the
/// local mock service) so the UI can honestly show sample / mixed / live status and the
/// per-section source labels. Optional on `CardSearchResult` so older responses still decode.
struct SearchMeta: Codable, Hashable {
    enum Mode: String, Codable, Hashable {
        case sample   // everything is sample data
        case mixed    // some live, some sample (e.g. live active + sample sold)
        case live     // everything is live
    }

    struct Sources: Codable, Hashable {
        var active: String
        var sold: String
    }

    struct LiveFlags: Codable, Hashable {
        var active: Bool
        var sold: Bool
    }

    var mode: Mode
    var sources: Sources
    var live: LiveFlags
    var notes: [String]?
    /// Pagination over the ranked active pool. `activeTotal` is the full pool size and
    /// `hasMore` is true when more active pages remain — used to drive "Show more results".
    /// Optional (nil for sample/older responses), so decoding stays backward-compatible.
    var activeTotal: Int? = nil
    var hasMore: Bool? = nil

    /// The meta the local mock service stamps onto sample results.
    static let sample = SearchMeta(
        mode: .sample,
        sources: Sources(active: "Sample data", sold: "Sample data"),
        live: LiveFlags(active: false, sold: false),
        notes: ["Sample data for development — connect a backend for live eBay results."]
    )
}
