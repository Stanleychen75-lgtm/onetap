import Foundation
import Vision
import UIKit

/// On-device visual index. Builds an Apple Vision **feature print** (a perceptual image
/// embedding) for each bundled reference card image, then finds the nearest references to
/// a photo's feature print. This is the real visual-matching half of the scan pipeline.
///
/// Reference images are currently generated per card (we have no licensed real-card
/// photos in sample mode), so matching a *real* card photo is approximate — the same
/// index becomes strong when populated from real images (eBay item photos) later.
final class CardReferenceIndex {
    static let shared = CardReferenceIndex()

    struct Reference {
        let cardName: String
        let imageName: String              // resource slug, e.g. "max-verstappen"
        let featurePrint: VNFeaturePrintObservation
    }

    struct Hit {
        let cardName: String
        let imageName: String
        let distance: Float                // smaller = more similar
    }

    private(set) var references: [Reference] = []
    var isAvailable: Bool { !references.isEmpty }

    private init() { build() }

    private func build() {
        for card in SampleCardIndex.shared.cards {
            let name = Self.slug(card.name)
            guard let image = Self.loadImage(name), let cg = image.cgImage,
                  let print = Self.featurePrint(cg) else { continue }
            references.append(Reference(cardName: card.name, imageName: name, featurePrint: print))
        }
        if references.isEmpty {
            print("⚠️ No reference card images found in bundle — visual matching falls back to OCR.")
        }
    }

    /// Nearest reference cards to a query image's feature print, ascending by distance.
    func nearest(to print: VNFeaturePrintObservation, max limit: Int = 3) -> [Hit] {
        references
            .compactMap { ref -> Hit? in
                var distance: Float = 0
                do { try ref.featurePrint.computeDistance(&distance, to: print) }
                catch { return nil }
                return Hit(cardName: ref.cardName, imageName: ref.imageName, distance: distance)
            }
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { $0 }
    }

    func image(named name: String) -> UIImage? { Self.loadImage(name) }

    // MARK: - Vision helpers

    static func featurePrint(for image: UIImage) -> VNFeaturePrintObservation? {
        guard let cg = image.cgImage else { return nil }
        return featurePrint(cg)
    }

    static func featurePrint(_ cgImage: CGImage) -> VNFeaturePrintObservation? {
        // NOTE: feature prints are ML-backed and require the Neural Engine — they work on
        // real devices (and macOS) but NOT on the iOS Simulator ("Failed to create espresso
        // context"). On the simulator this returns nil and the scanner falls back to OCR.
        let request = VNGenerateImageFeaturePrintRequest()
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        return request.results?.first as? VNFeaturePrintObservation
    }

    /// Slug used for reference image filenames (must match the generator).
    static func slug(_ name: String) -> String {
        let base = name.components(separatedBy: "—").first ?? name
        let folded = base.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return folded.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private static func loadImage(_ name: String) -> UIImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return UIImage(named: name)
    }
}
