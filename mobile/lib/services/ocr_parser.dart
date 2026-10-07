import '../constants/diseases.dart';

// Pure parsing of seed-label OCR text into variety, batch and planting date.
// Test cases are shared with src/phase2_ocr/extractor.py via
// tests/fixtures/ocr_cases.json (ADR-006) — change both together.

const int kVarietyTokenMatchScore = 60; // FR-14: minimum fuzzy score per word

const Map<String, int> _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

// ── Planting date ─────────────────────────────────────────────────────────────

/// Returns the first real calendar date in [text] as YYYY-MM-DD, or null.
/// Numeric dates are read day-first (DD/MM/YYYY), as printed on Nigerian labels.
String? parsePlantingDate(String text) {
  for (final m in RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b').allMatches(text)) {
    final iso = _isoDate(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    if (iso != null) return iso;
  }
  for (final m in RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b').allMatches(text)) {
    final iso = _isoDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (iso != null) return iso;
  }
  final textual = RegExp(
    r'\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{4})\b',
    caseSensitive: false,
  );
  for (final m in textual.allMatches(text)) {
    final month = _months[m[2]!.toLowerCase()]!;
    final iso = _isoDate(int.parse(m[3]!), month, int.parse(m[1]!));
    if (iso != null) return iso;
  }
  return null;
}

/// Validates the planting-date field on the OCR review form. Empty is allowed.
bool isValidPlantingDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  return m != null && _isoDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)) != null;
}

String? _isoDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1) return null;
  final date = DateTime(year, month, day);
  if (date.month != month || date.day != day) return null; // e.g. 30 Feb rolls over
  return '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

// ── Batch / lot number ────────────────────────────────────────────────────────

// A code carrying its own prefix. The separator may be read as a period, so
// "LOT.2023-686" is the same code as "LOT-2023-686". Only punctuation counts
// as the separator: "LOT NUMBER" is a label, not a code (T51).
final _prefixedCode = RegExp(
  r'\b(BN|LOT|BATCH)[-.]([A-Z0-9]*\d[A-Z0-9]*(?:[-.][A-Z0-9]+)*)\b',
  caseSensitive: false,
);

// A labelled value: "LOT NUMBER _ : 20220291". The separator run tolerates the
// stray underscores and periods OCR leaves between the label and the colon.
final _labelledCode = RegExp(
  r'\b(?:BATCH|LOT)\s*(?:NUMBER|NUM|NO)?[\s._\-]*[:#]?[\s._]*([A-Z0-9][A-Z0-9\-./]*)',
  caseSensitive: false,
);

// Tesseract and ML Kit both mangle the label itself — "LOT" becomes "Lor",
// "BATCH" becomes "BATGH". Anything before a colon that is nearly one of these
// counts as a label.
const _labelWords = ['LOT', 'BATCH', 'LOTNUMBER', 'BATCHNO', 'LOTNO', 'BATCHNUMBER'];
final _valueAfterColon = RegExp(r'^([A-Z0-9][A-Z0-9\-./]*)', caseSensitive: false);
final _digit = RegExp(r'\d');

bool _looksLikeLabel(String fragment) {
  final cleaned = fragment.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  if (cleaned.isEmpty || cleaned.length > 14) return false;
  for (final word in _labelWords) {
    final budget = word.length <= 5 ? 1 : 2;
    if (_levenshtein(cleaned, word) <= budget) return true;
  }
  return false;
}

/// Puts a prefixed code back into its canonical form.
String _normaliseCode(String code) {
  var value = code.toUpperCase();
  value = value.replaceAll(RegExp(r'^[\s.:_-]+|[\s.:_-]+$'), '');
  return value.replaceAllMapped(
    RegExp(r'(?<=[A-Z0-9])\.(?=[A-Z0-9])'),
    (_) => '-',
  );
}

/// Returns the batch/lot code without its "Batch No:" style label, or null.
String? parseBatch(String text) {
  final lines = text.split('\n');

  for (final line in lines) {
    final prefixed = _prefixedCode.firstMatch(line);
    if (prefixed != null) {
      return _normaliseCode('${prefixed[1]!.toUpperCase()}-${prefixed[2]!}');
    }
  }

  for (final line in lines) {
    for (final m in _labelledCode.allMatches(line)) {
      final value = m[1]!;
      if (_digit.hasMatch(value)) return _normaliseCode(value);
    }
  }

  // Last resort: a label the OCR mangled, followed by a colon and a value.
  for (final line in lines) {
    final colon = line.indexOf(':');
    if (colon < 0) continue;
    if (!_looksLikeLabel(line.substring(0, colon))) continue;
    final match = _valueAfterColon.firstMatch(line.substring(colon + 1).trim());
    if (match != null && _digit.hasMatch(match[1]!)) return _normaliseCode(match[1]!);
  }
  return null;
}

// ── Crop variety ──────────────────────────────────────────────────────────────

/// Returns the known variety named in [text], or null.
///
/// Matching is per word within a single line: numbers must match exactly (so
/// "SAMMAZ 16" is not SAMMAZ 15) and each other word must reach
/// [kVarietyTokenMatchScore] similarity, tolerating OCR slips like "SAMAZ".
String? parseVariety(String text, {List<String> varieties = kNigerianVarieties}) {
  String? best;
  var bestScore = 0.0;
  var bestLength = 0;

  for (final line in text.split('\n')) {
    final words = _words(line);
    for (final variety in varieties) {
      final target = _words(variety);
      final score = _bestWindowScore(words, target);
      if (score == null) continue;
      if (score > bestScore || (score == bestScore && target.length > bestLength)) {
        best = variety;
        bestScore = score;
        bestLength = target.length;
      }
    }
  }
  return best;
}

List<String> _words(String s) =>
    s.toUpperCase().split(RegExp(r'[^A-Z0-9]+')).where((w) => w.isNotEmpty).toList();

double? _bestWindowScore(List<String> words, List<String> target) {
  double? best;
  for (var start = 0; start + target.length <= words.length; start++) {
    var total = 0.0;
    var matched = true;
    for (var i = 0; i < target.length; i++) {
      final score = _wordScore(words[start + i], target[i]);
      if (score == null) {
        matched = false;
        break;
      }
      total += score;
    }
    if (matched) {
      final mean = total / target.length;
      if (best == null || mean > best) best = mean;
    }
  }
  return best;
}

double? _wordScore(String word, String target) {
  final isNumber = RegExp(r'^\d+$');
  if (isNumber.hasMatch(target) || isNumber.hasMatch(word)) {
    return word == target ? 100 : null;
  }
  final longest = word.length > target.length ? word.length : target.length;
  final score = 100 * (1 - _levenshtein(word, target) / longest);
  return score >= kVarietyTokenMatchScore ? score : null;
}

int _levenshtein(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}
