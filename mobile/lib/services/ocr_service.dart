import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/scan_record.dart';
import '../constants/diseases.dart';

class OcrService {
  static final OcrService instance = OcrService._();
  OcrService._();

  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static final _batchPatterns = [
    RegExp(r'BN[-/]\d{4}[-/]\d{3,}', caseSensitive: false),
    RegExp(r'LOT\s*[-#:]\s*\S+',      caseSensitive: false),
    RegExp(r'BATCH\s*NO[:\s]\s*\S+',  caseSensitive: false),
  ];

  static final _datePatterns = [
    RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b'),
    RegExp(r'\b(\d{4})[/-](\d{2})[/-](\d{2})\b'),
    RegExp(r'\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})\b',
           caseSensitive: false),
  ];

  static const _monthMap = {
    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
    'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
    'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
  };

  Future<OcrFields> extractFields(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);
    final rawText = recognized.text;

    return OcrFields(
      cropVariety:  _extractVariety(rawText),
      batchNumber:  _extractBatch(rawText),
      plantingDate: _extractDate(rawText),
      rawText:      rawText,
    );
  }

  String? _extractVariety(String text) {
    final upper = text.toUpperCase();
    String? best;
    int bestScore = 0;

    for (final variety in kNigerianVarieties) {
      // Direct substring match first
      if (upper.contains(variety)) return variety;

      // Fuzzy: count matching words
      final varWords = variety.split(' ');
      int score = 0;
      for (final word in varWords) {
        if (upper.contains(word)) score++;
      }
      if (score > bestScore && score >= (varWords.length * 0.6).ceil()) {
        bestScore = score;
        best = variety;
      }
    }
    return best;
  }

  String? _extractBatch(String text) {
    for (final pattern in _batchPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(0)!.trim();
    }
    return null;
  }

  String? _extractDate(String text) {
    for (final pattern in _datePatterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;

      try {
        final g = match.groups([1, 2, 3]);
        if (g[0] == null || g[1] == null || g[2] == null) continue;

        // YYYY-MM-DD pattern
        if ((g[0]!).length == 4) {
          return '${g[0]}-${g[1]!.padLeft(2,'0')}-${g[2]!.padLeft(2,'0')}';
        }
        // Month name pattern
        final month = _monthMap[g[1]!.toLowerCase().substring(0, 3)];
        if (month != null) {
          return '${g[2]}-$month-${g[0]!.padLeft(2,'0')}';
        }
        // DD/MM/YYYY
        return '${g[2]}-${g[1]!.padLeft(2,'0')}-${g[0]!.padLeft(2,'0')}';
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
