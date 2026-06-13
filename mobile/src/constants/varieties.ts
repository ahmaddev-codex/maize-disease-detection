// Nigerian maize varieties known to the OCR system
// Matches Flutter's OcrService KNOWN_VARIETIES list
export const KNOWN_VARIETIES = [
  'SAMMAZ 15',
  'SAMMAZ 17',
  'SAMMAZ 29',
  'SAMMAZ 34',
  'SAMMAZ 50',
  'OBA SUPER 2',
  'EVDT 99',
  'POOL 16 DT',
  'TZEE-W',
  'ABA WHITE',
  'ACROSS 97',
  'SUWAN 1',
  'EARLY THRIVING',
] as const;

export type KnownVariety = (typeof KNOWN_VARIETIES)[number];

/**
 * Simple fuzzy match: finds best variety match above threshold.
 * Equivalent to Flutter's fuzzywuzzy partial_ratio approach.
 */
export function fuzzyMatchVariety(
  text: string,
  threshold = 60,
): string | null {
  const upper = text.toUpperCase();
  let bestMatch: string | null = null;
  let bestScore = 0;

  for (const variety of KNOWN_VARIETIES) {
    const score = partialRatio(upper, variety);
    if (score > bestScore && score >= threshold) {
      bestScore = score;
      bestMatch = variety;
    }
  }
  return bestMatch;
}

function partialRatio(a: string, b: string): number {
  if (a.includes(b)) return 100;
  if (b.includes(a)) return 100;
  // Sliding window similarity
  const [shorter, longer] = a.length <= b.length ? [a, b] : [b, a];
  let best = 0;
  for (let i = 0; i <= longer.length - shorter.length; i++) {
    const window = longer.slice(i, i + shorter.length);
    const score = similarity(shorter, window);
    if (score > best) best = score;
  }
  return Math.round(best * 100);
}

function similarity(a: string, b: string): number {
  const longer = a.length > b.length ? a : b;
  const shorter = a.length > b.length ? b : a;
  if (longer.length === 0) return 1.0;
  return (longer.length - editDistance(longer, shorter)) / longer.length;
}

function editDistance(a: string, b: string): number {
  const matrix: number[][] = [];
  for (let i = 0; i <= b.length; i++) {
    matrix[i] = [i];
  }
  for (let j = 0; j <= a.length; j++) {
    matrix[0][j] = j;
  }
  for (let i = 1; i <= b.length; i++) {
    for (let j = 1; j <= a.length; j++) {
      matrix[i][j] =
        b[i - 1] === a[j - 1]
          ? matrix[i - 1][j - 1]
          : Math.min(
              matrix[i - 1][j - 1] + 1,
              matrix[i][j - 1] + 1,
              matrix[i - 1][j] + 1,
            );
    }
  }
  return matrix[b.length][a.length];
}
