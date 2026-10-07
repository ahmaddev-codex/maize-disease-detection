import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/services/classifier_preprocess.dart';

/// T10: decoding and resizing a 12 MP photo blocked the UI thread, freezing the
/// "Analyzing Leaf Sample…" overlay. The work must be isolate-safe so it can run
/// off the main thread.
void main() {
  test('preprocessing runs in a background isolate', () async {
    final bytes = File('test/fixtures/leaf.jpg').readAsBytesSync();

    final pixels = await Isolate.run(() => preprocessForModel(bytes, size: 300));

    expect(pixels.length, 300 * 300 * 3);
  });

  test('isolate result matches a main-thread run exactly', () async {
    final bytes = File('test/fixtures/leaf.jpg').readAsBytesSync();

    final onMain = preprocessForModel(bytes, size: 300);
    final inIsolate = await Isolate.run(() => preprocessForModel(bytes, size: 300));

    expect(inIsolate, equals(onMain));
  });
}
