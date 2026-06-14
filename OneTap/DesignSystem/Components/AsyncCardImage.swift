import SwiftUI

/// Loads a card image from a URL. Images use aspect-FIT (the whole card is always visible —
/// never stretched, distorted, or cropped) centered on a neutral background, so wide or
/// oddly-framed eBay photos letterbox tidily inside a fixed frame. Polished placeholder
/// while loading or when there's no image. Never shows a broken image.
struct AsyncCardImage: View {
    let url: URL?
    var cornerRadius: CGFloat = Theme.Radius.sm

    var body: some View {
        ZStack {
            // Neutral letterbox background — fills the caller's fixed frame so a contained
            // image (which may not cover the whole frame) still looks intentional and tidy.
            Theme.surfaceElevated
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1)
        )
    }

    @ViewBuilder private var content: some View {
        if let url {
            AsyncImage(url: url, transaction: .init(animation: .easeInOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    // .fit = "contain": the entire card is visible, never distorted.
                    image.resizable().aspectRatio(contentMode: .fit)
                case .empty:
                    ProgressView().tint(Theme.textTertiary)
                case .failure:
                    placeholderIcon
                @unknown default:
                    placeholderIcon
                }
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "viewfinder")
            .font(.system(size: 20, weight: .light))
            .foregroundStyle(Theme.textTertiary)
    }
}
