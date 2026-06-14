import Foundation

/// A query broken into meaningful parts so both sample and live search can reason about it.
struct NormalizedQuery {
    let raw: String
    let cleaned: String          // lowercased, punctuation→space, collapsed
    let tokens: [String]
    let nameTokens: [String]     // likely player/fighter/driver/character words
    let setTokens: [String]      // brand/set words (topps, prizm, chrome…)
    let parallels: [String]      // refractor, silver, holo…
    let surname: String?         // last human-name token (excludes sport/category words)
    let hasAuto: Bool
    let hasRookie: Bool
    let grade: GradePair?
    let cardNumber: String?
    let year: String?

    struct GradePair { let company: String; let value: String }

    var isUsable: Bool { !tokens.isEmpty }
}

/// The shared search brain — normalization, fallback variant generation, and relevance
/// scoring. Pure and I/O-free, so it powers BOTH the sample index and the live eBay path.
enum SearchEngine {

    // Vocabulary
    static let autoWords: Set<String> = ["auto", "autos", "autograph", "autographed", "signed", "signature"]
    static let rookieWords: Set<String> = ["rookie", "rookies", "rc"]
    static let parallelWords: Set<String> = ["refractor", "refractors", "silver", "gold", "holo", "holographic",
                                             "reverse", "secret", "rare", "sp", "ssp", "insert", "numbered",
                                             "parallel", "mojo", "wave", "pulsar", "disco", "prizm"]
    static let setBrandWords: Set<String> = ["topps", "panini", "chrome", "donruss", "optic", "select", "mosaic",
                                             "bowman", "fleer", "upper", "deck", "score", "update", "champions",
                                             "path", "world", "cup", "formula", "evolving", "skies"]
    static let gradeCompanies: Set<String> = ["psa", "bgs", "bvg", "cgc", "sgc", "csg", "hga"]
    static let stopWords: Set<String> = ["the", "a", "an", "of", "and", "card", "cards"]
    /// Category/sport words: count as name tokens (so "NBA" matches) but never as a surname.
    static let sportCategory: Set<String> = ["nba", "nfl", "mlb", "ufc", "f1", "tcg", "pokemon", "soccer",
                                             "baseball", "basketball", "football", "hockey", "wnba", "golf"]

    // MARK: Normalization

