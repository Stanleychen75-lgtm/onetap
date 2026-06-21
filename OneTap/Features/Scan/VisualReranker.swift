import Vision
import UIKit

#if DEBUG

/// Phase 2 (PROTOTYPE): on-device visual re-ranking using Apple Vision feature prints.
///
/// HONESTY: this ranks how visually SIMILAR each candidate listing image is to the user's
/// photo. It is NOT exact card identification and NOT a catalog match — it surfaces the
/// "closest-looking" listings among the existing search results. Feature prints need the
/// Neural Engine, so this only produces results on a REAL DEVICE (it no-ops on the Simulator,
/// returning [] so callers fall back to the original order).
struct RankedCandidate: Identifiable {
    let id: String
    let url: URL
    /// Lower = more visually similar. Only comparable WITHIN one batch on one device/revision.
    let distance: Float
}

enum VisualConfidence {
    case high   // one candidate clearly stands out visually → safe to promote
    case low    // closest-looking shown, but no clear winner → don't claim certainty
    case none   // couldn't compute (Simulator, or no candidate images)
}

enum VisualReranker {
    /// Locked revision → stable behavior across iOS updates (the default revision can change
    /// between OS versions, silently shifting distances). Bump only after re-measuring.
    private static let revision = VNGenerateImageFeaturePrintRequestRevision1

    /// Rank candidates by visual similarity to `source`, closest first. Returns [] if the
    /// source can't be embedded (e.g. Simulator) so callers keep the original order.
    static func rank(source: UIImage, candidates: [(id: String, url: URL)]) async -> [RankedCandidate] {
        guard let sourcePrint = await featurePrint(for: source) else { return [] }
        let results = await withTaskGroup(of: RankedCandidate?.self) { group -> [RankedCandidate] in
            for c in candidates {
                group.addTask {
                    guard let image = await downloadImage(c.url),
                          let print = await featurePrint(for: image) else { return nil }
                    var distance = Float.greatestFiniteMagnitude
                    do { try print.computeDistance(&distance, to: sourcePrint) } catch { return nil }
                    return RankedCandidate(id: c.id, url: c.url, distance: distance)
                }
            }
            var acc: [RankedCandidate] = []
            for await r in group { if let r { acc.append(r) } }
            return acc
        }
        return results.sorted { $0.distance < $1.distance }
    }

    /// Confidence from the SHAPE of the distance distribution (relative, NOT an absolute
    /// hardcoded threshold — those drift across iOS versions). A candidate is "confident"
    /// only if it sits clearly below the rest of the batch. Starting heuristic — the whole
    /// point of the prototype is to calibrate the 0.25 gap on real data.
    static func confidence(_ ranked: [RankedCandidate]) -> VisualConfidence {
        guard let best = ranked.first?.distance else { return .none }
        let rest = ranked.dropFirst().map(\.distance).sorted()
        guard rest.count >= 2 else { return .low }
        let median = rest[rest.count / 2]
        guard median > 0 else { return .low }
        let relativeGap = (median - best) / median          // 0…1: how far below the pack
        return relativeGap >= 0.25 ? .high : .low
    }

    // MARK: - Vision (on-device)

    private static func featurePrint(for image: UIImage) async -> VNFeaturePrintObservation? {
        guard let cg = image.cgImage else { return nil }
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNGenerateImageFeaturePrintRequest()
                request.revision = revision
                let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
                try? handler.perform([request])
                cont.resume(returning: request.results?.first as? VNFeaturePrintObservation)
            }
        }
    }

    private static func downloadImage(_ url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}

#endif
