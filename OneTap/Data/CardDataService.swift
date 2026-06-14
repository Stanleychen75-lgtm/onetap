import Foundation

/// The single seam between the UI and the world.
///
/// Every screen talks to this protocol and nothing else. Swapping sample data for a
/// real backend is a one-line change in `AppEnvironment` — no UI code changes.
protocol CardDataService {
    func search(query: String) async throws -> CardSearchResult
}

/// Honest, user-facing errors. The error states in the UI read straight from these,
/// so we never show a lie like "no results" when the truth is "not connected yet".
enum DataError: LocalizedError {
    case notConfigured
    case noResults
    case network(underlying: Error)
    case decoding

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "This data source isn’t connected yet."
        case .noResults:
            return "No listings found for that search."
        case .network:
            return "Couldn’t reach the server. Check your connection and try again."
        case .decoding:
            return "We reached the data source but couldn’t read the response."
        }
    }

    var isNotConfigured: Bool {
        if case .notConfigured = self { return true }
        return false
    }

    var isNoResults: Bool {
        if case .noResults = self { return true }
        return false
    }

    /// Longer, honest explanation for the error screen.
    var detail: String {
        switch self {
        case .notConfigured:
            return "The app is set to use a live data source, but no backend is configured. See the README — real eBay sold data requires your own backend plus eBay API approval."
        case .noResults:
            return "Try a broader search — a player or set name often works better than a full card number."
        case .network(let underlying):
            return underlying.localizedDescription
        case .decoding:
            return "The response format didn’t match what the app expected."
        }
    }
}

/// Which data source is live.
///
/// - `sample`: bundled mock JSON. The current default for development. (Mode A)
/// - `live`:   a backend/API *you* control. (Mode B — see `LiveCardDataService`)
///
/// A future "Mode C" (a better marketplace data provider, once you have access) is
/// just another case + another `CardDataService` implementation. Nothing else changes.
enum DataMode {
    case sample
    case live
}

/// Central app configuration. The one place to flip data sources and endpoints.
enum AppEnvironment {

    /// 👉 Flip this to `.live` once your backend is running, to hit real eBay listings.
    ///    (Kept `.sample` by default so the app always runs even with no backend up.)
    static let dataMode: DataMode = .live

    /// Default backend URL — your Mac on the local Wi-Fi. Used when no runtime override is
    /// set, so same-Wi-Fi testing keeps working out of the box.
    /// • iOS Simulator or same-Wi-Fi device: this LAN IP.
    /// • Production: your deployed HTTPS URL.
    static let defaultBackendURL = URL(string: "https://onetap-8no5.onrender.com")!

    /// UserDefaults key for an optional runtime override set in the Debug screen. Paste a
    /// public tunnel URL (e.g. https://xxx.trycloudflare.com) to test on mobile data WITHOUT
    /// rebuilding — free tunnel URLs rotate each restart, so this avoids a recompile each time.
    /// Clearing it falls back to `defaultBackendURL` (local Wi-Fi).
    static let backendURLOverrideKey = "backendURLOverride"

    /// The active backend URL: the pasted override if present, else the Wi-Fi default.
    static var backendBaseURL: URL {
        if let s = UserDefaults.standard.string(forKey: backendURLOverrideKey),
           !s.isEmpty, let url = URL(string: s) {
            return url
        }
        return defaultBackendURL
    }

    /// True when a Debug override URL is active (vs. the Wi-Fi default). Surfaced in the
    /// Debug screen so it's unambiguous which URL the app is really hitting.
    static var isUsingBackendOverride: Bool {
        guard let s = UserDefaults.standard.string(forKey: backendURLOverrideKey) else { return false }
        return !s.isEmpty && URL(string: s) != nil
    }

    /// Shared secret sent to the backend as `Authorization: Bearer …`. Leave empty for an
    /// unprotected local backend; set it to the backend's API_KEY before exposing publicly.
    /// (Note: a key embedded in a shipped app is extractable — fine for dev, rotate for prod.)
    static let backendAPIKey = ""

    static var isSampleMode: Bool { dataMode == .sample }

    static func makeCardDataService() -> CardDataService {
        switch dataMode {
        case .sample:
            return MockCardDataService()
        case .live:
            return LiveCardDataService(baseURL: backendBaseURL, apiKey: backendAPIKey)
        }
    }
}
