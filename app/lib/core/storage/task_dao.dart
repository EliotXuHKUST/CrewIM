import 'package:sqflite/sqflite.dart';
import 'local_database.dart';

class TaskDao {
  Future<Database> get _db => LocalDatabase.instance;

  Future<void> upsert(Map<String, dynamic> task) async {
    final db = await _db;
    await db.insert('tasks', task, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertAll(List<Map<String, dynamic>> tasks) async {
    final db = await _db;
    final batch = db.batch();
    for (final t in tasks) {
      batch.insert('tasks', t, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await _db;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getBySession(String sessionId) async {
    final db = await _db;
    return db.query(
      'tasks',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> updateStatus(String id, String status, {String? error, String? result}) async {
    final db = await _db;
    final values = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (error != null) values['error'] = error;
    if (result != null) values['result'] = result;
    await db.update('tasks', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBySession(String sessionId) async {
    final db = await _db;
    await db.delete('tasks', where: 'session_id = ?', whereArgs: [sessionId]);
  }
}
