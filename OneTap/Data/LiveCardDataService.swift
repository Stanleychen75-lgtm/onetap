import Foundation

/// Production data source (Mode B).
///
/// This talks to a backend **you** control at `GET {baseURL}/search?q=...`, expecting a
/// JSON body matching `CardSearchResult`. The networking is real and complete — the
/// moment your backend returns that shape, the whole app works against live data with
/// no UI changes.
///
/// ── Why a backend instead of calling eBay directly from the app? ──────────────────
/// • eBay **sold / completed** data is not available from a free, public, client-side
///   API. The modern source is eBay's **Marketplace Insights API**, which is a
///   *Limited Release* — you must apply and be approved.
/// • eBay **active** listings come from the **Browse API**, which needs an eBay
///   developer account + OAuth app tokens (and production access for higher limits).
/// • Both require secrets that must never ship inside an App Store binary.
/// So the honest architecture is: app → your backend → eBay (or another provider).
/// Your backend holds the keys, handles OAuth, caches results, and computes stats.
final class LiveCardDataService: CardDataService {

    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession

    init(baseURL: URL, apiKey: String = "", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    func search(query: String) async throws -> CardSearchResult {
        // Guard against shipping with the placeholder host still in place.
        if baseURL.host?.contains("example.com") ?? true {
            throw DataError.notConfigured
        }

        // Use the shared SearchEngine to pass the backend both a normalized primary query
        // and ordered fallback variants (full → important tokens → name → surname). The
        // backend tries them against eBay in order and merges/dedupes/ranks the results —
        // see backend/src/searchService.ts. Same search brain as sample mode.
        let nq = SearchEngine.normalize(query)
        let variants = SearchEngine.variants(nq)
        var components = URLComponents(url: baseURL.appendingPathComponent("search"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: nq.cleaned.isEmpty ? query : nq.cleaned),
            URLQueryItem(name: "variants", value: variants.joined(separator: "|")),
            // Native listings + currency for the user's chosen marketplace (read per request).
            URLQueryItem(name: "marketplace", value: AppEnvironment.selectedMarketplace.apiID),
        ]
        guard let url = components?.url else { throw DataError.notConfigured }

        var request = URLRequest(url: url)
        // Fail fast (≈12s) instead of hanging on skeleton cards for the 60s default when
        // the backend is unreachable — e.g. a real device that can't see your Mac's LAN.
        request.timeoutInterval = 12
        // Shared-secret auth — kept server-side; only sent if configured.
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                if http.statusCode == 404 { throw DataError.noResults }
                throw networkError(URLError(.badServerResponse), url: url, status: http.statusCode)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            do {
                let result = try decoder.decode(CardSearchResult.self, from: data)
                if result.isEmpty { throw DataError.noResults }
                return result
            } catch is DecodingError {
                throw DataError.decoding
            }
        } catch let error as DataError {
            throw error
        } catch {
            throw networkError(error, url: url)
        }
    }

    /// Wrap a networking failure so the surfaced error includes the exact URL we tried.
    /// DEBUG-only detail (keeps production error text clean) — this is what makes a failed
    /// search show, e.g., "Tried: https://…trycloudflare.com/search?q=…" so you can see at a
    /// glance whether the app used your override URL or silently fell back to the default.
    private func networkError(_ underlying: Error, url: URL, status: Int? = nil) -> DataError {
        #if DEBUG
        var msg = status.map { "Server returned HTTP \($0)." } ?? underlying.localizedDescription
        msg += "\nTried: \(url.absoluteString)"
        return .network(underlying: NSError(domain: "OneTap.Network",
                                            code: status ?? (underlying as NSError).code,
                                            userInfo: [NSLocalizedDescriptionKey: msg]))
        #else
        return .network(underlying: underlying)
        #endif
    }
}
