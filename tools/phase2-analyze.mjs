#!/usr/bin/env node
// Phase 2 visual-rerank evaluation analyzer.
//
// Reads a CSV exported by the DEBUG "Visual re-rank lab" and prints the go/no-go decision
// per the agreed framework, plus a relative-gap threshold sweep so you can see whether ANY
// confidence cutoff yields zero confident-wrong promotions with usable coverage.
//
// No device, no deps. Run on your Mac:
//   node tools/phase2-analyze.mjs path/to/OneTap-Phase2-Runs.csv
//
// What it computes (one "run" = one saved lab row, grouped by run_id):
//   - Promotion precision  : of HIGH-verdict runs, fraction where YOUR card is at visual #1
//                            (correct_present=Y, ambiguous=N). THE deciding metric.
//   - False-confident runs : HIGH runs that are NOT a clean correct-#1 (wrong card, ambiguous,
//                            or correct card not even present). Any one of these = ABANDON.
//   - HIGH coverage        : fraction of all runs that reached HIGH.
//   - Rank improvement     : mean(text_rank - visual_rank) for runs where your card was marked.
//   - Threshold sweep      : recomputes relativeGap = (median(rest) - best)/median from the
//                            stored candidate distances and, for each candidate cutoff, reports
//                            coverage / precision / wrong-count. Mirrors VisualReranker.confidence.

import { readFileSync } from 'node:fs';

// ---- args ----
const path = process.argv[2];
if (!path) {
  console.error('usage: node tools/phase2-analyze.mjs <exported-csv-path>');
  process.exit(2);
}

// ---- RFC-4180 CSV parser (handles quoted fields with commas, "" escapes, and newlines) ----
function parseCSV(text) {
  const rows = [];
  let row = [], field = '', inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; }
        else inQuotes = false;
      } else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field); rows.push(row); row = []; field = '';
    } else field += c;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  return rows.filter(r => r.length > 1 || (r.length === 1 && r[0].trim() !== ''));
}

const raw = readFileSync(path, 'utf8');
const table = parseCSV(raw);
if (table.length < 2) { console.error('No data rows in CSV.'); process.exit(1); }

const header = table[0].map(h => h.trim());
const required = [
  'run_id', 'card_label', 'category', 'run_number', 'verdict', 'correct_present',
  'ambiguous_variant', 'marked_visual_rank', 'marked_text_rank', 'candidate_count',
  'candidate_rerank_position', 'candidate_distance', 'candidate_is_marked_correct',
];
const missing = required.filter(c => !header.includes(c));
if (missing.length) { console.error('CSV missing columns: ' + missing.join(', ')); process.exit(1); }
const col = Object.fromEntries(header.map((h, i) => [h, i]));
const get = (r, name) => r[col[name]] ?? '';

// ---- group candidate rows into runs ----
const runs = new Map();
for (const r of table.slice(1)) {
  const id = get(r, 'run_id');
  if (!id) continue;
  if (!runs.has(id)) {
    runs.set(id, {
      id,
      label: get(r, 'card_label') || '(no label)',
      category: get(r, 'category'),
      runNumber: get(r, 'run_number'),
      verdict: (get(r, 'verdict') || '').toUpperCase(),
      correctPresent: get(r, 'correct_present').toUpperCase() === 'Y',
      ambiguous: get(r, 'ambiguous_variant').toUpperCase() === 'Y',
      markedVisualRank: parseInt(get(r, 'marked_visual_rank'), 10), // NaN if blank
      markedTextRank: parseInt(get(r, 'marked_text_rank'), 10),
      candidates: [],
    });
  }
  const rp = parseInt(get(r, 'candidate_rerank_position'), 10);
  const d = parseFloat(get(r, 'candidate_distance'));
  if (!Number.isNaN(rp) && !Number.isNaN(d)) {
    runs.get(id).candidates.push({
      rerankPos: rp,
      distance: d,
      isMarkedCorrect: get(r, 'candidate_is_marked_correct').toUpperCase() === 'Y',
    });
  }
}
const all = [...runs.values()];

// A run is a "clean correct-#1": verdict aside, YOUR card is the top visual result.
const isCleanCorrectTop = run =>
  run.correctPresent && !run.ambiguous &&
  run.candidates.some(c => c.isMarkedCorrect && c.rerankPos === 1);

// recompute relativeGap from candidate distances (mirrors VisualReranker.confidence)
function relativeGap(run) {
  const ds = run.candidates.map(c => c.distance).sort((a, b) => a - b);
  if (ds.length < 3) return null;            // rest needs >= 2 → otherwise LOW, never HIGH
  const best = ds[0];
  const rest = ds.slice(1);
  const median = rest[Math.floor(rest.length / 2)];
  if (median <= 0) return null;
  return (median - best) / median;
}

// ---- core metrics (using the verdicts users actually saw) ----
const total = all.length;
const byVerdict = { HIGH: 0, LOW: 0, NONE: 0, OTHER: 0 };
for (const r of all) byVerdict[r.verdict in byVerdict ? r.verdict : 'OTHER']++;

