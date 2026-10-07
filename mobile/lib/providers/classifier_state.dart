import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/classifier_service.dart';
import 'service_providers.dart';

enum ClassifierPhase { loading, ready, failed }

class ClassifierState {
  const ClassifierState._(this.phase, {this.status, this.error});

  const ClassifierState.loading() : this._(ClassifierPhase.loading);
  const ClassifierState.ready(String status) : this._(ClassifierPhase.ready, status: status);
  const ClassifierState.failed(String error) : this._(ClassifierPhase.failed, error: error);

  final ClassifierPhase phase;
  /// Loaded model variant, e.g. "EfficientNetB3 · FP16" (ready only).
  final String? status;
  /// Farmer-facing failure message (failed only).
  final String? error;

  bool get isReady  => phase == ClassifierPhase.ready;
  bool get isFailed => phase == ClassifierPhase.failed;
}

/// Loads the on-device model once and exposes loading / ready / failed so the
/// UI can show the real variant or a retry instead of spinning forever.
class ClassifierStateNotifier extends StateNotifier<ClassifierState> {
  ClassifierStateNotifier(this._service) : super(const ClassifierState.loading());

  final ClassifierService _service;
  Future<void>? _inFlight;

  /// Concurrent callers share one load; a failed load can be retried.
  Future<void> load() => _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    state = const ClassifierState.loading();
    try {
      await _service.loadModel();
      if (mounted) state = ClassifierState.ready(_service.modelStatus);
    } catch (e) {
      debugPrint('[Classifier] model load failed: $e');
      if (mounted) state = const ClassifierState.failed('The disease model could not be loaded.');
    }
  }
}

final classifierStateProvider =
    StateNotifierProvider<ClassifierStateNotifier, ClassifierState>(
  (ref) => ClassifierStateNotifier(ref.watch(classifierServiceProvider)),
);
