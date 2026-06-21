import SwiftUI

/// Honest Phase-1 review screen. Shows the cropped card and the TEXT we read from it,
/// editable, then runs the normal card-fenced search. It never claims to have identified
/// the exact card or variant — it's a faster way to start a text search.
struct ScanReviewView: View {
    let image: UIImage
    var onSearch: (String) -> Void
    var onRetake: () -> Void

    @State private var result: ScanResult?
    @State private var query: String = ""
    @State private var isScanning = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    Image(uiImage: result?.croppedImage ?? image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 220)
                        .background(Theme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(Theme.separator, lineWidth: 1))

                    if isScanning {
                        HStack(spacing: Theme.Space.sm) {
                            ProgressView()
                            Text("Reading the card…").foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.xl)
                    } else {
                        editor
                        searchButton
                        Button("Retake / choose another") { onRetake() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                }
                .padding(Theme.Space.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Scan text from a card")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Theme.accent)
        .task {
            let r = await CardTextScanner.scan(image)
            result = r
            query = r.suggestedQuery
            isScanning = false
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("WE READ THIS FROM THE CARD")
                .font(.system(size: 12, weight: .bold)).tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if result?.isLowConfidence == true {
                Text("The text was hard to read — please check and edit it before searching.")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("Type what to search", text: $query, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(size: 16))
                .padding(Theme.Space.md)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.separator, lineWidth: 1))

            Text("This reads the text on the card to start a search — it doesn’t identify the exact card or variant.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchButton: some View {
        Button {
            onSearch(query.trimmingCharacters(in: .whitespacesAndNewlines))
        } label: {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "magnifyingglass")
                Text("Search with this text")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.md)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
    }
}
