import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:logging/logging.dart';
import 'package:web/web.dart';

import '../connector.dart';
import '../log.dart';
import '../sync_status.dart';

/// Names used in [SyncWorkerMessage]
enum SyncWorkerMessageType {
  ping,

  /// Sent from client to the sync worker to request the synchronization
  /// starting.
  /// If parameters change, the sync worker reconnects.
  startSynchronization,

  /// The [SyncWorkerMessage.payload] for the request is a numeric id, the
  /// response can be anything (void).
  /// This disconnects immediately, even if other clients are still open.
  abortSynchronization,

  /// Sent from the sync worker to the client when it needs an endpoint to
  /// connect to to start the synchronization.
  ///
  /// [SyncWorkerMessage.payload] is a numeric request id, the response sends
  /// a [WebEndpoint].
  requestEndpoint,

  /// Invoke the `uploadCrud`, `fetchCredentials` and `getCredentialsCached`
  /// methods on the client.
  ///
  /// For requests, the [SyncWorkerMessage.payload] is a numeric request id.
  /// The response sends either a [SerializedCredentials] object or an empty
  /// object for uploads.
  uploadCrud,
  invalidCredentialsCallback,
  credentialsCallback,

  /// Notifies clients that the sync status has changed - the payload consists
  /// of [SerializedSyncStatus].
  notifySyncStatus,

  /// Notifies clients about a log event emitted by the worker (typically only
  /// used when workers were compiled in debug mode).
  /// The payload is a [JSString].
  logEvent,

  okResponse,
  errorResponse,
}

@anonymous
extension type SyncWorkerMessage._(JSObject _) implements JSObject {
  external factory SyncWorkerMessage(
      {required String type, required JSAny payload});

  external String get type;
  external JSAny get payload;
}

@anonymous
extension type StartSynchronization._(JSObject _) implements JSObject {
  external factory StartSynchronization(
      {required String databaseName,
      required int crudThrottleTimeMs,
      required int requestId,
      String? syncParamsEncoded});

  external String get databaseName;
  external int get requestId;
  external int get crudThrottleTimeMs;
  external String? get syncParamsEncoded;
}

@anonymous
extension type WebEndpoint._(JSObject _) implements JSObject {
  external factory WebEndpoint({
    required String databaseName,
    required MessagePort databasePort,
    required String? lockName,
  });

  external String get databaseName;
  external String? get lockName;
  external MessagePort get databasePort;
}

@anonymous
extension type OkResponse._(JSObject _) implements JSObject {
  external factory OkResponse({
    required int requestId,
    required JSAny? payload,
  });

  external int get requestId;
  external JSAny? get payload;
}

@anonymous
extension type ErrorResponse._(JSObject _) implements JSObject {
  external factory ErrorResponse({
    required int requestId,
    required JSString errorMessage,
  });

  external int get requestId;
  external JSString get errorMessage;
}

@anonymous
extension type SerializedCredentials._(JSObject _) implements JSObject {
  external factory SerializedCredentials({
    required JSString endpoint,
    required JSString token,
    required JSString? userId,
    required JSNumber? expiresAt,
  });

  factory SerializedCredentials.from(PowerSyncCredentials credentials) {
    return SerializedCredentials(
      endpoint: credentials.endpoint.toJS,
      token: credentials.token.toJS,
      userId: credentials.userId?.toJS,
      expiresAt: credentials.expiresAt?.microsecondsSinceEpoch.toJS,
    );
  }

  external JSString get endpoint;
  external JSString get token;
  external JSString? get userId;
  external JSNumber? get expiresAt;

  PowerSyncCredentials asCredentials() {
    return PowerSyncCredentials(
      endpoint: endpoint.toDart,
      token: token.toDart,
      userId: userId?.toDart,
      expiresAt: expiresAt.isUndefinedOrNull
          ? null
          : DateTime.fromMicrosecondsSinceEpoch(expiresAt!.toDartInt),
    );
  }
}

