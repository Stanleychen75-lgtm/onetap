import SwiftUI

/// The value summary at the top of the results screen.
///
/// Shows the average sold price prominently, with median / low / high beneath, and a
/// "lowest active ask" cross-reference so the user instantly sees *sold for* vs
/// *buy it now*. All figures are computed from the listings — never invented.
struct StatsSummaryView: View {
    let stats: PriceStats
    let lowestActive: Double?
    let activeCount: Int
    var currencyCode: String = "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            if stats.hasData {
                soldSummary
            } else {
                noSoldData
            }

            if let lowestActive {
                Divider().overlay(Theme.separator)
                HStack {
                    Label("Lowest active ask", systemImage: "tag")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(Listing.currency(lowestActive, code: currencyCode))
                        .font(Theme.price(15))
                        .foregroundStyle(Theme.active)
                }
            }
        }
        .cardSurface()
    }

    private var soldSummary: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack(alignment: .center) {
                Text("AVERAGE SOLD")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(stats.salesCount) sales")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.accent, in: Capsule())
            }

            Text(stats.formattedAverage ?? "—")
                .font(Theme.price(36, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 0) {
                StatColumn(label: "Median", value: stats.formattedMedian ?? "—")
                divider
                StatColumn(label: "Low", value: stats.minSold.map { Listing.currency($0, code: currencyCode) } ?? "—")
                divider
                StatColumn(label: "High", value: stats.maxSold.map { Listing.currency($0, code: currencyCode) } ?? "—")
            }

            Text("Based on \(stats.salesCount) recent sold listings")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var noSoldData: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NO RECENT SOLD DATA")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
            Text("\(activeCount) active \(activeCount == 1 ? "listing" : "listings")")
                .font(Theme.price(28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("We don’t have sold comps for this search yet.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.separator).frame(width: 1, height: 32)
    }
}

private struct StatColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.price(16))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
