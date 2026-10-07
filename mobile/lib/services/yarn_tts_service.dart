import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Wraps the YarnGPT TTS API (https://yarngpt.ai) with persistent disk caching
/// for authentic Yoruba / Igbo / Hausa speech synthesis.
///
/// Engineering highlights:
/// - Deterministic SHA-256 cache key based on `"$voice:$text"`.
/// - Local filesystem audio cache in ApplicationSupport/yarn_audio_cache.
/// - 0ms network latency on cache hits (replays, tab switches & offline access).
/// - Completely avoids reconnecting to the YarnGPT API for previously generated audio.
class YarnTtsService {
  static final YarnTtsService instance = YarnTtsService._();
  YarnTtsService._();

  static const _endpoint = 'https://yarngpt.ai/api/v1/tts';

  AudioPlayer? _player;
  StreamSubscription? _completeSub;
  Directory? _cacheDirectory;

  /// Returns the persistent audio cache directory.
  Future<Directory> _getCacheDirectory() async {
    if (_cacheDirectory != null) return _cacheDirectory!;
    final baseDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${baseDir.path}/yarn_audio_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    _cacheDirectory = cacheDir;
    return cacheDir;
  }

  /// Derives a deterministic cache file path for the given voice and text.
  Future<File> getCachedFile(String text, String voice) async {
    final dir = await _getCacheDirectory();
    final key = '$voice:${text.trim()}';
    final hash = sha256.convert(utf8.encode(key)).toString().substring(0, 24);
    return File('${dir.path}/tts_$hash.mp3');
  }

  /// Checks whether an audio file is already cached locally.
  Future<bool> isCached(String text, String voice) async {
    try {
      final file = await getCachedFile(text, voice);
      return await file.exists() && (await file.length()) > 0;
    } catch (_) {
      return false;
    }
  }

  /// Speaks the given text using YarnGPT with local cache resolution.
  ///
  /// If the speech has already been synthesized, plays the local audio
  /// file immediately without making any network request.
  Future<void> speak({
    required String text,
    required String apiKey,
    String voice = 'Idera',
    void Function()? onComplete,
  }) async {
    await stop(); // Stop any active playback

    final targetFile = await getCachedFile(text, voice);

    // ── 1. Cache Hit: Instant Local Playback (0ms Network) ──────────────────
    if (await targetFile.exists() && (await targetFile.length()) > 0) {
      debugPrint('[YarnTTS] Cache HIT for voice "$voice" (${targetFile.lengthSync()} bytes) — playing locally offline.');
      await _playFile(targetFile, onComplete);
      return;
    }

    // ── 2. Cache Miss: Synthesize via YarnGPT API ──────────────────────────
    debugPrint('[YarnTTS] Cache MISS for voice "$voice" — synthesizing via API.');

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'voice': voice,
        'response_format': 'mp3',
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('YarnGPT ${response.statusCode}: ${response.body}');
    }

    // Write to deterministic cache file
    await targetFile.writeAsBytes(response.bodyBytes, flush: true);
    debugPrint('[YarnTTS] Cached ${response.bodyBytes.length} bytes to ${targetFile.path}');

    // ── 3. Play from persistent local cache ─────────────────────────────────
    await _playFile(targetFile, onComplete);
  }

  Future<void> _playFile(File file, void Function()? onComplete) async {
    _player = AudioPlayer();
    _completeSub = _player!.onPlayerComplete.listen((_) {
      onComplete?.call();
      _completeSub?.cancel();
      _completeSub = null;
      _player?.dispose();
      _player = null;
    });

    await _player!.play(DeviceFileSource(file.path));
  }

  Future<void> stop() async {
    await _completeSub?.cancel();
    _completeSub = null;
    try {
      await _player?.stop();
    } catch (_) {}
    _player?.dispose();
    _player = null;
  }

  /// Clears the persistent audio cache if needed.
  Future<void> clearCache() async {
    try {
      final dir = await _getCacheDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _cacheDirectory = null;
      }
    } catch (e) {
      debugPrint('[YarnTTS] Cache clear error: $e');
    }
  }
}
