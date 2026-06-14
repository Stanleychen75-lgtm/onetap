import SwiftUI

/// Skeleton loading state — placeholder rows that mimic the real layout so the screen
/// feels fast and intentional while data loads.
struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.surface)
                .frame(height: 150)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.separator, lineWidth: 1))

            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.surface)
                    .frame(height: 100)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.separator, lineWidth: 1))
            }
        }
        .redacted(reason: .placeholder)
        .shimmer()
        .padding(Theme.Space.lg)
    }
}

/// Empty state — clear, friendly, with a suggestion. Never a dead end.
struct EmptyStateView: View {
    var title: String = "No listings found"
    var message: String
    var systemImage: String = "magnifyingglass"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        StateContainer(systemImage: systemImage, tint: Theme.textSecondary,
                       title: title, message: message,
                       actionTitle: actionTitle, action: action)
    }
}

/// Error state — honest about *why* something failed, with a retry.
struct ErrorStateView: View {
    let error: DataError
    var retry: (() -> Void)?

    var body: some View {
        StateContainer(
            systemImage: error.isNotConfigured ? "server.rack" : "exclamationmark.triangle",
            tint: error.isNotConfigured ? Theme.accent : .orange,
            title: error.errorDescription ?? "Something went wrong",
            message: error.detail,
            actionTitle: retry == nil ? nil : "Try again",
            action: retry
        )
    }
}

/// Honest data-source banner driven by the backend's `meta.mode`. Shows whether results
/// are sample / mixed / live and the per-section source labels — the in-app version of
/// "be honest — don't fake a real data pipeline".
struct ModeBanner: View {
    let meta: SearchMeta

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Active: \(meta.sources.active)  ·  Sold: \(meta.mode == .mixed ? "open on eBay" : meta.sources.sold)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: Theme.Space.sm)
            modePill
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .background(Theme.textPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    /// Emphasis escalates monochromatically: sample = outline, mixed = soft fill,
    /// live = solid.
    @ViewBuilder private var modePill: some View {
        let text = Text(meta.mode.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.5)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
        switch meta.mode {
        case .sample:
            text.foregroundStyle(Theme.textSecondary)
                .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 1))
        case .mixed:
            text.foregroundStyle(Theme.textPrimary)
                .background(Theme.textPrimary.opacity(0.12), in: Capsule())
        case .live:
            text.foregroundStyle(Theme.onAccent)
                .background(Theme.accent, in: Capsule())
        }
    }

    private var icon: String {
        switch meta.mode {
        case .sample: return "flask"
        case .mixed:  return "antenna.radiowaves.left.and.right"
        case .live:   return "checkmark.seal.fill"
        }
    }

    private var title: String {
        switch meta.mode {
        case .sample: return "Sample data"
        case .mixed:  return "Live listings · sold on eBay"
        case .live:   return "Live eBay data"
        }
    }
}

// MARK: - Shared container

private struct StateContainer: View {
    let systemImage: String
    let tint: Color
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(tint)
                .padding(.bottom, 2)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, Theme.Space.xl)
                        .padding(.vertical, Theme.Space.md)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Space.sm)
            }
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shimmer

private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Theme.textPrimary.opacity(0.06), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 1.5)
                    .offset(x: phase * geo.size.width * 1.5)
                }
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
            .clipped()
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}
