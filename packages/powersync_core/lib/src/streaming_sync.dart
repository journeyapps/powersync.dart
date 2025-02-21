import 'dart:async';
import 'dart:convert' as convert;

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:powersync_core/src/abort_controller.dart';
import 'package:powersync_core/src/exceptions.dart';
import 'package:powersync_core/src/log_internal.dart';
import 'package:powersync_core/src/user_agent/user_agent.dart';
import 'package:sqlite_async/mutex.dart';

import 'bucket_storage.dart';
import 'connector.dart';
import 'crud.dart';
import 'stream_utils.dart';
import 'sync_status.dart';
import 'sync_types.dart';

/// Since we use null to indicate "no change" in status updates, we need
/// a different value to indicate "no error".
const _noError = Object();

abstract interface class StreamingSync {
  Stream<SyncStatus> get statusStream;

  Future<void> streamingSync();

  /// Close any active streams.
  Future<void> abort();
}

class StreamingSyncImplementation implements StreamingSync {
  BucketStorage adapter;

  final Future<PowerSyncCredentials?> Function() credentialsCallback;
  final Future<void> Function()? invalidCredentialsCallback;

  final Future<void> Function() uploadCrud;

  // An internal controller which is used to trigger CRUD uploads internally
  // e.g. when reconnecting.
  // This is only a broadcast controller since the `crudLoop` method is public
  // and could potentially be called multiple times externally.
  final StreamController<Null> _internalCrudTriggerController =
      StreamController<Null>.broadcast();

  final Stream<void> crudUpdateTriggerStream;

  final StreamController<SyncStatus> _statusStreamController =
      StreamController<SyncStatus>.broadcast();

  @override
  late final Stream<SyncStatus> statusStream;

  late final http.Client _client;

  final StreamController<Null> _localPingController =
      StreamController.broadcast();

  final Duration retryDelay;

  final Map<String, dynamic>? syncParameters;

  SyncStatus lastStatus = const SyncStatus();

  AbortController? _abort;

  bool _safeToClose = true;

  final Mutex syncMutex, crudMutex;

  final Map<String, String> _userAgentHeaders;

  String? clientId;

  StreamingSyncImplementation(
      {required this.adapter,
      required this.credentialsCallback,
      this.invalidCredentialsCallback,
      required this.uploadCrud,
      required this.crudUpdateTriggerStream,
      required this.retryDelay,
      this.syncParameters,
      required http.Client client,

      /// A unique identifier for this streaming sync implementation
      /// A good value is typically the DB file path which it will mutate when syncing.
      String? identifier = "unknown"})
      : syncMutex = Mutex(identifier: "sync-$identifier"),
        crudMutex = Mutex(identifier: "crud-$identifier"),
        _userAgentHeaders = userAgentHeaders() {
    _client = client;
    statusStream = _statusStreamController.stream;
  }

  @override
  Future<void> abort() async {
    // If streamingSync() hasn't been called yet, _abort will be null.
    var future = _abort?.abort();
    // This immediately triggers a new iteration in the merged stream, allowing us
    // to break immediately.
    // However, we still need to close the underlying stream explicitly, otherwise
    // the break will wait for the next line of data received on the stream.
    _localPingController.add(null);
    // According to the documentation, the behavior is undefined when calling
    // close() while requests are pending. However, this is no other
    // known way to cancel open streams, and this appears to end the stream with
    // a consistent ClientException if a request is open.
    // We avoid closing the client while opening a request, as that does cause
    // unpredicable uncaught errors.
    if (_safeToClose) {
      _client.close();
    }

    await _internalCrudTriggerController.close();

    // wait for completeAbort() to be called
    await future;

    // Now close the client in all cases not covered above
    _client.close();
    _statusStreamController.close();
  }

  bool get aborted {
    return _abort?.aborted ?? false;
  }

  bool get isConnected {
    return lastStatus.connected;
  }

