import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_record.dart';
import '../services/database_service.dart';

// ── Scan history ──────────────────────────────────────────────────────────────
final scanListProvider = StateNotifierProvider<ScanListNotifier, List<ScanRecord>>(
  (ref) => ScanListNotifier(),
);

class ScanListNotifier extends StateNotifier<List<ScanRecord>> {
  ScanListNotifier() : super([]);

  Future<void> load({int? classFilter}) async {
    state = await DatabaseService.instance.getScans(classIdFilter: classFilter);
  }

  Future<void> add(ScanRecord record) async {
    final id = await DatabaseService.instance.insertScan(record);
    final saved = ScanRecord(
      id: id, imagePath: record.imagePath, classId: record.classId,
      className: record.className, shortName: record.shortName,
      confidence: record.confidence, allScores: record.allScores,
      latencyMs: record.latencyMs, latitude: record.latitude,
      longitude: record.longitude, cropVariety: record.cropVariety,
      batchNumber: record.batchNumber, plantingDate: record.plantingDate,
      scannedAt: record.scannedAt, notes: record.notes,
    );
    state = [saved, ...state];
  }

  Future<void> delete(int id) async {
    await DatabaseService.instance.deleteScan(id);
    state = state.where((r) => r.id != id).toList();
  }
}

// ── Last classification result ─────────────────────────────────────────────────
final lastResultProvider       = StateProvider<ClassificationResult?>((ref) => null);
final lastImagePathProvider    = StateProvider<String?>((ref) => null);
// Crop variety from the scan that produced lastResultProvider (not scans.first)
final lastScanVarietyProvider  = StateProvider<String?>((ref) => null);

// ── Pending OCR fields (from seed label scan, linked to next disease scan) ─────
final pendingOcrProvider = StateProvider<OcrFields?>((ref) => null);

// ── Theme ──────────────────────────────────────────────────────────────────────
final isDarkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>(
  (ref) => DarkModeNotifier(),
);

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('dark_mode') ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', state);
  }
}

// ── Gemini API key ─────────────────────────────────────────────────────────────
final geminiKeyProvider = StateNotifierProvider<GeminiKeyNotifier, String?>(
  (ref) => GeminiKeyNotifier(),
);

class GeminiKeyNotifier extends StateNotifier<String?> {
  GeminiKeyNotifier() : super(null) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _key     = 'gemini_api_key';

  Future<void> _load() async {
    state = await _storage.read(key: _key);
  }

  Future<void> save(String key) async {
    await _storage.write(key: _key, value: key);
    state = key;
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
    state = null;
  }
}

// ── Classifier readiness ───────────────────────────────────────────────────────
final classifierReadyProvider = StateProvider<bool>((ref) => false);

// ── Health trend (delta health rate: >0.1 improving, <-0.1 worsening) ─────────
final healthTrendProvider = FutureProvider<double>((ref) async {
  ref.watch(scanListProvider);
  return DatabaseService.instance.getHealthTrend();
});
