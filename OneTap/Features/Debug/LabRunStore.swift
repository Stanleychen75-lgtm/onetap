import SwiftUI
import UIKit

#if DEBUG

/// DEBUG/lab-only instrumentation for the Phase 2 visual rerank lab. None of this is
/// reachable in production — the only entry point is the DEBUG-gated ladybug → Developer →
/// Visual re-rank lab. It records each evaluation run as a structured, persisted row and
/// exports the set as CSV for offline calibration / go-no-go decisions. No backend, no
/// analytics, no production behavior.

/// One candidate's measured data within a single lab run.
struct LabRunCandidate: Codable, Identifiable {
    let id: String
    let title: String
    let originalTextRank: Int   // 1-based rank in the plain text search
    let rerankPosition: Int     // 1-based position after visual rerank
    let distance: Double        // lower = more visually similar
    let isMarkedCorrect: Bool
}

/// A fully recorded Phase 2 evaluation run: the ranked candidates plus the human-supplied
/// ground truth. This is the structured row the lab persists and exports — never just
/// transient UI state.
struct LabRun: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let deviceModel: String
    let iosVersion: String
    let query: String
    let cardLabel: String
    let note: String
    let category: Int
    let runNumber: Int
    let verdict: String              // HIGH / LOW / NONE
    let topDistance: Double?         // distance of the visual #1 candidate
    let correctPresent: Bool
    let ambiguousVariant: Bool
    let markedCorrectID: String?     // candidate id marked correct, nil if none
    let markedTextRank: Int?         // 1-based text rank of the marked-correct listing
    let markedVisualRank: Int?       // 1-based visual rank of the marked-correct listing
    let candidateCount: Int
    let candidates: [LabRunCandidate]
}

@MainActor
final class LabRunStore: ObservableObject {
    @Published private(set) var runs: [LabRun] = []

    init() { load() }

    func add(_ run: LabRun) {
        runs.append(run)
        save()
    }

    func delete(atOffsets offsets: IndexSet) {
        runs.remove(atOffsets: offsets)
        save()
    }

    func deleteAll() {
        runs.removeAll()
        save()
    }

    // MARK: - Persistence (Documents/phase2_lab_runs.json)
    // Persisted to disk (not just UI state) so a batch survives backgrounding/relaunch.

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("phase2_lab_runs.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }   // absent → fresh start
        guard let decoded = try? JSONDecoder().decode([LabRun].self, from: data) else {
            // Present but undecodable (e.g. a future schema change): quarantine the file so the
            // next save() can't silently clobber a recorded batch, then start fresh.
            let backup = Self.fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: Self.fileURL, to: backup)
            return
        }
        runs = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(runs) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: - CSV export (one row per candidate; run-level fields denormalized/repeated)

    static let csvHeader = [
        "run_id", "timestamp", "device_model", "ios_version", "query", "card_label", "note",
        "category", "run_number", "verdict", "top_distance", "correct_present", "ambiguous_variant",
        "marked_correct_id", "marked_text_rank", "marked_visual_rank", "candidate_count",
        "candidate_rerank_position", "candidate_original_text_rank", "candidate_distance",
        "candidate_is_marked_correct", "candidate_title",
    ].joined(separator: ",")

    func csvString() -> String {
        let iso = ISO8601DateFormatter()
        var lines = [Self.csvHeader]
        for run in runs {
            let runCols: [String] = [
                run.id.uuidString,
                iso.string(from: run.timestamp),
                run.deviceModel,
                run.iosVersion,
                run.query,
                run.cardLabel,
                run.note,
                String(run.category),
                String(run.runNumber),
                run.verdict,
                run.topDistance.map { String(format: "%.4f", $0) } ?? "",
                run.correctPresent ? "Y" : "N",
                run.ambiguousVariant ? "Y" : "N",
                run.markedCorrectID ?? "",
                run.markedTextRank.map(String.init) ?? "",
                run.markedVisualRank.map(String.init) ?? "",
                String(run.candidateCount),
            ]
            // Guard against header/row drift: the header must equal runCols + 5 candidate cols.
            assert(Self.csvHeader.split(separator: ",").count == runCols.count + 5, "CSV header/column drift")
            if run.candidates.isEmpty {
                // Defensive: a run always has candidates in practice, but never drop a row.
                lines.append((runCols + ["", "", "", "", ""]).map(Self.esc).joined(separator: ","))
            } else {
                for c in run.candidates {
                    let candCols: [String] = [
                        String(c.rerankPosition),
                        String(c.originalTextRank),
                        String(format: "%.4f", c.distance),
                        c.isMarkedCorrect ? "Y" : "N",
                        c.title,
                    ]
                    lines.append((runCols + candCols).map(Self.esc).joined(separator: ","))
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Write the CSV to a temp file and return its URL for the share sheet.
    func writeCSVFile() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("OneTap-Phase2-Runs.csv")
        guard let data = csvString().data(using: .utf8) else { return nil }
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }

    /// RFC-4180 quoting: wrap in quotes and double any embedded quote when the field
    /// contains a comma, quote, or newline (titles and notes routinely do).
    private static func esc(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// Device identifiers, for comparing distances/verdicts across hardware (they're only
/// comparable within one device/OS/Vision-revision).
enum DeviceInfo {
    static var model: String {
        var sys = utsname()
        uname(&sys)
        let id = withUnsafeBytes(of: &sys.machine) { raw -> String in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return id.isEmpty ? UIDevice.current.model : id
    }
    static var osVersion: String { UIDevice.current.systemVersion }
}

/// UIActivityViewController wrapper so the lab can present the CSV share sheet
/// (Save to Files / AirDrop / Mail). Used only by the DEBUG lab.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#endif
