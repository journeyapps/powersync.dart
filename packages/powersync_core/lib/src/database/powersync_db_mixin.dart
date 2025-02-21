import 'dart:async';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:powersync_core/sqlite3_common.dart';
import 'package:powersync_core/sqlite_async.dart';
import 'package:powersync_core/src/abort_controller.dart';
import 'package:powersync_core/src/connector.dart';
import 'package:powersync_core/src/crud.dart';
import 'package:powersync_core/src/powersync_update_notification.dart';
import 'package:powersync_core/src/schema.dart';
import 'package:powersync_core/src/schema_logic.dart';
import 'package:powersync_core/src/sync_status.dart';

mixin PowerSyncDatabaseMixin implements SqliteConnection {
  /// Schema used for the local database.
  Schema get schema;

  /// The underlying database.
  ///
  /// For the most part, behavior is the same whether querying on the underlying
  /// database, or on [PowerSyncDatabase]. The main difference is in update notifications:
  /// the underlying database reports updates to the underlying tables, while
  /// [PowerSyncDatabase] reports updates to the higher-level views.
  SqliteDatabase get database;

  /// The Logger used by this [PowerSyncDatabase].
  ///
  /// The default is [autoLogger], which logs to the console in debug builds.
  /// Use [debugLogger] to always log to the console.
  /// Use [attachedLogger] to propagate logs to [Logger.root] for custom logging.
  Logger get logger;

  Map<String, dynamic>? clientParams;

  /// Current connection status.
  SyncStatus currentStatus =
      const SyncStatus(connected: false, lastSyncedAt: null);

  /// Use this stream to subscribe to connection status updates.
  late final Stream<SyncStatus> statusStream;

  @protected
  StreamController<SyncStatus> statusStreamController =
      StreamController<SyncStatus>.broadcast();

  /// Use to prevent multiple connections from being opened concurrently
  final Mutex _connectMutex = Mutex();

  @override

  /// Broadcast stream that is notified of any table updates.
  ///
  /// Unlike in [SqliteDatabase.updates], the tables reported here are the
  /// higher-level views as defined in the [Schema], and exclude the low-level
  /// PowerSync tables.
  late final Stream<UpdateNotification> updates;

  /// Delay between retrying failed requests.
  /// Defaults to 5 seconds.
  /// Only has an effect if changed before calling [connect].
  Duration retryDelay = const Duration(seconds: 5);

  @protected
  Future<void> get isInitialized;

  /// null when disconnected, present when connecting or connected
  @protected
  AbortController? disconnecter;

  @protected
  Future<void> baseInit() async {
    statusStream = statusStreamController.stream;
    updates = powerSyncUpdateNotifications(database.updates);

    await database.initialize();
    await _checkVersion();
    await database.execute('SELECT powersync_init()');
    await updateSchema(schema);
    await _updateHasSynced();
  }

  /// Check that a supported version of the powersync extension is loaded.
  Future<void> _checkVersion() async {
    // Get version
    String version;
    try {
      final row =
          await database.get('SELECT powersync_rs_version() as version');
      version = row['version'] as String;
    } catch (e) {
      throw SqliteException(
          1, 'The powersync extension is not loaded correctly. Details: $e');
    }

    // Parse version
    List<int> versionInts;
    try {
      versionInts =
          version.split(RegExp(r'[./]')).take(3).map(int.parse).toList();
    } catch (e) {
      throw SqliteException(1,
          'Unsupported powersync extension version. Need >=0.2.0 <1.0.0, got: $version. Details: $e');
    }

    // Validate >=0.2.0 <1.0.0
    if (versionInts[0] != 0 ||
        (versionInts[1] < 2) ||
        (versionInts[1] == 2 && versionInts[2] < 0)) {
      throw SqliteException(1,
          'Unsupported powersync extension version. Need >=0.2.0 <1.0.0, got: $version');
    }
  }

  /// Wait for initialization to complete.
  ///
  /// While initializing is automatic, this helps to catch and report initialization errors.
  Future<void> initialize() {
    return isInitialized;
  }

  Future<void> _updateHasSynced() async {
    // Query the database to see if any data has been synced.
    final result = await database.getAll(
      'SELECT priority, last_synced_at FROM ps_sync_state ORDER BY priority;',
    );
    const prioritySentinel = 2147483647;
    var hasSynced = false;
    DateTime? lastCompleteSync;
    final priorityStatus = <SyncPriorityStatus>[];

    DateTime parseDateTime(String sql) {
      return DateTime.parse('${sql}Z').toLocal();
    }

    for (final row in result) {
      final priority = row.columnAt(0) as int;
      final lastSyncedAt = parseDateTime(row.columnAt(1) as String);

      if (priority == prioritySentinel) {
        hasSynced = true;
        lastCompleteSync = lastSyncedAt;
      } else {
        priorityStatus.add((
          hasSynced: true,
          lastSyncedAt: lastSyncedAt,
          priority: BucketPriority(priority)
        ));
      }
    }

    if (hasSynced != currentStatus.hasSynced) {
      final status = SyncStatus(
        hasSynced: hasSynced,
        lastSyncedAt: lastCompleteSync,
        statusInPriority: priorityStatus,
      );
      setStatus(status);
    }
  }

  /// Returns a [Future] which will resolve once at least one full sync cycle
  /// has completed (meaninng that the first consistent checkpoint has been
  /// reached across all buckets).
  ///
  /// When [priority] is null (the default), this method waits for the first
  /// full sync checkpoint to complete. When set to a [BucketPriority] however,
  /// it completes once all buckets within that priority (as well as those in
  /// higher priorities) have been synchronized at least once.
  Future<void> waitForFirstSync({BucketPriority? priority}) async {
    bool matches(SyncStatus status) {
      if (priority == null) {
        return status.hasSynced == true;
      } else {
        return status.statusForPriority(priority).hasSynced == true;
      }
    }

    if (matches(currentStatus)) {
      return;
    }
    await for (final result in statusStream) {
      if (matches(result)) {
        break;
      }
    }
  }

  @protected
  @visibleForTesting
  void setStatus(SyncStatus status) {
    if (status != currentStatus) {
      // Note that currently the streaming sync implementation will never set hasSynced.
      // lastSyncedAt implies that syncing has completed at some point (hasSynced = true).
      // The previous values of hasSynced should be preserved here.
      final newStatus = status.copyWith(
          hasSynced: status.lastSyncedAt != null
              ? true
              : status.hasSynced ?? currentStatus.hasSynced,
          lastSyncedAt: status.lastSyncedAt ?? currentStatus.lastSyncedAt);
      // If the absence of hasSync was the only difference, the new states would be equal
      // and don't require an event. So, check again.
      if (newStatus != currentStatus) {
        currentStatus = newStatus;
        statusStreamController.add(currentStatus);
      }
    }
  }

  @override
  bool get closed {
    return database.closed;
  }

  /// Close the database, releasing resources.
  ///
  /// Also [disconnect]s any active connection.
  ///
  /// Once close is called, this connection cannot be used again - a new one
  /// must be constructed.
  @override
  Future<void> close() async {
    // Don't close in the middle of the initialization process.
    await isInitialized;
    // Disconnect any active sync connection.
    await disconnect();
    // Now we can close the database
    await database.close();

    // If there are paused subscriptionso n the status stream, don't delay
    // closing the database because of that.
    unawaited(statusStreamController.close());
  }

  /// Connect to the PowerSync service, and keep the databases in sync.
  ///
  /// The connection is automatically re-opened if it fails for any reason.
  ///
  /// Status changes are reported on [statusStream].
  Future<void> connect(
      {required PowerSyncBackendConnector connector,

      /// Throttle time between CRUD operations
      /// Defaults to 10 milliseconds.
      Duration crudThrottleTime = const Duration(milliseconds: 10),
      Map<String, dynamic>? params}) async {
    clientParams = params;
    Zone current = Zone.current;

    Future<void> reconnect() {
      return _connectMutex.lock(() => baseConnect(
          connector: connector,
          crudThrottleTime: crudThrottleTime,
          // The reconnect function needs to run in the original zone,
          // to avoid recursive lock errors.
          reconnect: current.bindCallback(reconnect),
          params: params));
    }

    await reconnect();
  }

  /// Abstract connection method to be implemented by platform specific
  /// classes. This is wrapped inside an exclusive mutex in the [connect]
  /// method.
  @protected
  @internal
  Future<void> baseConnect(
      {required PowerSyncBackendConnector connector,

      /// Throttle time between CRUD operations
      /// Defaults to 10 milliseconds.
      required Duration crudThrottleTime,
      required Future<void> Function() reconnect,
      Map<String, dynamic>? params});

  /// Close the sync connection.
  ///
  /// Use [connect] to connect again.
  Future<void> disconnect() async {
    if (disconnecter != null) {
      /// Checking `disconnecter.aborted` prevents race conditions
      /// where multiple calls to `disconnect` can attempt to abort
      /// the controller more than once before it has finished aborting.
      if (disconnecter!.aborted == false) {
        await disconnecter!.abort();
        disconnecter = null;
      } else {
        /// Wait for the abort to complete. Continue updating the sync status after completed
        await disconnecter!.onAbort;
      }
    }
    setStatus(
        SyncStatus(connected: false, lastSyncedAt: currentStatus.lastSyncedAt));
  }

  /// Disconnect and clear the database.
  ///
  /// Use this when logging out.
  ///
  /// The database can still be queried after this is called, but the tables
  /// would be empty.
  ///
  /// To preserve data in local-only tables, set [clearLocal] to false.
  Future<void> disconnectAndClear({bool clearLocal = true}) async {
    await disconnect();

    await writeTransaction((tx) async {
      await tx.execute('select powersync_clear(?)', [clearLocal ? 1 : 0]);
    });
    // The data has been deleted - reset these
    currentStatus = SyncStatus(lastSyncedAt: null, hasSynced: false);
    statusStreamController.add(currentStatus);
  }

  @Deprecated('Use [disconnectAndClear] instead.')
  Future<void> disconnectedAndClear() async {
    await disconnectAndClear();
  }

  /// Whether a connection to the PowerSync service is currently open.
  bool get connected {
    return currentStatus.connected;
  }

  /// Replace the schema with a new version.
  /// This is for advanced use cases - typically the schema should just be
  /// specified once in the constructor.
  ///
  /// Cannot be used while connected - this should only be called before [connect].
  Future<void> updateSchema(Schema schema);

  /// A connection factory that can be passed to different isolates.
  ///
  /// Use this to access the database in background isolates.
  IsolateConnectionFactory<CommonDatabase> isolateConnectionFactory() {
    return database.isolateConnectionFactory();
  }

  /// Get an unique id for this client.
  /// This id is only reset when the database is deleted.
  Future<String> getClientId() async {
    final row = await get('SELECT powersync_client_id() as client_id');
    return row['client_id'] as String;
  }

  /// Get upload queue size estimate and count.
  Future<UploadQueueStats> getUploadQueueStats(
      {bool includeSize = false}) async {
    if (includeSize) {
      final row = await getOptional(
          'SELECT SUM(cast(data as blob) + 20) as size, count(*) as count FROM ps_crud');
      return UploadQueueStats(
          count: row?['count'] as int? ?? 0, size: row?['size'] as int? ?? 0);
    } else {
      final row = await getOptional('SELECT count(*) as count FROM ps_crud');
      return UploadQueueStats(count: row?['count'] as int? ?? 0);
    }
  }

  /// Get a batch of crud data to upload.
  ///
  /// Returns null if there is no data to upload.
  ///
  /// Use this from the [PowerSyncBackendConnector.uploadData]` callback.
  ///
  /// Once the data have been successfully uploaded, call [CrudBatch.complete] before
  /// requesting the next batch.
  ///
  /// Use [limit] to specify the maximum number of updates to return in a single
  /// batch.
  ///
  /// This method does include transaction ids in the result, but does not group
  /// data by transaction. One batch may contain data from multiple transactions,
  /// and a single transaction may be split over multiple batches.
  Future<CrudBatch?> getCrudBatch({int limit = 100}) async {
    final rows = await getAll(
        'SELECT id, tx_id, data FROM ps_crud ORDER BY id ASC LIMIT ?',
        [limit + 1]);
    List<CrudEntry> all = [for (var row in rows) CrudEntry.fromRow(row)];

    var haveMore = false;
    if (all.length > limit) {
      all.removeLast();
      haveMore = true;
    }
    if (all.isEmpty) {
      return null;
    }
    final last = all[all.length - 1];
    return CrudBatch(
        crud: all,
        haveMore: haveMore,
        complete: ({String? writeCheckpoint}) async {
          await writeTransaction((db) async {
            await db
                .execute('DELETE FROM ps_crud WHERE id <= ?', [last.clientId]);
            if (writeCheckpoint != null &&
                await db.getOptional('SELECT 1 FROM ps_crud LIMIT 1') == null) {
              await db.execute(
                  'UPDATE ps_buckets SET target_op = CAST(? as INTEGER) WHERE name=\'\$local\'',
                  [writeCheckpoint]);
            } else {
              await db.execute(
                  'UPDATE ps_buckets SET target_op = $maxOpId WHERE name=\'\$local\'');
            }
          });
        });
  }

  /// Get the next recorded transaction to upload.
  ///
  /// Returns null if there is no data to upload.
  ///
  /// Use this from the [PowerSyncBackendConnector.uploadData]` callback.
  ///
  /// Once the data have been successfully uploaded, call [CrudTransaction.complete] before
  /// requesting the next transaction.
  ///
  /// Unlike [getCrudBatch], this only returns data from a single transaction at a time.
  /// All data for the transaction is loaded into memory.
  Future<CrudTransaction?> getNextCrudTransaction() async {
    return await readTransaction((tx) async {
      final first = await tx.getOptional(
          'SELECT id, tx_id, data FROM ps_crud ORDER BY id ASC LIMIT 1');
      if (first == null) {
        return null;
      }
      final txId = first['tx_id'] as int?;
      List<CrudEntry> all;
      if (txId == null) {
        all = [CrudEntry.fromRow(first)];
      } else {
        final rows = await tx.getAll(
            'SELECT id, tx_id, data FROM ps_crud WHERE tx_id = ? ORDER BY id ASC',
            [txId]);
        all = [for (var row in rows) CrudEntry.fromRow(row)];
      }

      final last = all[all.length - 1];

      return CrudTransaction(
          transactionId: txId,
          crud: all,
          complete: ({String? writeCheckpoint}) async {
            await writeTransaction((db) async {
              await db.execute(
                  'DELETE FROM ps_crud WHERE id <= ?', [last.clientId]);
              if (writeCheckpoint != null &&
                  await db.getOptional('SELECT 1 FROM ps_crud LIMIT 1') ==
                      null) {
                await db.execute(
                    'UPDATE ps_buckets SET target_op = CAST(? as INTEGER) WHERE name=\'\$local\'',
                    [writeCheckpoint]);
              } else {
                await db.execute(
                    'UPDATE ps_buckets SET target_op = $maxOpId WHERE name=\'\$local\'');
              }
            });
          });
    });
  }

  /// Takes a read lock, without starting a transaction.
  ///
  /// In most cases, [readTransaction] should be used instead.
  @override
  Future<T> readLock<T>(Future<T> Function(SqliteReadContext tx) callback,
      {String? debugContext, Duration? lockTimeout});

  /// Takes a global lock, without starting a transaction.
  ///
  /// In most cases, [writeTransaction] should be used instead.
  @override
  Future<T> writeLock<T>(Future<T> Function(SqliteWriteContext tx) callback,
      {String? debugContext, Duration? lockTimeout});

  @override
  Stream<ResultSet> watch(String sql,
      {List<Object?> parameters = const [],
      Duration throttle = const Duration(milliseconds: 30),
      Iterable<String>? triggerOnTables}) {
    if (triggerOnTables == null || triggerOnTables.isEmpty) {
      return database.watch(sql, parameters: parameters, throttle: throttle);
    }
    List<String> powersyncTables = [];
    for (String tableName in triggerOnTables) {
      powersyncTables.add(tableName);
      powersyncTables.add(_prefixTableNames(tableName, 'ps_data__'));
      powersyncTables.add(_prefixTableNames(tableName, 'ps_data_local__'));
    }
    return database.watch(sql,
        parameters: parameters,
        throttle: throttle,
        triggerOnTables: powersyncTables);
  }

  @protected
  String _prefixTableNames(String tableName, String prefix) {
    String prefixedString = tableName.replaceRange(0, 0, prefix);
    return prefixedString;
  }

  @override
  Future<bool> getAutoCommit() {
    return database.getAutoCommit();
  }

  @override
  Future<void> refreshSchema() async {
    await database.refreshSchema();
  }
}

Stream<UpdateNotification> powerSyncUpdateNotifications(
    Stream<UpdateNotification> inner) {
  return inner
      .map((update) =>
          PowerSyncUpdateNotification.fromUpdateNotification(update))
      .where((update) => update.isNotEmpty)
      .cast<UpdateNotification>();
}
