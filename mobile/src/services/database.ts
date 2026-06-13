/**
 * SQLite persistence layer using op-sqlite v16.
 * Schema mirrors Flutter's Drift ScanRecords table exactly.
 */
import {open, DB} from '@op-engineering/op-sqlite';
import {ScanRecord} from '../types/scanRecord';
import {Prediction, SeedLabelData} from '../types/prediction';

const DB_NAME = 'maizeguard.db';
let _db: DB | null = null;

function getDb(): DB {
  if (!_db) {
    throw new Error('Database not initialized. Call initDatabase() first.');
  }
  return _db;
}

export async function initDatabase(): Promise<void> {
  _db = open({name: DB_NAME});
  await _db.execute(`
    CREATE TABLE IF NOT EXISTS scan_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      image_path TEXT NOT NULL,
      class_id INTEGER NOT NULL,
      class_name TEXT NOT NULL,
      short_name TEXT NOT NULL,
      confidence REAL NOT NULL,
      all_scores TEXT NOT NULL,
      latency_ms REAL NOT NULL,
      latitude REAL,
      longitude REAL,
      crop_variety TEXT,
      batch_number TEXT,
      planting_date TEXT,
      scanned_at TEXT NOT NULL DEFAULT (datetime('now')),
      notes TEXT
    );
  `);
  await _db.execute(
    `CREATE INDEX IF NOT EXISTS idx_scanned_at ON scan_records(scanned_at DESC);`,
  );
  await _db.execute(
    `CREATE INDEX IF NOT EXISTS idx_class_id ON scan_records(class_id);`,
  );
}

export async function insertScan(
  imagePath: string,
  prediction: Prediction,
  location: {latitude: number; longitude: number} | null,
  label: SeedLabelData | null,
): Promise<number> {
  const result = await getDb().execute(
    `INSERT INTO scan_records
      (image_path, class_id, class_name, short_name, confidence, all_scores,
       latency_ms, latitude, longitude, crop_variety, batch_number, planting_date)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      imagePath,
      prediction.classId,
      prediction.className,
      prediction.shortName,
      prediction.confidence,
      JSON.stringify(prediction.allScores),
      prediction.latencyMs,
      location?.latitude ?? null,
      location?.longitude ?? null,
      label?.cropVariety ?? null,
      label?.batchNumber ?? null,
      label?.plantingDate ?? null,
    ],
  );
  return result.insertId ?? 0;
}

export async function allScans(): Promise<ScanRecord[]> {
  const result = await getDb().execute(
    'SELECT * FROM scan_records ORDER BY scanned_at DESC',
  );
  return (result.rows ?? []).map(rowToScanRecord);
}

export async function recentScans(limit: number): Promise<ScanRecord[]> {
  const result = await getDb().execute(
    'SELECT * FROM scan_records ORDER BY scanned_at DESC LIMIT ?',
    [limit],
  );
  return (result.rows ?? []).map(rowToScanRecord);
}

export async function scansInLastDays(days: number): Promise<ScanRecord[]> {
  const result = await getDb().execute(
    `SELECT * FROM scan_records
     WHERE scanned_at >= datetime('now', ?)
     ORDER BY scanned_at DESC`,
    [`-${days} days`],
  );
  return (result.rows ?? []).map(rowToScanRecord);
}

export async function scansByClass(classId: number): Promise<ScanRecord[]> {
  const result = await getDb().execute(
    'SELECT * FROM scan_records WHERE class_id = ? ORDER BY scanned_at DESC',
    [classId],
  );
  return (result.rows ?? []).map(rowToScanRecord);
}

export async function deleteScan(id: number): Promise<void> {
  await getDb().execute('DELETE FROM scan_records WHERE id = ?', [id]);
}

export async function updateNotes(id: number, notes: string): Promise<void> {
  await getDb().execute(
    'UPDATE scan_records SET notes = ? WHERE id = ?',
    [notes, id],
  );
}

export async function getScanById(id: number): Promise<ScanRecord | null> {
  const result = await getDb().execute(
    'SELECT * FROM scan_records WHERE id = ?',
    [id],
  );
  const rows = result.rows ?? [];
  return rows.length > 0 ? rowToScanRecord(rows[0]) : null;
}

function rowToScanRecord(row: Record<string, unknown>): ScanRecord {
  return {
    id: row.id as number,
    imagePath: row.image_path as string,
    classId: row.class_id as number,
    className: row.class_name as string,
    shortName: row.short_name as string,
    confidence: row.confidence as number,
    allScores: JSON.parse(row.all_scores as string),
    latencyMs: row.latency_ms as number,
    latitude: row.latitude as number | undefined,
    longitude: row.longitude as number | undefined,
    cropVariety: row.crop_variety as string | undefined,
    batchNumber: row.batch_number as string | undefined,
    plantingDate: row.planting_date as string | undefined,
    scannedAt: row.scanned_at as string,
    notes: row.notes as string | undefined,
  };
}
