import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_env.dart';
import '../models/scan_record.dart';
import '../services/database_service.dart';
import 'service_providers.dart';

// ── Scan history ──────────────────────────────────────────────────────────────
final scanListProvider = StateNotifierProvider<ScanListNotifier, List<ScanRecord>>(
  (ref) => ScanListNotifier(),
);

class ScanListNotifier extends StateNotifier<List<ScanRecord>> {
  ScanListNotifier() : super([]);

  Future<void> load({int? classFilter}) async {
    state = await DatabaseService.instance.getScans(classIdFilter: classFilter);
  }

  Future<int> add(ScanRecord record) async {
    final id = await DatabaseService.instance.insertScan(record);
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
    await DatabaseService.instance.updateFeedback(id, feedback);
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(feedback: feedback) else r,
    ];
  }

  Future<void> delete(int id) async {
    await DatabaseService.instance.deleteScan(id);
    state = state.where((r) => r.id != id).toList();
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

Future<String?> _tryReadEnvKey(String envKey) async {
  try {
    for (final p in [
      '.env.json',
      'mobile/.env.json',
      '/Users/mac/projects/maize-disease-detection/mobile/.env.json',
    ]) {
      final f = File(p);
      if (f.existsSync()) {
        final data = jsonDecode(await f.readAsString());
        if (data is Map && data[envKey] is String && (data[envKey] as String).isNotEmpty) {
          return (data[envKey] as String).trim();
        }
      }
    }
  } catch (_) {}
  return null;
}

// ── Groq API key (Primary & exclusive AI provider) ──────────────────────────────
final groqKeyProvider = StateNotifierProvider<GroqKeyNotifier, String?>(
  (ref) => GroqKeyNotifier(),
);

class GroqKeyNotifier extends StateNotifier<String?> {
  GroqKeyNotifier() : super(null) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _key     = 'groq_api_key';

  Future<void> _load() async {
    final saved = await _storage.read(key: _key);
    if (saved != null && saved.trim().isNotEmpty) {
      state = saved.trim();
      return;
    }
    if (AppEnv.groqApiKey.isNotEmpty) {
      state = AppEnv.groqApiKey;
      await _storage.write(key: _key, value: state!);
      return;
    }
    final fileKey = await _tryReadEnvKey('GROQ_API_KEY');
    if (fileKey != null && fileKey.isNotEmpty) {
      state = fileKey;
      await _storage.write(key: _key, value: fileKey);
    }
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
  YarnGptKeyNotifier() : super(null) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _key     = 'yarngpt_api_key';

  Future<void> _load() async {
    final saved = await _storage.read(key: _key);
    if (saved != null && saved.trim().isNotEmpty) {
      state = saved.trim();
      return;
    }
    if (AppEnv.yarnGptApiKey.isNotEmpty) {
      state = AppEnv.yarnGptApiKey;
      await _storage.write(key: _key, value: state!);
      return;
    }
    final fileKey = await _tryReadEnvKey('YARNGPT_API_KEY');
    if (fileKey != null && fileKey.isNotEmpty) {
      state = fileKey;
      await _storage.write(key: _key, value: fileKey);
    }
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

// ── Health trend (delta health rate: >0.1 improving, <-0.1 worsening) ─────────
final healthTrendProvider = FutureProvider<double>((ref) async {
  ref.watch(scanListProvider);
  return DatabaseService.instance.getHealthTrend();
});
