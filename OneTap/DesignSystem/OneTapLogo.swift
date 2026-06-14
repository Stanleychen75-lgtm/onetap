import SwiftUI

/// The OneTap reticle mark — a crosshair: a ring with a cross that extends past it.
/// Pure vector so it scales crisply and inherits the current foreground color.
struct OneTapMark: View {
    var lineWidth: CGFloat = 2.4
    var radiusRatio: CGFloat = 0.32   // ring radius as a fraction of the frame
    var reachRatio: CGFloat = 0.5     // crosshair half-length as a fraction of the frame

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let radius = s * radiusRatio
            let reach = s * reachRatio
            ZStack {
                Circle()
                    .stroke(lineWidth: lineWidth)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(x: cx, y: cy)
                Path { p in
                    p.move(to: CGPoint(x: cx - reach, y: cy))
                    p.addLine(to: CGPoint(x: cx + reach, y: cy))
                    p.move(to: CGPoint(x: cx, y: cy - reach))
                    p.addLine(to: CGPoint(x: cx, y: cy + reach))
                }
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The wordmark — the reticle stands in for the **"O"**, reading as `⊕neTap` → "OneTap".
/// One combined mark: monochrome, minimal, premium.
struct OneTapLogo: View {
    /// Roughly the wordmark's point size.
    var size: CGFloat = 28

    var body: some View {
        HStack(alignment: .center, spacing: -size * 0.06) {
            OneTapMark(lineWidth: max(2, size * 0.07))
                .frame(width: size * 1.08, height: size * 1.08)
            Text("neTap")
                .font(.system(size: size, weight: .heavy))
                .baselineOffset(0)
        }
        .foregroundStyle(Theme.textPrimary)
        .accessibilityElement()
        .accessibilityLabel("OneTap")
    }
}

#Preview {
    VStack(spacing: 40) {
        OneTapLogo(size: 30)
        OneTapLogo(size: 44)
        OneTapMark().frame(width: 64, height: 64)
    }
    .padding()
}
