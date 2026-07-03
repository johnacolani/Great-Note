import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../storage/app_paths.dart';

/// Result of an export: the ZIP [bytes] and a suggested [fileName].
class BackupResult {
  final Uint8List bytes;
  final String fileName;

  const BackupResult(this.bytes, this.fileName);
}

/// Exports/imports everything the user owns (folders, notes, note images and
/// the app background) as a single ZIP file.
///
/// ZIP layout:
///   backup.json          -> manifest with folders + notes + background info
///   note_images/         -> image files referenced by notes
///   background/          -> the custom app background (if it's a file)
class BackupService {
  final Database db;

  BackupService(this.db);

  /// Bumped when the manifest format changes, so imports can adapt.
  static const int schemaVersion = 1;

  static String _two(int v) => v.toString().padLeft(2, '0');

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<BackupResult> exportBackup() async {
    final folders = await db.query('folders');
    final notes = await db.query('notes');
    final backgrounds = await db.query('backgrounds');

    final archive = Archive();

    // Resolve how the background is stored (inline data URI vs a file on disk).
    Map<String, dynamic> backgroundJson = {'type': 'none'};
    if (backgrounds.isNotEmpty) {
      final bgPath = backgrounds.first['image_path']?.toString() ?? '';
      if (bgPath.startsWith('data:')) {
        backgroundJson = {'type': 'data', 'value': bgPath};
      } else if (bgPath.isNotEmpty && !kIsWeb && File(bgPath).existsSync()) {
        final bytes = await File(bgPath).readAsBytes();
        final name = p.basename(bgPath);
        archive.add(ArchiveFile.bytes('background/$name', bytes));
        backgroundJson = {'type': 'file', 'fileName': name};
      }
    }

    final manifest = {
      'version': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'folders': folders,
      'notes': notes,
      'background': backgroundJson,
    };
    archive.add(ArchiveFile.string('backup.json', jsonEncode(manifest)));

    // Bundle every note image file.
    if (!kIsWeb && AppPaths.isInitialized) {
      final dir = Directory(AppPaths.noteImagesPath);
      if (dir.existsSync()) {
        for (final entity in dir.listSync()) {
          if (entity is File) {
            final bytes = await entity.readAsBytes();
            final name = p.basename(entity.path);
            archive.add(
              ArchiveFile.bytes('${AppPaths.noteImagesDir}/$name', bytes),
            );
          }
        }
      }
    }

    final zipBytes = ZipEncoder().encodeBytes(archive);

    final now = DateTime.now();
    final fileName = 'great_note_backup_${now.year}${_two(now.month)}'
        '${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}'
        '${_two(now.second)}.zip';

    return BackupResult(zipBytes, fileName);
  }

  Future<BackupResult> exportNotesZip() async {
    final folders = await db.query('folders');
    final notes = await db.rawQuery('''
      SELECT n.id, n.folder_id, n.title, n.description, f.name as folder_name
      FROM notes n
      INNER JOIN folders f ON n.folder_id = f.id
      ORDER BY f.name ASC, n.title ASC
    ''');

    final archive = Archive();
    final exportedAt = DateTime.now().toIso8601String();

    archive.add(
      ArchiveFile.string(
        'notes_manifest.json',
        jsonEncode({
          'exportedAt': exportedAt,
          'folderCount': folders.length,
          'noteCount': notes.length,
          'format': 'md',
        }),
      ),
    );

    for (final note in notes) {
      final folderName = _sanitizeFileName(
        (note['folder_name'] ?? 'Folder').toString(),
        fallback: 'Folder',
      );
      final noteTitle = _sanitizeFileName(
        (note['title'] ?? 'Untitled').toString(),
        fallback: 'Untitled',
      );
      final noteId = note['id']?.toString() ?? '0';
      final description = _noteDescriptionToPlainText(
        (note['description'] ?? '').toString(),
      );

      final filePath =
          'notes/$folderName/${noteTitle}_${noteId}.md';
      final content = StringBuffer()
        ..writeln('# ${(note['title'] ?? 'Untitled').toString()}')
        ..writeln()
        ..writeln('Folder: ${(note['folder_name'] ?? 'Folder').toString()}')
        ..writeln('Note ID: $noteId')
        ..writeln('Exported: $exportedAt')
        ..writeln()
        ..writeln('---')
        ..writeln()
        ..writeln(description.isEmpty ? 'No content.' : description);

      archive.add(ArchiveFile.string(filePath, content.toString()));
    }

    final zipBytes = ZipEncoder().encodeBytes(archive);
    final now = DateTime.now();
    final fileName = 'great_note_notes_export_${now.year}${_two(now.month)}'
        '${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}'
        '${_two(now.second)}.zip';

    return BackupResult(zipBytes, fileName);
  }

