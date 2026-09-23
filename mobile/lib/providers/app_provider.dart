import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_env.dart';
import '../models/farm_stats.dart';
import '../models/scan_record.dart';
import '../services/database_service.dart';
import '../services/scan_storage.dart';
import 'service_providers.dart';

// ── Scan history ──────────────────────────────────────────────────────────────
final scanListProvider = StateNotifierProvider<ScanListNotifier, List<ScanRecord>>(
  (ref) => ScanListNotifier(
    ref.watch(databaseServiceProvider),
    storage: ref.watch(scanStorageProvider),
    ref: ref,
  ),
);

class ScanListNotifier extends StateNotifier<List<ScanRecord>> {
  ScanListNotifier(DatabaseService? db, {ScanStorage? storage, Ref? ref})
      : _db = db ?? DatabaseService.instance,
        _storage = storage ?? ScanStorage.instance,
        _ref = ref,
        super([]);

  final DatabaseService _db;
  final ScanStorage _storage;

  /// Present when built from [scanListProvider]; lets a delete or purge reset
  /// the scan the Result screen is pointing at (T21).
  final Ref? _ref;

  void _forgetActiveScan([int? onlyIfId]) {
    final ref = _ref;
    if (ref == null) return;
    if (onlyIfId != null && ref.read(activeScanIdProvider) != onlyIfId) return;
    ref.read(activeScanIdProvider.notifier).state = null;
  }

  Future<void> load({int? classFilter}) async {
    state = await _db.getScans(classIdFilter: classFilter);
  }

  Future<int> add(ScanRecord record) async {
    final id = await _db.insertScan(record);
    final saved = ScanRecord(
      id: id, imagePath: record.imagePath, classId: record.classId,
      className: record.className, shortName: record.shortName,
      confidence: record.confidence, allScores: record.allScores,
      latencyMs: record.latencyMs, latitude: record.latitude,
      longitude: record.longitude, cropVariety: record.cropVariety,
      batchNumber: record.batchNumber, plantingDate: record.plantingDate,
      scannedAt: record.scannedAt, notes: record.notes, feedback: record.feedback,
    );
    state = [saved, ...state];
    return id;
  }

  Future<void> setFeedback(int id, int feedback) async {
    await _db.updateFeedback(id, feedback);
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(feedback: feedback) else r,
    ];
  }

  Future<void> delete(int id) async {
    // Read the path before the row goes, or the image can never be found.
    final record = await _db.getScanById(id);
    await _db.deleteScan(id);
    if (record != null) await _storage.deleteImage(record.imagePath);
    state = state.where((r) => r.id != id).toList();
    _forgetActiveScan(id);
  }

  /// Purges every record plus the files behind them: captures and cached speech.
  Future<void> clear() async {
    await _db.clearAll();
    await _storage.clearAll();
    state = [];
    _forgetActiveScan();
  }
}

// ── Active scan ID and record (for viewing scan details in ResultScreen) ─────
final activeScanIdProvider = StateProvider<int?>((ref) => null);

final activeScanRecordProvider = FutureProvider<ScanRecord?>((ref) async {
  final id = ref.watch(activeScanIdProvider);
  if (id == null) return null;
  return ref.watch(databaseServiceProvider).getScanById(id);
});

// ── Pending OCR fields (from seed label scan, linked to next disease scan) ─────
final pendingOcrProvider = StateProvider<OcrFields?>((ref) => null);

// ── Crop to the on-screen box (experimental, T19) ─────────────────────────────
// Off until field photos show it helps: a tight crop can cut off the lesion
// that a reticle-shy farmer framed loosely.
final cropToReticleProvider = StateNotifierProvider<CropToReticleNotifier, bool>(
  (ref) => CropToReticleNotifier(),
);

class CropToReticleNotifier extends StateNotifier<bool> {
  CropToReticleNotifier() : super(false) {
    _load();
  }

  static const _key = 'crop_to_reticle';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

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

// ── Groq API key (Primary & exclusive AI provider) ──────────────────────────────
final groqKeyProvider = StateNotifierProvider<GroqKeyNotifier, String?>(
  (ref) => GroqKeyNotifier(),
);

class GroqKeyNotifier extends StateNotifier<String?> {
  GroqKeyNotifier({String? envKey}) : _envKey = envKey ?? AppEnv.groqApiKey, super(null) {
    _load();
  }

  /// The build-time key, if the app was built with one. Injectable so the
  /// seed-once behaviour can be tested (T28).
  final String _envKey;

  static const _storage = FlutterSecureStorage();
  static const _key     = 'groq_api_key';
  static const _seededFlag = 'groq_api_key_seeded';

