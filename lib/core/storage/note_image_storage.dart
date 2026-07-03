import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';

/// Handles persisting note images to disk and turning stored image references
/// back into [ImageProvider]s.
///
/// Storage format of an image reference (the string embedded in the Quill doc):
///   * `data:<mime>;base64,...`  -> legacy/base64 image (used on web too)
///   * `note_images/<file>`      -> file stored under the documents directory
class NoteImageStorage {
  NoteImageStorage._();

  static int _counter = 0;

  static String _extensionForMime(String? mime, String? nameHint) {
    if (nameHint != null && p.extension(nameHint).isNotEmpty) {
      return p.extension(nameHint); // includes leading dot
    }
    switch (mime) {
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/gif':
        return '.gif';
      case 'image/bmp':
        return '.bmp';
      default:
        return '.jpg';
    }
  }

  /// Persist [bytes] and return the reference string to embed in the note.
  ///
  /// On web there is no writable file system, so a base64 data URI is returned
  /// (kept inline in the note, same as before).
  static Future<String> saveImage(
    Uint8List bytes, {
    String? mimeType,
    String? nameHint,
  }) async {
    if (kIsWeb) {
      final mime = mimeType ?? 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }

    final ext = _extensionForMime(mimeType, nameHint);
    // Unique-enough filename: timestamp + a per-session counter.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final fileName = 'img_${stamp}_${_counter++}$ext';
    final relativeRef = p.join(AppPaths.noteImagesDir, fileName);
    final file = File(p.join(AppPaths.documentsPath, relativeRef));
    await file.writeAsBytes(bytes, flush: true);
    // Always store forward-slash relative refs for cross-platform safety.
    return relativeRef.replaceAll(r'\', '/');
  }

  /// Turn a stored image reference into an [ImageProvider], or null if it can't
  /// be resolved. Used by the Quill embed builders.
  static ImageProvider? providerFor(BuildContext context, String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return null;

    // Base64 data URI (legacy notes + web).
    if (trimmed.startsWith('data:') && trimmed.contains(',')) {
      final base64Part = trimmed.split(',').last;
      return MemoryImage(base64Decode(base64Part));
    }

    if (kIsWeb) return null;

    // File reference (relative or absolute).
    final absolute = AppPaths.resolveImageRef(trimmed);
    final file = File(absolute);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }
}
