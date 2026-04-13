import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

part 'database.g.dart';

// ── Table definition ──────────────────────────────────────────────────────────

class ScanRecords extends Table {
  IntColumn    get id          => integer().autoIncrement()();
  TextColumn   get imagePath   => text()();
  IntColumn    get classId     => integer()();
  TextColumn   get className   => text()();
  TextColumn   get shortName   => text()();
  RealColumn   get confidence  => real()();
  TextColumn   get allScores   => text()();        // JSON: "[0.1,0.7,0.1,0.1]"
  RealColumn   get latencyMs   => real()();
  RealColumn   get latitude    => real().nullable()();
  RealColumn   get longitude   => real().nullable()();
  TextColumn   get cropVariety => text().nullable()();
  TextColumn   get batchNumber => text().nullable()();
  TextColumn   get plantingDate=> text().nullable()();
  DateTimeColumn get scannedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn   get notes       => text().nullable()();
}

// ── DAO ───────────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [ScanRecords])
class ScanDao extends DatabaseAccessor<AppDatabase> with _$ScanDaoMixin {
  ScanDao(super.db);

  // Insert a new scan; returns the inserted row id.
  Future<int> insertScan(ScanRecordsCompanion entry) =>
      into(scanRecords).insert(entry);

  // All scans, newest first.
  Future<List<ScanRecord>> allScans() =>
      (select(scanRecords)..orderBy([(t) => OrderingTerm.desc(t.scannedAt)]))
          .get();

  // Watch all scans (live stream for the history screen).
  Stream<List<ScanRecord>> watchAllScans() =>
      (select(scanRecords)..orderBy([(t) => OrderingTerm.desc(t.scannedAt)]))
          .watch();

  // Most recent N scans for the dashboard strip.
  Future<List<ScanRecord>> recentScans({int limit = 10}) =>
      (select(scanRecords)
            ..orderBy([(t) => OrderingTerm.desc(t.scannedAt)])
            ..limit(limit))
          .get();

  // Scans filtered by class id.
  Stream<List<ScanRecord>> watchByClass(int classId) =>
      (select(scanRecords)
            ..where((t) => t.classId.equals(classId))
            ..orderBy([(t) => OrderingTerm.desc(t.scannedAt)]))
          .watch();

  // Scans in the last [days] days.
  Future<List<ScanRecord>> scansInLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (select(scanRecords)
          ..where((t) => t.scannedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([(t) => OrderingTerm.asc(t.scannedAt)]))
        .get();
  }

  // Delete a single scan record (and caller should delete the image file too).
  Future<int> deleteScan(int id) =>
      (delete(scanRecords)..where((t) => t.id.equals(id))).go();

  // Update notes on a scan.
  Future<bool> updateNotes(int id, String notes) =>
      (update(scanRecords)..where((t) => t.id.equals(id)))
          .write(ScanRecordsCompanion(notes: Value(notes)))
          .then((n) => n > 0);
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [ScanRecords], daos: [ScanDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'maizeguard.db',
      web: kIsWeb
          ? DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
            )
          : null,
    );
  }

  // Convenience singleton so every widget can share one connection.
  static final AppDatabase instance = AppDatabase();
}

// ── Helper: build a ScanRecordsCompanion from domain objects ─────────────────

ScanRecordsCompanion buildScanEntry({
  required String imagePath,
  required int classId,
  required String className,
  required String shortName,
  required double confidence,
  required List<double> allScores,
  required double latencyMs,
  double? latitude,
  double? longitude,
  String? cropVariety,
  String? batchNumber,
  String? plantingDate,
}) {
  return ScanRecordsCompanion(
    imagePath:    Value(imagePath),
    classId:      Value(classId),
    className:    Value(className),
    shortName:    Value(shortName),
    confidence:   Value(confidence),
    allScores:    Value('[${allScores.join(',')}]'),
    latencyMs:    Value(latencyMs),
    latitude:     Value(latitude),
    longitude:    Value(longitude),
    cropVariety:  Value(cropVariety),
    batchNumber:  Value(batchNumber),
    plantingDate: Value(plantingDate),
  );
}