@anonymous
extension type SerializedSyncStatus._(JSObject _) implements JSObject {
  external factory SerializedSyncStatus({
    required bool connected,
    required bool connecting,
    required bool downloading,
    required bool uploading,
    required int? lastSyncedAt,
    required bool? hasSyned,
    required String? uploadError,
    required String? downloadError,
    required JSArray? statusInPriority,
  });

  factory SerializedSyncStatus.from(SyncStatus status) {
    return SerializedSyncStatus(
      connected: status.connected,
      connecting: status.connecting,
      downloading: status.downloading,
      uploading: status.uploading,
      lastSyncedAt: status.lastSyncedAt?.microsecondsSinceEpoch,
      hasSyned: status.hasSynced,
      uploadError: status.uploadError?.toString(),
      downloadError: status.downloadError?.toString(),
      statusInPriority: <JSArray?>[
        for (final entry in status.statusInPriority)
          [
            entry.priority.priorityNumber.toJS,
            entry.lastSyncedAt?.microsecondsSinceEpoch.toJS,
            entry.hasSynced?.toJS,
          ].toJS
      ].toJS,
    );
  }

  external bool get connected;
  external bool get connecting;
  external bool get downloading;
  external bool get uploading;
  external int? lastSyncedAt;
  external bool? hasSynced;
  external String? uploadError;
  external String? downloadError;
  external JSArray? statusInPriority;

  SyncStatus asSyncStatus() {
    return SyncStatus(
      connected: connected,
      connecting: connecting,
      downloading: downloading,
      uploading: uploading,
      lastSyncedAt: lastSyncedAt == null
          ? null
          : DateTime.fromMicrosecondsSinceEpoch(lastSyncedAt!),
      hasSynced: hasSynced,
      uploadError: uploadError,
      downloadError: downloadError,
      statusInPriority: statusInPriority?.toDart.map((e) {
            final [rawPriority, rawSynced, rawHasSynced, ...] =
                (e as JSArray).toDart;
            final syncedMillis = (rawSynced as JSNumber?)?.toDartInt;

            return (
              priority: BucketPriority((rawPriority as JSNumber).toDartInt),
              lastSyncedAt: syncedMillis != null
                  ? DateTime.fromMicrosecondsSinceEpoch(syncedMillis)
                  : null,
              hasSynced: (rawHasSynced as JSBoolean?)?.toDart,
            );
          }).toList() ??
          const [],
    );
  }
}

final class WorkerCommunicationChannel {
  final Map<int, Completer<JSAny?>> _pendingRequests = {};
  int _nextRequestId = 0;
  bool _hasError = false;
  StreamSubscription<MessageEvent>? _incomingMessages;
  StreamSubscription<Event>? _incomingErrors;

  final MessagePort port;
  final FutureOr<(JSAny?, JSArray?)> Function(SyncWorkerMessageType, JSAny)
      requestHandler;
  final StreamController<(SyncWorkerMessageType, JSAny)> _events =
      StreamController();
  final Logger _logger;

  Stream<(SyncWorkerMessageType, JSAny)> get events => _events.stream;

