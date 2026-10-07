import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/providers/app_provider.dart';
import 'package:maizeguard/providers/service_providers.dart';
import 'package:maizeguard/screens/camera_screen.dart';
import 'package:maizeguard/screens/result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_services.dart';

/// T23: seed-label data was linked invisibly — nothing on the camera said a
/// label was attached, and the result never showed the variety it was saved with.
final _scan = ScanRecord(
  id: 1,
  imagePath: 'scans/missing.jpg',
  classId: 2,
  className: 'Gray Leaf Spot',
  shortName: 'GLS',
  confidence: 0.9,
  allScores: const [0.04, 0.04, 0.88, 0.04],
  latencyMs: 30,
  cropVariety: 'SAMMAZ 15',
  batchNumber: 'BN-2024-042',
  plantingDate: '2024-03-15',
  scannedAt: DateTime.utc(2026, 9, 23, 9),
);

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

  testWidgets('the result shows the seed label saved with the scan', (tester) async {
    final container = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(FakeDatabaseService({1: _scan})),
      aiAdvisorProvider.overrideWithValue(FakeAiAdvisor()),
    ]);
    addTearDown(container.dispose);
    container.read(activeScanIdProvider.notifier).state = 1;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ResultScreen()),
    ));
    await _settle(tester);

    final seedCard = find.byKey(const Key('result-seed-label'));
    await tester.scrollUntilVisible(seedCard, 300, scrollable: find.byType(Scrollable).first);

    expect(find.textContaining('SAMMAZ 15'), findsWidgets);
    expect(find.textContaining('BN-2024-042'), findsWidgets);
    expect(find.textContaining('2024-03-15'), findsWidgets);
  });

  testWidgets('the camera shows which seed label will be attached, and can clear it',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(pendingOcrProvider.notifier).state = const OcrFields(
      cropVariety: 'OBA SUPER 2',
      batchNumber: 'LOT-2024-007',
      plantingDate: '2024-05-20',
      rawText: 'OBA SUPER 2',
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CameraScreen()),
    ));
    await _settle(tester);

    expect(find.textContaining('OBA SUPER 2'), findsWidgets);

    await tester.tap(find.byKey(const Key('camera-clear-seed-label')));
    await _settle(tester);

    expect(container.read(pendingOcrProvider), isNull);
    expect(find.textContaining('OBA SUPER 2'), findsNothing);
  });
}
