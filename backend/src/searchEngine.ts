// Mirror of the iOS app's SearchEngine.swift — the SAME search brain on the server, so
// sample and live behave consistently. Pure functions: normalization, fallback variant
// generation, and relevance scoring.

export interface NormalizedQuery {
  raw: string;
  cleaned: string;
  tokens: string[];
  nameTokens: string[];
  setTokens: string[];
  parallels: string[];
  surname: string | null;
  hasAuto: boolean;
  hasRookie: boolean;
  grade: { company: string; value: string } | null;
  cardNumber: string | null;
  year: string | null;
}

const AUTO = new Set(["auto", "autos", "autograph", "autographed", "signed", "signature"]);
const ROOKIE = new Set(["rookie", "rookies", "rc"]);
const PARALLEL = new Set(["refractor", "refractors", "silver", "gold", "holo", "holographic",
  "reverse", "secret", "rare", "sp", "ssp", "insert", "numbered", "parallel", "mojo", "wave",
  "pulsar", "disco", "prizm"]);
const SET_BRAND = new Set(["topps", "panini", "chrome", "donruss", "optic", "select", "mosaic",
  "bowman", "fleer", "upper", "deck", "score", "update", "champions", "path", "world", "cup",
  "formula", "evolving", "skies"]);
const GRADE_CO = new Set(["psa", "bgs", "bvg", "cgc", "sgc", "csg", "hga"]);
const STOP = new Set(["the", "a", "an", "of", "and", "card", "cards"]);
const SPORT = new Set(["nba", "nfl", "mlb", "ufc", "f1", "tcg", "pokemon", "soccer", "baseball",
  "basketball", "football", "hockey", "wnba", "golf"]);

function fold(s: string): string {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

export function tokenize(s: string): string[] {
  return fold(s).split(/[^a-z0-9]+/).filter((t) => t.length >= 2);
}

function firstMatch(pattern: RegExp, text: string): string | null {
  const m = text.match(pattern);
  return m ? m[0] : null;
}

export function normalize(raw: string): NormalizedQuery {
  const lower = fold(raw);
  const cleaned = lower.split(/[^a-z0-9]+/).filter(Boolean).join(" ");
  const toks = cleaned.split(" ").filter((t) => t.length >= 2);

  const names: string[] = [], sets: string[] = [], paras: string[] = [];
  let hasAuto = false, hasRookie = false;
  for (const t of toks) {
    if (AUTO.has(t)) hasAuto = true;
    else if (ROOKIE.has(t)) hasRookie = true;
    else if (PARALLEL.has(t)) paras.push(t);
    else if (GRADE_CO.has(t)) { /* via grade regex */ }
    else if (SET_BRAND.has(t)) sets.push(t);
    else if (STOP.has(t)) { /* ignore */ }
    else if (/^\d+$/.test(t)) { /* number, via regex */ }
    else names.push(t);
  }

  const surname = [...names].reverse().find((n) => !SPORT.has(n)) ?? null;
  const gradeRaw = firstMatch(/(psa|bgs|bvg|cgc|sgc|csg|hga)\s?(10|9\.5|9|8\.5|8|7|6|5|4|3|2|1)/, lower);
  let grade: NormalizedQuery["grade"] = null;
  if (gradeRaw) {
    grade = {
      company: firstMatch(/psa|bgs|bvg|cgc|sgc|csg|hga/, gradeRaw) ?? "",
      value: firstMatch(/10|9\.5|9|8\.5|8|7|6|5|4|3|2|1/, gradeRaw) ?? "",
    };
  }

  return {
    raw, cleaned, tokens: toks, nameTokens: names, setTokens: sets, parallels: paras,
    surname, hasAuto, hasRookie, grade,
    cardNumber: firstMatch(/#\s?\d{1,4}|\b\d{1,3}\s?\/\s?\d{1,3}\b/, lower)?.replace(/\s/g, "") ?? null,
    year: firstMatch(/\b(19|20)\d{2}\b/, lower),
  };
}

export function variants(nq: NormalizedQuery): string[] {
  const out: string[] = [];
  const add = (s: string) => {
    const t = s.trim();
    if (t.length >= 2 && !out.includes(t)) out.push(t);
  };
  add(nq.cleaned);
  const important = [...nq.nameTokens];
  if (nq.hasAuto) important.push("auto");
  if (nq.hasRookie) important.push("rookie");
  if (nq.cardNumber) important.push(nq.cardNumber);
  add(important.join(" "));
  add(nq.nameTokens.join(" "));
  if (nq.surname) {
    if (nq.hasAuto) add(`${nq.surname} auto`);
    add(nq.surname);
  }
  return out;
}

function levenshtein(a: string, b: string): number {
  if (Math.abs(a.length - b.length) > 2) return 99;
  const prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    let prevDiag = prev[0];
    prev[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const tmp = prev[j];
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      prev[j] = Math.min(prev[j] + 1, prev[j - 1] + 1, prevDiag + cost);
      prevDiag = tmp;
    }
  }
  return prev[b.length];
}

export function score(title: string, nq: NormalizedQuery): number {
  const tt = new Set(tokenize(title));
  if (tt.size === 0) return 0;
  let s = 0;
  for (const name of nq.nameTokens) {
    const isSurname = name === nq.surname;
    if (tt.has(name)) s += isSurname ? 3.0 : 2.0;
    else if (name.length >= 4 && [...tt].some((w) => w.startsWith(name))) s += isSurname ? 2.2 : 1.3;
    else if (name.length >= 5 && [...tt].some((w) => levenshtein(w, name) <= 1)) s += isSurname ? 2.2 : 1.2;
  }
  for (const set of nq.setTokens) if (tt.has(set)) s += 0.8;
  for (const p of nq.parallels) if (tt.has(p)) s += 0.6;
  if (nq.hasAuto && [...tt].some((w) => AUTO.has(w))) s += 0.9;
  if (nq.hasRookie && [...tt].some((w) => ROOKIE.has(w))) s += 0.7;
  if (nq.grade && tt.has(nq.grade.company) && tt.has(nq.grade.value)) s += 1.0;
  if (nq.cardNumber) {
    const core = nq.cardNumber.replace("#", "");
    if (fold(title).includes(core)) s += 1.0;
  }
  if (nq.year && tt.has(nq.year)) s += 0.4;
  if (nq.nameTokens.length > 0 && fold(title).includes(nq.cleaned)) s += 3.0;
  return s;
}
