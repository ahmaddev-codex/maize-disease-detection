import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_record.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'maizeguard.db'),
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
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
        ''');
        await db.execute('CREATE INDEX idx_scanned_at ON scan_records(scanned_at DESC)');
        await db.execute('CREATE INDEX idx_class_id ON scan_records(class_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE scan_records ADD COLUMN feedback INTEGER');
        }
      },
    );
  }

  Database get _database {
    if (_db == null) throw StateError('DatabaseService not initialised — call init() first');
    return _db!;
  }

  Future<int> insertScan(ScanRecord record) async {
    return _database.insert('scan_records', record.toMap());
  }

  Future<List<ScanRecord>> getScans({int? classIdFilter, int limit = 500}) async {
    final where = classIdFilter != null ? 'class_id = ?' : null;
    final args  = classIdFilter != null ? [classIdFilter] : null;
    final rows  = await _database.query(
      'scan_records',
      where: where,
      whereArgs: args,
      orderBy: 'scanned_at DESC',
      limit: limit,
    );
    return rows.map(ScanRecord.fromMap).toList();
  }

  Future<ScanRecord?> getScanById(int id) async {
    final rows = await _database.query(
      'scan_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ScanRecord.fromMap(rows.first);
  }

  Future<List<ScanRecord>> getScansInRange(DateTime from, DateTime to) async {
    final rows = await _database.query(
      'scan_records',
      where: 'scanned_at >= ? AND scanned_at <= ?',
      whereArgs: [from.toUtc().toIso8601String(), to.toUtc().toIso8601String()],
      orderBy: 'scanned_at DESC',
    );
    return rows.map(ScanRecord.fromMap).toList();
  }

  Future<void> deleteScan(int id) async {
    await _database.delete('scan_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateNotes(int id, String notes) async {
    await _database.update(
      'scan_records',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // feedback: 1 = correct, 0 = incorrect, -1 = unsure
  Future<void> updateFeedback(int id, int feedback) async {
    await _database.update(
      'scan_records',
      {'feedback': feedback},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getClassCounts({int days = 30}) async {
    final since = DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();
    final rows = await _database.rawQuery('''
      SELECT class_name, COUNT(*) as cnt
      FROM scan_records
      WHERE scanned_at >= ?
      GROUP BY class_name
    ''', [since]);
    return {for (final r in rows) r['class_name'] as String: r['cnt'] as int};
  }

  Future<void> clearAll() async {
    await _database.delete('scan_records');
  }

  // Returns scan count per day for the last [days] days (for the bar chart)
  Future<Map<String, int>> getDailyScans({int days = 7}) async {
    final since = DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();
    final rows = await _database.rawQuery('''
      SELECT substr(scanned_at, 1, 10) as day, COUNT(*) as cnt
      FROM scan_records
      WHERE scanned_at >= ?
      GROUP BY day
      ORDER BY day ASC
    ''', [since]);
    return {for (final r in rows) r['day'] as String: r['cnt'] as int};
  }

  // Returns health rate change: positive = improving, negative = worsening.
  // Compares healthy% in last 7 days vs 7–14 days ago.
  Future<double> getHealthTrend() async {
    final now   = DateTime.now().toUtc();
    final week1 = now.subtract(const Duration(days: 7)).toIso8601String();
    final week2 = now.subtract(const Duration(days: 14)).toIso8601String();

    Future<double?> rate(String from, String? to) async {
      final clause = to != null
          ? 'scanned_at >= ? AND scanned_at < ?'
          : 'scanned_at >= ?';
      final args = to != null ? [from, to] : [from];
      final r = await _database.rawQuery('''
        SELECT COUNT(*) as total,
               SUM(CASE WHEN class_id = 3 THEN 1 ELSE 0 END) as healthy
        FROM scan_records WHERE $clause
      ''', args);
      final total   = (r.first['total']   as int?) ?? 0;
      final healthy = (r.first['healthy'] as int?) ?? 0;
      if (total == 0) return null;
      return healthy / total;
    }

    final recent = await rate(week1, null);
    final older  = await rate(week2, week1);
    if (recent == null || older == null) return 0.0;
    return recent - older; // positive = improving, negative = worsening
  }
}
