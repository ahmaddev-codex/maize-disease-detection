import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/services/classifier_postprocess.dart';

/// T33: the same cases the Python pipeline runs
/// (tests/fixtures/postprocess_cases.json, ADR-006). If these two drift apart,
/// the confidence on the phone stops meaning what the reported metrics mean.
void main() {
  final file = File('../tests/fixtures/postprocess_cases.json');
  final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final tolerance = (fixture['tolerance'] as num).toDouble();

  for (final entry in fixture['cases'] as List) {
    final c = entry as Map<String, dynamic>;
    test('shared case: ${c['name']}', () {
      final probs = probabilitiesFrom(
        (c['raw'] as List).cast<num>(),
        integerOutput: c['integer_output'] as bool,
        scale: (c['scale'] as num).toDouble(),
        zeroPoint: c['zero_point'] as int,
      );

      final expected = (c['expected'] as List).cast<num>();
      expect(probs, hasLength(expected.length));
      for (var i = 0; i < expected.length; i++) {
        expect(probs[i], closeTo(expected[i].toDouble(), tolerance),
            reason: 'index $i of ${c['name']}');
      }
      expect(probs.reduce((a, b) => a + b), closeTo(1.0, 1e-6));
      expect(argmax(probs), c['expected_class_id']);
    });
  }

  test('probabilities are never softmaxed', () {
    final probs = probabilitiesFrom(
      const [0.8, 0.1, 0.05, 0.05],
      integerOutput: false,
      scale: 0,
      zeroPoint: 0,
    );
    expect(probs.first, closeTo(0.8, 1e-6));
  });

  test('class names come from the one disease table', () {
    expect(classDisplayName(0), 'Northern Corn Leaf Blight');
    expect(classDisplayName(3), 'Healthy');
  });
}
