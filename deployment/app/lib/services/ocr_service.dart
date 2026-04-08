import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/prediction.dart';

/// Extracts crop metadata from a seed bag label photograph using ML Kit OCR.
///
/// All processing is on-device — no network call.
/// Only construct this class on Android / iOS.
class OcrService {
  // Lazy: do NOT create TextRecognizer at construction time.
  // The native plugin is not available on macOS / desktop.
  TextRecognizer? _recognizer;
  TextRecognizer get _rec {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  // Known Nigerian maize variety names for fuzzy matching
  static const List<String> _knownVarieties = [
    'SAMMAZ 15', 'SAMMAZ 17', 'SAMMAZ 29', 'SAMMAZ 34', 'SAMMAZ 50',
    'OBA SUPER 2', 'EVDT 99', 'POOL 16 DT', 'TZEE-W',
    'ABA WHITE', 'ACROSS 97', 'SUWAN 1', 'EARLY THRIVING',
  ];

  static final RegExp _batchRegex = RegExp(
    r'(?:BN[-\s]?\d{4}[-\s]?\d{2,4}|BATCH\s*(?:NO\.?|NUMBER)?\s*[:=]?\s*[\w-]+|LOT\s*#?\s*[\w-]+)',
    caseSensitive: false,
  );

  static final List<RegExp> _datePatterns = [
    // DD/MM/YYYY or DD-MM-YYYY
    RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})'),
    // YYYY-MM-DD
    RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})'),
    // "15 March 2024" or "March 2024"
    RegExp(r'(\d{1,2})\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{4})',
        caseSensitive: false),
  ];

  static const Map<String, int> _monthMap = {
    'jan': 1, 'january': 1, 'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,   'apr': 4, 'april': 4,
    'may': 5, 'jun': 6,     'june': 6, 'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,  'sep': 9, 'september': 9,
    'oct': 10,'october': 10,'nov': 11,'november': 11,
    'dec': 12,'december': 12,
  };

  /// Run OCR on [imageFile] and extract structured seed label fields.
  Future<SeedLabelData> extractFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognised = await _rec.processImage(inputImage);
    final rawText    = recognised.text;
    final upperText  = rawText.toUpperCase();

    return SeedLabelData(
      cropVariety:  _extractVariety(upperText),
      batchNumber:  _extractBatch(rawText),
      plantingDate: _extractDate(rawText),
      rawText:      rawText,
    );
  }

  String? _extractVariety(String upperText) {
    // Direct substring match first (fast path)
    for (final variety in _knownVarieties) {
      if (upperText.contains(variety)) return variety;
    }
    // Fuzzy: check if any word tokens overlap significantly
    for (final variety in _knownVarieties) {
      final tokens = variety.split(' ');
      final matched = tokens.where((t) => upperText.contains(t)).length;
      if (matched >= tokens.length - 1 && tokens.length > 1) return variety;
    }
    return null;
  }

  String? _extractBatch(String text) {
    final match = _batchRegex.firstMatch(text);
    return match?.group(0)?.trim();
  }

  String? _extractDate(String text) {
    // Pattern 0: DD/MM/YYYY
    var m = _datePatterns[0].firstMatch(text);
    if (m != null) {
      final d = m.group(1)!.padLeft(2, '0');
      final mo = m.group(2)!.padLeft(2, '0');
      final y = m.group(3)!;
      return '$y-$mo-$d';
    }
    // Pattern 1: YYYY-MM-DD
    m = _datePatterns[1].firstMatch(text);
    if (m != null) {
      return '${m.group(1)}-${m.group(2)!.padLeft(2, '0')}-${m.group(3)!.padLeft(2, '0')}';
    }
    // Pattern 2: "15 March 2024"
    m = _datePatterns[2].firstMatch(text);
    if (m != null) {
      final d  = m.group(1)!.padLeft(2, '0');
      final mo = _monthMap[m.group(2)!.toLowerCase()]!.toString().padLeft(2, '0');
      final y  = m.group(3)!;
      return '$y-$mo-$d';
    }
    return null;
  }

  void dispose() => _recognizer?.close();
}
