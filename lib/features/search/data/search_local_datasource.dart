import 'package:sqflite/sqflite.dart';

class SearchLocalDataSource {
  final Database db;

  SearchLocalDataSource(this.db);

  // Search across both folders and notes
  Future<Map<String, List<Map<String, dynamic>>>> searchAll(String query) async {
    final searchQuery = '%${query.toLowerCase()}%';
    
    // Search folders
    final folders = await db.rawQuery('''
      SELECT id, name, color, createdAt, 'folder' as type
      FROM folders 
      WHERE LOWER(name) LIKE ?
      ORDER BY name ASC
    ''', [searchQuery]);

    // Search notes
    final notes = await db.rawQuery('''
      SELECT n.id, n.folder_id, n.title, n.description, f.name as folder_name, 'note' as type
      FROM notes n
      INNER JOIN folders f ON n.folder_id = f.id
      WHERE LOWER(n.title) LIKE ? OR LOWER(n.description) LIKE ?
      ORDER BY n.title ASC
    ''', [searchQuery, searchQuery]);

    return {
      'folders': folders,
      'notes': notes,
    };
  }

  // Search only in folder names
  Future<List<Map<String, dynamic>>> searchFolders(String query) async {
    final searchQuery = '%${query.toLowerCase()}%';
    
    return await db.rawQuery('''
      SELECT id, name, color, createdAt
      FROM folders 
      WHERE LOWER(name) LIKE ?
      ORDER BY name ASC
    ''', [searchQuery]);
  }

  // Search only in notes
  Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    final searchQuery = '%${query.toLowerCase()}%';
    
    return await db.rawQuery('''
      SELECT n.id, n.folder_id, n.title, n.description, f.name as folder_name
      FROM notes n
      INNER JOIN folders f ON n.folder_id = f.id
      WHERE LOWER(n.title) LIKE ? OR LOWER(n.description) LIKE ?
      ORDER BY n.title ASC
    ''', [searchQuery, searchQuery]);
  }

  // Get note count for a folder
  Future<int> getNoteCount(int folderId) async {
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM notes
      WHERE folder_id = ?
    ''', [folderId]);
    
    return (result.first['count'] as int?) ?? 0;
  }
}