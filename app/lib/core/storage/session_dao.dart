import 'package:sqflite/sqflite.dart';
import 'local_database.dart';

class SessionDao {
  Future<Database> get _db => LocalDatabase.instance;

  Future<void> insert(Map<String, dynamic> session) async {
    final db = await _db;
    await db.insert('sessions', session, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(String id, Map<String, dynamic> values) async {
    final db = await _db;
    await db.update('sessions', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await _db;
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await _db;
    return db.query('sessions', orderBy: 'updated_at DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await _db;
    return db.query('sessions', where: 'synced = 0');
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update('sessions', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Returns session with last message summary for list display.
  Future<List<Map<String, dynamic>>> getAllWithLastMessage() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT s.*, m.content AS last_message, m.created_at AS last_message_at
      FROM sessions s
      LEFT JOIN (
        SELECT session_id, content, created_at,
               ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY created_at DESC) AS rn
        FROM messages
      ) m ON m.session_id = s.id AND m.rn = 1
      ORDER BY COALESCE(m.created_at, s.updated_at) DESC
    ''');
  }
}
