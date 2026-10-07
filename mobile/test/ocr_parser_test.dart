import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/services/ocr_parser.dart';

/// Cases shared with the Python extractor (tests/fixtures/ocr_cases.json, ADR-006).
Map<String, dynamic> _loadCases() {
  final file = File('../tests/fixtures/ocr_cases.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

String _label(String text) => text.replaceAll('\n', r'\n');

void main() {
  final cases = _loadCases();

  group('parsePlantingDate', () {
    for (final c in (cases['dates'] as List).cast<Map<String, dynamic>>()) {
      test('"${_label(c['text'] as String)}" -> ${c['expected']}', () {
        expect(parsePlantingDate(c['text'] as String), c['expected']);
      });
    }
  });

  group('parseVariety', () {
    for (final c in (cases['varieties'] as List).cast<Map<String, dynamic>>()) {
      test('"${_label(c['text'] as String)}" -> ${c['expected']}', () {
        expect(parseVariety(c['text'] as String), c['expected']);
      });
    }
  });

  group('parseBatch', () {
    for (final c in (cases['batches'] as List).cast<Map<String, dynamic>>()) {
      test('"${_label(c['text'] as String)}" -> ${c['expected']}', () {
        expect(parseBatch(c['text'] as String), c['expected']);
      });
    }
  });

  group('isValidPlantingDate (OCR review form)', () {
    test('accepts a real ISO calendar date', () {
      expect(isValidPlantingDate('2024-03-15'), isTrue);
    });

    test('rejects impossible dates and free text', () {
      expect(isValidPlantingDate('2024-02-30'), isFalse);
      expect(isValidPlantingDate('15/03/2024'), isFalse);
      expect(isValidPlantingDate('last week'), isFalse);
    });

    test('treats an empty field as valid (the date is optional)', () {
      expect(isValidPlantingDate(''), isTrue);
    });
  });
}
