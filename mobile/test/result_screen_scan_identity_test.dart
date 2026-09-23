import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/providers/app_provider.dart';
import 'package:maizeguard/providers/service_providers.dart';
import 'package:maizeguard/screens/history_screen.dart';
import 'package:maizeguard/screens/home_screen.dart';
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

class _FixedScanList extends ScanListNotifier {
  _FixedScanList(List<ScanRecord> scans) {
    state = scans;
  }

  @override
  Future<void> load({int? classFilter}) async {}
}

Iterable<String> _shownImagePaths(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((image) => image.image)
    .whereType<FileImage>()
    .map((fileImage) => fileImage.file.path);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  late Directory tmp;
  late ScanRecord scanA;
  late ScanRecord scanB;
  late FakeDatabaseService db;
  late FakeAiAdvisor ai;
  late ProviderContainer container;

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

    db = FakeDatabaseService({1: scanA, 2: scanB});
    ai = FakeAiAdvisor();
    container = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(db),
      aiAdvisorProvider.overrideWithValue(ai),
      scanListProvider.overrideWith((ref) => _FixedScanList([scanB, scanA])),
    ]);
  });

  tearDown(() {
    container.dispose();
    tmp.deleteSync(recursive: true);
  });

  Future<void> pumpRoutes(WidgetTester tester, Widget start) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => start),
      GoRoute(path: '/result', builder: (_, __) => const ResultScreen()),
      GoRoute(path: '/camera', builder: (_, __) => const SizedBox()),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _settle(tester);
  }

  testWidgets('switching the active scan from A to B shows and advises on B', (tester) async {
    container.read(activeScanIdProvider.notifier).state = 1;
    await pumpRoutes(tester, const ResultScreen());
    expect(ai.calls.map((c) => c.classId), [1]);

    container.read(activeScanIdProvider.notifier).state = 2;
    await _settle(tester);

    expect(ai.calls.map((c) => c.classId), [1, 2]);
    expect(ai.calls.last.cropVariety, 'OBA SUPER 2');
    expect(_shownImagePaths(tester), contains(scanB.imagePath));
    expect(_shownImagePaths(tester), isNot(contains(scanA.imagePath)));
  });

  testWidgets('nothing is fetched while the scan record is still loading', (tester) async {
    db.lookupGate = Completer<void>();
    container.read(activeScanIdProvider.notifier).state = 2;
    await pumpRoutes(tester, const ResultScreen());

    expect(find.byKey(const Key('result-loading')), findsOneWidget);
    expect(ai.calls, isEmpty);

    db.lookupGate!.complete();
    await _settle(tester);

    expect(ai.calls.map((c) => c.classId), [2]);
  });

  testWidgets('tapping a History record opens that scan', (tester) async {
    await pumpRoutes(tester, const HistoryScreen());

    await tester.ensureVisible(find.text('Gray Leaf Spot'));
    await _settle(tester);
    await tester.tap(find.text('Gray Leaf Spot'));
    await _settle(tester);

    expect(container.read(activeScanIdProvider), 2);
    expect(ai.calls.map((c) => c.classId), [2]);
  });

  testWidgets('tapping a recent scan on Home opens that scan', (tester) async {
    await pumpRoutes(tester, const HomeScreen());

    // Recent scans sit below the fold in the test viewport; scroll until the row
    // exists, then bring it fully on screen so the tap lands on it.
    await tester.scrollUntilVisible(find.text('Common Rust'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Common Rust'));
    await _settle(tester);
    await tester.tap(find.text('Common Rust'));
    await _settle(tester);

    expect(container.read(activeScanIdProvider), 1);
    expect(ai.calls.map((c) => c.classId), [1]);
  });
}
