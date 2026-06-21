import Foundation

/// Whether a listing is a completed sale (`sold`) or an item currently for sale (`active`).
///
/// Keeping this as an enum (instead of a bool) makes the intent obvious at call sites
/// and leaves room for more kinds later (e.g. `accepted offer`, `auction`).
enum ListingKind: String, Codable, CaseIterable, Hashable {
    case sold
    case active

    var label: String {
        switch self {
        case .sold:   return "Sold"
        case .active: return "For sale"
        }
    }
}

/// The marketplace a listing came from. An enum so new sources slot in cleanly later
/// (TCGplitter, COMC, PWCC, etc.) without touching call sites.
enum Marketplace: String, Codable, Hashable {
    case ebay   = "eBay"
    case other  = "Other"

    var displayName: String { rawValue }
}

/// Condition / grade for a card. Handles both raw cards and graded slabs.
///
/// - Raw card:    `rawDescription = "Near Mint"`, no grading company.
/// - Graded slab: `gradingCompany = "PSA"`, `grade = 10`.
struct CardCondition: Codable, Hashable {
    /// Free-text condition for raw cards, e.g. "Near Mint", "Lightly Played". Nil for graded.
    var rawDescription: String?
    /// Grading company, e.g. "PSA", "BGS", "CGC", "SGC". Nil for raw cards.
    var gradingCompany: String?
    /// Numeric grade, e.g. 10, 9.5. Nil for raw cards.
    var grade: Double?

    var isGraded: Bool { gradingCompany != nil && grade != nil }

    /// Short label for badges, e.g. "PSA 10" or "Near Mint".
    var shortLabel: String {
        if let company = gradingCompany, let grade {
            let g = grade == grade.rounded() ? String(Int(grade)) : String(grade)
            return "\(company) \(g)"
        }
        return rawDescription ?? "Ungraded"
    }
}

/// A single marketplace listing — the core unit the whole app is built around.
///
/// Deliberately marketplace-agnostic: a sold eBay record and an active eBay record are
/// the same shape, and a future source only has to produce this struct.
struct Listing: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var kind: ListingKind
    var price: Double
    var currencyCode: String
    /// Present for sold listings; nil for active ones.
    var soldDate: Date?
    var condition: CardCondition?
    var marketplace: Marketplace
    var imageURL: URL?
    /// Direct link to the real listing, when we have one.
    var listingURL: URL?
    /// Optional shipping cost shown alongside the price.
    var shippingPrice: Double?

    var isGraded: Bool { condition?.isGraded ?? false }

    var formattedPrice: String { Self.currency(price, code: currencyCode) }

    var formattedShipping: String? {
        guard let shippingPrice else { return nil }
        if shippingPrice <= 0 { return "Free shipping" }
        return Self.currency(shippingPrice, code: currencyCode) + " shipping"
    }

    /// Absolute sold date, e.g. "May 20, 2026".
    var formattedSoldDate: String? {
        guard let soldDate else { return nil }
        return Self.absoluteDate.string(from: soldDate)
    }

    /// Relative sold date, e.g. "3 weeks ago".
    var relativeSoldDate: String? {
        guard let soldDate else { return nil }
        return Self.relativeDate.localizedString(for: soldDate, relativeTo: Date())
    }

    /// The URL we open when the user taps through.
    ///
    /// Prefers a real listing URL; otherwise falls back to a genuinely useful eBay
    /// search for this exact title (sold filter for sold listings). We never fabricate
    /// a fake "item" link — a search is honest about what we can actually offer.
    var resolvedURL: URL? {
        if let listingURL, Self.isSafeEbayURL(listingURL) { return listingURL }
        return Self.ebaySearchURL(query: title, sold: kind == .sold)
    }

    /// The image to display, but only if it's HTTPS on an eBay image CDN — otherwise nil so the
    /// view shows a placeholder. Stops a malicious/compromised backend from using the image slot
    /// to load an arbitrary https host (e.g. a tracking/exfil beacon).
    var safeImageURL: URL? {
        guard let imageURL, Self.isSafeImageURL(imageURL) else { return nil }
        return imageURL
    }

    /// Only follow a provider-supplied listing URL if it's HTTPS and on an eBay domain;
    /// otherwise fall back to a safe eBay search. Guards against a malicious or compromised
    /// backend handing us a phishing / non-eBay link to open when the user taps through.
    static func isSafeEbayURL(_ url: URL) -> Bool {
        isHTTPS(url, registrableDomains: ["ebay.com", "ebay.co.uk", "ebay.com.au", "ebay.ca", "ebay.de"])
    }

    /// eBay image CDNs (HTTPS only) — used to validate listing image URLs before loading them.
    static func isSafeImageURL(_ url: URL) -> Bool {
        isHTTPS(url, registrableDomains: ["ebayimg.com", "ebaystatic.com"])
    }

    /// True iff `url` is HTTPS and its host equals (or is a subdomain of) one of the allowed
    /// registrable domains. "www." is ignored; the exact-or-dotted-suffix match rejects tricks
    /// like "ebay.com.evil.com" or "notebay.com".
    private static func isHTTPS(_ url: URL, registrableDomains: [String]) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return registrableDomains.contains { bare == $0 || bare.hasSuffix("." + $0) }
    }

    static func ebaySearchURL(query: String, sold: Bool) -> URL? {
        var components = URLComponents(string: "https://www.ebay.com/sch/i.html")
        var items = [URLQueryItem(name: "_nkw", value: query)]
        if sold {
            // Sold + completed, sorted by most-recently-ended → the most useful comps
            // (latest real sale prices first, like 130point's sold view).
            items.append(URLQueryItem(name: "LH_Complete", value: "1"))
            items.append(URLQueryItem(name: "LH_Sold", value: "1"))
            items.append(URLQueryItem(name: "_sop", value: "13"))   // Time: ended recently
        }
        // Live = all active listings on eBay's relevance (Best Match) ranking — the
        // cleanest, most complete "what's for sale now" view (auctions + Buy It Now).
        components?.queryItems = items
        return components?.url
    }

    // MARK: - Formatters (shared, created once)

    static func currency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = value == value.rounded() ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let absoluteDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let relativeDate: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
}
