import Vision
import UIKit
import CoreImage

// Compiled when scan is enabled (SCAN_ENABLED) OR in DEBUG, because the DEBUG-only Phase 2
// visual-rerank lab also uses this OCR helper. Out of Release entirely.
#if SCAN_ENABLED || DEBUG

/// On-device card TEXT reader (Apple Vision).
///
/// HONESTY: this is NOT card identification or image matching. It detects/crops the card
/// and OCRs the printed text to hand the user an *editable* starting search query. Visual
/// matching against a reference catalog is a separate, later phase. Everything here runs
/// on-device; nothing is sent anywhere.
struct ScanResult {
    let croppedImage: UIImage
    /// Editable text we read from the card — the starting point for a normal search.
    let suggestedQuery: String
    /// True when OCR was sparse/low-confidence → tell the user to check before searching.
    let isLowConfidence: Bool
}

enum CardTextScanner {
    /// Detect + crop the card, OCR it, and build an editable suggested search query.
    static func scan(_ image: UIImage) async -> ScanResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let upright = normalizedUp(image)
                let cropped = croppedCard(from: upright) ?? upright   // graceful fallback to full image
                let (lines, confidence) = recognizeText(in: cropped)
                let query = buildQuery(from: lines)
                let low = lines.isEmpty || confidence < 0.45 || query.count < 3
                continuation.resume(returning: ScanResult(
                    croppedImage: cropped,
                    suggestedQuery: query,
                    isLowConfidence: low
                ))
            }
        }
    }

    // MARK: - Card detection + perspective crop

    private static func croppedCard(from image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.45   // portrait cards ≈ 0.71; slack for angled shots
        request.maximumAspectRatio = 0.95
        request.minimumSize = 0.2
        request.minimumConfidence = 0.6
        request.maximumObservations = 1
        request.quadratureTolerance = 25

        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let rect = (request.results as? [VNRectangleObservation])?.first else { return nil }

        // Perspective-correct the detected quad → a clean, deskewed crop (better OCR).
        let ci = CIImage(cgImage: cg)
        let w = ci.extent.width, h = ci.extent.height
        func vec(_ p: CGPoint) -> CIVector { CIVector(x: p.x * w, y: p.y * h) }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(vec(rect.topLeft), forKey: "inputTopLeft")
        filter.setValue(vec(rect.topRight), forKey: "inputTopRight")
        filter.setValue(vec(rect.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(vec(rect.bottomRight), forKey: "inputBottomRight")
        guard let output = filter.outputImage,
              let result = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: result)
    }

    // MARK: - OCR

    private static func recognizeText(in image: UIImage) -> (lines: [String], confidence: Float) {
        guard let cg = image.cgImage else { return ([], 0) }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let observations = request.results as? [VNRecognizedTextObservation] else { return ([], 0) }

        var scored: [(text: String, confidence: Float, area: CGFloat)] = []
        for obs in observations {
            guard let top = obs.topCandidates(1).first else { continue }
            let text = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 2 else { continue }
            scored.append((text, top.confidence, obs.boundingBox.width * obs.boundingBox.height))
        }
        scored.sort { $0.area > $1.area }   // most prominent text first (player name / set / brand)
        let avg = scored.isEmpty ? 0 : scored.map(\.confidence).reduce(0, +) / Float(scored.count)
        return (scored.map(\.text), avg)
    }

    // MARK: - Query building

    private static func buildQuery(from lines: [String]) -> String {
        // Favor recall (the user edits this): keep the most prominent lines, drop obvious
        // filler, collapse whitespace, cap length so the search box stays sensible.
        let noise: Set<String> = ["the", "and", "card", "trading", "rookie"]
        let picked = lines.prefix(6).filter { !noise.contains($0.lowercased()) }
        var q = picked.joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if q.count > 80 { q = String(q.prefix(80)).trimmingCharacters(in: .whitespaces) }
        return q
    }

    // MARK: - Helpers

    /// Redraw the image as `.up` so Vision + Core Image coordinate spaces line up (camera
    /// photos are often `.right`).
    private static func normalizedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

#endif
