import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PathResolver {
  static String _docsDir = '';

  static Future<void> init() async {
    _docsDir = (await getApplicationDocumentsDirectory()).path;
  }

  // Returns the current absolute path for any stored imagePath.
  // Handles three cases:
  //   1. Relative path ('scans/foo.jpg') — prepend current docsDir
  //   2. Current absolute path — return as-is
  //   3. Stale absolute path (old container UUID after iOS reinstall) — rebuild
  //      from filename only, which is stable across reinstalls.
  static String resolve(String imagePath) {
    if (imagePath.isEmpty) return imagePath;
    if (!imagePath.startsWith('/')) {
      return p.join(_docsDir, imagePath);
    }
    if (imagePath.startsWith(_docsDir)) return imagePath;
    return p.join(_docsDir, 'scans', p.basename(imagePath));
  }

  // Converts an absolute path under docsDir/scans to 'scans/<filename>' so
  // the stored path stays valid even when the iOS container UUID rotates.
  static String toRelative(String absPath) {
    final scansDir = p.join(_docsDir, 'scans');
    if (absPath.startsWith(scansDir)) {
      return p.join('scans', p.basename(absPath));
    }
    return absPath;
  }
}
