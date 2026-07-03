import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';


class FolderLocalDataSource {
  final Database db;

  FolderLocalDataSource(this.db);

  Future<List<Map<String, dynamic>>> getFolders() async {
    try {
      final folders = await db.query('folders');
      return folders.map((folder) {
        return {
          ...folder,
          'createdAt': folder['createdAt'] != null
              ? DateTime.parse(folder['createdAt'] as String)
              : DateTime.now(), // Fallback to current time if null
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading folders: $e');
      throw Exception('Failed to load folders');
    }
  }

  Future<int> insertFolder(Map<String, dynamic> folder) async {
    try {
      // Print the folder data being inserted
      debugPrint('Inserting folder with data: $folder');

      // Ensure 'createdAt' is included if not provided
      if (!folder.containsKey('createdAt')) {
        folder['createdAt'] = DateTime.now().toIso8601String();
      }

      // Insert into database and return the result
      return await db.insert('folders', folder);
    } catch (e) {
      debugPrint('Error in insertFolder: $e');
      throw Exception('Failed to insert folder');
    }
  }

  Future<int> deleteFolder(int id) async {
    return await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }
  // Update the folder name in the database
  Future<void> updateFolderName(int folderId, String newName) async {
    await db.update(
      'folders',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  // Update the folder color in the database
  Future<void> updateFolderColor(int folderId, String color) async {
    await db.update(
      'folders',
      {'color': color},
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }
}
