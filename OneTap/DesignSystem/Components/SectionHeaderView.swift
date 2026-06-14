import SwiftUI

/// Section header used above the sold and active lists, with a colored dot, a title,
/// and a count.
struct SectionHeaderView: View {
    let title: String
    let count: Int
    var accentColor: Color = Theme.textPrimary
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.sm) {
            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("\(count)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Theme.separator.opacity(0.6), in: Capsule())
            Spacer()
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}
