import SwiftUI

/// "SOLD" / "FOR SALE" pill. Monochrome: SOLD is a solid (filled) mark, FOR SALE is an
/// outline — distinct at a glance without using color.
struct KindBadge: View {
    let kind: ListingKind

    var body: some View {
        Text(kind == .sold ? "SOLD" : "FOR SALE")
            .font(.system(size: 10, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(kind == .sold ? Theme.onAccent : Theme.textPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                if kind == .sold {
                    Capsule().fill(Theme.accent)
                } else {
                    Capsule().strokeBorder(Theme.separator, lineWidth: 1)
                }
            }
    }
}

/// Condition / grade pill, e.g. "PSA 10" or "Near Mint". Graded slabs get a filled chip
/// so they stand out from raw cards (outlined) — monochrome.
struct ConditionBadge: View {
    let condition: CardCondition?

    var body: some View {
        if let condition {
            Text(condition.shortLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(condition.isGraded ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background {
                    if condition.isGraded {
                        Capsule().fill(Theme.textPrimary.opacity(0.10))
                    } else {
                        Capsule().strokeBorder(Theme.separator, lineWidth: 1)
                    }
                }
        }
    }
}