  @override
  Future<void> streamingSync() async {
    try {
      _abort = AbortController();
      clientId = await adapter.getClientId();
      crudLoop();
      var invalidCredentials = false;
      while (!aborted) {
        _updateStatus(connecting: true);
        try {
          if (invalidCredentials && invalidCredentialsCallback != null) {
            // This may error. In that case it will be retried again on the next
            // iteration.
            await invalidCredentialsCallback!();
            invalidCredentials = false;
          }
          // Protect sync iterations with exclusivity (if a valid Mutex is provided)
          await syncMutex.lock(
              () => streamingSyncIteration(abortController: _abort),
              timeout: retryDelay);
        } catch (e, stacktrace) {
          if (aborted && e is http.ClientException) {
            // Explicit abort requested - ignore. Example error:
            // ClientException: Connection closed while receiving data, uri=http://localhost:8080/sync/stream
            return;
          }
          final message = _syncErrorMessage(e);
          isolateLogger.warning('Sync error: $message', e, stacktrace);
          invalidCredentials = true;

          _updateStatus(
              connected: false,
              connecting: true,
              downloading: false,
              downloadError: e);

          // On error, wait a little before retrying
          // When aborting, don't wait
          await _delayRetry();
        }
      }
    } finally {
      _abort!.completeAbort();
    }
  }

  Future<void> crudLoop() async {
    await uploadAllCrud();

    // Trigger a CRUD upload whenever the upstream trigger fires
    // as-well-as whenever the sync stream reconnects.
    // This has the potential (in rare cases) to affect the crudThrottleTime,
    // but it should not result in excessive uploads since the
    // sync reconnects are also throttled.
    // The stream here is closed on abort.
    await for (var _ in mergeStreams(
        [crudUpdateTriggerStream, _internalCrudTriggerController.stream])) {
      await uploadAllCrud();
    }
  }

  Future<void> uploadAllCrud() async {
    return crudMutex.lock(() async {
      // Keep track of the first item in the CRUD queue for the last `uploadCrud` iteration.
      CrudEntry? checkedCrudItem;

      while (true) {
        try {
          // It's possible that an abort or disconnect operation could
          // be followed by a `close` operation. The close would cause these
          // operations, which use the DB, to throw an exception. Breaking the loop
          // here prevents unnecessary potential (caught) exceptions.
          if (aborted) {
            break;
          }
          // This is the first item in the FIFO CRUD queue.
          CrudEntry? nextCrudItem = await adapter.nextCrudItem();
          if (nextCrudItem != null) {
            _updateStatus(uploading: true);
            if (nextCrudItem.clientId == checkedCrudItem?.clientId) {
              // This will force a higher log level than exceptions which are caught here.
              isolateLogger.warning(
                  """Potentially previously uploaded CRUD entries are still present in the upload queue. 
                Make sure to handle uploads and complete CRUD transactions or batches by calling and awaiting their [.complete()] method.
                The next upload iteration will be delayed.""");
              throw Exception(
                  'Delaying due to previously encountered CRUD item.');
            }

            checkedCrudItem = nextCrudItem;
            await uploadCrud();
            _updateStatus(uploadError: _noError);
          } else {
            // Uploading is completed
            await adapter.updateLocalTarget(() => getWriteCheckpoint());
            break;
          }
        } catch (e, stacktrace) {
          checkedCrudItem = null;
          isolateLogger.warning('Data upload error', e, stacktrace);
          _updateStatus(uploading: false, uploadError: e);
          await _delayRetry();
          if (!isConnected) {
            // Exit the upload loop if the sync stream is no longer connected
            break;
          }
          isolateLogger.warning(
              "Caught exception when uploading. Upload will retry after a delay",
              e,
              stacktrace);
        } finally {
          _updateStatus(uploading: false);
        }
      }
    }, timeout: retryDelay);
  }

