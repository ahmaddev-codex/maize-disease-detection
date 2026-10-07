import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/services/classifier_preprocess.dart';

/// T09: the app must prepare pixels the way training did (bilinear resize).
/// Nearest-neighbour resizing cost ~1.8 accuracy points on the test split.
void main() {
  late Map<String, dynamic> fixture;
  late List<int> pixels;

  setUpAll(() {
    fixture = jsonDecode(File('test/fixtures/preprocess_fixture.json').readAsStringSync())
        as Map<String, dynamic>;
    pixels = preprocessForModel(File('test/fixtures/leaf.jpg').readAsBytesSync(), size: 300);
  });

  test('produces a 300x300 RGB byte buffer', () {
    expect(pixels.length, 300 * 300 * 3);
  });

  test('per-channel means match the Python pipeline within 1.0', () {
    final expected = (fixture['channel_means'] as List).cast<num>();
    for (var c = 0; c < 3; c++) {
      var sum = 0.0;
      for (var i = c; i < pixels.length; i += 3) {
        sum += pixels[i];
      }
      final mean = sum / (300 * 300);
      expect((mean - expected[c]).abs(), lessThan(1.0),
          reason: 'channel $c mean $mean vs Python ${expected[c]}');
    }
  });

  test('mean absolute difference from the Python tensor is at most 1.0', () {
    final expected = (fixture['pooled_30x30'] as List)
        .map((row) => (row as List).map((cell) => (cell as List).cast<num>()).toList())
        .toList();

    var totalDiff = 0.0;
    var count = 0;
    for (var by = 0; by < 30; by++) {
      for (var bx = 0; bx < 30; bx++) {
        final sums = [0.0, 0.0, 0.0];
        for (var y = by * 10; y < by * 10 + 10; y++) {
          for (var x = bx * 10; x < bx * 10 + 10; x++) {
            final base = (y * 300 + x) * 3;
            for (var c = 0; c < 3; c++) {
              sums[c] += pixels[base + c];
            }
          }
        }
        for (var c = 0; c < 3; c++) {
          totalDiff += (sums[c] / 100 - expected[by][bx][c]).abs();
          count++;
        }
      }
    }
    expect(totalDiff / count, lessThanOrEqualTo(1.0));
  });
}
