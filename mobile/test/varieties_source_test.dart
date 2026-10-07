import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/constants/varieties.dart';

/// T53: the Dart list is generated from `data/reference/maize_varieties.csv`
/// (ADR-006). If someone edits one and not the other, this fails here rather
/// than producing an app that recognises a variety the pipeline does not.
void main() {
  test('the app list matches the reference CSV, in order', () {
    final csv = File('../data/reference/maize_varieties.csv');
    expect(csv.existsSync(), isTrue, reason: 'the reference file is missing');

    final rows = csv
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
        .toList();
    final header = rows.first.split(',');
    expect(header.first, 'name');

    final names = rows.skip(1).map((line) => line.split(',').first.trim()).toList();

    expect(kNigerianVarieties, names,
        reason: 'run: python scripts/sync_varieties.py');
  });

  test('the generated file is marked as generated', () {
    final dart = File('lib/constants/varieties.dart').readAsStringSync();
    expect(dart, contains('GENERATED FILE'));
    expect(dart, contains('scripts/sync_varieties.py'));
  });
}
