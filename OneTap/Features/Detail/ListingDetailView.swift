import SwiftUI

/// Detail for a single listing, with a tap-through to eBay.
///
/// Honesty note: in sample mode we don't have a real item link, so the button runs a
/// live eBay search for this exact card (sold filter for sold listings) rather than
/// pretending to deep-link to a specific listing.
struct ListingDetailView: View {
    let listing: Listing
    var averageSold: Double? = nil
    @Environment(\.openURL) private var openURL

    // Gate the "View on eBay" label on the SAME safety check the tap uses (resolvedURL), so the
    // button can't claim a direct listing while actually falling back to a search.
    private var hasRealListing: Bool { listing.listingURL.map(Listing.isSafeEbayURL) ?? false }

    /// How this listing's price compares to the average sold (monochrome, no hype).
    private var vsAverageText: (icon: String, text: String)? {
        guard let avg = averageSold, avg > 0 else { return nil }
        let diff = (listing.price - avg) / avg
        let pct = Int((abs(diff) * 100).rounded())
        if pct < 1 { return ("equal.circle", "About the average sold") }
        if diff > 0 { return ("arrow.up", "\(pct)% above average sold") }
        return ("arrow.down", "\(pct)% below average sold")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.lg) {
                AsyncCardImage(url: listing.safeImageURL, cornerRadius: Theme.Radius.md)
                    .frame(width: 200, height: 280)
                    .padding(.top, Theme.Space.md)

                VStack(spacing: Theme.Space.md) {
                    HStack(spacing: Theme.Space.sm) {
                        KindBadge(kind: listing.kind)
                        ConditionBadge(condition: listing.condition)
                        Spacer()
                        Text(listing.marketplace.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    Text(listing.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .firstTextBaseline) {
                        Text(listing.formattedPrice)
                            .font(Theme.price(34, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        if let shipping = listing.formattedShipping {
                            Text("+ \(shipping)")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        Spacer()
                    }

                    if let badge = vsAverageText {
                        HStack(spacing: 6) {
                            Image(systemName: badge.icon).font(.system(size: 11, weight: .bold))
                            Text(badge.text).font(.system(size: 12, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(Theme.textSecondary)
                    }
                }
                .cardSurface()

                detailRows

                button

                soldOnEbayButton

                if AppEnvironment.isSampleMode {
                    Text("Sample listing. The button runs a live eBay search for this card.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(Theme.Space.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Listing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailRows: some View {
        VStack(spacing: 0) {
            detailRow("Status", listing.kind.label)
            if let date = listing.formattedSoldDate {
                Divider().overlay(Theme.separator)
                detailRow("Sold date", date)
            }
            if let condition = listing.condition {
                Divider().overlay(Theme.separator)
                detailRow("Condition", condition.shortLabel)
            }
            Divider().overlay(Theme.separator)
            detailRow("Marketplace", listing.marketplace.displayName)
        }
        .cardSurface(padding: 0)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, Theme.Space.md)
    }

    private var button: some View {
        Button {
            if let url = listing.resolvedURL { openURL(url) }
        } label: {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: hasRealListing ? "arrow.up.right.square" : "magnifyingglass")
                Text(hasRealListing ? "View on eBay" : "Search this card on eBay")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.md)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Secondary action: jump to eBay's REAL recent sold results for this exact card. This
    /// is OneTap's v1 sold experience — verified comps live on eBay until there's a real
    /// in-app sold source (Marketplace Insights).
    private var soldOnEbayButton: some View {
        Button {
            if let url = Listing.ebaySearchURL(query: listing.title, sold: true) { openURL(url) }
        } label: {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "checkmark.seal")
                Text("See sold comps on eBay")
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold)).opacity(0.7)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.md)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