  // ---------------------------------------------------------------------------
  // Import (replace everything)
  // ---------------------------------------------------------------------------

  /// Wipes existing folders/notes/images/background and restores from [zipBytes].
  Future<void> importBackupReplace(Uint8List zipBytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw const FormatException('The selected file is not a valid backup ZIP.');
    }

    ArchiveFile? manifestFile;
    for (final f in archive.files) {
      if (f.name == 'backup.json') {
        manifestFile = f;
        break;
      }
    }
    if (manifestFile == null) {
      throw const FormatException('Invalid backup: backup.json is missing.');
    }

    final manifest =
        jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;

    final folders =
        (manifest['folders'] as List? ?? []).cast<Map<String, dynamic>>();
    final notes =
        (manifest['notes'] as List? ?? []).cast<Map<String, dynamic>>();
    final background = manifest['background'] as Map<String, dynamic>?;

    // Replace the database content atomically.
    await db.transaction((txn) async {
      await txn.delete('notes');
      await txn.delete('folders');
      await txn.delete('backgrounds');

      for (final folder in folders) {
        await txn.insert('folders', {
          'id': folder['id'],
          'name': folder['name'],
          'color': folder['color'],
          'createdAt': folder['createdAt'],
        });
      }
      for (final note in notes) {
        await txn.insert('notes', {
          'id': note['id'],
          'folder_id': note['folder_id'],
          'title': note['title'],
          'description': note['description'],
        });
      }
    });

    // Restore note image files (wipe the folder first for a clean replace).
    if (!kIsWeb && AppPaths.isInitialized) {
      final imagesDir = Directory(AppPaths.noteImagesPath);
      if (imagesDir.existsSync()) {
        imagesDir.deleteSync(recursive: true);
      }
      imagesDir.createSync(recursive: true);

      final prefix = '${AppPaths.noteImagesDir}/';
      for (final f in archive.files) {
        if (!f.isFile || !f.name.startsWith(prefix)) continue;
        final name = p.basename(f.name);
        final out = File(p.join(AppPaths.noteImagesPath, name));
        await out.writeAsBytes(f.content, flush: true);
      }
    }

    // Restore the app background.
    if (background != null && background['type'] != 'none') {
      String? bgValue;
      if (background['type'] == 'data') {
        bgValue = background['value'] as String?;
      } else if (background['type'] == 'file' &&
          !kIsWeb &&
          AppPaths.isInitialized) {
        final name = background['fileName']?.toString();
        if (name != null) {
          ArchiveFile? bgFile;
          for (final f in archive.files) {
            if (f.name == 'background/$name') {
              bgFile = f;
              break;
            }
          }
          if (bgFile != null) {
            final out =
                File(p.join(AppPaths.documentsPath, 'background_$name'));
            await out.writeAsBytes(bgFile.content, flush: true);
            bgValue = out.path;
          }
        }
      }
      if (bgValue != null) {
        await db.insert('backgrounds', {'image_path': bgValue});
      }
    }
  }

  String _sanitizeFileName(String input, {required String fallback}) {
    final cleaned = input
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (cleaned.isEmpty) return fallback;
    return cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;
  }

  String _noteDescriptionToPlainText(String description) {
    if (description.trim().isEmpty) return '';

    try {
      final parsed = jsonDecode(description);
      if (parsed is List) {
        final buffer = StringBuffer();
        for (final op in parsed) {
          if (op is! Map<String, dynamic>) continue;
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          } else if (insert is Map && insert.containsKey('image')) {
            buffer.writeln('[image]');
          }
        }
        return buffer.toString().trim();
      }
    } catch (_) {
      // Fall back to the stored value below.
    }

    return description.trim();
  }
}