  Future<void> _load() async {
    final saved = await _storage.read(key: _key);
    if (saved != null && saved.trim().isNotEmpty) {
      state = saved.trim();
      return;
    }
    if (_envKey.isEmpty) return;

    // Seeded once only: a farmer who removes the key must not find it back
    // after the next launch (T28).
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seededFlag) ?? false) return;
    await prefs.setBool(_seededFlag, true);
    state = _envKey;
    await _storage.write(key: _key, value: _envKey);
  }

  Future<void> save(String key) async {
    await _storage.write(key: _key, value: key.trim());
    state = key.trim();
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
    state = null;
  }
}

// ── YarnGPT API key (Nigerian local voice TTS) ──────────────────────────────────
final yarnGptKeyProvider = StateNotifierProvider<YarnGptKeyNotifier, String?>(
  (ref) => YarnGptKeyNotifier(),
);

class YarnGptKeyNotifier extends StateNotifier<String?> {
  YarnGptKeyNotifier({String? envKey}) : _envKey = envKey ?? AppEnv.yarnGptApiKey, super(null) {
    _load();
  }

  /// The build-time key, if the app was built with one. Injectable so the
  /// seed-once behaviour can be tested (T28).
  final String _envKey;

  static const _storage = FlutterSecureStorage();
  static const _key     = 'yarngpt_api_key';
  static const _seededFlag = 'yarngpt_api_key_seeded';

  Future<void> _load() async {
    final saved = await _storage.read(key: _key);
    if (saved != null && saved.trim().isNotEmpty) {
      state = saved.trim();
      return;
    }
    if (_envKey.isEmpty) return;

    // Seeded once only: a farmer who removes the key must not find it back
    // after the next launch (T28).
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seededFlag) ?? false) return;
    await prefs.setBool(_seededFlag, true);
    state = _envKey;
    await _storage.write(key: _key, value: _envKey);
  }

  Future<void> save(String key) async {
    await _storage.write(key: _key, value: key.trim());
    state = key.trim();
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
    state = null;
  }
}

// Backwards compatibility alias for components being refactored
final geminiKeyProvider = groqKeyProvider;

// ── Display language ───────────────────────────────────────────────────────────
enum DisplayLanguage { english, yoruba, igbo, hausa }

extension DisplayLanguageX on DisplayLanguage {
  String get label => switch (this) {
    DisplayLanguage.english => 'English',
    DisplayLanguage.yoruba  => 'Yoruba',
    DisplayLanguage.igbo    => 'Igbo',
    DisplayLanguage.hausa   => 'Hausa',
  };
  String get promptName => switch (this) {
    DisplayLanguage.english => 'English',
    DisplayLanguage.yoruba  => 'Yoruba',
    DisplayLanguage.igbo    => 'Igbo',
    DisplayLanguage.hausa   => 'Hausa',
  };
  bool get isEnglish => this == DisplayLanguage.english;

  // YarnGPT voice per language (Yoruba/Igbo/Hausa names chosen to match
  // the language of the content being spoken).
  String get yarnVoice => switch (this) {
    DisplayLanguage.english => 'Jude',
    DisplayLanguage.yoruba  => 'Idera',
    DisplayLanguage.igbo    => 'Chinenye',
    DisplayLanguage.hausa   => 'Zainab',
  };

  // BCP-47 locale tried first; if device TTS doesn't have it we fall back
  // to the base tag, then to en-US.  Android Google TTS ships yo & ha;
  // Igbo (ig) support is device-dependent.
  List<String> get ttsLocaleFallbacks => switch (this) {
    DisplayLanguage.english => ['en-US'],
    DisplayLanguage.yoruba  => ['yo-NG', 'yo', 'en-NG', 'en-US'],
    DisplayLanguage.igbo    => ['ig-NG', 'ig', 'en-NG', 'en-US'],
    DisplayLanguage.hausa   => ['ha-NG', 'ha', 'en-NG', 'en-US'],
  };
}

final displayLanguageProvider =
    StateNotifierProvider<DisplayLanguageNotifier, DisplayLanguage>(
  (ref) => DisplayLanguageNotifier(),
);

class DisplayLanguageNotifier extends StateNotifier<DisplayLanguage> {
  DisplayLanguageNotifier() : super(DisplayLanguage.english) {
    _load();
  }

  static const _key = 'display_language';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    state = DisplayLanguage.values[index.clamp(0, DisplayLanguage.values.length - 1)];
  }

  Future<void> set(DisplayLanguage lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, lang.index);
  }
}

// ── Farm statistics (Home and the dashboard share one source) ─────────────────
final farmStatsProvider = FutureProvider.family<FarmStats, int>((ref, days) async {
  ref.watch(scanListProvider); // recompute after a scan, delete or clear
  return ref.watch(databaseServiceProvider).farmStats(days: days);
});

// ── Health trend (delta health rate: >0.1 improving, <-0.1 worsening) ─────────
final healthTrendProvider = FutureProvider<double>((ref) async {
  ref.watch(scanListProvider);
  return DatabaseService.instance.getHealthTrend();
});
