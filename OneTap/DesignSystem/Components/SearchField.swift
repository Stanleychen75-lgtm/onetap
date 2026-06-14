import SwiftUI

/// The hero search field on the home screen. Big, tappable, with a clear button and a
/// submit action on return.
struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search a card, player, or set"
    var onSubmit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            TextField(placeholder, text: $text)
                .font(.system(size: 17))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .onSubmit(onSubmit)
                .foregroundStyle(Theme.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 54)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(focused ? Theme.accent.opacity(0.6) : Theme.separator,
                              lineWidth: focused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: focused)
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }
}

/// A tappable pill used for example searches and recent searches.
struct SearchChip: View {
    let text: String
    var icon: String?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                }
                Text(text).font(.system(size: 14, weight: .medium)).lineLimit(1)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background(Theme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
