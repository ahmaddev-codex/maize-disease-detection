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
import 'package:maizeguard/services/database_service.dart';
import 'package:maizeguard/services/scan_flow.dart';
import 'package:maizeguard/services/scan_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_services.dart';

/// T48: the journey a farmer actually takes, end to end, with fake services:
/// scan a seed label, take a photo, read the result, find it again in history,
/// delete it. Each step is covered in isolation elsewhere; this test exists to
/// catch the seams between them.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late Directory scansDir;
  late DatabaseService db;
  late ScanStorage storage;
  late FakeClassifierService classifier;
  late FakeAiAdvisor advisor;
  late ProviderContainer container;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('critical_path');
    scansDir = await Directory('${tmp.path}/scans').create(recursive: true);

    db = DatabaseService.forTesting();
    await db.init(path: inMemoryDatabasePath);
    storage = ScanStorage(scansDir: scansDir, clearAudioCache: () async {});
    classifier = FakeClassifierService(
      result: const ClassificationResult(
        classId: 1,
        className: 'Common Rust',
        shortName: 'Rust',
        confidence: 0.93,
        allScores: [0.02, 0.93, 0.03, 0.02],
        latencyMs: 180,
      ),
    );
    advisor = FakeAiAdvisor();

    container = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(db),
      scanStorageProvider.overrideWithValue(storage),
      classifierServiceProvider.overrideWithValue(classifier),
      aiAdvisorProvider.overrideWithValue(advisor),
      locationServiceProvider.overrideWithValue(FakeLocationService()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 400,
        scrollable: find.byType(Scrollable).first, maxScrolls: 40);
    await settle(tester);
  }

  test('a scan carries its seed label into storage, and delete removes both', () async {
    // ── 1. The seed label scanned before the photo is held for the next scan.
    const label = OcrFields(
      cropVariety: 'SAMMAZ 15',
      batchNumber: 'BN-2024-042',
      plantingDate: '2024-03-15',
      rawText: 'SAMMAZ 15 BN-2024-042 2024-03-15',
    );
    container.read(pendingOcrProvider.notifier).state = label;

    // ── 2. A capture is classified and saved with that label attached.
    final imageFile = File('${scansDir.path}/capture.jpg')
      ..writeAsBytesSync(List<int>.filled(32, 3));
    final result = await classifier.classify(imageFile.path);
    final saved = await saveScan(
      imagePath: imageFile.path,
      result: result,
      pending: container.read(pendingOcrProvider),
      scans: container.read(scanListProvider.notifier),
      location: container.read(locationServiceProvider),
      db: db,
    );
    await saved.locationAttached;
    container.read(pendingOcrProvider.notifier).state = null;

    final stored = await db.getScanById(saved.id);
    expect(stored!.className, 'Common Rust');
    expect(stored.cropVariety, 'SAMMAZ 15');
    expect(stored.batchNumber, 'BN-2024-042');

    // ── 3. History lists it, and it is the scan the list opens.
    await container.read(scanListProvider.notifier).load();
    expect(container.read(scanListProvider).single.id, saved.id);
    container.read(activeScanIdProvider.notifier).state = saved.id;

    // ── 4. Deleting it removes the record, the photo and the active scan.
    await container.read(scanListProvider.notifier).delete(saved.id);

    expect(await db.getScanById(saved.id), isNull);
    expect(imageFile.existsSync(), isFalse, reason: 'the photo outlived the record');
    expect(container.read(activeScanIdProvider), isNull);
    expect(container.read(scanListProvider), isEmpty);
  });

  testWidgets('the result screen shows the diagnosis, the seed label and a source',
      (tester) async {
    // The screens run against the in-memory fake: a real database future never
    // completes under testWidgets' fake clock.
    const scanId = 11;
    final imageFile = File('${scansDir.path}/shown.jpg')
      ..writeAsBytesSync(List<int>.filled(32, 3));
    final record = ScanRecord(
      id: scanId,
      imagePath: imageFile.path,
      classId: 1,
      className: 'Common Rust',
      shortName: 'Rust',
      confidence: 0.93,
      allScores: const [0.02, 0.93, 0.03, 0.02],
      latencyMs: 180,
      cropVariety: 'SAMMAZ 15',
      batchNumber: 'BN-2024-042',
      plantingDate: '2024-03-15',
      scannedAt: DateTime.utc(2026, 9, 24, 8),
    );
    final fakeDb = FakeDatabaseService({scanId: record});
    final screenContainer = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(fakeDb),
      aiAdvisorProvider.overrideWithValue(advisor),
      classifierServiceProvider.overrideWithValue(classifier),
      locationServiceProvider.overrideWithValue(FakeLocationService()),
    ]);
    addTearDown(screenContainer.dispose);
    screenContainer.read(activeScanIdProvider.notifier).state = scanId;

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ResultScreen()),
      GoRoute(path: '/result', builder: (_, __) => const ResultScreen()),
      GoRoute(path: '/camera', builder: (_, __) => const SizedBox()),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: screenContainer,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);

    expect(find.textContaining('Common Rust'), findsWidgets);

    await scrollTo(tester, find.byKey(const Key('result-seed-label')));
    expect(find.textContaining('SAMMAZ 15'), findsWidgets);

    await scrollTo(tester, find.byKey(const Key('result-advice-source')));
    expect(tester.widget<Text>(find.byKey(const Key('result-advice-source'))).data,
        isNotEmpty);
    expect(advisor.calls, hasLength(1), reason: 'advice should be fetched once');
    expect(fakeDb.adviceWrites, hasLength(1), reason: 'advice should be stored with the scan');
  });

  testWidgets('a scan with no seed label shows no seed card', (tester) async {
    const scanId = 12;
    final fakeDb = FakeDatabaseService({
      scanId: ScanRecord(
        id: scanId,
        imagePath: '',
        classId: 1,
        className: 'Common Rust',
        shortName: 'Rust',
        confidence: 0.93,
        allScores: const [0.02, 0.93, 0.03, 0.02],
        latencyMs: 180,
        scannedAt: DateTime.utc(2026, 9, 24, 8),
      )
    });
    final screenContainer = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(fakeDb),
      aiAdvisorProvider.overrideWithValue(advisor),
      locationServiceProvider.overrideWithValue(FakeLocationService()),
    ]);
    addTearDown(screenContainer.dispose);
    screenContainer.read(activeScanIdProvider.notifier).state = scanId;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: screenContainer,
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, __) => const ResultScreen()),
            GoRoute(path: '/camera', builder: (_, __) => const SizedBox()),
          ]),
        ),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('result-seed-label')), findsNothing);
    expect(find.textContaining('Common Rust'), findsWidgets);
  });
}
