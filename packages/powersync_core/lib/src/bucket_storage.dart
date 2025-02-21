import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:powersync_core/sqlite_async.dart';
import 'package:powersync_core/sqlite3_common.dart';

import 'crud.dart';
import 'schema_logic.dart';
import 'sync_types.dart';

const compactOperationInterval = 1000;

class BucketStorage {
  final SqliteConnection _internalDb;
  bool _hasCompletedSync = false;
  bool _pendingBucketDeletes = false;
  int _compactCounter = compactOperationInterval;

  BucketStorage(SqliteConnection db) : _internalDb = db {
    _init();
  }

  void _init() {}

  // Use only for read statements
  Future<ResultSet> select(String query,
      [List<Object?> parameters = const []]) async {
    return await _internalDb.execute(query, parameters);
  }

  void startSession() {}

  Future<List<BucketState>> getBucketStates() async {
    final rows = await select(
        'SELECT name as bucket, cast(last_op as TEXT) as op_id FROM ps_buckets WHERE pending_delete = 0 AND name != \'\$local\'');
    return [
      for (var row in rows)
        BucketState(
            bucket: row['bucket'] as String, opId: row['op_id'] as String)
    ];
  }

  Future<String> getClientId() async {
    final rows = await select('SELECT powersync_client_id() as client_id');
    return rows.first['client_id'] as String;
  }

  Future<void> saveSyncData(SyncDataBatch batch) async {
    var count = 0;

    await writeTransaction((tx) async {
      for (var b in batch.buckets) {
        count += b.data.length;
        await _updateBucket2(
            tx,
            jsonEncode({
              'buckets': [b],
            }));
      }
      // No need to flush - the data is not directly visible to the user either way.
      // We get major initial sync performance improvements with IndexedDB by
      // not flushing here.
    }, flush: false);
    _compactCounter += count;
  }

  Future<void> _updateBucket2(SqliteWriteContext tx, String json) async {
    await tx.execute('INSERT INTO powersync_operations(op, data) VALUES(?, ?)',
        ['save', json]);
  }

  Future<void> removeBuckets(List<String> buckets) async {
    for (final bucket in buckets) {
      await deleteBucket(bucket);
    }
  }

  Future<void> deleteBucket(String bucket) async {
    await writeTransaction((tx) async {
      await tx.execute(
          'INSERT INTO powersync_operations(op, data) VALUES(?, ?)',
          ['delete_bucket', bucket]);
      // No need to flush - not directly visible to the user
    }, flush: false);

    _pendingBucketDeletes = true;
  }

  Future<bool> hasCompletedSync() async {
    if (_hasCompletedSync) {
      return true;
    }
    final rs = await select("SELECT powersync_last_synced_at() as synced_at");
    final value = rs.first['synced_at'] as String?;

    if (value != null) {
      _hasCompletedSync = true;
      return true;
    }
    return false;
  }

  Future<SyncLocalDatabaseResult> syncLocalDatabase(Checkpoint checkpoint,
      {int? forPriority}) async {
    final r = await validateChecksums(checkpoint, priority: forPriority);

    if (!r.checkpointValid) {
      for (String b in r.checkpointFailures ?? []) {
        await deleteBucket(b);
      }
      return r;
    }
    final bucketNames = [
      for (final c in checkpoint.checksums)
        if (forPriority == null || c.priority <= forPriority) c.bucket
    ];

    await writeTransaction((tx) async {
      await tx.execute(
          "UPDATE ps_buckets SET last_op = ? WHERE name IN (SELECT json_each.value FROM json_each(?))",
          [checkpoint.lastOpId, jsonEncode(bucketNames)]);
      if (forPriority == null && checkpoint.writeCheckpoint != null) {
        await tx.execute(
            "UPDATE ps_buckets SET last_op = ? WHERE name = '\$local'",
            [checkpoint.writeCheckpoint]);
      }
      // Not flushing here - the flush will happen in the next step
    }, flush: false);

    final valid = await updateObjectsFromBuckets(checkpoint,
        forPartialPriority: forPriority);
    if (!valid) {
      return SyncLocalDatabaseResult(ready: false);
    }

    await forceCompact();

    return SyncLocalDatabaseResult(ready: true);
  }

