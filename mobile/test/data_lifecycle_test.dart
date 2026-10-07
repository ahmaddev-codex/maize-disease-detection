import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/providers/app_provider.dart';
import 'package:maizeguard/providers/service_providers.dart';
import 'package:maizeguard/services/database_service.dart';
import 'package:maizeguard/services/scan_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// T21: a deleted or purged scan must take its captured image — and the
/// synthesized speech recorded for it — off the device, not just its row.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory scansDir;
  late DatabaseService db;
  late int audioCacheClears;
  late ScanStorage storage;

  ScanRecord recordFor(String imagePath) => ScanRecord(
        imagePath: imagePath,
        classId: 3,
        className: 'Healthy',
        shortName: 'Healthy',
        confidence: 0.91,
        allScores: const [0.03, 0.03, 0.03, 0.91],
        latencyMs: 120,
        scannedAt: DateTime.now().toUtc(),
      );

  Future<File> captureFile(String name) async {
    final file = File('${scansDir.path}/$name');
    await file.writeAsBytes(List<int>.filled(64, 7));
    return file;
  }

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('maizeguard_lifecycle');
    scansDir = await Directory('${tempRoot.path}/scans').create(recursive: true);
    audioCacheClears = 0;
    storage = ScanStorage(
      scansDir: scansDir,
      clearAudioCache: () async => audioCacheClears++,
    );
    db = DatabaseService.forTesting();
    await db.init(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
    if (tempRoot.existsSync()) await tempRoot.delete(recursive: true);
  });

  test('deleting a scan removes its captured image, not only the row', () async {
    final image = await captureFile('capture.jpg');
    final scans = ScanListNotifier(db, storage: storage);
    final id = await scans.add(recordFor(image.path));

    await scans.delete(id);

    expect(image.existsSync(), isFalse, reason: 'the image outlived its record');
    expect(await db.getScanById(id), isNull);
    expect(scans.state, isEmpty);
  });

  test('deleting the scan being viewed clears the active scan', () async {
    final image = await captureFile('active.jpg');
    final container = ProviderContainer(overrides: [
      databaseServiceProvider.overrideWithValue(db),
      scanStorageProvider.overrideWithValue(storage),
    ]);
    addTearDown(container.dispose);

    final scans = container.read(scanListProvider.notifier);
    final id = await scans.add(recordFor(image.path));
    container.read(activeScanIdProvider.notifier).state = id;

    await scans.delete(id);

    expect(container.read(activeScanIdProvider), isNull,
        reason: 'the result screen would still point at a deleted scan');
  });

  test('purging removes every capture and the cached speech', () async {
    final a = await captureFile('one.jpg');
    final b = await captureFile('two.jpg');
    final scans = ScanListNotifier(db, storage: storage);
    await scans.add(recordFor(a.path));
    await scans.add(recordFor(b.path));

    await scans.clear();

    expect(scansDir.listSync(), isEmpty, reason: 'captures survived the purge');
    expect(audioCacheClears, 1, reason: 'the audio cache was left behind');
    expect(await db.getScans(), isEmpty);
    expect(scans.state, isEmpty);
  });

  test('a capture whose diagnosis fails is cleaned up, and a missing file is not an error', () async {
    final orphan = await captureFile('failed.jpg');

    await storage.deleteImage(orphan.path);
    expect(orphan.existsSync(), isFalse);

    // Deleting it a second time (or a file already gone) must not throw.
    await storage.deleteImage(orphan.path);
    await storage.deleteImage('${scansDir.path}/never-existed.jpg');
    await storage.deleteImage('');
  });
}
