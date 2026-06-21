import SwiftUI
import PhotosUI

#if DEBUG

/// DEBUG-only Phase 2 measurement harness. Pick a card photo → runs the real Phase 1
/// crop + OCR, the real card-fenced search, then ranks the candidate listing images by
/// on-device visual similarity. Surfaces each candidate's distance AND its original
/// text-search rank, plus the confidence verdict — so we can measure on a REAL DEVICE
/// whether visual re-ranking actually surfaces the right card, without touching the
/// production results screen. (No-op on the Simulator: feature prints need the Neural Engine.)
///
/// Phase 2 instrumentation: each run can be marked with ground truth (which candidate is the
/// real card, "not present", or "ambiguous") and saved as a structured, persisted row, then
/// exported as CSV for offline calibration. All DEBUG/lab-only — see LabRunStore.
struct VisualRerankLabView: View {
    @State private var item: PhotosPickerItem?
    @State private var cropped: UIImage?
    @State private var query = ""
    @State private var rows: [LabRow] = []
    @State private var confidence: VisualConfidence = .none
    @State private var status = "Pick a card photo to measure visual re-ranking."
    @State private var running = false

    // Ground-truth recording (mutually exclusive states).
    @StateObject private var store = LabRunStore()
    @State private var groundTruth: GroundTruth = .none
    @State private var cardLabel = ""
    @State private var note = ""
    @State private var category = 1
    @State private var runNumber = 1
    @State private var savedNote: String?
    @State private var share: ShareItem?
    @State private var showClearConfirm = false

    struct LabRow: Identifiable {
        let id: String
        let url: URL
        let distance: Float
        let title: String
        let originalRank: Int   // its position in the plain text search (0-based)
    }

    private let categories: [(Int, String)] = [
        (1, "raw base"), (2, "slab"), (3, "foil/holo"), (4, "parallel/variant"),
        (5, "angled"), (6, "poor light"), (7, "multi-card lot"), (8, "relic/patch/auto"),
        (9, "low-pop"),
    ]

