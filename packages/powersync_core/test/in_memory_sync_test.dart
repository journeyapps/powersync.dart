import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:powersync_core/powersync_core.dart';
import 'package:powersync_core/sqlite3_common.dart';
import 'package:powersync_core/src/log_internal.dart';
import 'package:powersync_core/src/streaming_sync.dart';
import 'package:powersync_core/src/sync_types.dart';
import 'package:test/test.dart';

import 'server/sync_server/in_memory_sync_server.dart';
import 'utils/abstract_test_utils.dart';
import 'utils/in_memory_http.dart';
import 'utils/test_utils_impl.dart';

void main() {
  group('in-memory sync tests', () {
    late final testUtils = TestUtils();

    late TestPowerSyncFactory factory;
    late CommonDatabase raw;
    late PowerSyncDatabase database;
    late MockSyncService syncService;
    late StreamingSyncImplementation syncClient;

    setUp(() async {
      final (client, server) = inMemoryServer();
      syncService = MockSyncService();
      server.mount(syncService.router.call);

      factory = await testUtils.testFactory();
      (raw, database) = await factory.openInMemoryDatabase();
      await database.initialize();
      syncClient = database.connectWithMockService(
        client,
        TestConnector(() async {
          return PowerSyncCredentials(
            endpoint: server.url.toString(),
            token: 'token not used here',
            expiresAt: DateTime.now(),
          );
        }),
      );
    });

    tearDown(() async {
      await syncClient.abort();
      await database.close();
      await syncService.stop();
    });

    Future<StreamQueue<SyncStatus>> waitForConnection(
        {bool expectNoWarnings = true}) async {
      if (expectNoWarnings) {
        isolateLogger.onRecord.listen((e) {
          if (e.level >= Level.WARNING) {
            fail('Unexpected log: $e');
          }
        });
      }
      syncClient.streamingSync();
      await syncService.waitForListener;

      expect(database.currentStatus.lastSyncedAt, isNull);
      expect(database.currentStatus.downloading, isFalse);
      final status = StreamQueue(database.statusStream);
      addTearDown(status.cancel);

      syncService.addKeepAlive();
      await expectLater(
          status, emits(isSyncStatus(connected: true, hasSynced: false)));
      return status;
    }

    test('persists completed sync information', () async {
      final status = await waitForConnection();

      syncService.addLine({
        'checkpoint': Checkpoint(
          lastOpId: '0',
          writeCheckpoint: null,
          checksums: [BucketChecksum(bucket: 'bkt', priority: 1, checksum: 0)],
        )
      });
      await expectLater(status, emits(isSyncStatus(downloading: true)));

      syncService.addLine({
        'checkpoint_complete': {'last_op_id': '0'}
      });
      await expectLater(
          status, emits(isSyncStatus(downloading: false, hasSynced: true)));

      final independentDb = factory.wrapRaw(raw);
      // Even though this database doesn't have a sync client attached to it,
      // is should reconstruct hasSynced from the database.
      await independentDb.initialize();
      expect(independentDb.currentStatus.hasSynced, isTrue);
      // A complete sync also means that all partial syncs have completed
      expect(
          independentDb.currentStatus
              .statusForPriority(BucketPriority(3))
              .hasSynced,
          isTrue);
    });

    test('can save independent buckets in same transaction', () async {
      final status = await waitForConnection();

      syncService.addLine({
        'checkpoint': Checkpoint(
          lastOpId: '0',
          writeCheckpoint: null,
          checksums: [
            BucketChecksum(bucket: 'a', checksum: 0, priority: 3),
            BucketChecksum(bucket: 'b', checksum: 0, priority: 3),
          ],
        )
      });
      await expectLater(status, emits(isSyncStatus(downloading: true)));

      var commits = 0;
      raw.commits.listen((_) => commits++);

      syncService
        ..addLine({
          'data': {
            'bucket': 'a',
            'data': <Map<String, Object?>>[
              {
                'op_id': '1',
                'op': 'PUT',
                'object_type': 'a',
                'object_id': '1',
                'checksum': 0,
                'data': {},
              }
            ],
          }
        })
        ..addLine({
          'data': {
            'bucket': 'b',
            'data': <Map<String, Object?>>[
              {
                'op_id': '2',
                'op': 'PUT',
                'object_type': 'b',
                'object_id': '1',
                'checksum': 0,
                'data': {},
              }
            ],
          }
        });

      // Wait for the operations to be inserted.
      while (raw.select('SELECT * FROM ps_oplog;').length < 2) {
        await pumpEventQueue();
      }

      // The two buckets should have been inserted in a single transaction
      // because the messages were received in quick succession.
      expect(commits, 1);
    });

    group('partial sync', () {
      test('updates sync state incrementally', () async {
        final status = await waitForConnection();

        final checksums = [
          for (var prio = 0; prio <= 3; prio++)
            BucketChecksum(
                bucket: 'prio$prio', priority: prio, checksum: 10 + prio)
        ];
        syncService.addLine({
          'checkpoint': Checkpoint(
            lastOpId: '4',
            writeCheckpoint: null,
            checksums: checksums,
          )
        });
        var operationId = 1;

        void addRow(int priority) {
          syncService.addLine({
            'data': {
              'bucket': 'prio$priority',
              'data': [
                {
                  'checksum': priority + 10,
                  'data': {'name': 'test', 'email': 'email'},
                  'op': 'PUT',
                  'op_id': '${operationId++}',
                  'object_id': 'prio$priority',
                  'object_type': 'customers'
                }
              ]
            }
          });
        }

        // Receiving the checkpoint sets the state to downloading
        await expectLater(
            status, emits(isSyncStatus(downloading: true, hasSynced: false)));

        // Emit partial sync complete for each priority but the last.
        for (var prio = 0; prio < 3; prio++) {
          addRow(prio);
          syncService.addLine({
            'partial_checkpoint_complete': {
              'last_op_id': operationId.toString(),
              'priority': prio,
            }
          });

          await expectLater(
            status,
            emits(isSyncStatus(downloading: true, hasSynced: false).having(
              (e) => e.statusForPriority(BucketPriority(0)).hasSynced,
              'status for $prio',
              isTrue,
            )),
          );

          await database.waitForFirstSync(priority: BucketPriority(prio));
          expect(await database.getAll('SELECT * FROM customers'),
              hasLength(prio + 1));
        }

        // Complete the sync
        addRow(3);
        syncService.addLine({
          'checkpoint_complete': {'last_op_id': operationId.toString()}
        });

        await expectLater(
            status, emits(isSyncStatus(downloading: false, hasSynced: true)));
        await database.waitForFirstSync();
        expect(await database.getAll('SELECT * FROM customers'), hasLength(4));
      });

      test('remembers last partial sync state', () async {
        final status = await waitForConnection();

        syncService.addLine({
          'checkpoint': Checkpoint(
            lastOpId: '0',
            writeCheckpoint: null,
            checksums: [
              BucketChecksum(bucket: 'bkt', priority: 1, checksum: 0)
            ],
          )
        });
        await expectLater(status, emits(isSyncStatus(downloading: true)));

        syncService.addLine({
          'partial_checkpoint_complete': {
            'last_op_id': '0',
            'priority': 1,
          }
        });
        await database.waitForFirstSync(priority: BucketPriority(1));
        expect(database.currentStatus.hasSynced, isFalse);

        final independentDb = factory.wrapRaw(raw);
        await independentDb.initialize();
        expect(independentDb.currentStatus.hasSynced, isFalse);
        // Completing a sync for prio 1 implies a completed sync for prio 0
        expect(
            independentDb.currentStatus
                .statusForPriority(BucketPriority(0))
                .hasSynced,
            isTrue);
        expect(
            independentDb.currentStatus
                .statusForPriority(BucketPriority(3))
                .hasSynced,
            isFalse);
      });
    });
  });
}

TypeMatcher<SyncStatus> isSyncStatus(
    {Object? downloading, Object? connected, Object? hasSynced}) {
  var matcher = isA<SyncStatus>();
  if (downloading != null) {
    matcher = matcher.having((e) => e.downloading, 'downloading', downloading);
  }
  if (connected != null) {
    matcher = matcher.having((e) => e.connected, 'connected', connected);
  }
  if (hasSynced != null) {
    matcher = matcher.having((e) => e.hasSynced, 'hasSynced', hasSynced);
  }

  return matcher;
}
