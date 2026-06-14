import SwiftUI

/// Filter controls for the results screen: scope (Both/Sold/Active) as a segmented
/// control, plus Type (All/Raw/Graded) and Sort as compact menus.
struct FilterBarView: View {
    @Binding var filters: ResultFilters

    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            Picker("Scope", selection: $filters.scope) {
                ForEach(ListingScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: Theme.Space.sm) {
                menu(title: "Type", value: filters.cardType.title, systemImage: "square.stack.3d.up") {
                    Picker("Type", selection: $filters.cardType) {
                        ForEach(CardTypeFilter.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }

                menu(title: "Sort", value: filters.sort.shortTitle, systemImage: "arrow.up.arrow.down") {
                    Picker("Sort", selection: $filters.sort) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    private func menu<Content: View>(title: String, value: String, systemImage: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                Text("\(title):").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background(Theme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 1))
        }
    }
}