  WorkerCommunicationChannel({
    required this.port,
    required this.requestHandler,
    Stream<Event>? errors,
    Logger? logger,
  }) : _logger = logger ?? autoLogger {
    port.start();
    _incomingErrors = errors?.listen((event) {
      _hasError = true;

      _pendingRequests.forEach((_, value) {
        value.completeError('Worker error: $event');
      });
      _pendingRequests.clear();
    });

    _incomingMessages =
        EventStreamProviders.messageEvent.forTarget(port).listen((event) async {
      final message = event.data as SyncWorkerMessage;
      final type = SyncWorkerMessageType.values.byName(message.type);
      _logger.fine('[in] $type');

      int requestId;

      switch (type) {
        case SyncWorkerMessageType.ping:
          requestId = (message.payload as JSNumber).toDartInt;
          port.postMessage(SyncWorkerMessage(
            type: SyncWorkerMessageType.okResponse.name,
            payload: OkResponse(requestId: requestId, payload: null),
          ));
          return;
        case SyncWorkerMessageType.startSynchronization:
          requestId = (message.payload as StartSynchronization).requestId;
        case SyncWorkerMessageType.requestEndpoint:
        case SyncWorkerMessageType.abortSynchronization:
        case SyncWorkerMessageType.credentialsCallback:
        case SyncWorkerMessageType.invalidCredentialsCallback:
        case SyncWorkerMessageType.uploadCrud:
          requestId = (message.payload as JSNumber).toDartInt;
        case SyncWorkerMessageType.okResponse:
          final payload = message.payload as OkResponse;
          _pendingRequests.remove(payload.requestId)!.complete(payload.payload);
          return;
        case SyncWorkerMessageType.errorResponse:
          final payload = message.payload as ErrorResponse;
          _pendingRequests
              .remove(payload.requestId)!
              .completeError(payload.errorMessage.toDart);
          return;
        case SyncWorkerMessageType.notifySyncStatus:
          _events.add((type, message.payload));
          return;
        case SyncWorkerMessageType.logEvent:
          final msg = (message.payload as JSString).toDart;
          _logger.info('[Sync Worker]: $msg');
          return;
      }

      try {
        final (response, transfer) =
            await requestHandler(type, message.payload);
        final responseMessage = SyncWorkerMessage(
          type: SyncWorkerMessageType.okResponse.name,
          payload: OkResponse(requestId: requestId, payload: response),
        );

        if (transfer != null) {
          port.postMessage(responseMessage, transfer);
        } else {
          port.postMessage(responseMessage);
        }
      } catch (e) {
        port.postMessage(SyncWorkerMessage(
          type: SyncWorkerMessageType.errorResponse.name,
          payload: ErrorResponse(
              requestId: requestId, errorMessage: e.toString().toJS),
        ));
      }
    });
  }

  (int, Future<JSAny?>) _newRequest() {
    if (_hasError) {
      throw StateError('Channel has error, cannot send new requests');
    }

    final id = _nextRequestId++;
    final completer = _pendingRequests[id] = Completer<JSAny?>.sync();
    return (id, completer.future);
  }

  Future<JSAny?> _numericRequest(SyncWorkerMessageType type) {
    final (id, future) = _newRequest();
    port.postMessage(SyncWorkerMessage(type: type.name, payload: id.toJS));
    return future;
  }

  void notify(SyncWorkerMessageType notificationType, JSAny payload) {
    port.postMessage(
        SyncWorkerMessage(type: notificationType.name, payload: payload));
  }

  Future<void> ping() async {
    await _numericRequest(SyncWorkerMessageType.ping);
  }

  Future<void> startSynchronization(String databaseName, int crudThrottleTimeMs,
      Map<String, dynamic>? syncParams) async {
    final (id, completion) = _newRequest();
    port.postMessage(SyncWorkerMessage(
      type: SyncWorkerMessageType.startSynchronization.name,
      payload: StartSynchronization(
          databaseName: databaseName,
          crudThrottleTimeMs: crudThrottleTimeMs,
          requestId: id,
          syncParamsEncoded:
              syncParams == null ? null : jsonEncode(syncParams)),
    ));
    await completion;
  }

  Future<void> abortSynchronization() async {
    await _numericRequest(SyncWorkerMessageType.abortSynchronization);
  }

  // Called by the sync worker to request a [WebEndpoint] for the database
  // managed by the client.
  Future<WebEndpoint> requestDatabase() async {
    return await _numericRequest(SyncWorkerMessageType.requestEndpoint)
        as WebEndpoint;
  }

  Future<PowerSyncCredentials?> credentialsCallback() async {
    final serialized =
        await _numericRequest(SyncWorkerMessageType.credentialsCallback)
            as SerializedCredentials?;
    return serialized?.asCredentials();
  }

  Future<PowerSyncCredentials?> invalidCredentialsCallback() async {
    final serialized =
        await _numericRequest(SyncWorkerMessageType.invalidCredentialsCallback)
            as SerializedCredentials?;
    return serialized?.asCredentials();
  }

  Future<void> uploadCrud() async {
    await _numericRequest(SyncWorkerMessageType.uploadCrud);
  }

  Future<void> close() async {
    _incomingMessages?.cancel();
    _incomingErrors?.cancel();
    port.close();
  }
}
