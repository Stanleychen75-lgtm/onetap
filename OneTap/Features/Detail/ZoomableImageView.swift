import SwiftUI

/// Full-screen, zoomable viewer for a single listing photo. Pure SwiftUI, self-contained:
/// pinch to zoom, drag to pan while zoomed, double-tap to toggle zoom, and an X to close.
/// Used by the listing detail screen when the user taps the photo. The image loads the same
/// URL the detail thumbnail used (URLCache means it's usually already cached → instant).
struct ZoomableImageView: View {
    let url: URL?
    let onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            imageContent
            closeButton
        }
    }

    @ViewBuilder private var imageContent: some View {
        if let url {
            AsyncImage(url: url, transaction: .init(animation: .easeInOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnification)
                        .simultaneousGesture(drag)
                        .onTapGesture(count: 2) { toggleZoom() }
                case .empty:
                    ProgressView().tint(.white)
                default:
                    fallbackIcon
                }
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "photo")
            .font(.system(size: 32, weight: .light))
            .foregroundStyle(.white.opacity(0.4))
    }

    // MARK: - Gestures

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale {
                    withAnimation(.easeOut(duration: 0.2)) { resetPan() }
                }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }   // pan only when zoomed in
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if scale > minScale {
                scale = minScale; lastScale = minScale; resetPan()
            } else {
                scale = 2.5; lastScale = 2.5
            }
        }
    }

    private func resetPan() { offset = .zero; lastOffset = .zero }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .padding(.trailing, Theme.Space.md)
                .padding(.top, Theme.Space.md)
            }
            Spacer()
        }
    }
}
