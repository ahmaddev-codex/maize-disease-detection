// ignore_for_file: avoid_classes_with_only_static_members

/// Web stub — TFLite / dart:ffi is not available in browsers.
/// The app still loads; inference features show an appropriate message.
library;

import '../models/prediction.dart';

class MaizeClassifier {
  static const List<String> classNames = [
    'NCLB (Northern Corn Leaf Blight)',
    'Rust (Common Rust)',
    'GLS (Gray Leaf Spot)',
    'Healthy',
  ];

  bool get isReady => false;
  String get activeModel => 'web-unsupported';

  Future<void> init() async {
    throw UnsupportedError(
      'On-device TFLite inference is not available in the browser.\n'
      'Please use the macOS desktop app or the iOS / Android mobile app.',
    );
  }

  Future<Prediction> classify(dynamic imageFile) async {
    throw UnsupportedError('Inference not available on web.');
  }

  void dispose() {}
}
