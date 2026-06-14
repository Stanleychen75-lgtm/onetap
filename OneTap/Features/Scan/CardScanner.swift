import Foundation
import Vision
import UIKit

/// The fused result of a card scan: a visual match (Apple Vision feature prints) confirmed
/// and refined by OCR text. Visual leads; OCR supports.
struct ScanMatch {
    enum Method {
        case fused      // visual + OCR agree → strongest
        case visual     // visual clearly led; OCR didn't confirm
        case ocrOnly    // no usable visual match; relied on reading the text
        case none       // couldn't read or match anything

        var label: String {
            switch self {
            case .fused:   return "Matched this card"
            case .visual:  return "Visual match"
            case .ocrOnly: return "Matched by text"
            case .none:    return "No match"
            }
        }
        var usesVisual: Bool { self == .fused || self == .visual }
    }

    struct Candidate: Identifiable {
        var id: String { cardName }
        let cardName: String
        let imageName: String
    }

    var method: Method
    var cardName: String?
    var referenceImageName: String?
    var suggestedQuery: String
    var confidence: Double            // 0...1
    var candidates: [Candidate]       // alternates for low-confidence choosing
    var ocrLines: [String]

    static let empty = ScanMatch(method: .none, cardName: nil, referenceImageName: nil,
                                 suggestedQuery: "", confidence: 0, candidates: [], ocrLines: [])
}

/// On-device card scanner: **visual matching first** (Vision feature prints vs. the
/// reference index), with OCR as a supporting/confirming signal. Honest by design — it
/// reports how it matched (fused / visual / text) so the UI never overclaims.
enum CardScanner {

    static func scan(_ image: UIImage) async -> ScanMatch {
        async let ocrTask = runOCR(image)
        let visual = visualMatches(for: image)
        let ocr = await ocrTask
        return fuse(ocr: ocr, visual: visual)
    }

    // MARK: - Visual

    private static func visualMatches(for image: UIImage) -> [CardReferenceIndex.Hit] {
        guard let print = CardReferenceIndex.featurePrint(for: image) else { return [] }
        return CardReferenceIndex.shared.nearest(to: print, max: 3)
    }

    // MARK: - Fusion (visual leads, OCR supports)

    private static func fuse(ocr: OCRResult, visual: [CardReferenceIndex.Hit]) -> ScanMatch {
        let ocrText = ocr.allLines.joined(separator: " ")
        let ocrCard = SampleCardIndex.shared.search(ocrText)?.cardName   // OCR's catalog hit
        let candidates = visual.map { ScanMatch.Candidate(cardName: $0.cardName, imageName: $0.imageName) }

        // No reference images available → fall back to text.
        guard let best = visual.first else {
            return ocrOnlyMatch(ocr: ocr, ocrCard: ocrCard)
        }

        // Is the top visual hit clearly closer than the runner-up? (relative ratio test)
        let second = visual.count > 1 ? visual[1].distance : best.distance * 2
        let visualConfident = best.distance < second * 0.92

        let ocrAgrees = (ocrCard == best.cardName) || ocrMentions(best.cardName, in: ocrText)

        if ocrAgrees {
            // Visual + OCR agree → strongest possible match here.
            return ScanMatch(method: .fused, cardName: best.cardName, referenceImageName: best.imageName,
                             suggestedQuery: best.cardName, confidence: 0.92,
                             candidates: candidates, ocrLines: ocr.allLines)
        }
        if let ocrCard, !visualConfident {
            // Visual ambiguous but OCR clearly identified a catalog card → trust OCR.
            return ScanMatch(method: .fused, cardName: ocrCard,
                             referenceImageName: CardReferenceIndex.slug(ocrCard),
                             suggestedQuery: ocrCard, confidence: 0.72,
                             candidates: candidates, ocrLines: ocr.allLines)
        }
        if visualConfident {
            // Visual led; OCR didn't confirm → medium confidence, offer alternates.
            return ScanMatch(method: .visual, cardName: best.cardName, referenceImageName: best.imageName,
                             suggestedQuery: best.cardName, confidence: 0.6,
                             candidates: candidates, ocrLines: ocr.allLines)
        }
        // Everything uncertain: if OCR gave us usable words, lead with text + offer visual picks.
        if ocr.suggestedQuery.count >= 2 {
            return ScanMatch(method: .ocrOnly, cardName: ocrCard,
                             referenceImageName: ocrCard.map(CardReferenceIndex.slug),
                             suggestedQuery: ocrCard ?? ocr.suggestedQuery, confidence: 0.45,
                             candidates: candidates, ocrLines: ocr.allLines)
        }
        // Last resort: present the closest visual candidates to choose from.
        return ScanMatch(method: .visual, cardName: best.cardName, referenceImageName: best.imageName,
                         suggestedQuery: best.cardName, confidence: 0.4,
                         candidates: candidates, ocrLines: ocr.allLines)
    }

