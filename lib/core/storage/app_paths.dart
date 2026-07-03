import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Central place for app storage locations.
///
/// [documentsPath] is cached once at startup so it can be read synchronously
/// while building widgets (e.g. resolving a note image file). Note images are
/// stored as *relative* references (e.g. `note_images/img_123.jpg`) and resolved
/// against this directory, so they survive app reinstalls and backup/restore
/// across devices where absolute paths would break.
class AppPaths {
  AppPaths._();

  static String? _documentsPath;

  /// Subdirectory (relative to documents) where note images live.
  static const String noteImagesDir = 'note_images';

  /// The absolute documents directory path, cached after [init].
  static String get documentsPath {
    final path = _documentsPath;
    if (path == null) {
      throw StateError('AppPaths.init() must be called before use.');
    }
    return path;
  }

  static bool get isInitialized => _documentsPath != null;

  /// Absolute path to the note-images directory.
  static String get noteImagesPath => p.join(documentsPath, noteImagesDir);

  /// Initialize and cache storage paths. Call once in main() before runApp.
  /// No-op on web (there is no writable documents directory there).
  static Future<void> init() async {
    if (kIsWeb) return;
    final dir = await getApplicationDocumentsDirectory();
    _documentsPath = dir.path;
    // Make sure the note images folder exists.
    final imagesDir = Directory(p.join(dir.path, noteImagesDir));
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
  }

  /// Resolve a stored note-image reference to an absolute path.
  /// Handles both relative refs (`note_images/x.jpg`) and absolute paths.
  static String resolveImageRef(String ref) {
    if (p.isAbsolute(ref)) return ref;
    return p.join(documentsPath, ref);
  }
}
