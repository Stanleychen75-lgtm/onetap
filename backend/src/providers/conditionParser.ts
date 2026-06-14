import type { CardCondition } from "../types";

// Detects graded slabs from a listing title, e.g. "... PSA 10", "BGS 9.5", "CGC 9".
const GRADE_RE =
  /\b(PSA|BGS|BVG|SGC|CGC|CSG|HGA|TAG)\s*\.?\s*(10|9\.5|9|8\.5|8|7\.5|7|6\.5|6|5\.5|5|4|3|2|1)\b/i;

/**
 * Turn an eBay item into our `CardCondition`. eBay item summaries don't expose card
 * grades directly, so we parse the title (which is how collectors actually search).
 * Falls back to eBay's coarse condition string ("New" / "Used") for raw cards.
 */
export function parseCondition(title: string, ebayCondition?: string): CardCondition | undefined {
  const match = title.match(GRADE_RE);
  if (match) {
    return { gradingCompany: match[1].toUpperCase(), grade: Number(match[2]) };
  }
  if (ebayCondition) return { rawDescription: ebayCondition };
  return undefined;
}
