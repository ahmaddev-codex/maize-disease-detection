import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/providers/app_provider.dart';
import 'package:maizeguard/providers/service_providers.dart';
import 'package:maizeguard/screens/result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_services.dart';

ScanRecord _record({
  required int id,
  required int classId,
  required String className,
  required String imagePath,
  required String variety,
}) =>
    ScanRecord(
      id: id,
      imagePath: imagePath,
      classId: classId,
      className: className,
      shortName: className,
      confidence: 0.91,
      allScores: List.generate(4, (i) => i == classId ? 0.91 : 0.03),
      latencyMs: 40,
      cropVariety: variety,
      scannedAt: DateTime.utc(2026, 9, 10, 9),
    );

Iterable<String> _shownImagePaths(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((image) => image.image)
    .whereType<FileImage>()
    .map((fileImage) => fileImage.file.path);

void main() {
  late Directory tmp;
  late ScanRecord scanA;
  late ScanRecord scanB;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('result_identity');
    File('${tmp.path}/a.jpg').writeAsBytesSync([0]);
    File('${tmp.path}/b.jpg').writeAsBytesSync([0]);
    scanA = _record(id: 1, classId: 1, className: 'Common Rust',
        imagePath: '${tmp.path}/a.jpg', variety: 'SAMMAZ 15');
    scanB = _record(id: 2, classId: 2, className: 'Gray Leaf Spot',
        imagePath: '${tmp.path}/b.jpg', variety: 'OBA SUPER 2');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(ProviderContainer, FakeAiAdvisor)> pumpResult(
    WidgetTester tester, {
    required FakeDatabaseService db,
    required int activeScanId,
    bool afterCameraScanOfA = false,
  }) async {
    final ai = FakeAiAdvisor();
    final container = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(db),
      aiAdvisorProvider.overrideWithValue(ai),
    ]);
    addTearDown(container.dispose);

    if (afterCameraScanOfA) {
      // State the camera flow leaves behind after scanning A.
      container.read(lastResultProvider.notifier).state = scanA.toResult();
      container.read(lastImagePathProvider.notifier).state = scanA.imagePath;
      container.read(lastScanVarietyProvider.notifier).state = scanA.cropVariety;
    }
    container.read(activeScanIdProvider.notifier).state = activeScanId;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ResultScreen()),
      ),
    );
    return (container, ai);
  }

  testWidgets('opening scan B after a camera scan of A shows and advises on B only', (tester) async {
    final (_, ai) = await pumpResult(
      tester,
      db: FakeDatabaseService({2: scanB}),
      activeScanId: 2,
      afterCameraScanOfA: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(ai.calls.map((c) => c.classId), [2]);
    expect(ai.calls.single.cropVariety, 'OBA SUPER 2');
    expect(_shownImagePaths(tester), contains(scanB.imagePath));
    expect(_shownImagePaths(tester), isNot(contains(scanA.imagePath)));
    expect(find.text('Gray Leaf Spot'), findsWidgets);
  });

  testWidgets('nothing is fetched while the scan record is still loading', (tester) async {
    final db = FakeDatabaseService({2: scanB})..lookupGate = Completer<void>();
    final (_, ai) = await pumpResult(tester, db: db, activeScanId: 2, afterCameraScanOfA: true);
    await tester.pump();

    expect(find.byKey(const Key('result-loading')), findsOneWidget);
    expect(ai.calls, isEmpty);

    db.lookupGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(ai.calls.map((c) => c.classId), [2]);
  });
}
