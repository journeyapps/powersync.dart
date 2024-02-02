import 'dart:async';

import 'package:sqlite_async/sqlite_async.dart';
import 'package:sqlite_async/sqlite3_common.dart' as sqlite;

Future<T> asyncDirectTransaction<T>(sqlite.CommonDatabase db,
    FutureOr<T> Function(sqlite.CommonDatabase db) callback) async {
  for (var i = 50; i >= 0; i--) {
    try {
      db.execute('BEGIN IMMEDIATE');
      late T result;
      try {
        result = await callback(db);
        db.execute('COMMIT');
      } catch (e) {
        try {
          db.execute('ROLLBACK');
        } catch (e2) {
          // Safe to ignore
        }
        rethrow;
      }

      return result;
    } catch (e) {
      if (e is sqlite.SqliteException) {
        if (e.resultCode == 5 && i != 0) {
          // SQLITE_BUSY
          await Future.delayed(const Duration(milliseconds: 50));
          continue;
        }
      }
      rethrow;
    }
  }
  throw AssertionError('Should not reach this');
}

Future<T> internalTrackedWriteTransaction<T>(SqliteWriteContext ctx,
    Future<T> Function(SqliteWriteContext tx) callback) async {
  try {
    await ctx.execute('BEGIN IMMEDIATE');
    final result = await internalTrackedWrite(ctx, callback);
    await ctx.execute('COMMIT');
    return result;
  } catch (e) {
    try {
      await ctx.execute('ROLLBACK');
    } catch (e) {
      // In rare cases, a ROLLBACK may fail.
      // Safe to ignore.
    }
    rethrow;
  }
}

/// Internally tracks a write
/// The transaction is assumed to be started externally
Future<T> internalTrackedWrite<T>(SqliteWriteContext ctx,
    Future<T> Function(SqliteWriteContext tx) callback) async {
  await ctx.execute(
      'UPDATE ps_tx SET current_tx = next_tx, next_tx = next_tx + 1 WHERE id = 1');
  final result = await callback(ctx);
  await ctx.execute('UPDATE ps_tx SET current_tx = NULL WHERE id = 1');
  return result;
}
