import SwiftUI

@MainActor
final class ScanViewModel: ObservableObject {
    enum State { case scanning, done(ScanMatch) }

    @Published var state: State = .scanning
    @Published var query: String = ""
    @Published var selectedName: String?       // overrides the matched card when user picks
    @Published var selectedImage: String?

    let image: UIImage
    init(image: UIImage) { self.image = image }

    func run() async {
        state = .scanning
        let match = await CardScanner.scan(image)
        query = match.suggestedQuery
        selectedName = match.cardName
        selectedImage = match.referenceImageName
        state = .done(match)
    }

    func select(_ candidate: ScanMatch.Candidate) {
        query = candidate.cardName
        selectedName = candidate.cardName
        selectedImage = candidate.imageName
    }
}

/// Confirm/edit step after a photo — leads with the visual match, shows a matched-card
/// preview + honest match strength, lets the user pick an alternate or edit the query.
struct ScanReviewView: View {
    @StateObject private var viewModel: ScanViewModel
    @Environment(\.dismiss) private var dismiss

    let onSearch: (String) -> Void
    let onRetake: () -> Void

    init(image: UIImage, onSearch: @escaping (String) -> Void, onRetake: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: ScanViewModel(image: image))
        self.onSearch = onSearch
        self.onRetake = onRetake
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Theme.Space.lg) {
                        photo
                        content
                    }
                    .padding(Theme.Space.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Scan card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .task { await viewModel.run() }
        }
        .tint(Theme.accent)
    }

    private var photo: some View {
        Image(uiImage: viewModel.image)
            .resizable().scaledToFill()
            .frame(height: 170).frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .scanning:
            VStack(spacing: Theme.Space.md) {
                ProgressView()
                Text("Matching card…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text("Comparing the photo visually and reading its text.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, Theme.Space.xl)

        case .done(let match):
            if viewModel.selectedName != nil {
                matchedState(match)
            } else if match.method == .ocrOnly {
                ocrOnlyState(match)
            } else {
                noMatchState(match)
            }
        }
    }

    // MARK: Matched

    private func matchedState(_ match: ScanMatch) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            sectionLabel(match.method.usesVisual ? "MATCHED CARD" : "BEST MATCH")
            matchedCardRow(name: viewModel.selectedName ?? "",
                           imageName: viewModel.selectedImage,
                           method: match.method)

            queryField

            // Offer alternates when we're not highly confident.
            let alternates = match.candidates.filter { $0.cardName != viewModel.selectedName }
            if !alternates.isEmpty && match.confidence < 0.85 {
                sectionLabel("NOT RIGHT? PICK ANOTHER")
                ForEach(alternates) { candidate in
                    Button { viewModel.select(candidate) } label: { candidateRow(candidate) }
                        .buttonStyle(.plain)
                }
            }

            searchButton
            retakeButton
            honestNote(match)
        }
    }

    private func matchedCardRow(name: String, imageName: String?, method: ScanMatch.Method) -> some View {
        HStack(spacing: Theme.Space.md) {
            referenceThumb(imageName)
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Image(systemName: method.usesVisual ? "checkmark.seal.fill" : "textformat")
                        .font(.system(size: 11, weight: .bold))
                    Text(method.label)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .cardSurface()
    }

    // MARK: OCR-only

    private func ocrOnlyState(_ match: ScanMatch) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            sectionLabel("MATCHED BY TEXT")
            Text("No confident visual match — using the text read from the card. Edit if needed.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            queryField
            if !match.ocrLines.isEmpty {
                Text("Read: " + match.ocrLines.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            searchButton
            retakeButton
        }
    }

    // MARK: No match

    private func noMatchState(_ match: ScanMatch) -> some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: "viewfinder.trianglebadge.exclamationmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("Couldn’t match this photo")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Try a sharper, straight-on photo that fills the frame. You can also type the card instead.")
                .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            queryField
            searchButton
            retakeButton
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Shared pieces

    private var queryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("SEARCH QUERY")
            TextField("Edit the search query", text: $viewModel.query, axis: .vertical)
                .font(.system(size: 16, weight: .medium))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(Theme.Space.md)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.separator, lineWidth: 1))
        }
    }

    private func candidateRow(_ candidate: ScanMatch.Candidate) -> some View {
        HStack(spacing: Theme.Space.md) {
            referenceThumb(candidate.imageName, size: CGSize(width: 40, height: 56))
            Text(candidate.cardName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary).lineLimit(2)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textTertiary)
        }
        .padding(Theme.Space.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .strokeBorder(Theme.separator, lineWidth: 1))
    }

    private func referenceThumb(_ imageName: String?, size: CGSize = CGSize(width: 58, height: 80)) -> some View {
        Group {
            if let imageName, let ui = CardReferenceIndex.shared.image(named: imageName) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Theme.surfaceElevated.overlay(
                    Image(systemName: "rectangle.portrait").foregroundStyle(Theme.textTertiary))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
            .strokeBorder(Theme.separator, lineWidth: 1))
    }

    private var searchButton: some View {
        Button {
            let q = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard q.count >= 2 else { return }
            onSearch(q)
        } label: {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "magnifyingglass")
                Text("See prices")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity).padding(.vertical, Theme.Space.md)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .opacity(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
        .padding(.top, Theme.Space.sm)
    }

    private var retakeButton: some View {
        Button(action: onRetake) {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "camera.rotate")
                Text("Retake / choose another")
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity).padding(.vertical, Theme.Space.md)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func honestNote(_ match: ScanMatch) -> some View {
        if AppEnvironment.isSampleMode {
            Text(match.method.usesVisual
                 ? "Visual match runs on-device against the sample reference set. Accuracy improves a lot with real card images once live data is connected."
                 : "Matched from the card’s text. Visual matching improves with real reference images later.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold)).tracking(0.8)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
