import SwiftUI

/// Results screen: value summary, filters, and the sold + active lists.
struct ResultsView: View {
    @StateObject private var viewModel: ResultsViewModel
    @Environment(\.openURL) private var openURL

    init(query: String) {
        _viewModel = StateObject(wrappedValue: ResultsViewModel(query: query))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
        }
        .navigationTitle(viewModel.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ListingRef.self) { ref in
            ListingDetailView(listing: ref.listing, averageSold: ref.averageSold)
        }
        .task {
            if case .loading = viewModel.state { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            LoadingStateView()
        case .failed(let error):
            ScrollView { ErrorStateView(error: error) { Task { await viewModel.load() } } }
        case .empty:
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    EmptyStateView(message: emptyMessage)
                    searchOnEbayButton
                    if !viewModel.didYouMean.isEmpty { didYouMeanSection }
                    suggestionChips
                }
                .padding(.top, Theme.Space.xxl)
                .padding(.horizontal, Theme.Space.lg)
            }
        case .loaded(let result):
            loaded(result)
        }
    }

    private func loaded(_ result: CardSearchResult) -> some View {
        ScrollView {
            VStack(spacing: Theme.Space.lg) {
                if let meta = result.meta { ModeBanner(meta: meta) }

                summaryLine(result)

                if viewModel.soldUnavailable { soldUnavailableCard }

                ebayLinkCard((result.cardName ?? viewModel.query).replacingOccurrences(of: "—", with: " "))

                FilterBarView(filters: $viewModel.filters)

                listingsList(result)
            }
            .padding(Theme.Space.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Compact, SECONDARY summary. The sold average appears ONLY when sold data is
    /// verified-real (`meta.live.sold`); otherwise we show a count + price range of the
    /// listings actually displayed — never a misleading average built from sample data.
    private func summaryLine(_ result: CardSearchResult) -> some View {
        // Display currency comes from the shown (live) listings — they carry the marketplace's
        // native currency; stats may still be USD from sample sold, so don't use it here.
        let code = viewModel.listings.first?.currencyCode ?? result.stats.currencyCode
        let prices = viewModel.listings.map(\.price)   // only what's actually shown
        let range = (prices.min().map { Listing.currency($0, code: code) } ?? "—")
            + "–" + (prices.max().map { Listing.currency($0, code: code) } ?? "—")
        let text: String
        if viewModel.soldIsVerified, result.stats.hasData, let avg = result.stats.formattedAverage {
            text = "Avg sold \(avg) · \(result.stats.salesCount) sold · \(range)"
        } else if viewModel.isBroad {
            text = "\(prices.count) listings · \(range) · several cards match — add a year or set to narrow"
        } else {
            text = "\(prices.count) listings · \(range)"
        }
        return Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Honest sold state for live/mixed searches with no verified comps: we refuse to show
    /// sample data as real, say so plainly, and send the user to eBay's actual sold view.
    private var soldUnavailableCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal").font(.system(size: 13, weight: .semibold))
                Text("SOLD COMPS").font(.system(size: 12, weight: .bold)).tracking(0.8)
            }
            .foregroundStyle(Theme.textSecondary)
            Text("Sold comps live on eBay for now, so we send you there instead of faking numbers in-app.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let url = Listing.ebaySearchURL(query: viewModel.query, sold: true) { openURL(url) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square").font(.system(size: 13, weight: .semibold))
                    Text("See sold on eBay").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.sm)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Space.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .strokeBorder(Theme.separator, lineWidth: 1))
    }

    /// The default result: one flat, ranked list of listings (130point-style) —
    /// photo, title, price, SOLD/LIVE status, and date.
    private func listingsList(_ result: CardSearchResult) -> some View {
        // Only pass a "vs. average sold" baseline when sold data is verified-real — never
        // compare a live price against a sample/unverified average.
        let avg = viewModel.soldIsVerified ? result.stats.averageSold : nil
        return VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeaderView(title: "Listings", count: viewModel.listings.count,
                              accentColor: Theme.textPrimary,
                              subtitle: viewModel.activeIsVerified ? "Active listings are live from eBay" : result.meta?.sources.active)
            if viewModel.listings.isEmpty {
                Text("No listings match your filters.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Space.sm)
            } else {
                ForEach(viewModel.listings) { listing in
                    NavigationLink(value: ListingRef(listing: listing, averageSold: avg)) {
                        ListingRowView(listing: listing, isSample: viewModel.isPureSample)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyMessage: String {
        if AppEnvironment.isSampleMode {
            return "No sample cards match “\(viewModel.query)”. Sample mode includes only a handful of demo cards — once a live eBay source is connected, real searches will be far more accurate and complete."
        }
        return "We couldn’t find listings for “\(viewModel.query)”. Try a broader search — a player or set name usually works best."
    }

    private var didYouMeanSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("DID YOU MEAN")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(viewModel.didYouMean, id: \.self) { name in
                NavigationLink(value: SearchQuery(text: name)) {
                    HStack(spacing: Theme.Space.md) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Text(name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(Theme.Space.md)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.separator, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("TRY ONE OF THESE")
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(ExampleSearch.defaults.prefix(4)) { example in
                NavigationLink(value: SearchQuery(text: example.query)) {
                    HStack(spacing: Theme.Space.md) {
                        Image(systemName: example.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(Theme.accent.opacity(0.10), in: Circle())
                        Text(example.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(Theme.Space.md)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.separator, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var searchOnEbayButton: some View {
        Button {
            if let url = Listing.ebaySearchURL(query: viewModel.query, sold: true) { openURL(url) }
        } label: {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "arrow.up.right.square")
                Text("Search “\(viewModel.query)” on eBay")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.md)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Real eBay live + sold results for this card (opens Safari). Works with no API approval.
    private func ebayLinkCard(_ query: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("SEE REAL LISTINGS ON EBAY")
                .font(.system(size: 12, weight: .bold)).tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Theme.Space.sm) {
                ebayLinkButton("Live", icon: "tag", query: query, sold: false)
                ebayLinkButton("Sold", icon: "checkmark.seal", query: query, sold: true)
            }
        }
    }

    private func ebayLinkButton(_ title: String, icon: String, query: String, sold: Bool) -> some View {
        Button {
            if let url = Listing.ebaySearchURL(query: query, sold: sold) { openURL(url) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 15, weight: .semibold))
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold)).opacity(0.7)
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.md)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Navigation payload so the detail screen can show a listing's price vs. the average sold.
struct ListingRef: Hashable {
    let listing: Listing
    let averageSold: Double?
}