    private static func ocrOnlyMatch(ocr: OCRResult, ocrCard: String?) -> ScanMatch {
        guard ocr.suggestedQuery.count >= 2 || ocrCard != nil else {
            return ScanMatch(method: .none, cardName: nil, referenceImageName: nil,
                             suggestedQuery: ocr.suggestedQuery, confidence: 0,
                             candidates: [], ocrLines: ocr.allLines)
        }
        return ScanMatch(method: .ocrOnly, cardName: ocrCard,
                         referenceImageName: ocrCard.map(CardReferenceIndex.slug),
                         suggestedQuery: ocrCard ?? ocr.suggestedQuery,
                         confidence: ocrCard != nil ? 0.6 : 0.4,
                         candidates: [], ocrLines: ocr.allLines)
    }

    /// Does the OCR text mention this card's name (esp. surname)? Confirms a visual hit.
    private static func ocrMentions(_ cardName: String, in ocrText: String) -> Bool {
        let nq = SearchEngine.normalize(cardName)
        let ocrTokens = Set(SearchEngine.tokens(ocrText))
        if let surname = nq.surname, ocrTokens.contains(surname) { return true }
        return nq.nameTokens.contains { ocrTokens.contains($0) }
    }

    // MARK: - OCR (supporting signal)

    private struct OCRResult {
        var allLines: [String]
        var suggestedQuery: String
    }

    private static func runOCR(_ image: UIImage) async -> OCRResult {
        guard let cgImage = image.cgImage else { return OCRResult(allLines: [], suggestedQuery: "") }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [Line] = observations.compactMap { obs in
                    guard let c = obs.topCandidates(1).first else { return nil }
                    return Line(text: c.string, confidence: c.confidence, height: obs.boundingBox.height)
                }
                continuation.resume(returning: buildOCR(from: lines))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage,
                                                orientation: cgOrientation(image.imageOrientation), options: [:])
            DispatchQueue.global(qos: .userInitiated).async { try? handler.perform([request]) }
        }
    }

    private struct Line { let text: String; let confidence: Float; let height: CGFloat }

    private static func buildOCR(from rawLines: [Line]) -> OCRResult {
        let lines = rawLines.filter {
            $0.confidence > 0.3 && $0.text.trimmingCharacters(in: .whitespaces).count >= 2
        }
        guard !lines.isEmpty else { return OCRResult(allLines: [], suggestedQuery: "") }
        let allText = lines.map(\.text)
        let joined = allText.joined(separator: " ")
        var pieces = lines.sorted { $0.height > $1.height }.prefix(3).map(\.text)
        if let year = firstMatch(#"\b(19|20)\d{2}\b"#, in: joined) { pieces.append(year) }
        if let number = firstMatch(#"#\d{1,4}|\b\d{1,3}/\d{1,3}\b"#, in: joined) { pieces.append(number) }
        if let grade = firstMatch(#"(PSA|BGS|BVG|CGC|SGC)\s?\d{1,2}(\.5)?"#, in: joined.uppercased()) {
            pieces.append(grade)
        }
        return OCRResult(allLines: allText, suggestedQuery: dedupeWords(pieces.joined(separator: " "), maxWords: 12))
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, range: range), let r = Range(m.range, in: text) else { return nil }
        return String(text[r])
    }

    private static func dedupeWords(_ text: String, maxWords: Int) -> String {
        var seen = Set<String>()
        var out: [String] = []
        for word in text.split(separator: " ") where seen.insert(word.lowercased()).inserted {
            out.append(String(word))
            if out.count >= maxWords { break }
        }
        return out.joined(separator: " ")
    }

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
