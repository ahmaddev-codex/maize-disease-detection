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

/// T24: reopening a scan called Groq again, and the new wording missed the
/// speech cache, so the farmer paid twice to hear the same advice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const scanId = 7;
  late Directory tmp;
  late FakeDatabaseService db;
  late FakeAiAdvisor ai;
  late ProviderContainer container;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  ScanRecord rustScan({String? advice, String? language}) => ScanRecord(
        id: scanId,
        imagePath: '${tmp.path}/rust.jpg',
        classId: 1,
        className: 'Common Rust',
        shortName: 'Rust',
        confidence: 0.91,
        allScores: const [0.03, 0.91, 0.03, 0.03],
        latencyMs: 40,
        cropVariety: 'SAMMAZ 15',
        scannedAt: DateTime.utc(2026, 9, 10, 9),
        aiAdvice: advice,
        aiLanguage: language,
        aiSource: advice == null ? null : 'groq',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('advice_cache');
    File('${tmp.path}/rust.jpg').writeAsBytesSync([0]);

    db = FakeDatabaseService({scanId: rustScan()});
    ai = FakeAiAdvisor();
    container = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(db),
      aiAdvisorProvider.overrideWithValue(ai),
    ]);
  });

  tearDown(() async {
    container.dispose();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<void> pumpResult(WidgetTester tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ResultScreen()),
      GoRoute(path: '/result', builder: (_, __) => const ResultScreen()),
      GoRoute(path: '/camera', builder: (_, __) => const SizedBox()),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);
  }

  testWidgets('advice generated for a scan is stored with it', (tester) async {
    container.read(activeScanIdProvider.notifier).state = scanId;
    await pumpResult(tester);

    expect(ai.calls, hasLength(1));
    expect(db.adviceWrites, hasLength(1));
    expect(db.adviceWrites.single.language, 'English');
    expect(db.adviceWrites.single.source, 'groq');
    expect(db.records[scanId]!.aiAdvice, 'Advice for class 1');
  });

  testWidgets('reopening a scan spends nothing: the saved advice is shown', (tester) async {
    db.records[scanId] = rustScan(
      advice: 'Apply a triazole and scout again in five days.',
      language: 'English',
    );

    container.read(activeScanIdProvider.notifier).state = scanId;
    await pumpResult(tester);

    expect(ai.calls, isEmpty, reason: 'the advisor was called for advice already on disk');

    // The advice card is far down the page, so scroll it into the tree.
    final advice = find.textContaining('Apply a triazole');
    await tester.scrollUntilVisible(advice, 400,
        scrollable: find.byType(Scrollable).first, maxScrolls: 40);
    await settle(tester);
    expect(advice, findsWidgets);
  });

  testWidgets('advice saved in another language is not shown as this one', (tester) async {
    db.records[scanId] = rustScan(advice: 'Yi amfani da maganin fungi.', language: 'Hausa');

    container.read(activeScanIdProvider.notifier).state = scanId;
    await pumpResult(tester);

    expect(ai.calls, hasLength(1), reason: 'English advice must not come from a Hausa cache');
  });
}
