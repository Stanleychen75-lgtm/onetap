import SwiftUI

/// Settings — marketplace/currency selection plus a plain-English "how it works" so users
/// always understand what's live vs. external. Presented as a sheet from the home screen.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var marketplace = AppEnvironment.selectedMarketplace

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Currency", selection: $marketplace) {
                        ForEach(EbayMarketplace.allCases) { m in
                            Text(m.currency).tag(m)
                        }
                    }
                } header: {
                    Text("Pricing currency")
                } footer: {
                    Text("Choose the currency you want prices shown in. OneTap pulls listings from the matching eBay marketplace and shows the real listed amount — no conversion.")
                }

                Section("How OneTap works") {
                    howItWorks("tag", "Live listings",
                               "What cards are listed for right now — straight from eBay.")
                    howItWorks("checkmark.seal", "Sold comps",
                               "Real sold prices live on eBay for now — tap “See sold comps on eBay” on any card. We never show estimated or sample prices as real.")
                }

                Section {
                    HStack {
                        Text("Version").foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(appVersion).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.accent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: marketplace) { _, newValue in
                AppEnvironment.selectedMarketplace = newValue   // persists; next search uses it
            }
        }
    }

    private func howItWorks(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    SettingsView()
}
