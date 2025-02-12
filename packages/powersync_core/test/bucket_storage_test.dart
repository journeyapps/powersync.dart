import 'package:powersync_core/powersync_core.dart';
import 'package:powersync_core/src/bucket_storage.dart';
import 'package:powersync_core/src/sync_types.dart';
import 'package:sqlite_async/sqlite3_common.dart';
import 'package:test/test.dart';

import 'utils/abstract_test_utils.dart';
import 'utils/test_utils_impl.dart';

final testUtils = TestUtils();

const putAsset1_1 = OplogEntry(
    opId: '1',
    op: OpType.put,
    rowType: 'assets',
    rowId: 'O1',
    data: '{"description": "bar"}',
    checksum: 1);

const putAsset2_2 = OplogEntry(
    opId: '2',
    op: OpType.put,
    rowType: 'assets',
    rowId: 'O2',
    data: '{"description": "bar"}',
    checksum: 2);

const putAsset1_3 = OplogEntry(
    opId: '3',
    op: OpType.put,
    rowType: 'assets',
    rowId: 'O1',
    data: '{"description": "bard"}',
    checksum: 3);

const removeAsset1_4 = OplogEntry(
    opId: '4', op: OpType.remove, rowType: 'assets', rowId: 'O1', checksum: 4);

const removeAsset1_5 = OplogEntry(
    opId: '5', op: OpType.remove, rowType: 'assets', rowId: 'O1', checksum: 5);

BucketChecksum checksum(
    {required String bucket, required int checksum, int priority = 1}) {
  return BucketChecksum(bucket: bucket, priority: priority, checksum: checksum);
}

SyncDataBatch syncDataBatch(List<SyncBucketData> data) {
  return SyncDataBatch(data);
}