    static func normalize(_ raw: String) -> NormalizedQuery {
        let lower = raw.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let cleaned = lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
        let toks = cleaned.split(separator: " ").map(String.init).filter { $0.count >= 2 }

        var names: [String] = [], sets: [String] = [], paras: [String] = []
        var hasAuto = false, hasRookie = false
        for t in toks {
            if autoWords.contains(t) { hasAuto = true }
            else if rookieWords.contains(t) { hasRookie = true }
            else if parallelWords.contains(t) { paras.append(t) }
            else if gradeCompanies.contains(t) { /* via grade regex */ }
            else if setBrandWords.contains(t) { sets.append(t) }
            else if stopWords.contains(t) { /* ignore */ }
            else if t.allSatisfy(\.isNumber) { /* number, via regex */ }
            else { names.append(t) }
        }

        let surname = names.last(where: { !sportCategory.contains($0) })
        return NormalizedQuery(
            raw: raw, cleaned: cleaned, tokens: toks,
            nameTokens: names, setTokens: sets, parallels: paras,
            surname: surname, hasAuto: hasAuto, hasRookie: hasRookie,
            grade: firstGrade(lower),
            cardNumber: firstMatch(#"#\s?\d{1,4}|\b\d{1,3}\s?/\s?\d{1,3}\b"#, lower)?.replacingOccurrences(of: " ", with: ""),
            year: firstMatch(#"\b(19|20)\d{2}\b"#, lower)
        )
    }

    // MARK: Fallback variants (broad → narrow), for the live provider to try in order

    static func variants(_ nq: NormalizedQuery) -> [String] {
        var out: [String] = []
        func add(_ s: String) {
            let t = s.trimmingCharacters(in: .whitespaces)
            if t.count >= 2, !out.contains(t) { out.append(t) }
        }
        add(nq.cleaned)                                                   // full query
        var important = nq.nameTokens                                     // names + key modifiers + number
        if nq.hasAuto { important.append("auto") }
        if nq.hasRookie { important.append("rookie") }
        if let n = nq.cardNumber { important.append(n) }
        add(important.joined(separator: " "))
        add(nq.nameTokens.joined(separator: " "))                        // name only
        if let surname = nq.surname {
            if nq.hasAuto { add("\(surname) auto") }                     // surname + key modifier
            add(surname)                                                  // surname only
        }
        return out
    }

    // MARK: Relevance scoring

    /// Score how well a listing/card title matches the query. Higher = more relevant.
    static func score(title: String, _ nq: NormalizedQuery) -> Double {
        let titleTokens = Set(tokens(title))
        guard !titleTokens.isEmpty else { return 0 }
        var s = 0.0

        for name in nq.nameTokens {
            let isSurname = (name == nq.surname)
            if titleTokens.contains(name) {
                s += isSurname ? 3.0 : 2.0
            } else if name.count >= 4 && titleTokens.contains(where: { $0.hasPrefix(name) }) {
                s += isSurname ? 2.2 : 1.3
            } else if name.count >= 5 && titleTokens.contains(where: { levenshtein($0, name) <= 1 }) {
                s += isSurname ? 2.2 : 1.2   // typo tolerance
            }
        }
        for set in nq.setTokens where titleTokens.contains(set) { s += 0.8 }
        for parallel in nq.parallels where titleTokens.contains(parallel) { s += 0.6 }
        if nq.hasAuto, titleTokens.contains(where: autoWords.contains) { s += 0.9 }
        if nq.hasRookie, titleTokens.contains(where: rookieWords.contains) { s += 0.7 }
        if let g = nq.grade, titleTokens.contains(g.company), titleTokens.contains(g.value) { s += 1.0 }
        if let n = nq.cardNumber {
            let core = n.replacingOccurrences(of: "#", with: "")
            if title.lowercased().contains(core) { s += 1.0 }
        }
        if let y = nq.year, titleTokens.contains(y) { s += 0.4 }
        // Exact-phrase bonus — only when the query has a real name, so brand/parallel-only
        // queries like "prizm" or "topps chrome" can't be inflated into a match.
        if !nq.nameTokens.isEmpty, title.lowercased().contains(nq.cleaned) { s += 3.0 }
        return s
    }

    // MARK: Helpers

    static func tokens(_ s: String) -> [String] {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init).filter { $0.count >= 2 }
    }

    private static func firstGrade(_ text: String) -> NormalizedQuery.GradePair? {
        guard let m = firstMatch(#"(psa|bgs|bvg|cgc|sgc|csg|hga)\s?(10|9\.5|9|8\.5|8|7|6|5|4|3|2|1)"#, text) else { return nil }
        let parts = m.split(whereSeparator: { $0 == " " })
        // Re-extract company + value robustly.
        let company = firstMatch(#"psa|bgs|bvg|cgc|sgc|csg|hga"#, m) ?? String(parts.first ?? "")
        let value = firstMatch(#"10|9\.5|9|8\.5|8|7|6|5|4|3|2|1"#, m) ?? ""
        return NormalizedQuery.GradePair(company: company, value: value)
    }

    private static func firstMatch(_ pattern: String, _ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, range: range), let r = Range(m.range, in: text) else { return nil }
        return String(text[r])
    }

    /// Bounded Levenshtein distance for short tokens (typo tolerance).
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a), t = Array(b)
        if abs(s.count - t.count) > 2 { return 99 }
        var prev = Array(0...t.count)
        var cur = [Int](repeating: 0, count: t.count + 1)
        for i in 1...max(1, s.count) {
            cur[0] = i
            for j in 1...max(1, t.count) {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                cur[j] = Swift.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &cur)
        }
        return prev[t.count]
    }
}
