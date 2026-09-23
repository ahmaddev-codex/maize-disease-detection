import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// T24: advice is stored per scan, which needs a v3 schema. Farmers already
/// have v2 databases full of scans, so the upgrade has to be additive.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String dbPath;

  const v2Schema = '''
    CREATE TABLE scan_records (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      image_path    TEXT NOT NULL,
      class_id      INTEGER NOT NULL,
      class_name    TEXT NOT NULL,
      short_name    TEXT NOT NULL,
      confidence    REAL NOT NULL,
      all_scores    TEXT NOT NULL,
      latency_ms    REAL NOT NULL,
      latitude      REAL,
      longitude     REAL,
      crop_variety  TEXT,
      batch_number  TEXT,
      planting_date TEXT,
      scanned_at    TEXT NOT NULL,
      notes         TEXT,
      feedback      INTEGER
    )
  ''';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('maizeguard_migration');
    dbPath = '${tmp.path}/maizeguard.db';

    final legacy = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async => db.execute(v2Schema),
      ),
    );
    await legacy.insert('scan_records', {
      'image_path': 'scans/old.jpg',
      'class_id': 1,
      'class_name': 'Common Rust',
      'short_name': 'Rust',
      'confidence': 0.88,
      'all_scores': '[0.04,0.88,0.04,0.04]',
      'latency_ms': 210.0,
      'crop_variety': 'SAMMAZ 15',
      'scanned_at': DateTime.utc(2026, 8, 1, 7, 30).toIso8601String(),
      'notes': 'first outbreak of the season',
      'feedback': 1,
    });
    await legacy.close();
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('a v2 database upgrades to v3 with every row intact', () async {
    final db = DatabaseService.forTesting();
    await db.init(path: dbPath);
    addTearDown(db.close);

    final scans = await db.getScans();
    expect(scans, hasLength(1));
    final scan = scans.single;
    expect(scan.className, 'Common Rust');
    expect(scan.confidence, closeTo(0.88, 0.001));
    expect(scan.cropVariety, 'SAMMAZ 15');
    expect(scan.notes, 'first outbreak of the season');
    expect(scan.feedback, 1);

    // The new columns exist and are empty for scans made before the upgrade.
    expect(scan.aiAdvice, isNull);
    expect(scan.aiLanguage, isNull);
  });

  test('advice saved against an upgraded row reads back with its provenance', () async {
    final db = DatabaseService.forTesting();
    await db.init(path: dbPath);
    addTearDown(db.close);

    final id = (await db.getScans()).single.id!;
    await db.saveAdvice(
      id,
      advice: 'Scout the field twice this week.',
      language: 'English',
      source: 'groq',
      model: 'llama-3.3-70b-versatile',
    );

    final saved = await db.getScanById(id);
    expect(saved!.aiAdvice, 'Scout the field twice this week.');
    expect(saved.aiLanguage, 'English');
    expect(saved.aiSource, 'groq');
    expect(saved.aiModel, 'llama-3.3-70b-versatile');
    expect(saved.aiCreatedAt, isNotNull);
  });

  test('a fresh install creates v3 directly', () async {
    final freshPath = '${tmp.path}/fresh.db';
    final db = DatabaseService.forTesting();
    await db.init(path: freshPath);
    addTearDown(db.close);

    final id = await db.insertScan(ScanRecord(
      imagePath: 'scans/new.jpg',
      classId: 3,
      className: 'Healthy',
      shortName: 'Healthy',
      confidence: 0.95,
      allScores: const [0.02, 0.01, 0.02, 0.95],
      latencyMs: 180,
      scannedAt: DateTime.now().toUtc(),
    ));
    await db.saveAdvice(id, advice: 'Monitor only.', language: 'Hausa', source: 'offline');

    final saved = await db.getScanById(id);
    expect(saved!.aiAdvice, 'Monitor only.');
    expect(saved.aiLanguage, 'Hausa');
    expect(saved.aiSource, 'offline');
  });
}
