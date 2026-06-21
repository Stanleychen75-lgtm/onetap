import SwiftUI

#if DEBUG

/// Lightweight developer/test screen (reachable only from the DEBUG ladybug button on the
/// home screen). Shows the active configuration, runs a one-tap self-test across every
/// sample query, and can ping the backend's /health. Not shipped to users.
@MainActor
final class DebugViewModel: ObservableObject {
    struct Row: Identifiable {
        let id = UUID()
        let query: String
        let ok: Bool
        let detail: String
    }

    @Published var rows: [Row] = []
    @Published var running = false
    @Published var health: String?
    @Published var overrideURL: String = UserDefaults.standard.string(forKey: AppEnvironment.backendURLOverrideKey) ?? ""

    /// Save the pasted URL as the active backend override (for mobile-data tunnel testing).
    /// Empty input clears it → falls back to the local Wi-Fi default.
    func saveOverride() {
        var s = overrideURL.trimmingCharacters(in: .whitespacesAndNewlines)
        // Assume https:// if the scheme was omitted, so a scheme-less paste still works.
        if !s.isEmpty, !s.lowercased().hasPrefix("http://"), !s.lowercased().hasPrefix("https://") {
            s = "https://" + s
        }
        overrideURL = s
        if s.isEmpty {
            UserDefaults.standard.removeObject(forKey: AppEnvironment.backendURLOverrideKey)
        } else {
            UserDefaults.standard.set(s, forKey: AppEnvironment.backendURLOverrideKey)
        }
        // Belt-and-suspenders: make the write durable immediately.
        UserDefaults.standard.synchronize()
    }

    /// Clear the override → fall back to the local Wi-Fi default URL.
    func clearOverride() {
        UserDefaults.standard.removeObject(forKey: AppEnvironment.backendURLOverrideKey)
        overrideURL = ""
    }

    /// Run each query through the real data service and report counts / mode / stats.
    func runSelfTest() async {
        running = true
        rows = []
        let service = AppEnvironment.makeCardDataService()   // fresh each run → picks up a changed backend URL
        // Known cards + one deliberate no-match to exercise the empty/no-results path.
        // Curated cards + search-quality cases (recall, typo, modifier, and queries that
        // should cleanly return no results).
        let queries = ExampleSearch.defaults.map(\.query) + [
            "Max Verstappen", "verstapen", "wemby", "Adesanya auto", "Mahomes", "NFL",
            "prizm", "topps chrome", "zzz not a real card",
        ]
        for query in queries {
            do {
                let result = try await service.search(query: query)
                let mode = result.meta?.mode.rawValue ?? "—"
                rows.append(Row(
                    query: query,
                    ok: true,
                    detail: "sold \(result.sold.count) · active \(result.active.count) · \(mode) · avg \(result.stats.formattedAverage ?? "—")"
                ))
            } catch let error as DataError {
                // For "zzz not a real card", a no-results error is the correct outcome.
                rows.append(Row(query: query, ok: error.isNoResults, detail: error.errorDescription ?? "error"))
            } catch {
                rows.append(Row(query: query, ok: false, detail: error.localizedDescription))
            }
        }
        running = false
    }

    func checkHealth() async {
        health = "Checking…"
        let url = AppEnvironment.backendBaseURL.appendingPathComponent("health")
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            health = "HTTP \(code)\n" + (String(data: data, encoding: .utf8) ?? "")
        } catch {
            health = "Failed: \(error.localizedDescription)"
        }
    }
}

struct DebugView: View {
    @StateObject private var viewModel = DebugViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Configuration") {
                    row("Data mode", AppEnvironment.isSampleMode ? "sample" : "live")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ACTIVE BASE URL — what the app is really using")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                        Text(AppEnvironment.backendBaseURL.absoluteString)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(AppEnvironment.isUsingBackendOverride
                             ? "source: Debug override ✓"
                             : "source: default — hosted backend (no override set)")
                            .font(.system(size: 11))
                            .foregroundStyle(AppEnvironment.isUsingBackendOverride ? Theme.sold : .orange)
                    }
                    .padding(.vertical, 2)
                }

                Section("Backend URL (mobile-data testing)") {
                    TextField("https://xxx.trycloudflare.com", text: $viewModel.overrideURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.system(size: 13, design: .monospaced))
                    // Each button is on its own row with .borderless so ONLY the tapped
                    // button fires. Without this, a List row treats multiple buttons as one
                    // tap target and runs BOTH actions — "Use this URL" was being instantly
                    // undone by "Reset", so the override never stuck. This is the bug fix.
                    Button("Use this URL") { viewModel.saveOverride() }
                        .buttonStyle(.borderless)
                        .font(.system(size: 14, weight: .semibold))
                        .disabled(viewModel.overrideURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Reset to default", role: .destructive) { viewModel.clearOverride() }
                        .buttonStyle(.borderless)
                        .font(.system(size: 14, weight: .semibold))
                    Text("Override the backend URL for testing (e.g. a local dev server), then tap “Use this URL”. Clear it to use the default: \(AppEnvironment.defaultBackendURL.absoluteString).")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }

                Section("Self-test") {
                    Button {
                        Task { await viewModel.runSelfTest() }
                    } label: {
                        HStack {
                            Image(systemName: "checklist")
                            Text(viewModel.running ? "Running…" : "Run self-test")
                            if viewModel.running { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(viewModel.running)

                    ForEach(viewModel.rows) { r in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: r.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(r.ok ? Theme.sold : .red)
                                Text(r.query).font(.system(size: 14, weight: .medium))
                            }
                            Text(r.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Backend /health") {
                    Button {
                        Task { await viewModel.checkHealth() }
                    } label: {
                        Label("Ping /health", systemImage: "stethoscope")
                    }
                    if let health = viewModel.health {
                        Text(health)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text("Only meaningful in live mode (set dataMode = .live and point backendBaseURL at your server).")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }

                Section("Phase 2 prototype") {
                    NavigationLink {
                        VisualRerankLabView()
                    } label: {
                        Label("Visual re-rank lab", systemImage: "square.stack.3d.up")
                    }
                    Text("Measures on-device visual re-ranking of search results by image similarity. Real device only — feature prints need the Neural Engine.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#endif