  Future<bool> updateObjectsFromBuckets(Checkpoint checkpoint,
      {int? forPartialPriority}) async {
    return writeTransaction((tx) async {
      await tx
          .execute("INSERT INTO powersync_operations(op, data) VALUES(?, ?)", [
        'sync_local',
        forPartialPriority != null
            ? jsonEncode({
                'priority': forPartialPriority,
                // If we're at a partial checkpoint, we should only publish the
                // buckets at the completed priority levels.
                'buckets': [
                  for (final desc in checkpoint.checksums)
                    // Note that higher priorities are encoded as smaller values
                    if (desc.priority <= forPartialPriority) desc.bucket,
                ],
              })
            : null,
      ]);
      final rs = await tx.execute('SELECT last_insert_rowid() as result');
      final result = rs[0]['result'];
      if (result == 1) {
        return true;
      } else {
        // can_update_local(db) == false
        return false;
      }
      // Important to flush here.
      // After this step, the synced data will be visible to the user,
      // and we don't want that to be reverted.
    }, flush: true);
  }

  Future<SyncLocalDatabaseResult> validateChecksums(Checkpoint checkpoint,
      {int? priority}) async {
    final rs =
        await select("SELECT powersync_validate_checkpoint(?) as result", [
      jsonEncode({...checkpoint.toJson(priority: priority)})
    ]);
    final result =
        jsonDecode(rs[0]['result'] as String) as Map<String, dynamic>;
    if (result['valid'] as bool) {
      return SyncLocalDatabaseResult(ready: true);
    } else {
      return SyncLocalDatabaseResult(
          checkpointValid: false,
          ready: false,
          checkpointFailures:
              (result['failed_buckets'] as List).cast<String>());
    }
  }

  Future<void> forceCompact() async {
    _compactCounter = compactOperationInterval;
    _pendingBucketDeletes = true;

    await autoCompact();
  }

  Future<void> autoCompact() async {
    // This is a no-op since powersync-sqlite-core v0.3.0

    // 1. Delete buckets
    await _deletePendingBuckets();

    // 2. Clear REMOVE operations, only keeping PUT ones
    await _clearRemoveOps();
  }

  Future<void> _deletePendingBuckets() async {
    // This is a no-op since powersync-sqlite-core v0.3.0
    if (_pendingBucketDeletes) {
      // Executed once after start-up, and again when there are pending deletes.
      await writeTransaction((tx) async {
        await tx.execute(
            'INSERT INTO powersync_operations(op, data) VALUES (?, ?)',
            ['delete_pending_buckets', '']);
        // No need to flush - not directly visible to the user
      }, flush: false);
      _pendingBucketDeletes = false;
    }
  }

  Future<void> _clearRemoveOps() async {
    if (_compactCounter < compactOperationInterval) {
      return;
    }

    // This is a no-op since powersync-sqlite-core v0.3.0
    await writeTransaction((tx) async {
      await tx.execute(
          'INSERT INTO powersync_operations(op, data) VALUES (?, ?)',
          ['clear_remove_ops', '']);
      // No need to flush - not directly visible to the user
    }, flush: false);
    _compactCounter = 0;
  }

  void setTargetCheckpoint(Checkpoint checkpoint) {
    // No-op for now
  }

  Future<bool> updateLocalTarget(
      Future<String> Function() checkpointCallback) async {
    final rs1 = await select(
        'SELECT CAST(target_op AS TEXT) FROM ps_buckets WHERE name = \'\$local\' AND target_op = $maxOpId');
    if (rs1.isEmpty) {
      // Nothing to update
      return false;
    }
    final rs = await select(
        'SELECT seq FROM sqlite_sequence WHERE name = \'ps_crud\'');
    if (rs.isEmpty) {
      // Nothing to update
      return false;
    }
    int seqBefore = rs.first['seq'] as int;
    var opId = await checkpointCallback();

    return await writeTransaction((tx) async {
      final anyData = await tx.execute('SELECT 1 FROM ps_crud LIMIT 1');
      if (anyData.isNotEmpty) {
        return false;
      }
      final rs = await tx
          .execute('SELECT seq FROM sqlite_sequence WHERE name = \'ps_crud\'');
      assert(rs.isNotEmpty);

      int seqAfter = rs.first['seq'] as int;
      if (seqAfter != seqBefore) {
        // New crud data may have been uploaded since we got the checkpoint. Abort.
        return false;
      }

      await tx.execute(
          "UPDATE ps_buckets SET target_op = CAST(? as INTEGER) WHERE name='\$local'",
          [opId]);

      return true;
      // Flush here - don't want to lose the write checkpoint updates.
    }, flush: true);
  }

