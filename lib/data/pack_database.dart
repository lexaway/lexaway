import 'dart:io';

import 'package:sqlite_async/sqlite_async.dart';

import '../models/question.dart';
import 'day_key.dart';

class PackDatabase {
  final String packsDir;
  SqliteDatabase? _db;

  PackDatabase({required this.packsDir});

  Future<void> open(String packId) async {
    await close();
    final dbPath = '$packsDir/$packId.db';

    if (!File(dbPath).existsSync()) {
      throw StateError('Pack "$packId" not downloaded — use PackManager first');
    }

    _db = SqliteDatabase(path: dbPath);
    await _migrate();
  }

  /// Idempotent migration for pack schema changes after launch.
  /// Pre-launch, bake new columns directly into build.py instead.
  Future<void> _migrate() async {
    // Add migrations here when users have local packs that can't be rebuilt.
  }

  static const _sm2Cols =
      'id, phrase, translation, blank_index, answer, options, '
      'easiness, interval_days, repetitions';

  /// Build a WHERE clause for the difficulty filter.
  /// beginner → only beginner rows; intermediate → beginner + intermediate;
  /// advanced / null → no filter.
  static ({String clause, List<String> args}) _difficultyFilter(
      String? difficulty) {
    switch (difficulty) {
      case 'beginner':
        return (clause: "level = ?", args: ['beginner']);
      case 'intermediate':
        return (
          clause: "level IN (?, ?)",
          args: ['beginner', 'intermediate'],
        );
      default:
        return (clause: '', args: <String>[]);
    }
  }

  /// Load fresh (not-yet-due-for-review) questions.
  Future<List<Question>> loadQuestions({
    String? difficulty,
    int limit = 200,
  }) async {
    final db = _db!;
    final diff = _difficultyFilter(difficulty);
    final today = todayKey();

    final conditions = <String>[
      // Exclude items currently due for review — they come from loadReviewQuestions.
      "(next_review = '' OR next_review > ?)",
    ];
    final args = <Object>[today];

    if (diff.clause.isNotEmpty) {
      conditions.add(diff.clause);
      args.addAll(diff.args);
    }
    args.add(limit);

    final where = 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.getAll(
      'SELECT $_sm2Cols FROM phrases $where ORDER BY RANDOM() LIMIT ?',
      args,
    );
    return rows.map((r) => Question.fromMap(r)).toList();
  }

  /// Load questions that are due for review (next_review <= today).
  Future<List<Question>> loadReviewQuestions({
    String? difficulty,
    int limit = 50,
  }) async {
    final db = _db!;
    final diff = _difficultyFilter(difficulty);
    final today = todayKey();

    final conditions = <String>[
      "next_review != ''",
      "next_review <= ?",
    ];
    final args = <Object>[today];

    if (diff.clause.isNotEmpty) {
      conditions.add(diff.clause);
      args.addAll(diff.args);
    }
    args.add(limit);

    final where = 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.getAll(
      'SELECT $_sm2Cols FROM phrases $where ORDER BY next_review ASC LIMIT ?',
      args,
    );
    return rows.map((r) => Question.fromMap(r)).toList();
  }

  /// Write updated SM-2 state back to a single row.
  Future<void> updateSm2(
    int id, {
    required double easiness,
    required int intervalDays,
    required int repetitions,
    required String nextReview,
  }) async {
    await _db!.execute(
      'UPDATE phrases SET easiness = ?, interval_days = ?, '
      'repetitions = ?, next_review = ? WHERE id = ?',
      [easiness, intervalDays, repetitions, nextReview, id],
    );
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    try {
      await db?.close();
    } catch (_) {
      // Abandon the connection — native handle will be GC'd.
    }
  }
}
