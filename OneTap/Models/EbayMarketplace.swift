import Foundation

/// An eBay marketplace the user can browse. Each maps to a real eBay site that returns its
/// own listings in its own **native currency** — no FX conversion, so prices are always the
/// real listed amount. Verified: all five share the same trading-card category IDs, so the
/// card fence works identically across them.
///
/// (Distinct from `Marketplace` in Listing.swift, which tags a listing's *source*.)
enum EbayMarketplace: String, CaseIterable, Identifiable, Hashable {
    case us = "EBAY_US"
    case gb = "EBAY_GB"
    case au = "EBAY_AU"
    case ca = "EBAY_CA"
    case de = "EBAY_DE"

    var id: String { rawValue }

    /// Sent to the backend as the `marketplace` query param → eBay marketplace context.
    var apiID: String { rawValue }

    /// User-facing label — CURRENCY only. The user is choosing which currency to see prices
    /// in; which eBay marketplace backs it (e.g. EUR → eBay Germany) is an internal detail.
    var currency: String {
        switch self {
        case .us: return "USD"
        case .gb: return "GBP"
        case .au: return "AUD"
        case .ca: return "CAD"
        case .de: return "EUR"
        }
    }

    /// US is the deepest card market — the sensible default.
    static let `default`: EbayMarketplace = .us
}