void main() {
  group('Bucket Storage Tests', () {
    late PowerSyncDatabase powersync;
    late BucketStorage bucketStorage;
    late String path;

    setUp(() async {
      path = testUtils.dbPath();
      await testUtils.cleanDb(path: path);

      powersync = await testUtils.setupPowerSync(path: path);
      bucketStorage = BucketStorage(powersync);
    });

    tearDown(() async {
      await powersync.close();
    });

    Future<void> syncLocalChecked(Checkpoint checkpoint) async {
      var result = await bucketStorage.syncLocalDatabase(checkpoint);
      expect(result, equals(SyncLocalDatabaseResult(ready: true)));
    }

    Future<void> expectAsset1_3() async {
      expect(
          await powersync.execute(
              "SELECT id, description, make FROM assets WHERE id = 'O1'"),
          equals([
            {'id': 'O1', 'description': 'bard', 'make': null}
          ]));
    }

    Future<void> expectNoAsset1() async {
      expect(
          await powersync.execute(
              "SELECT id, description, make FROM assets WHERE id = 'O1'"),
          equals([]));
    }

    Future<void> expectNoAssets() async {
      expect(
          await powersync.execute("SELECT id, description, make FROM assets"),
          equals([]));
    }

    test('Basic Setup', () async {
      expect(await bucketStorage.getBucketStates(), equals([]));
      expect(await bucketStorage.hasCompletedSync(), equals(false));

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset2_2, putAsset1_3],
        )
      ]));

      final bucketStates = await bucketStorage.getBucketStates();
      expect(bucketStates,
          equals([const BucketState(bucket: 'bucket1', opId: '3')]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      await expectAsset1_3();

      expect(await bucketStorage.hasCompletedSync(), equals(true));
    });

    test('empty sync', () async {
      expect(await bucketStorage.getBucketStates(), equals([]));
      expect(await bucketStorage.hasCompletedSync(), equals(false));

      await syncLocalChecked(Checkpoint(lastOpId: '3', checksums: []));

      expect(await bucketStorage.getBucketStates(), equals([]));
      expect(await bucketStorage.hasCompletedSync(), equals(true));
    });

    test('should get an object from multiple buckets', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_3],
        ),
        SyncBucketData(bucket: 'bucket2', data: [putAsset1_3])
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '3', checksums: [
        checksum(bucket: 'bucket1', checksum: 3),
        checksum(bucket: 'bucket2', checksum: 3)
      ]));

      await expectAsset1_3();
    });

    test('should prioritize later updates', () async {
      // Test behaviour when the same object is present in multiple buckets.
      // In this case, there are two different versions in the different buckets.
      // While we should not get this with our server implementation, the client still specifies this behaviour:
      // The largest op_id wins.
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [putAsset1_3]),
        SyncBucketData(bucket: 'bucket2', data: [putAsset1_1])
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '3', checksums: [
        checksum(bucket: 'bucket1', checksum: 3),
        checksum(bucket: 'bucket2', checksum: 1)
      ]));

      await expectAsset1_3();
    });

    test('should ignore a remove from one bucket', () async {
      // When we have 1 PUT and 1 REMOVE, the object must be kept.
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [putAsset1_3]),
        SyncBucketData(bucket: 'bucket2', data: [putAsset1_3, removeAsset1_4])
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '4', checksums: [
        checksum(bucket: 'bucket1', checksum: 3),
        checksum(bucket: 'bucket2', checksum: 7)
      ]));

      await expectAsset1_3();
    });

    test('should remove when removed from all buckets', () async {
      // When we only have REMOVE left for an object, it must be deleted.
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [putAsset1_3, removeAsset1_5]),
        SyncBucketData(bucket: 'bucket2', data: [putAsset1_3, removeAsset1_4])
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '5', checksums: [
        checksum(bucket: 'bucket1', checksum: 8),
        checksum(bucket: 'bucket2', checksum: 7)
      ]));

      await expectNoAssets();
    });

    test('put then remove', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [putAsset1_3]),
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '3', checksums: [
        checksum(bucket: 'bucket1', checksum: 3),
      ]));

      await expectAsset1_3();

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [removeAsset1_5])
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '5', checksums: [
        checksum(bucket: 'bucket1', checksum: 8),
      ]));

      await expectNoAssets();
    });

    test('blank remove', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [putAsset1_3, removeAsset1_4]),
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '4', checksums: [
        checksum(bucket: 'bucket1', checksum: 7),
      ]));

      await expectNoAssets();

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [removeAsset1_5])
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '5', checksums: [
        checksum(bucket: 'bucket1', checksum: 12),
      ]));

      await expectNoAssets();
    });

    test('put | put remove', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [putAsset1_1]),
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '1', checksums: [
        checksum(bucket: 'bucket1', checksum: 1),
      ]));

      expect(
          await powersync.execute(
              "SELECT id, description, make FROM assets WHERE id = 'O1'"),
          equals([
            {'id': 'O1', 'description': 'bar', 'make': null}
          ]));

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [putAsset1_3]),
        SyncBucketData(bucket: 'bucket1', data: [removeAsset1_5])
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '5', checksums: [
        checksum(bucket: 'bucket1', checksum: 9),
      ]));

      await expectNoAssets();
    });

    test('should use subkeys', () async {
      // subkeys cause this to be treated as a separate entity in the oplog,
      // but same entity in the local db.
      var put4 = OplogEntry(
          opId: '4',
          op: OpType.put,
          subkey: 'b',
          rowType: 'assets',
          rowId: 'O1',
          data: '{"description": "B"}',
          checksum: 4);

      var remove5 = OplogEntry(
          opId: '5',
          op: OpType.remove,
          subkey: 'b',
          rowType: 'assets',
          rowId: 'O1',
          checksum: 5);

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
            bucket: 'bucket1', data: [putAsset1_1, putAsset1_3, put4]),
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '4', checksums: [
        checksum(bucket: 'bucket1', checksum: 8),
      ]));

      expect(
          await powersync.execute(
              "SELECT id, description, make FROM assets WHERE id = 'O1'"),
          equals([
            {'id': 'O1', 'description': 'B', 'make': null}
          ]));

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [remove5]),
      ]));

      await syncLocalChecked(Checkpoint(lastOpId: '5', checksums: [
        checksum(bucket: 'bucket1', checksum: 13),
      ]));

      await expectAsset1_3();
    });

    test('should fail checksum validation', () async {
      // Simple checksum validation
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
            bucket: 'bucket1', data: [putAsset1_1, putAsset2_2, putAsset1_3]),
      ]));

      var result = await bucketStorage
          .syncLocalDatabase(Checkpoint(lastOpId: '3', checksums: [
        checksum(bucket: 'bucket1', checksum: 10),
        checksum(bucket: 'bucket2', checksum: 1)
      ]));
      expect(
          result,
          equals(SyncLocalDatabaseResult(
              ready: false,
              checkpointValid: false,
              checkpointFailures: ['bucket1', 'bucket2'])));

      await expectNoAssets();
    });

    test('should delete buckets', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_3],
        ),
        SyncBucketData(
          bucket: 'bucket2',
          data: [putAsset1_3],
        ),
      ]));

      await bucketStorage.removeBuckets(['bucket2']);
      // The delete only takes effect after syncLocal.

      await syncLocalChecked(Checkpoint(lastOpId: '3', checksums: [
        checksum(bucket: 'bucket1', checksum: 3),
      ]));

      // Bucket is deleted, but object is still present in other buckets.
      await expectAsset1_3();

      await bucketStorage.removeBuckets(['bucket1']);
      await syncLocalChecked(Checkpoint(lastOpId: '3', checksums: []));
      // Both buckets deleted - object removed.
      await expectNoAssets();
    });

    test('should delete and re-create buckets', () async {
      // Save some data
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1],
        ),
      ]));

      // Delete the bucket
      await bucketStorage.removeBuckets(['bucket1']);

      // Save some data again
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset1_3],
        ),
      ]));
      // Delete again
      await bucketStorage.removeBuckets(['bucket1']);

      // Final save of data
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset1_3],
        ),
      ]));

      // Check that the data is there
      await syncLocalChecked(Checkpoint(lastOpId: '3', checksums: [
        checksum(bucket: 'bucket1', checksum: 4),
      ]));
      await expectAsset1_3();

      // Now final delete
      await bucketStorage.removeBuckets(['bucket1']);
      await syncLocalChecked(Checkpoint(lastOpId: '3', checksums: []));
      await expectNoAssets();
    });

    test('should handle MOVE', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [OplogEntry(opId: '1', op: OpType.move, checksum: 1)],
        ),
      ]));

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_3],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 4)]));

      await expectAsset1_3();
    });

    test('should handle CLEAR', () async {
      // Save some data
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '1',
          checksums: [checksum(bucket: 'bucket1', checksum: 1)]));

      // CLEAR, then save new data
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [
            OplogEntry(opId: '2', op: OpType.clear, checksum: 2),
            OplogEntry(
                opId: '3',
                checksum: 3,
                op: putAsset2_2.op,
                data: putAsset2_2.data,
                rowId: putAsset2_2.rowId,
                rowType: putAsset2_2.rowType)
          ],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          // 2 + 3. 1 is replaced with 2.
          checksums: [checksum(bucket: 'bucket1', checksum: 5)]));

      await expectNoAsset1();
      expect(
          await powersync
              .execute("SELECT id, description FROM assets WHERE id = 'O2'"),
          equals([
            {'id': 'O2', 'description': 'bar'}
          ]));
    });

    test('update with new types', () async {
      // Test case where a type is added to the schema after we already have the data.

      // Re-initialize with empty database
      await testUtils.cleanDb(path: path);

      powersync = PowerSyncDatabase.withFactory(
          await testUtils.testFactory(path: path),
          schema: const Schema([]));
      await powersync.initialize();
      bucketStorage = BucketStorage(powersync);

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset2_2, putAsset1_3],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '4',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      await expectLater(() async {
        await powersync.execute('SELECT * FROM assets');
      },
          throwsA((dynamic e) =>
              e is SqliteException && e.message.contains('no such table')));

      await powersync.close();

      // Now open another instance with new schema
      powersync = PowerSyncDatabase.withFactory(
          await testUtils.testFactory(path: path),
          schema: defaultSchema);
      await expectAsset1_3();
    });

    test('should remove types', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset2_2, putAsset1_3],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      await expectAsset1_3();

      await powersync.close();

      // Now open another instance with new schema
      powersync = PowerSyncDatabase.withFactory(
          await testUtils.testFactory(path: path),
          schema: const Schema([]));

      await expectLater(
          () async => await powersync.execute('SELECT * FROM assets'),
          throwsA((dynamic e) =>
              e is SqliteException && e.message.contains('no such table')));

      await powersync.close();

      // Add schema again
      powersync = PowerSyncDatabase.withFactory(
          await testUtils.testFactory(path: path),
          schema: schema);
      await expectAsset1_3();
    });

    test('should compact', () async {
      // Test compacting behaviour.
      // This test relies heavily on internals, and will have to be updated when the compact implementation is updated.

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
            bucket: 'bucket1', data: [putAsset1_1, putAsset2_2, removeAsset1_4])
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '4',
          writeCheckpoint: '4',
          checksums: [checksum(bucket: 'bucket1', checksum: 7)]));

      await bucketStorage.forceCompact();

      await syncLocalChecked(Checkpoint(
          lastOpId: '4',
          writeCheckpoint: '4',
          checksums: [checksum(bucket: 'bucket1', checksum: 7)]));

      final stats = await powersync.execute(
          'SELECT row_type as type, row_id as id, count(*) as count FROM ps_oplog GROUP BY row_type, row_id ORDER BY row_type, row_id');
      expect(
          stats,
          equals([
            {'type': 'assets', 'id': 'O2', 'count': 1}
          ]));
    });

    test('should compact with checksum wrapping', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [
          OplogEntry(
              opId: '1',
              op: OpType.put,
              rowType: 'assets',
              rowId: 'O1',
              data: '{"description": "b1"}',
              checksum: 2147483647),
          OplogEntry(
              opId: '2',
              op: OpType.put,
              rowType: 'assets',
              rowId: 'O1',
              data: '{"description": "b2"}',
              checksum: 2147483646),
          OplogEntry(
              opId: '3',
              op: OpType.put,
              rowType: 'assets',
              rowId: 'O1',
              data: '{"description": "b3"}',
              checksum: 2147483645)
        ])
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '4',
          writeCheckpoint: '4',
          checksums: [checksum(bucket: 'bucket1', checksum: 2147483642)]));

      await bucketStorage.forceCompact();

      await syncLocalChecked(Checkpoint(
          lastOpId: '4',
          writeCheckpoint: '4',
          checksums: [checksum(bucket: 'bucket1', checksum: 2147483642)]));

      final stats = await powersync.execute(
          'SELECT row_type as type, row_id as id, count(*) as count FROM ps_oplog GROUP BY row_type, row_id ORDER BY row_type, row_id');
      expect(
          stats,
          equals([
            {'type': 'assets', 'id': 'O1', 'count': 1}
          ]));
    });

    test('should compact with checksum wrapping (2)', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(bucket: 'bucket1', data: [
          OplogEntry(
              opId: '1',
              op: OpType.put,
              rowType: 'assets',
              rowId: 'O1',
              data: '{"description": "b1"}',
              checksum: 2147483647),
          OplogEntry(
              opId: '2',
              op: OpType.put,
              rowType: 'assets',
              rowId: 'O1',
              data: '{"description": "b2"}',
              checksum: 2147483646),
        ])
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '4',
          writeCheckpoint: '4',
          checksums: [checksum(bucket: 'bucket1', checksum: -3)]));

      await bucketStorage.forceCompact();

      await syncLocalChecked(Checkpoint(
          lastOpId: '4',
          writeCheckpoint: '4',
          checksums: [checksum(bucket: 'bucket1', checksum: -3)]));

      final stats = await powersync.execute(
          'SELECT row_type as type, row_id as id, count(*) as count FROM ps_oplog GROUP BY row_type, row_id ORDER BY row_type, row_id');
      expect(
          stats,
          equals([
            {'type': 'assets', 'id': 'O1', 'count': 1}
          ]));
    });

    test('should not sync local db with pending crud - server removed',
        () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset2_2, putAsset1_3],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      // Local save
      powersync.execute('INSERT INTO assets(id) VALUES(?)', ['O3']);
      expect(
          await powersync.execute('SELECT id FROM assets WHERE id = \'O3\''),
          equals([
            {'id': 'O3'}
          ]));

      // At this point, we have data in the crud table, and are not able to sync the local db.
      final result = await bucketStorage.syncLocalDatabase(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));
      expect(result, equals(SyncLocalDatabaseResult(ready: false)));

      final batch = await bucketStorage.getCrudBatch();
      await batch!.complete();
      await bucketStorage.updateLocalTarget(() async {
        return '4';
      });

      // At this point, the data has been uploaded, but not synced back yet.
      final result3 = await bucketStorage.syncLocalDatabase(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));
      expect(result3, equals(SyncLocalDatabaseResult(ready: false)));

      // The data must still be present locally.
      expect(
          await powersync.execute('SELECT id FROM assets WHERE id = \'O3\''),
          equals([
            {'id': 'O3'}
          ]));

      await bucketStorage.saveSyncData(
          syncDataBatch([SyncBucketData(bucket: 'bucket1', data: [])]));

      // Now we have synced the data back (or lack of data in this case),
      // so we can do a local sync.
      await syncLocalChecked(Checkpoint(
          lastOpId: '5',
          writeCheckpoint: '5',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      // Since the object was not in the sync response, it is deleted.
      expect(await powersync.execute('SELECT id FROM assets WHERE id = \'O3\''),
          equals([]));
    });

    test(
        'should not sync local db with pending crud when more crud is added (1)',
        () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset2_2, putAsset1_3],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      // Local save
      powersync.execute('INSERT INTO assets(id) VALUES(?)', ['O3']);

      final batch = await bucketStorage.getCrudBatch();
      await batch!.complete();
      await bucketStorage.updateLocalTarget(() async {
        return '4';
      });

      final result3 = await bucketStorage.syncLocalDatabase(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));
      expect(result3, equals(SyncLocalDatabaseResult(ready: false)));

      await bucketStorage.saveSyncData(
          syncDataBatch([SyncBucketData(bucket: 'bucket1', data: [])]));

      // Add more data before syncLocalDatabase.
      powersync.execute('INSERT INTO assets(id) VALUES(?)', ['O4']);

      final result4 = await bucketStorage.syncLocalDatabase(Checkpoint(
          lastOpId: '5',
          writeCheckpoint: '5',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));
      expect(result4, equals(SyncLocalDatabaseResult(ready: false)));
    });

    test(
        'should not sync local db with pending crud when more crud is added (2)',
        () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset2_2, putAsset1_3],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      // Local save
      await powersync.execute('INSERT INTO assets(id) VALUES(?)', ['O3']);
      final batch = await bucketStorage.getCrudBatch();
      // Add more data before the complete() call

      await powersync.execute('INSERT INTO assets(id) VALUES(?)', ['O4']);
      await batch!.complete();
      await bucketStorage.updateLocalTarget(() async {
        return '4';
      });

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [],
        ),
      ]));

      final result4 = await bucketStorage.syncLocalDatabase(Checkpoint(
          lastOpId: '5',
          writeCheckpoint: '5',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));
      expect(result4, equals(SyncLocalDatabaseResult(ready: false)));
    });

    test('should not sync local db with pending crud - update on server',
        () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset2_2, putAsset1_3],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      // Local save
      powersync.execute('INSERT INTO assets(id) VALUES(?)', ['O3']);
      final batch = await bucketStorage.getCrudBatch();
      await batch!.complete();
      await bucketStorage.updateLocalTarget(() async {
        return '4';
      });

      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [
            OplogEntry(
                opId: '5',
                op: OpType.put,
                rowType: 'assets',
                rowId: 'O3',
                checksum: 5,
                data: '{"description": "server updated"}')
          ],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '5',
          writeCheckpoint: '5',
          checksums: [checksum(bucket: 'bucket1', checksum: 11)]));

      expect(
          await powersync
              .execute('SELECT description FROM assets WHERE id = \'O3\''),
          equals([
            {'description': 'server updated'}
          ]));
    });

    test('should revert a failing insert', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset2_2, putAsset1_3],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      // Local insert, later rejected by server
      await powersync.execute(
          'INSERT INTO assets(id, description) VALUES(?, ?)',
          ['O3', 'inserted']);
      final batch = await bucketStorage.getCrudBatch();
      await batch!.complete();
      await bucketStorage.updateLocalTarget(() async {
        return '4';
      });

      expect(
          await powersync
              .execute('SELECT description FROM assets WHERE id = \'O3\''),
          equals([
            {'description': 'inserted'}
          ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '4',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      expect(
          await powersync
              .execute('SELECT description FROM assets WHERE id = \'O3\''),
          equals([]));
    });

    test('should revert a failing delete', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset2_2, putAsset1_3],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      // Local delete, later rejected by server
      await powersync.execute('DELETE FROM assets WHERE id = ?', ['O2']);

      expect(
          await powersync
              .execute('SELECT description FROM assets WHERE id = \'O2\''),
          equals([]));
      // Simulate a permissions error when uploading - data should be preserved.
      final batch = await bucketStorage.getCrudBatch();
      await batch!.complete();

      await bucketStorage.updateLocalTarget(() async {
        return '4';
      });

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '4',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      expect(
          await powersync
              .execute('SELECT description FROM assets WHERE id = \'O2\''),
          equals([
            {'description': 'bar'}
          ]));
    });

    test('should revert a failing update', () async {
      await bucketStorage.saveSyncData(syncDataBatch([
        SyncBucketData(
          bucket: 'bucket1',
          data: [putAsset1_1, putAsset2_2, putAsset1_3],
        ),
      ]));

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '3',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      // Local update, later rejected by server
      await powersync.execute(
          'UPDATE assets SET description = ? WHERE id = ?', ['updated', 'O2']);

      expect(
          await powersync
              .execute('SELECT description FROM assets WHERE id = \'O2\''),
          equals([
            {'description': 'updated'}
          ]));
      // Simulate a permissions error when uploading - data should be preserved.
      final batch = await bucketStorage.getCrudBatch();
      await batch!.complete();

      await bucketStorage.updateLocalTarget(() async {
        return '4';
      });

      await syncLocalChecked(Checkpoint(
          lastOpId: '3',
          writeCheckpoint: '4',
          checksums: [checksum(bucket: 'bucket1', checksum: 6)]));

      expect(
          await powersync
              .execute('SELECT description FROM assets WHERE id = \'O2\''),
          equals([
            {'description': 'bar'}
          ]));
    });
  });
}