const highRuns = all.filter(r => r.verdict === 'HIGH');
const falseConfident = highRuns.filter(r => !isCleanCorrectTop(r));
const cleanHigh = highRuns.length - falseConfident.length;
const precision = highRuns.length ? cleanHigh / highRuns.length : null;
const coverage = total ? highRuns.length / total : 0;

const improvements = all
  .filter(r => Number.isFinite(r.markedVisualRank) && Number.isFinite(r.markedTextRank))
  .map(r => r.markedTextRank - r.markedVisualRank);
const meanImprovement = improvements.length
  ? improvements.reduce((a, b) => a + b, 0) / improvements.length : null;

const why = r => {
  if (!r.correctPresent) return 'correct card NOT present';
  if (r.ambiguous) return 'ambiguous variant';
  const mc = r.candidates.find(c => c.isMarkedCorrect);
  return mc ? `your card at visual #${mc.rerankPos}, not #1` : 'no candidate marked correct';
};

// ---- report ----
const pct = x => x == null ? 'n/a' : (x * 100).toFixed(0) + '%';
console.log('='.repeat(64));
console.log('PHASE 2 VISUAL-RERANK EVALUATION  ·  ' + path);
console.log('='.repeat(64));
console.log(`Runs: ${total}   verdicts: HIGH ${byVerdict.HIGH} · LOW ${byVerdict.LOW} · NONE ${byVerdict.NONE}` +
  (byVerdict.OTHER ? ` · ?? ${byVerdict.OTHER}` : ''));
console.log('');
console.log('DECIDING METRICS');
console.log(`  Promotion precision (correct@#1 | HIGH) : ${pct(precision)}  [${cleanHigh}/${highRuns.length}]`);
console.log(`  False-confident HIGH runs               : ${falseConfident.length}   <-- any > 0 = ABANDON`);
console.log(`  HIGH coverage                           : ${pct(coverage)}  [${highRuns.length}/${total}]`);
console.log(`  Mean rank improvement (text - visual)   : ${meanImprovement == null ? 'n/a' : meanImprovement.toFixed(2)}  (diagnostic)`);

if (falseConfident.length) {
  console.log('');
  console.log('  FALSE-CONFIDENT RUNS (these kill rollout):');
  for (const r of falseConfident) console.log(`    - "${r.label}" (cat ${r.category}, run ${r.runNumber}): ${why(r)}`);
}

// ---- decision ----
let decision, reason;
if (falseConfident.length > 0) {
  decision = 'ABANDON (redesign)';
  reason = 'a HIGH verdict promoted a non-correct result — the safety gate can be confidently wrong.';
} else if (highRuns.length === 0) {
  decision = 'KEEP-IN-LAB';
  reason = 'no run reached HIGH — precision is unmeasured. Gather more / recalibrate the gap.';
} else if (coverage < 0.25) {
  decision = 'KEEP-IN-LAB';
  reason = `zero wrong HIGHs, but HIGH coverage ${pct(coverage)} < 25% — too rare to surface. Recalibrate / gather more.`;
} else {
  decision = 'LAB-EXIT-CANDIDATE';
  reason = `zero wrong HIGHs and coverage ${pct(coverage)} >= 25% — evidence justifies a scoped rollout discussion (never auto-ship).`;
}
console.log('');
console.log('DECISION: ' + decision);
console.log('  ' + reason);

// ---- threshold sweep (calibration) ----
console.log('');
console.log('RELATIVE-GAP THRESHOLD SWEEP (recomputed from candidate distances)');
console.log('  thr   would-HIGH   coverage   precision   wrong');
const computable = all.filter(r => relativeGap(r) != null);
let anyCleanThreshold = null;
for (let t = 0.10; t <= 0.5001; t += 0.05) {
  const wouldHigh = computable.filter(r => relativeGap(r) >= t);
  const correct = wouldHigh.filter(isCleanCorrectTop).length;
  const wrong = wouldHigh.length - correct;
  const cov = total ? wouldHigh.length / total : 0;
  const prec = wouldHigh.length ? correct / wouldHigh.length : null;
  const flag = (wrong === 0 && wouldHigh.length > 0) ? '  <- 0 wrong' : '';
  if (wrong === 0 && cov >= 0.25 && anyCleanThreshold == null) anyCleanThreshold = t;
  console.log(
    `  ${t.toFixed(2)}` +
    `   ${String(wouldHigh.length).padStart(9)}` +
    `   ${pct(cov).padStart(8)}` +
    `   ${(prec == null ? 'n/a' : pct(prec)).padStart(9)}` +
    `   ${String(wrong).padStart(5)}${flag}`
  );
}
console.log('');
if (!computable.length) {
  console.log('  (No runs had >=3 candidate distances — sweep needs on-device runs with real candidates.)');
} else if (anyCleanThreshold != null) {
  console.log(`  Calibration hint: gap >= ${anyCleanThreshold.toFixed(2)} gives 0 wrong promotions at >=25% coverage.`);
} else {
  console.log('  Calibration hint: NO swept threshold reaches 0 wrong AND >=25% coverage — strong abandon signal.');
}
console.log('='.repeat(64));
