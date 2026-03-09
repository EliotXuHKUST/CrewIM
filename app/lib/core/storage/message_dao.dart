import 'package:sqflite/sqflite.dart';
import 'local_database.dart';

class MessageDao {
  Future<Database> get _db => LocalDatabase.instance;

  Future<void> insert(Map<String, dynamic> message) async {
    final db = await _db;
    await db.insert('messages', message, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertAll(List<Map<String, dynamic>> messages) async {
    final db = await _db;
    final batch = db.batch();
    for (final m in messages) {
      batch.insert('messages', m, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getBySession(String sessionId) async {
    final db = await _db;
    return db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await _db;
    return db.query('messages', where: 'synced = 0');
  }

  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update('messages', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBySession(String sessionId) async {
    final db = await _db;
    await db.delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
  }
}
