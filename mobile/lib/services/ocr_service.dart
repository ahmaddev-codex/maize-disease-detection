import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/scan_record.dart';
import 'ocr_parser.dart';

class OcrService {
  static final OcrService instance = OcrService._();
  OcrService._();

  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrFields> extractFields(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);
    final rawText = recognized.text;

    return OcrFields(
      cropVariety:  parseVariety(rawText),
      batchNumber:  parseBatch(rawText),
      plantingDate: parsePlantingDate(rawText),
      rawText:      rawText,
    );
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