    var body: some View {
        List {
            Section("Source") {
                PhotosPicker(selection: $item, matching: .images) {
                    Label("Pick a card photo", systemImage: "photo")
                }
                if let cropped {
                    Image(uiImage: cropped).resizable().scaledToFit().frame(maxHeight: 150)
                }
                if !query.isEmpty {
                    Text("OCR query: \(query)").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                HStack {
                    Text(status).font(.system(size: 12)).foregroundStyle(.secondary)
                    if running { Spacer(); ProgressView() }
                }
            }

            if !rows.isEmpty {
                Section("Visual confidence") {
                    Text(confidenceText).font(.system(size: 13)).foregroundStyle(confidenceColor)
                }

                Section("Tap the row that matches your card") {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { idx, r in
                        HStack(spacing: 10) {
                            Image(systemName: isMarked(r.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isMarked(r.id) ? .green : .secondary)
                            AsyncImage(url: r.url) { $0.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.12) }
                                .frame(width: 42, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.title).font(.system(size: 12)).lineLimit(2)
                                Text(String(format: "rerank #%d · distance %.3f · text rank #%d", idx + 1, r.distance, r.originalRank + 1))
                                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .opacity(groundTruth == .notPresent ? 0.4 : 1)
                        .onTapGesture { toggleMark(r.id) }
                    }
                }

                Section("Record this run") {
                    TextField("Card label (e.g. 2023 Prizm Wembanyama base)", text: $cardLabel)
                        .autocorrectionDisabled()
                        .font(.system(size: 13))
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.0) { Text("\($0.0) — \($0.1)").tag($0.0) }
                    }
                    Stepper("Run # \(runNumber)", value: $runNumber, in: 1...20)
                    TextField("Note (glare, lot won #1, base/parallel confusion…)", text: $note)
                        .font(.system(size: 13))
                    Toggle("Correct card NOT present", isOn: notPresentBinding)
                    Toggle("Ambiguous — can't confirm variant", isOn: ambiguousBinding)
                    Button { saveRow() } label: {
                        Label("Save test row", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!canSave)
                    if !canSave {
                        Text("To save: enter a card label and either tap a row, “not present”, or “ambiguous”.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if let savedNote {
                        Text(savedNote).font(.system(size: 12)).foregroundStyle(.green)
                    }
                }
            }

            Section("Saved runs (\(store.runs.count))") {
                Button {
                    if let url = store.writeCSVFile() { share = ShareItem(url: url) }
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(store.runs.isEmpty)

                Button(role: .destructive) { showClearConfirm = true } label: {
                    Label("Clear all test data", systemImage: "trash")
                }
                .disabled(store.runs.isEmpty)

                ForEach(store.runs) { run in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(run.cardLabel.isEmpty ? "(no label)" : run.cardLabel)
                            .font(.system(size: 13, weight: .medium))
                        Text(summaryLine(run))
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                .onDelete { store.delete(atOffsets: $0) }
            }
        }
        .navigationTitle("Visual re-rank (prototype)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task { await run(newItem) }
        }
        .sheet(item: $share) { item in ActivityView(items: [item.url]) }
        .confirmationDialog("Delete all recorded runs?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) { store.deleteAll() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Ground truth

    private func isMarked(_ id: String) -> Bool { groundTruth == .correct(id) }

    private func toggleMark(_ id: String) {
        guard groundTruth != .notPresent else { return }   // no row applies when "not present"
        groundTruth = isMarked(id) ? .none : .correct(id)
    }

    private var notPresentBinding: Binding<Bool> {
        Binding(get: { groundTruth == .notPresent },
                set: { groundTruth = $0 ? .notPresent : .none })
    }
    private var ambiguousBinding: Binding<Bool> {
        Binding(get: { groundTruth == .ambiguous },
                set: { groundTruth = $0 ? .ambiguous : .none })
    }

    private var canSave: Bool {
        !cardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && groundTruth != .none
    }

    private var verdictString: String {
        switch confidence {
        case .high: return "HIGH"
        case .low:  return "LOW"
        case .none: return "NONE"
        }
    }

    private func saveRow() {
        guard canSave else { return }
        let markedIndex = rows.firstIndex { isMarked($0.id) }
        let markedRow = markedIndex.map { rows[$0] }
        let candidates = rows.enumerated().map { idx, r in
            LabRunCandidate(id: r.id, title: r.title,
                            originalTextRank: r.originalRank + 1,
                            rerankPosition: idx + 1,
                            distance: Double(r.distance),
                            isMarkedCorrect: isMarked(r.id))
        }
        let run = LabRun(
            id: UUID(),
            timestamp: Date(),
            deviceModel: DeviceInfo.model,
            iosVersion: DeviceInfo.osVersion,
            query: query,
            cardLabel: cardLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            runNumber: runNumber,
            verdict: verdictString,
            topDistance: rows.first.map { Double($0.distance) },
            correctPresent: groundTruth != .notPresent,
            ambiguousVariant: groundTruth == .ambiguous,
            markedCorrectID: markedRow?.id,
            markedTextRank: markedRow.map { $0.originalRank + 1 },
            markedVisualRank: markedIndex.map { $0 + 1 },
            candidateCount: rows.count,
            candidates: candidates
        )
        store.add(run)
        savedNote = "Saved “\(run.cardLabel)” (\(store.runs.count) total). Pick the next photo or bump Run #."
        groundTruth = .none
        note = ""
    }

    private func summaryLine(_ run: LabRun) -> String {
        let truth: String
        if !run.correctPresent { truth = "not present" }
        else if run.ambiguousVariant { truth = "ambiguous" }
        else { truth = "visual #\(run.markedVisualRank ?? 0) (text #\(run.markedTextRank ?? 0))" }
        return "cat \(run.category) · run \(run.runNumber) · \(run.verdict) · \(truth)"
    }

    // MARK: - Display helpers

    private var confidenceText: String {
        switch confidence {
        case .high: return "HIGH — one listing clearly looks closest; safe to promote it."
        case .low:  return "LOW — closest-looking shown, but no clear winner (don't claim certainty)."
        case .none: return "NONE — couldn't compute. On a real device? Any candidate images?"
        }
    }
    private var confidenceColor: Color {
        switch confidence { case .high: return .green; case .low: return .orange; case .none: return .red }
    }

    private func run(_ pickerItem: PhotosPickerItem) async {
        running = true; rows = []; confidence = .none; query = ""; cropped = nil
        // Clear the card identity too: a new photo is a new card, and a stale label must never
        // ride onto a different card's run (that would silently mislabel the calibration data).
        // category/runNumber are kept on purpose so a batch of the same card is fast to log.
        groundTruth = .none; savedNote = nil; cardLabel = ""; note = ""
        status = "Loading image…"
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            status = "Couldn't load image."; running = false; return
        }

        status = "Reading card (crop + OCR)…"
        let scan = await CardTextScanner.scan(image)
        cropped = scan.croppedImage
        query = scan.suggestedQuery

        status = "Searching eBay…"
        let service = AppEnvironment.makeCardDataService()
        var candidates: [(id: String, url: URL)] = []
        var titles: [String: String] = [:]
        do {
            let result = try await service.search(query: query.isEmpty ? "card" : query)
            for l in result.active {
                guard let url = l.imageURL else { continue }
                candidates.append((l.id, url))
                titles[l.id] = l.title
            }
        } catch {
            status = "Search failed: \(error.localizedDescription)"; running = false; return
        }
        guard !candidates.isEmpty else { status = "No candidate images to rank."; running = false; return }

        let originalRank = Dictionary(candidates.enumerated().map { ($0.element.id, $0.offset) },
                                      uniquingKeysWith: { a, _ in a })

        status = "Ranking by visual similarity (on-device)…"
        let ranked = await VisualReranker.rank(source: scan.croppedImage, candidates: candidates)
        guard !ranked.isEmpty else {
            status = "Feature prints returned nothing — likely the Simulator. Run on a real device."
            running = false; return
        }
        // ranked ids are always a subset of candidate ids, so the originalRank lookup always
        // hits; the -1 fallback is unreachable and exists only to satisfy the optional.
        rows = ranked.map { LabRow(id: $0.id, url: $0.url, distance: $0.distance,
                                   title: titles[$0.id] ?? "", originalRank: originalRank[$0.id] ?? -1) }
        confidence = VisualReranker.confidence(ranked)
        status = "Ranked \(rows.count) candidates against your photo. Mark the correct row, then Save."
        running = false
    }
}

/// Mutually exclusive ground-truth states for one run.
private enum GroundTruth: Equatable {
    case none
    case ambiguous
    case notPresent
    case correct(String)   // candidate id
}

/// Identifiable wrapper so the CSV file URL can drive an item-based share sheet.
private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

#endif
