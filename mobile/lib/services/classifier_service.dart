import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/scan_record.dart';
import '../constants/diseases.dart';

class ClassifierService {
  static final ClassifierService instance = ClassifierService._();
  ClassifierService._();

  Interpreter? _interpreter;
  bool _isLoaded  = false;
  bool _isInt8    = true; // false → FP16 fallback was loaded

  static const String _int8Model = 'assets/models/efficientnetb3_maize_int8.tflite';
  static const String _fp16Model = 'assets/models/efficientnetb3_maize_fp16.tflite';
  static const int _inputSize   = 300;
  static const int _numClasses  = 4;

  // INT8 dequantisation params (scale=1/256, zp=0 per REQUIREMENTS.md §6.4)
  static const double _scale     = 0.00390625;
  static const int    _zeroPoint = 0;

  String get modelStatus {
    if (!_isLoaded) return 'Model not loaded';
    return 'EfficientNetB3 · ${_isInt8 ? "INT8" : "FP16"}';
  }

  Future<void> loadModel() async {
    if (_isLoaded) return; // guard against double-load
    try {
      _interpreter = await _loadWithDelegate(_int8Model);
      _isInt8  = true;
      _isLoaded = true;
    } catch (_) {
      // GPU delegate failed or INT8 not supported — try FP16 on CPU
      try {
        _interpreter = await _loadWithDelegate(_fp16Model);
        _isInt8  = false;
        _isLoaded = true;
      } catch (e) {
        throw Exception('Failed to load TFLite model: $e');
      }
    }
  }

  Future<Interpreter> _loadWithDelegate(String asset) async {
    try {
      final options = InterpreterOptions()..addDelegate(GpuDelegateV2());
      return await Interpreter.fromAsset(asset, options: options);
    } catch (_) {
      return await Interpreter.fromAsset(asset);
    }
  }

  Future<ClassificationResult> classify(String imagePath) async {
    if (!_isLoaded || _interpreter == null) await loadModel();

    final stopwatch = Stopwatch()..start();

    // ── Preprocess image ──────────────────────────────────────────────────────
    final bytes   = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Failed to decode image: $imagePath');

    final resized = img.copyResize(decoded, width: _inputSize, height: _inputSize);

    // Build [1, 300, 300, 3] uint8 input tensor
    final input = Uint8List(_inputSize * _inputSize * 3);
    int idx = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[idx++] = pixel.r.toInt();
        input[idx++] = pixel.g.toInt();
        input[idx++] = pixel.b.toInt();
      }
    }

    final inputTensor = input.reshape([1, _inputSize, _inputSize, 3]);

    // ── Output buffer — type depends on loaded model ───────────────────────────
    // INT8 → int buffer; FP16 → double buffer. Mixing types causes a cast error.
    final outputTensor = _isInt8
        ? List.filled(_numClasses, 0).reshape([1, _numClasses])
        : List.filled(_numClasses, 0.0).reshape([1, _numClasses]);

    _interpreter!.run(inputTensor, outputTensor);
    stopwatch.stop();

    // ── Dequantise / normalise ────────────────────────────────────────────────
    List<double> scores;
    if (_isInt8) {
      final raw = (outputTensor[0] as List).cast<int>();
      scores = raw.map((v) => (v - _zeroPoint) * _scale).toList();
    } else {
      // FP16 model already outputs float probabilities
      scores = (outputTensor[0] as List).cast<double>();
    }

    // Normalise so scores sum to 1 (softmax if needed)
    final sum = scores.fold<double>(0, (a, b) => a + b);
    final normalised = (sum > 0 && (sum - 1.0).abs() > 0.01)
        ? scores.map((s) => s / sum).toList()
        : scores;

    final classId    = normalised.indexOf(normalised.reduce((a, b) => a > b ? a : b));
    final confidence = normalised[classId];
    final disease    = diseaseForClass(classId);

    return ClassificationResult(
      classId:    classId,
      className:  disease.name,
      shortName:  disease.shortName,
      confidence: confidence,
      allScores:  normalised,
      latencyMs:  stopwatch.elapsedMilliseconds.toDouble(),
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded    = false;
  }
}