  Future<CrudEntry?> nextCrudItem() async {
    var next = await _internalDb
        .getOptional('SELECT * FROM ps_crud ORDER BY id ASC LIMIT 1');
    return next == null ? null : CrudEntry.fromRow(next);
  }

  Future<bool> hasCrud() async {
    final anyData = await select('SELECT 1 FROM ps_crud LIMIT 1');
    return anyData.isNotEmpty;
  }

  /// For tests only. Others should use the version on PowerSyncDatabase.
  Future<CrudBatch?> getCrudBatch({int limit = 100}) async {
    if (!(await hasCrud())) {
      return null;
    }

    final rows =
        await select('SELECT * FROM ps_crud ORDER BY id ASC LIMIT ?', [limit]);
    List<CrudEntry> all = [];
    for (var row in rows) {
      all.add(CrudEntry.fromRow(row));
    }
    if (all.isEmpty) {
      return null;
    }
    final last = all[all.length - 1];
    return CrudBatch(
        crud: all,
        haveMore: true,
        complete: ({String? writeCheckpoint}) async {
          await writeTransaction((tx) async {
            await tx
                .execute('DELETE FROM ps_crud WHERE id <= ?', [last.clientId]);
            if (writeCheckpoint != null &&
                (await tx.execute('SELECT 1 FROM ps_crud LIMIT 1')).isEmpty) {
              await tx.execute(
                  'UPDATE ps_buckets SET target_op = CAST(? as INTEGER) WHERE name=\'\$local\'',
                  [writeCheckpoint]);
            } else {
              await tx.execute(
                  'UPDATE ps_buckets SET target_op = $maxOpId WHERE name=\'\$local\'');
            }
            // Flush here - don't want to lose the write checkpoint updates.
          }, flush: true);
        });
  }

  /// Note: The asynchronous nature of this is due to this needing a global
  /// lock. The actual database operations are still synchronous, and it
  /// is assumed that multiple functions on this instance won't be called
  /// concurrently.
  Future<T> writeTransaction<T>(
      Future<T> Function(SqliteWriteContext tx) callback,
      {Duration? lockTimeout,
      required bool flush}) async {
    return _internalDb.writeTransaction(callback, lockTimeout: lockTimeout);
  }
}

class BucketState {
  final String bucket;
  final String opId;

  const BucketState({required this.bucket, required this.opId});

  @override
  String toString() {
    return "BucketState<$bucket:$opId>";
  }

  @override
  int get hashCode {
    return Object.hash(bucket, opId);
  }

  @override
  bool operator ==(Object other) {
    return other is BucketState && other.bucket == bucket && other.opId == opId;
  }
}

class SyncLocalDatabaseResult {
  final bool ready;
  final bool checkpointValid;
  final List<String>? checkpointFailures;

  const SyncLocalDatabaseResult(
      {this.ready = true,
      this.checkpointValid = true,
      this.checkpointFailures});

  @override
  String toString() {
    return "SyncLocalDatabaseResult<ready=$ready, checkpointValid=$checkpointValid, failures=$checkpointFailures>";
  }

  @override
  int get hashCode {
    return Object.hash(ready, checkpointValid,
        const ListEquality<String?>().hash(checkpointFailures));
  }

  @override
  bool operator ==(Object other) {
    return other is SyncLocalDatabaseResult &&
        other.ready == ready &&
        other.checkpointValid == checkpointValid &&
        const ListEquality<String?>()
            .equals(other.checkpointFailures, checkpointFailures);
  }
}

class ChecksumCache {
  String lastOpId;
  Map<String, BucketChecksum> checksums;

  ChecksumCache(this.lastOpId, this.checksums);
}

enum OpType {
  clear(1),
  move(2),
  put(3),
  remove(4);

  final int value;

  const OpType(this.value);

  static OpType? fromJson(String json) {
    switch (json) {
      case 'CLEAR':
        return clear;
      case 'MOVE':
        return move;
      case 'PUT':
        return put;
      case 'REMOVE':
        return remove;
      default:
        return null;
    }
  }

  String toJson() {
    switch (this) {
      case clear:
        return 'CLEAR';
      case move:
        return 'MOVE';
      case put:
        return 'PUT';
      case remove:
        return 'REMOVE';
    }
  }
}
