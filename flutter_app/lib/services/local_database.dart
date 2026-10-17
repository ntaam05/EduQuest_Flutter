import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null) return current;

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = '${docsDir.path}/eduquest_local.db';

    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profile_cache (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE quiz_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            quiz_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );

    _database = db;
    return db;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<void> saveProfileCache(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      'profile_cache',
      {
        'id': 1,
        'payload': jsonEncode(profile),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> loadProfileCache() async {
    final db = await database;
    final rows = await db.query('profile_cache', where: 'id = ?', whereArgs: [1], limit: 1);
    if (rows.isEmpty) return null;
    final payload = rows.first['payload'];
    if (payload is! String || payload.isEmpty) return null;
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  Future<void> saveQuizCache(List<Map<String, dynamic>> quizzes) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('quiz_cache');
      for (final quiz in quizzes) {
        await txn.insert('quiz_cache', {
          'quiz_id': (quiz['id'] ?? '').toString(),
          'payload': jsonEncode(quiz),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> loadQuizCache() async {
    final db = await database;
    final rows = await db.query('quiz_cache', orderBy: 'updated_at DESC');
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final payload = row['payload'];
      if (payload is! String || payload.isEmpty) continue;
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        result.add(decoded);
      } else if (decoded is Map) {
        result.add(decoded.map((key, value) => MapEntry(key.toString(), value)));
      }
    }
    return result;
  }
}
