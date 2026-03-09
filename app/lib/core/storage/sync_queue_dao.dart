import 'package:sqflite/sqflite.dart';
import 'local_database.dart';

class SyncQueueDao {
  Future<Database> get _db => LocalDatabase.instance;

  Future<void> enqueue(String action, String payload) async {
    final db = await _db;
    await db.insert('sync_queue', {
      'action': action,
      'payload': payload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'retries': 0,
    });
  }

  Future<List<Map<String, dynamic>>> peekBatch({int limit = 10}) async {
    final db = await _db;
    return db.query('sync_queue', orderBy: 'created_at ASC', limit: limit);
  }

  Future<void> remove(int id) async {
    final db = await _db;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetries(int id) async {
    final db = await _db;
    await db.rawUpdate('UPDATE sync_queue SET retries = retries + 1 WHERE id = ?', [id]);
  }

  Future<void> removeCompleted(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _db;
    final placeholders = ids.map((_) => '?').join(',');
    await db.rawDelete('DELETE FROM sync_queue WHERE id IN ($placeholders)', ids);
  }

  Future<int> pendingCount() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) AS cnt FROM sync_queue');
    return (result.first['cnt'] as int?) ?? 0;
  }
}
