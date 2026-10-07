import 'dart:io';

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

/// T29: the app claimed more than it can show. Nothing here is verified by an
/// agronomist, the model is not "validated in the field", and the app does not
/// work fully offline (advice and local-language voice both need the network).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Claims the app cannot support. Each entry is matched case-insensitively
  // against every Dart source under lib/.
  const bannedPhrases = [
    'Offline Verified',
    'Verified by MaizeGuard',
    'Agronomist Verification',
    'works fully offline',
    'Field Validation',
    'Optimized for direct sunlight',
    'verified agronomic',
  ];

  test('no shipped screen makes a claim the app cannot back', () {
    final offences = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final phrase in bannedPhrases) {
          if (lines[i].toLowerCase().contains(phrase.toLowerCase())) {
            offences.add('${entity.path}:${i + 1} — "$phrase"');
          }
        }
      }
    }
    expect(offences, isEmpty, reason: offences.join('\n'));
  });

  testWidgets('the feedback prompt asks a question, and fits a small screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final record = ScanRecord(
      id: 1,
      imagePath: '',
      classId: 1,
      className: 'Common Rust',
      shortName: 'Rust',
      confidence: 0.91,
      allScores: const [0.03, 0.91, 0.03, 0.03],
      latencyMs: 40,
      scannedAt: DateTime.utc(2026, 9, 10, 9),
    );
    final container = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(FakeDatabaseService({1: record})),
      aiAdvisorProvider.overrideWithValue(FakeAiAdvisor()),
    ]);
    addTearDown(container.dispose);
    container.read(activeScanIdProvider.notifier).state = 1;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, __) => const ResultScreen()),
            GoRoute(path: '/camera', builder: (_, __) => const SizedBox()),
          ]),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final question = find.textContaining('Was this diagnosis right?');
    await tester.scrollUntilVisible(question, 400,
        scrollable: find.byType(Scrollable).first, maxScrolls: 40);
    await tester.pump(const Duration(milliseconds: 20));

    expect(question, findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'the copy overflowed at 320px');
  });
}
