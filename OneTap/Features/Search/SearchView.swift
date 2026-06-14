import SwiftUI

/// Home screen: a big search field, curated examples, and recents.
/// The single entry point into the app. (Photo scan was removed in v1 — text search is
/// reliable and matches the 130point experience; a dependable card-recognition scan can
/// return later once it's backed by real recognition rather than a tiny on-device index.)
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var path = NavigationPath()
    @State private var showDebug = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    header
                    SearchField(text: $viewModel.searchText, onSubmit: submit)
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
        }
        .tint(Theme.accent)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Theme.Space.sm) {
                OneTapLogo(size: 26)
                Spacer()
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
}

#Preview {
    SearchView()
}
