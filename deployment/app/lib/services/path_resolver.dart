import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Resolves scan image paths to absolute file-system paths.
///
/// On iOS, every `flutter run` (re)install gives the app a new container UUID,
/// so absolute paths stored from a previous session become invalid. Storing
/// only the relative portion (`scans/filename.jpg`) and resolving at runtime
/// via the *current* documents directory keeps images accessible across
/// restarts.
///
/// Call [init] once at startup (before [runApp]), then use [resolve] anywhere
/// a [File] is needed from a [ScanRecord.imagePath].
class PathResolver {
  PathResolver._();

  static String? _docsPath;

  /// Cache the documents directory path. Call once in main() before runApp.
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _docsPath = dir.path;
    // Ensure the scans subdirectory exists.
    final scans = Directory('${dir.path}/scans');
    if (!scans.existsSync()) scans.createSync(recursive: true);
  }

  /// Returns the absolute path for a stored [imagePath].
  ///
  /// - Relative path (`scans/foo.jpg`)  → prepends current documents dir.
  /// - Legacy absolute path (`/var/…/foo.jpg`) → extracts filename and
  ///   rebuilds under current `documents/scans/` directory. This handles
  ///   records written before this fix was applied.
  static String resolve(String imagePath) {
    final docs = _docsPath;
    if (docs == null) return imagePath; // not yet initialised — return as-is
    if (!imagePath.startsWith('/')) {
      return '$docs/$imagePath';
    }
    // Legacy absolute path: rebuild from filename only.
    final filename = imagePath.split(Platform.pathSeparator).last;
    return '$docs/scans/$filename';
  }

  /// Converts an absolute path to a relative path suitable for DB storage.
  /// Strips the documents-directory prefix so the path survives reinstalls.
  static String makeRelative(String absolutePath) {
    final docs = _docsPath;
    if (docs == null) return absolutePath;
    if (absolutePath.startsWith(docs)) {
      // e.g. /docs/path/scans/foo.jpg  →  scans/foo.jpg
      return absolutePath.substring(docs.length + 1); // +1 skips the '/'
    }
    return absolutePath; // unknown prefix — store as-is
  }
}
