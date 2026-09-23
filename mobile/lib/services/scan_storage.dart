import 'dart:io';

import 'package:flutter/foundation.dart';

import 'path_resolver.dart';
import 'yarn_tts_service.dart';

/// Owns the files a scan leaves on the device: the captured image under
/// `scans/` and the speech synthesized for its advice.
///
/// Deleting a record used to drop only the database row, so every capture
/// stayed on disk forever and "Purge All" was a promise the app did not keep
/// (T21). The directories are injectable so the behaviour can be proven
/// against a temp directory instead of a real device.
class ScanStorage {
  ScanStorage({Directory? scansDir, Future<void> Function()? clearAudioCache})
      : _scansDir = scansDir,
        _clearAudioCache = clearAudioCache;

  final Directory? _scansDir;
  final Future<void> Function()? _clearAudioCache;

  static final ScanStorage instance = ScanStorage();

  /// `<documents>/scans`, resolved late so it follows the current container.
  Directory get scansDir => _scansDir ?? Directory(PathResolver.resolve('scans'));

  /// Removes the image behind a stored path. A path that is empty, already
  /// gone or unreadable is not an error: the record is going away either way.
  Future<void> deleteImage(String imagePath) async {
    if (imagePath.isEmpty) return;
    try {
      final file = File(PathResolver.resolve(imagePath));
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[ScanStorage] could not delete $imagePath: $e');
    }
  }

  /// Empties `scans/`, keeping the directory itself so the next capture works.
  Future<void> clearImages() async {
    try {
      final dir = scansDir;
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        await entity.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[ScanStorage] could not clear captures: $e');
    }
  }

  /// Drops the synthesized-speech cache; advice is re-spoken on demand.
  Future<void> clearAudioCache() async {
    final clear = _clearAudioCache ?? YarnTtsService.instance.clearCache;
    try {
      await clear();
    } catch (e) {
      debugPrint('[ScanStorage] could not clear the audio cache: $e');
    }
  }

  /// Everything scanning wrote to the filesystem.
  Future<void> clearAll() async {
    await clearImages();
    await clearAudioCache();
  }
}
