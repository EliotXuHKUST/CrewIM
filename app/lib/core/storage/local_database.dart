import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class LocalDatabase {
  static Database? _db;
  static const _dbName = 'zhizhi.db';
  static const _dbVersion = 2;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE sessions (
        id         TEXT PRIMARY KEY,
        title      TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced     INTEGER DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE messages (
        id         TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role       TEXT NOT NULL,
        content    TEXT NOT NULL,
        task_id    TEXT,
        type       TEXT NOT NULL DEFAULT 'text',
        metadata   TEXT,
        created_at TEXT NOT NULL,
        synced     INTEGER DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE tasks (
        id              TEXT PRIMARY KEY,
        session_id      TEXT NOT NULL,
        input_text      TEXT,
        understanding   TEXT,
        status          TEXT NOT NULL DEFAULT 'created',
        result          TEXT,
        error           TEXT,
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL,
        synced          INTEGER DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE sync_queue (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        action     TEXT NOT NULL,
        payload    TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retries    INTEGER DEFAULT 0
      )
    ''');

    batch.execute('CREATE INDEX idx_messages_session ON messages(session_id, created_at)');
    batch.execute('CREATE INDEX idx_tasks_session ON tasks(session_id, created_at)');
    batch.execute('CREATE INDEX idx_sync_queue_created ON sync_queue(created_at)');

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE messages ADD COLUMN type TEXT NOT NULL DEFAULT 'text'");
      await db.execute('ALTER TABLE messages ADD COLUMN metadata TEXT');
    }
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
