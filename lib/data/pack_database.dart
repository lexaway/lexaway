import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite_async/sqlite_async.dart';

import '../models/question.dart';

class PackDatabase {
  SqliteDatabase? _db;

  Future<void> open(String lang) async {
    await close();
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/packs/$lang.db';

    if (!File(dbPath).existsSync()) {
      throw StateError('Pack "$lang" not downloaded — use PackManager first');
    }

    _db = SqliteDatabase(path: dbPath);
    await _migrate();
  }

  /// Idempotent migration: add SRS columns if they don't exist yet.
  Future<void> _migrate() async {
    final db = _db!;
    await db.writeTransaction((tx) async {
      final cols = await tx.getAll("PRAGMA table_info('phrases')");
      final colNames = cols.map((r) => r['name'] as String).toSet();

      if (!colNames.contains('easiness')) {
        await tx.execute(
          'ALTER TABLE phrases ADD COLUMN easiness REAL NOT NULL DEFAULT 2.5',
        );
      }
      if (!colNames.contains('interval_days')) {
        await tx.execute(
          'ALTER TABLE phrases ADD COLUMN interval_days INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!colNames.contains('repetitions')) {
        await tx.execute(
          'ALTER TABLE phrases ADD COLUMN repetitions INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!colNames.contains('next_review')) {
        await tx.execute(
          "ALTER TABLE phrases ADD COLUMN next_review TEXT NOT NULL DEFAULT ''",
        );
      }
    });
  }

  Future<List<Question>> loadQuestions({String? level, int limit = 200}) async {
    final db = _db!;
    final where = level != null ? 'WHERE level = ?' : '';
    final args = level != null ? [level] : <String>[];
    final rows = await db.getAll(
      'SELECT phrase, translation, blank_index, answer, options '
      'FROM phrases $where ORDER BY RANDOM() LIMIT ?',
      [...args, limit],
    );
    return rows.map((r) => Question.fromMap(r)).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
