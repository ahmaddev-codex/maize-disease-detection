import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/providers/app_provider.dart';
import 'package:maizeguard/providers/service_providers.dart';
import 'package:maizeguard/screens/history_screen.dart';
import 'package:maizeguard/screens/result_screen.dart';
import 'package:maizeguard/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_services.dart';

ScanRecord _record(int id, {int? feedback, String className = 'Gray Leaf Spot'}) => ScanRecord(
      id: id,
      imagePath: '${Directory.systemTemp.path}/missing_$id.jpg',
      classId: 2,
      className: className,
      shortName: 'GLS',
      confidence: 0.9,
      allScores: const [0.03, 0.03, 0.9, 0.04],
      latencyMs: 30,
      scannedAt: DateTime.utc(2026, 9, 10, 9),
      feedback: feedback,
    );

class _FixedScanList extends ScanListNotifier {
  _FixedScanList(List<ScanRecord> scans, [DatabaseService? db]) : super(db) {
    state = scans;
  }

  @override
  Future<void> load({int? classFilter}) async {}
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('tapping Correct highlights it immediately and it stays selected after reopening',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final db = FakeDatabaseService({2: _record(2)});
    final container = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(db),
      aiAdvisorProvider.overrideWithValue(FakeAiAdvisor()),
      scanListProvider.overrideWith((ref) => _FixedScanList([_record(2)], db)),
    ]);
    addTearDown(container.dispose);
    container.read(activeScanIdProvider.notifier).state = 2;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ResultScreen()),
    ));
    await _settle(tester);

    final correct = find.byKey(const Key('feedback-correct'));
    // The list builds lazily: scroll until the option exists, then bring it fully on screen.
    await tester.scrollUntilVisible(correct, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(correct);
    await _settle(tester);
    await tester.tap(correct);
    await _settle(tester);

    expect(db.records[2]!.feedback, 1);
    expect(tester.getSemantics(correct), isSemantics(isSelected: true));

    container.invalidate(activeScanRecordProvider); // reopen the same scan
    await _settle(tester);
    // The list builds lazily: scroll until the option exists, then bring it fully on screen.
    await tester.scrollUntilVisible(correct, 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(correct);
    await _settle(tester);

    expect(tester.getSemantics(correct), isSemantics(isSelected: true));
    semantics.dispose();
  });

  testWidgets('History shows a feedback label only for scans that have feedback', (tester) async {
    final container = ProviderContainer(overrides: [
      scanListProvider.overrideWith((ref) => _FixedScanList([
            _record(3, className: 'Common Rust'),
            _record(4, feedback: -1),
          ])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HistoryScreen()),
    ));
    await _settle(tester);

    expect(find.text('Uncertain'), findsOneWidget);
  });
}
