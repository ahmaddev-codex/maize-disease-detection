import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/providers/app_provider.dart';
import 'package:maizeguard/providers/service_providers.dart';
import 'package:maizeguard/screens/result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_services.dart';

/// T22: the result screen always jumped to Home, so opening a scan from History
/// and going back lost your place; a low-confidence scan asked for a retake with
/// no way to take one.
ScanRecord _scan({required int id, double confidence = 0.92}) => ScanRecord(
      id: id,
      imagePath: 'scans/missing.jpg',
      classId: 2,
      className: 'Gray Leaf Spot',
      shortName: 'GLS',
      confidence: confidence,
      allScores: const [0.04, 0.04, 0.88, 0.04],
      latencyMs: 30,
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

  Future<GoRouter> pump(WidgetTester tester, ScanRecord scan, {required String start}) async {
    final container = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(FakeDatabaseService({scan.id!: scan})),
      aiAdvisorProvider.overrideWithValue(FakeAiAdvisor()),
    ]);
    addTearDown(container.dispose);
    container.read(activeScanIdProvider.notifier).state = scan.id;

    final router = GoRouter(initialLocation: start, routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('HOME')),
      GoRoute(path: '/history', builder: (_, __) => const Text('HISTORY')),
      GoRoute(path: '/camera', builder: (_, __) => const Text('CAMERA')),
      GoRoute(path: '/result', builder: (_, __) => const ResultScreen()),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await _settle(tester);
    return router;
  }

  testWidgets('back returns to the screen the scan was opened from', (tester) async {
    final router = await pump(tester, _scan(id: 1), start: '/history');
    router.push('/result');
    await _settle(tester);
    expect(find.text('Gray Leaf Spot'), findsWidgets);

    await tester.tap(find.byKey(const Key('result-back')));
    await _settle(tester);

    expect(find.text('HISTORY'), findsOneWidget);
  });

  testWidgets('back falls through to Home when there is nothing to pop', (tester) async {
    await pump(tester, _scan(id: 2), start: '/result');

    await tester.tap(find.byKey(const Key('result-back')));
    await _settle(tester);

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a low-confidence result offers a retake that opens the camera', (tester) async {
    await pump(tester, _scan(id: 3, confidence: 0.42), start: '/result');

    final retake = find.byKey(const Key('result-retake'));
    await tester.ensureVisible(retake);
    await _settle(tester);
    await tester.tap(retake);
    await _settle(tester);

    expect(find.text('CAMERA'), findsOneWidget);
  });
}
