import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// T16: the dashboard counted scans by class *name* while the database stores
/// the full disease name, so NCLB/Rust/GLS always showed 0.
ScanRecord _scan(int classId, String className, {DateTime? at}) => ScanRecord(
      imagePath: 'scans/x.jpg',
      classId: classId,
      className: className,
      shortName: className,
      confidence: 0.9,
      allScores: const [0.1, 0.2, 0.3, 0.4],
      latencyMs: 30,
      scannedAt: at ?? DateTime.now().toUtc(),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;

  setUp(() async {
    db = DatabaseService.forTesting();
    await db.init(path: inMemoryDatabasePath);
  });

  // sqflite reuses an open in-memory database for the same path.
  tearDown(() => db.close());

  test('counts every disease class, not just Healthy', () async {
    await db.insertScan(_scan(0, 'Northern Corn Leaf Blight'));
    await db.insertScan(_scan(1, 'Common Rust'));
    await db.insertScan(_scan(3, 'Healthy'));
    await db.insertScan(_scan(3, 'Healthy'));

    final stats = await db.farmStats();

    expect(stats.total, 4);
    expect(stats.countFor(0), 1);
    expect(stats.countFor(1), 1);
    expect(stats.countFor(2), 0);
    expect(stats.countFor(3), 2);
    expect(stats.shareOf(0), closeTo(0.25, 0.001));
    expect(stats.healthRate, closeTo(0.5, 0.001));
  });

  test('an empty farm has no health score to show', () async {
    final stats = await db.farmStats();

    expect(stats.total, 0);
    expect(stats.healthRate, isNull); // UI shows an empty state, not 100%
  });

  test('daily buckets use local days, not UTC days', () async {
    final instant = DateTime.now().toUtc().subtract(const Duration(days: 1));
    await db.insertScan(_scan(1, 'Common Rust', at: instant));

    final daily = await db.getDailyScans(days: 7);

    final localKey = DateFormat('yyyy-MM-dd').format(instant.toLocal());
    expect(daily[localKey], 1, reason: 'bucketed under ${daily.keys.toList()}');
  });
}
