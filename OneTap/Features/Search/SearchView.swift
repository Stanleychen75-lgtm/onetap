import SwiftUI
import PhotosUI

/// Home screen: a big search field, curated examples, and recents — the single entry point
/// into the app. (A photo-scan entry exists in DEBUG builds only; it's hidden from the v1
/// release until its quality is ready. See the #if DEBUG block in the body.)
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var path = NavigationPath()
    @State private var showDebug = false
    @State private var showSettings = false

    // Photo-scan flow — HIDDEN for v1 via the SCAN_ENABLED compile flag, which is defined in
    // NO build configuration. The whole scan subsystem (state, presentation, camera, review,
    // OCR) is therefore compiled out of BOTH Debug and Release: no entry point, no reachable
    // route, no scan/camera strings in any binary. To bring it back later, add SCAN_ENABLED to
    // the target's "Active Compilation Conditions" (Build Settings). Code is preserved, not deleted.
    #if SCAN_ENABLED
    @State private var showScanOptions = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?   // temp holder while the camera dismisses
    @State private var scan: ScanImage?          // drives the review sheet
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    header
                    VStack(spacing: Theme.Space.md) {
                        SearchField(text: $viewModel.searchText, onSubmit: submit)
                        // Scan entry point — hidden in ALL builds for v1 (SCAN_ENABLED is undefined,
                        // so this compiles out everywhere). Flip SCAN_ENABLED on to restore it.
                        #if SCAN_ENABLED
                        scanButton
                        #endif
                    }
                    trendingSection
                    mostPopularSection
                    moreCategoriesSection
                    if !viewModel.recentSearches.isEmpty { recents }
                }
                .padding(Theme.Space.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationDestination(for: SearchQuery.self) { query in
                ResultsView(query: query.text)
            }
            #if SCAN_ENABLED
            .confirmationDialog("Scan a card", isPresented: $showScanOptions, titleVisibility: .visible) {
                if CameraPicker.isAvailable {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Choose from Library") { showLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera, onDismiss: presentReviewFromCamera) {
                CameraPicker { capturedImage = $0 }.ignoresSafeArea()
            }
            .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .images)
            .onChange(of: libraryItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    let data = try? await newItem.loadTransferable(type: Data.self)
                    await MainActor.run {
                        if let data, let image = UIImage(data: data) { scan = ScanImage(image: image) }
                        libraryItem = nil
                    }
                }
            }
            .sheet(item: $scan) { item in
                ScanReviewView(
                    image: item.image,
                    onSearch: { query in scan = nil; run(query) },
                    onRetake: { scan = nil; showScanOptions = true }
                )
            }
            #endif
        }
        .tint(Theme.accent)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Theme.Space.md) {
                OneTapLogo(size: 26)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .sheet(isPresented: $showSettings) { SettingsView() }
                #if DEBUG
                Button { showDebug = true } label: {
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Developer tools")
                .sheet(isPresented: $showDebug) { DebugView() }
                #endif
            }
            Text("Check what any trading card is selling for.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, Theme.Space.sm)
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            sectionLabel("TRENDING")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.sm) {
                    ForEach(viewModel.trending) { item in
                        Button { run(item.query) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                Text(item.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, Theme.Space.sm)
                            .background(Theme.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private var mostPopularSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            sectionLabel("MOST POPULAR")
            HStack(spacing: Theme.Space.md) {
                ForEach(viewModel.mostPopular) { category in
                    Button { run(category.query) } label: { popularCard(category) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func popularCard(_ category: HomeCategory) -> some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: category.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 46, height: 46)
                .background(Theme.accent.opacity(0.08), in: Circle())
            Text(category.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.lg)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .strokeBorder(Theme.separator, lineWidth: 1))
    }

    private var moreCategoriesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            sectionLabel("MORE CATEGORIES")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: Theme.Space.sm)],
                spacing: Theme.Space.sm
            ) {
                ForEach(viewModel.moreCategories) { category in
                    Button { run(category.query) } label: { categoryChip(category) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func categoryChip(_ category: HomeCategory) -> some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon).font(.system(size: 13, weight: .semibold))
            Text(category.name).font(.system(size: 14, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .strokeBorder(Theme.separator, lineWidth: 1))
    }

    private var recents: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            HStack {
                sectionLabel("RECENT")
                Spacer()
                Button("Clear") { viewModel.clearRecents() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            ForEach(viewModel.recentSearches, id: \.self) { term in
                Button {
                    run(term)
                } label: {
                    HStack(spacing: Theme.Space.md) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textTertiary)
                        Text(term)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, Theme.Space.sm)
                }
                .buttonStyle(.plain)
                Divider().overlay(Theme.separator)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.textSecondary)
    }

    // MARK: - Actions

    private func submit() {
        run(viewModel.searchText)
    }

    private func run(_ text: String) {
        guard let query = viewModel.makeQuery(from: text) else { return }
        viewModel.recordSearch(query.trimmed)
        viewModel.searchText = query.trimmed
        path.append(query)
    }

    #if SCAN_ENABLED
    private var scanButton: some View {
        Button { showScanOptions = true } label: {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "camera.viewfinder").font(.system(size: 16, weight: .semibold))
                Text("Scan a card").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func presentReviewFromCamera() {
        if let image = capturedImage {
            capturedImage = nil
            scan = ScanImage(image: image)
        }
    }
    #endif
}

#if SCAN_ENABLED
/// Wrapper so a captured/picked image can drive an item-based review sheet. (Scan is
/// hidden in v1 via the SCAN_ENABLED flag — see SearchView.)
private struct ScanImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
#endif

#Preview {
    SearchView()
}
