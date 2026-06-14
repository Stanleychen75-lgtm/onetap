import SwiftUI

/// One row in the sold or active list. Tapping it opens the detail screen.
struct ListingRowView: View {
    let listing: Listing
    /// When true, the row is tagged "SAMPLE" so demo data is never mistaken for real comps.
    var isSample: Bool = false

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            AsyncCardImage(url: listing.imageURL)
                .frame(width: 56, height: 76)

            VStack(alignment: .leading, spacing: 6) {
                Text(listing.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if isSample {
                        Text("SAMPLE")
                            .font(.system(size: 9, weight: .bold)).tracking(0.5)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 1))
                    }
                    KindBadge(kind: listing.kind)
                    ConditionBadge(condition: listing.condition)
                    if let date = listing.relativeSoldDate {
                        Label(date, systemImage: "clock")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            Spacer(minLength: Theme.Space.sm)

            VStack(alignment: .trailing, spacing: 4) {
                Text(listing.formattedPrice)
                    .font(Theme.price(17))
                    .foregroundStyle(Theme.textPrimary)
                if let shipping = listing.formattedShipping {
                    Text(shipping)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
            }
        }
        .padding(Theme.Space.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
