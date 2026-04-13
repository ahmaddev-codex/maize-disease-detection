import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/prediction.dart';

/// Runs EfficientNetB3 TFLite inference on a single maize leaf image.
class MaizeClassifier {
  static const _modelInt8 = 'assets/models/efficientnetb3_maize_int8.tflite';
  static const _modelFp16 = 'assets/models/efficientnetb3_maize_fp16.tflite';

  static const int _imgSize = 300;
  static const int _numClasses = 4;

  static const List<String> classNames = [
    'NCLB (Northern Corn Leaf Blight)',
    'Rust (Common Rust)',
    'GLS (Gray Leaf Spot)',
    'Healthy',
  ];

  Interpreter? _interpreter;
  bool _isInitialised = false;
  String _activeModel = _modelInt8;

  bool get isReady => _isInitialised;
  String get activeModel => _activeModel;

  Future<void> init() async {
    final options = InterpreterOptions()..threads = 2;

    String? int8Error;
    try {
      _interpreter = await Interpreter.fromAsset(_modelInt8, options: options);
      _interpreter!.allocateTensors();
      _activeModel = _modelInt8;
      _isInitialised = true;
      return;
    } catch (e) {
      int8Error = e.toString();
      _interpreter = null;
    }

    try {
      _interpreter = await Interpreter.fromAsset(_modelFp16, options: options);
      _interpreter!.allocateTensors();
      _activeModel = _modelFp16;
      _isInitialised = true;
    } catch (e) {
      throw Exception(
        'Could not load TFLite model.\nINT8 error: $int8Error\nFP16 error: $e',
      );
    }
  }

  /// Classify an image file. Returns a [Prediction] with class scores and
  /// latency in milliseconds.
  Future<Prediction> classify(File imageFile) async {
    if (!_isInitialised || _interpreter == null) {
      throw StateError('Classifier not initialised. Call init() first.');
    }

    // Read the file — catches sandbox permission errors on macOS.
    final Uint8List imageBytes;
    try {
      imageBytes = await imageFile.readAsBytes();
    } catch (e) {
      throw Exception(
          'Cannot read image at ${imageFile.path}.\n'
          'On macOS verify the "files.user-selected.read-only" entitlement.\n$e');
    }

    final inputTensor  = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);

    // Preprocess in a Flutter compute isolate so the UI stays responsive.
    // compute() properly initialises the child isolate for Flutter.
    final _PrepareArgs args = _PrepareArgs(imageBytes, inputTensor.type, _imgSize);
    final input = await compute(_preprocessCompute, args);

    // Allocate output as a plain nested List — tflite_flutter fills it via
    // copyTo → _duplicateList, no typed-list casts needed.
    final output = _allocateOutputList(outputTensor.type);

    final sw = Stopwatch()..start();
    _interpreter!.run(input, output);
    sw.stop();

    final scores  = _parseOutput(output, outputTensor.type, outputTensor.params);
    final classId = scores.indexOf(scores.reduce((a, b) => a > b ? a : b));

    return Prediction(
      classId:    classId,
      className:  classNames[classId],
      confidence: scores[classId],
      allScores:  scores,
      latencyMs:  sw.elapsedMilliseconds.toDouble(),
    );
  }

  // ── Preprocessing ─────────────────────────────────────────────────────────

  /// Message bag for [compute]; all fields must be sendable across isolates.
  static Object _preprocessCompute(_PrepareArgs args) {
    final decoded = img.decodeImage(args.bytes);
    if (decoded == null) {
      throw Exception('Image decode failed. Ensure the file is a valid JPEG/PNG.');
    }
    final resized = img.copyResize(decoded, width: args.imgSize, height: args.imgSize);
    final size = args.imgSize;

    if (args.dtype == TensorType.uint8) {
      // Build a plain nested List<List<List<List<int>>>> [1,H,W,3]
      // so tflite_flutter's ByteConversionUtils._convertElementToBytes receives
      // concrete `int` values — no type ambiguity across the isolate boundary.
      return List.generate(1, (_) =>
        List.generate(size, (y) =>
          List.generate(size, (x) {
            final p = resized.getPixel(x, y);
            return [p.r.toInt(), p.g.toInt(), p.b.toInt()];
          })
        )
      );
    } else {
      // float32: EfficientNetB3 has internal Rescaling so pass raw [0,255].
      return List.generate(1, (_) =>
        List.generate(size, (y) =>
          List.generate(size, (x) {
            final p = resized.getPixel(x, y);
            return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
          })
        )
      );
    }
  }

  // ── Output helpers ─────────────────────────────────────────────────────────

  /// Allocate the output as a mutable nested List that tflite_flutter can
  /// write into via _duplicateList.  Shape: [1, numClasses].
  List<List<num>> _allocateOutputList(TensorType dtype) {
    if (dtype == TensorType.uint8) {
      return [List<int>.filled(_numClasses, 0)];
    }
    return [List<double>.filled(_numClasses, 0.0)];
  }

  List<double> _parseOutput(
      Object output, TensorType dtype, QuantizationParams params) {
    // output is List<List<num>> — shape [1, numClasses] filled by tflite_flutter.
    final row = (output as List).first as List;
    if (dtype == TensorType.uint8) {
      final scale     = params.scale;
      final zeroPoint = params.zeroPoint;
      return row.map<double>((v) => ((v as num).toInt() - zeroPoint) * scale).toList();
    }
    return row.map<double>((v) => (v as num).toDouble()).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialised = false;
  }
}

// ── Isolate message types ────────────────────────────────────────────────────

class _PrepareArgs {
  final Uint8List bytes;
  final TensorType dtype;
  final int imgSize;
  const _PrepareArgs(this.bytes, this.dtype, this.imgSize);
}