  Future<String> getWriteCheckpoint() async {
    final credentials = await credentialsCallback();
    if (credentials == null) {
      throw CredentialsException("Not logged in");
    }
    final uri =
        credentials.endpointUri('write-checkpoint2.json?client_id=$clientId');

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization': "Token ${credentials.token}",
      ..._userAgentHeaders
    };

    final response = await _client.get(uri, headers: headers);
    if (response.statusCode == 401) {
      if (invalidCredentialsCallback != null) {
        await invalidCredentialsCallback!();
      }
    }
    if (response.statusCode != 200) {
      throw SyncResponseException.fromResponse(response);
    }

    final body = convert.jsonDecode(response.body);
    return body['data']['write_checkpoint'] as String;
  }

  void _updateStatusForPriority(SyncPriorityStatus completed) {
    // Note: statusInPriority is sorted by priorities (ascending)
    final existingPriorityState = lastStatus.statusInPriority;

    for (final (i, priority) in existingPriorityState.indexed) {
      switch (
          BucketPriority.comparator(priority.priority, completed.priority)) {
        case > 0:
          // Entries from here on have a higher priority than the one that was
          // just completed
          final copy = existingPriorityState.toList();
          copy.insert(i, completed);
          _updateStatus(statusInPriority: copy);
          return;
        case 0:
          final copy = existingPriorityState.toList();
          copy[i] = completed;
          _updateStatus(statusInPriority: copy);
          return;
        case < 0:
          continue;
      }
    }

    _updateStatus(statusInPriority: [...existingPriorityState, completed]);
  }

  /// Update sync status based on any non-null parameters.
  /// To clear errors, use [_noError] instead of null.
  void _updateStatus({
    DateTime? lastSyncedAt,
    bool? hasSynced,
    bool? connected,
    bool? connecting,
    bool? downloading,
    bool? uploading,
    Object? uploadError,
    Object? downloadError,
    List<SyncPriorityStatus>? statusInPriority,
  }) {
    final c = connected ?? lastStatus.connected;
    var newStatus = SyncStatus(
      connected: c,
      connecting: !c && (connecting ?? lastStatus.connecting),
      lastSyncedAt: lastSyncedAt ?? lastStatus.lastSyncedAt,
      hasSynced: hasSynced ?? lastStatus.hasSynced,
      downloading: downloading ?? lastStatus.downloading,
      uploading: uploading ?? lastStatus.uploading,
      uploadError: uploadError == _noError
          ? null
          : (uploadError ?? lastStatus.uploadError),
      downloadError: downloadError == _noError
          ? null
          : (downloadError ?? lastStatus.downloadError),
      statusInPriority: statusInPriority ?? lastStatus.statusInPriority,
    );

    if (!_statusStreamController.isClosed) {
      lastStatus = newStatus;
      _statusStreamController.add(newStatus);
    }
  }

  Future<(List<BucketRequest>, Map<String, BucketDescription?>)>
      _collectLocalBucketState() async {
    final bucketEntries = await adapter.getBucketStates();

    final initialRequests = [
      for (final entry in bucketEntries) BucketRequest(entry.bucket, entry.opId)
    ];
    final localDescriptions = {
      for (final entry in bucketEntries) entry.bucket: null
    };

    return (initialRequests, localDescriptions);
  }

  Future<bool> streamingSyncIteration(
      {AbortController? abortController}) async {
    adapter.startSession();

    var (bucketRequests, bucketMap) = await _collectLocalBucketState();

    Checkpoint? targetCheckpoint;
    Checkpoint? validatedCheckpoint;
    Checkpoint? appliedCheckpoint;

    var requestStream = streamingSyncRequest(
        StreamingSyncRequest(bucketRequests, syncParameters, clientId!));

    var merged = addBroadcast(requestStream, _localPingController.stream);

    Future<void>? credentialsInvalidation;
    bool haveInvalidated = false;

    // Trigger a CRUD upload on reconnect
    _internalCrudTriggerController.add(null);

    await for (var line in merged) {
      if (aborted) {
        break;
      }

      _updateStatus(connected: true, connecting: false);
      switch (line) {
        case Checkpoint():
          targetCheckpoint = line;
          final Set<String> bucketsToDelete = {...bucketMap.keys};
          final Map<String, BucketDescription> newBuckets = {};
          for (final checksum in line.checksums) {
            newBuckets[checksum.bucket] = (
              name: checksum.bucket,
              priority: checksum.priority,
            );
            bucketsToDelete.remove(checksum.bucket);
          }
          bucketMap = newBuckets;
          await adapter.removeBuckets([...bucketsToDelete]);
          _updateStatus(downloading: true);
        case StreamingSyncCheckpointComplete():
          final result = await adapter.syncLocalDatabase(targetCheckpoint!);
          if (!result.checkpointValid) {
            // This means checksums failed. Start again with a new checkpoint.
            // TODO: better back-off
            // await new Promise((resolve) => setTimeout(resolve, 50));
            return false;
          } else if (!result.ready) {
            // Checksums valid, but need more data for a consistent checkpoint.
            // Continue waiting.
          } else {
            appliedCheckpoint = targetCheckpoint;

            final now = DateTime.now();
            _updateStatus(
              downloading: false,
              downloadError: _noError,
              lastSyncedAt: now,
              statusInPriority: [
                if (appliedCheckpoint.checksums.isNotEmpty)
                  (
                    hasSynced: true,
                    lastSyncedAt: now,
                    priority: maxBy(
                      appliedCheckpoint.checksums
                          .map((cs) => BucketPriority(cs.priority)),
                      (priority) => priority,
                      compare: BucketPriority.comparator,
                    )!,
                  )
              ],
            );
          }

          validatedCheckpoint = targetCheckpoint;
        case StreamingSyncCheckpointPartiallyComplete(:final bucketPriority):
          final result = await adapter.syncLocalDatabase(targetCheckpoint!,
              forPriority: bucketPriority);
          if (!result.checkpointValid) {
            // This means checksums failed. Start again with a new checkpoint.
            // TODO: better back-off
            // await new Promise((resolve) => setTimeout(resolve, 50));
            return false;
          } else if (!result.ready) {
            // Checksums valid, but need more data for a consistent checkpoint.
            // Continue waiting.
          } else {
            _updateStatusForPriority((
              priority: BucketPriority(bucketPriority),
              lastSyncedAt: DateTime.now(),
              hasSynced: true,
            ));
          }
        case StreamingSyncCheckpointDiff():
          // TODO: It may be faster to just keep track of the diff, instead of
          // the entire checkpoint
          if (targetCheckpoint == null) {
            throw PowerSyncProtocolException(
                'Checkpoint diff without previous checkpoint');
          }
          _updateStatus(downloading: true);
          final diff = line;
          final Map<String, BucketChecksum> newBuckets = {};
          for (var checksum in targetCheckpoint.checksums) {
            newBuckets[checksum.bucket] = checksum;
          }
          for (var checksum in diff.updatedBuckets) {
            newBuckets[checksum.bucket] = checksum;
          }
          for (var bucket in diff.removedBuckets) {
            newBuckets.remove(bucket);
          }

          final newCheckpoint = Checkpoint(
              lastOpId: diff.lastOpId,
              checksums: [...newBuckets.values],
              writeCheckpoint: diff.writeCheckpoint);
          targetCheckpoint = newCheckpoint;

          bucketMap = newBuckets.map((name, checksum) =>
              MapEntry(name, (name: name, priority: checksum.priority)));
          await adapter.removeBuckets(diff.removedBuckets);
          adapter.setTargetCheckpoint(targetCheckpoint);
        case SyncDataBatch():
          _updateStatus(downloading: true);
          await adapter.saveSyncData(line);
        case StreamingSyncKeepalive(:final tokenExpiresIn):
          if (tokenExpiresIn == 0) {
            // Token expired already - stop the connection immediately
            invalidCredentialsCallback?.call().ignore();
            break;
          } else if (tokenExpiresIn <= 30) {
            // Token expires soon - refresh it in the background
            if (credentialsInvalidation == null &&
                invalidCredentialsCallback != null) {
              credentialsInvalidation = invalidCredentialsCallback!().then((_) {
                // Token has been refreshed - we should restart the connection.
                haveInvalidated = true;
                // trigger next loop iteration ASAP, don't wait for another
                // message from the server.
                _localPingController.add(null);
              }, onError: (_) {
                // Token refresh failed - retry on next keepalive.
                credentialsInvalidation = null;
              });
            }
          }
        case UnknownSyncLine(:final rawData):
          isolateLogger.fine('Unknown sync line: $rawData');
        case null: // Local ping
          if (targetCheckpoint == appliedCheckpoint) {
            _updateStatus(
                downloading: false,
                downloadError: _noError,
                lastSyncedAt: DateTime.now());
          } else if (validatedCheckpoint == targetCheckpoint) {
            final result = await adapter.syncLocalDatabase(targetCheckpoint!);
            if (!result.checkpointValid) {
              // This means checksums failed. Start again with a new checkpoint.
              // TODO: better back-off
              // await new Promise((resolve) => setTimeout(resolve, 50));
              return false;
            } else if (!result.ready) {
              // Checksums valid, but need more data for a consistent checkpoint.
              // Continue waiting.
            } else {
              appliedCheckpoint = targetCheckpoint;

              _updateStatus(
                  downloading: false,
                  downloadError: _noError,
                  lastSyncedAt: DateTime.now());
            }
          }
      }

      if (haveInvalidated) {
        // Stop this connection, so that a new one will be started
        break;
      }
    }
    return true;
  }

  Stream<StreamingSyncLine> streamingSyncRequest(
      StreamingSyncRequest data) async* {
    final credentials = await credentialsCallback();
    if (credentials == null) {
      throw CredentialsException('Not logged in');
    }
    final uri = credentials.endpointUri('sync/stream');

    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = "Token ${credentials.token}";
    request.headers.addAll(_userAgentHeaders);

    request.body = convert.jsonEncode(data);

    http.StreamedResponse res;
    try {
      // Do not close the client during the request phase - this causes uncaught errors.
      _safeToClose = false;
      res = await _client.send(request);
    } finally {
      _safeToClose = true;
    }
    if (aborted) {
      return;
    }

    if (res.statusCode == 401) {
      if (invalidCredentialsCallback != null) {
        await invalidCredentialsCallback!();
      }
    }
    if (res.statusCode != 200) {
      throw await SyncResponseException.fromStreamedResponse(res);
    }

    // Note: The response stream is automatically closed when this loop errors
    yield* ndjson(res.stream)
        .cast<Map<String, dynamic>>()
        .transform(StreamingSyncLine.reader)
        .takeWhile((_) => !aborted);
  }

  /// Delays the standard `retryDelay` Duration, but exits early if
  /// an abort has been requested.
  Future<void> _delayRetry() async {
    await Future.any([Future<void>.delayed(retryDelay), _abort!.onAbort]);
  }
}

/// Attempt to give a basic summary of the error for cases where the full error
/// is not logged.
String _syncErrorMessage(Object? error) {
  if (error == null) {
    return 'Unknown';
  } else if (error is http.ClientException) {
    return 'Sync service error';
  } else if (error is SyncResponseException) {
    if (error.statusCode == 401) {
      return 'Authorization error';
    } else {
      return 'Sync service error';
    }
  } else if (error is ArgumentError || error is FormatException) {
    return 'Configuration error';
  } else if (error is CredentialsException) {
    return 'Credentials error';
  } else if (error is PowerSyncProtocolException) {
    return 'Protocol error';
  } else {
    return '${error.runtimeType}';
  }
}
