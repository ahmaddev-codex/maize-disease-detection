import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'classifier_postprocess.dart';
import 'classifier_preprocess.dart';
import '../models/scan_record.dart';
import '../constants/diseases.dart';

/// Loads a TFLite interpreter for a bundled model asset.
typedef InterpreterLoader = Future<Interpreter> Function(String asset);

class ClassifierService {
  static final ClassifierService instance = ClassifierService._();

  ClassifierService._([InterpreterLoader? loader])
      : _loadInterpreter = loader ?? _loadWithDelegate;

  /// Lets tests observe which model assets are tried, and in what order.
  @visibleForTesting
  factory ClassifierService.forTesting(InterpreterLoader loader) =>
      ClassifierService._(loader);

  final InterpreterLoader _loadInterpreter;

  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  bool _isLoaded  = false;
  bool _isInt8    = false; // true -> INT8 fallback was loaded (ADR-001)

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

  Future<void>? _loading;

  /// Loads the model once; concurrent callers share the same in-flight load.
  Future<void> loadModel() {
    if (_isLoaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    // ADR-001: FP16 is the primary model (91.10% vs INT8 88.08% on the test
    // split, and INT8 measured slower on CPU). INT8 is the fallback.
    try {
      _interpreter = await _loadInterpreter(_fp16Model);
      _isInt8  = false;
      _isLoaded = true;
    } catch (_) {
      try {
        _interpreter = await _loadInterpreter(_int8Model);
        _isInt8  = true;
        _isLoaded = true;
      } catch (e) {
        throw Exception('Failed to load TFLite model: $e');
      }
    }

    // Inference runs on its own isolate so a scan never janks the UI (T10).
    try {
      _isolateInterpreter = await IsolateInterpreter.create(address: _interpreter!.address);
    } catch (e) {
      debugPrint('[Classifier] isolate interpreter unavailable, running inline: $e');
    }
  }

  static Future<Interpreter> _loadWithDelegate(String asset) async {
    try {
      final options = InterpreterOptions()..addDelegate(GpuDelegateV2());
      return await Interpreter.fromAsset(asset, options: options);
    } catch (_) {
      return await Interpreter.fromAsset(asset);
    }
  }

  Future<ClassificationResult> classify(String imagePath) async {
    if (!_isLoaded || _interpreter == null) await loadModel();

    final totalWatch = Stopwatch()..start();

    // ── Preprocess image ──────────────────────────────────────────────────────
    // Decoding and resizing a 12 MP photo on the UI thread froze the
    // "Analyzing Leaf Sample…" overlay, so it runs on a background isolate (T10).
    final bytes = await File(imagePath).readAsBytes();
    final rgb = await Isolate.run(() => preprocessForModel(bytes, size: _inputSize));

    // Inspect actual input tensor type to prevent buffer length mismatch crashes
    final inputTensorInfo = _interpreter!.getInputTensor(0);
    final isFloatInput = inputTensorInfo.type == TensorType.float32;

    dynamic inputTensor;

    if (isFloatInput) {
      // FP16 / Float32 model: expects [1, 300, 300, 3] float32 in [0, 255]
      final floatBuffer = Float32List(rgb.length);
      for (var i = 0; i < rgb.length; i++) {
        floatBuffer[i] = rgb[i].toDouble();
      }
      inputTensor = floatBuffer.reshape([1, _inputSize, _inputSize, 3]);
    } else {
      // INT8 / Uint8 model: expects [1, 300, 300, 3] uint8
      inputTensor = rgb.reshape([1, _inputSize, _inputSize, 3]);
    }

    // ── Output buffer — dynamically match output tensor type ──────────────────
    final outputTensorInfo = _interpreter!.getOutputTensor(0);
    final isFloatOutput = outputTensorInfo.type == TensorType.float32;

    final outputTensor = isFloatOutput
        ? List.filled(_numClasses, 0.0).reshape([1, _numClasses])
        : List.filled(_numClasses, 0).reshape([1, _numClasses]);

    final modelWatch = Stopwatch()..start();
    final isolateInterpreter = _isolateInterpreter;
    if (isolateInterpreter != null) {
      await isolateInterpreter.run(inputTensor, outputTensor);
    } else {
      _interpreter!.run(inputTensor, outputTensor);
    }
    modelWatch.stop();
    totalWatch.stop();
    debugPrint('[Classifier] model ${modelWatch.elapsedMilliseconds} ms · '
        'capture-to-result ${totalWatch.elapsedMilliseconds} ms');

    // ── Dequantise / normalise ────────────────────────────────────────────────
    // One shared rule, checked against the Python pipeline's fixtures (T33).
    final normalised = probabilitiesFrom(
      (outputTensor[0] as List).cast<num>(),
      integerOutput: !isFloatOutput,
      scale: _scale,
      zeroPoint: _zeroPoint,
    );

    final classId    = argmax(normalised);
    final confidence = normalised[classId];
    final disease    = diseaseForClass(classId);

    return ClassificationResult(
      classId:    classId,
      className:  disease.name,
      shortName:  disease.shortName,
      confidence: confidence,
      allScores:  normalised,
      latencyMs:  modelWatch.elapsedMilliseconds.toDouble(),
    );
  }

  Future<void> dispose() async {
    await _isolateInterpreter?.close();
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
    _isLoaded    = false;
  }
}
