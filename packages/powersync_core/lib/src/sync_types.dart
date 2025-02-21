import 'dart:async';
import 'dart:convert';

import 'bucket_storage.dart';

/// Messages sent from the sync service.
sealed class StreamingSyncLine {
  const StreamingSyncLine();

  /// Parses a [StreamingSyncLine] from JSON.
  static StreamingSyncLine fromJson(Map<String, dynamic> line) {
    if (line.containsKey('checkpoint')) {
      return Checkpoint.fromJson(line['checkpoint'] as Map<String, Object?>);
    } else if (line.containsKey('checkpoint_diff')) {
      return StreamingSyncCheckpointDiff.fromJson(
          line['checkpoint_diff'] as Map<String, Object?>);
    } else if (line.containsKey('checkpoint_complete')) {
      return StreamingSyncCheckpointComplete.fromJson(
          line['checkpoint_complete'] as Map<String, Object?>);
    } else if (line.containsKey('partial_checkpoint_complete')) {
      return StreamingSyncCheckpointPartiallyComplete.fromJson(
          line['partial_checkpoint_complete'] as Map<String, Object?>);
    } else if (line.containsKey('data')) {
      return SyncDataBatch([
        SyncBucketData.fromJson(line['data'] as Map<String, Object?>),
      ]);
    } else if (line.containsKey('token_expires_in')) {
      return StreamingSyncKeepalive.fromJson(line);
    } else {
      return UnknownSyncLine(line);
    }
  }

  /// A [StreamTransformer] that returns a stream emitting raw JSON objects into
  /// a stream emitting [StreamingSyncLine].
  static StreamTransformer<Map<String, dynamic>, StreamingSyncLine> reader =
      StreamTransformer.fromBind((source) {
    return Stream.eventTransformed(source, _StreamingSyncLineParser.new);
  });
}

final class _StreamingSyncLineParser
    implements EventSink<Map<String, dynamic>> {
  final EventSink<StreamingSyncLine> _out;

  /// When we receive multiple `data` lines in quick succession, group them into
  /// a single batch. This will make the streaming sync service insert them with
  /// a single transaction, which is more efficient than inserting them
  /// individually.
  (SyncDataBatch, Timer)? _pendingBatch;

  _StreamingSyncLineParser(this._out);

  void _flushBatch() {
    if (_pendingBatch case (final pending, final timer)?) {
      timer.cancel();
      _pendingBatch = null;
      _out.add(pending);
    }
  }

  @override
  void add(Map<String, dynamic> event) {
    final parsed = StreamingSyncLine.fromJson(event);

    // Buffer small batches and group them to reduce amounts of transactions
    // used to store them.
    if (parsed is SyncDataBatch && parsed.totalOperations <= 100) {
      if (_pendingBatch case (final batch, _)?) {
        // Add this line to the pending batch of data items
        batch.buckets.addAll(parsed.buckets);

        if (batch.totalOperations >= 1000) {
          // This is unlikely to happen since we're only buffering for a single
          // event loop iteration, but make sure we're not keeping huge amonts
          // of data in memory.
          _flushBatch();
        }
      } else {
        // Insert of adding this batch directly, keep it buffered here for a
        // while so that we can add new entries to it.
        final timer = Timer(Duration.zero, () {
          _out.add(_pendingBatch!.$1);
          _pendingBatch = null;
        });
        _pendingBatch = (parsed, timer);
      }
    } else {
      _flushBatch();
      _out.add(parsed);
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _flushBatch();
    _out.addError(error, stackTrace);
  }

  @override
  void close() {
    _flushBatch();
    _out.close();
  }
}

/// A message from the sync service that this client doesn't support.
final class UnknownSyncLine implements StreamingSyncLine {
  final Map<String, dynamic> rawData;

  const UnknownSyncLine(this.rawData);
}

/// Indicates that a checkpoint is available, along with checksums for each
/// bucket in the checkpoint.
///
/// Note: Called `StreamingSyncCheckpoint` in sync service protocol.
final class Checkpoint extends StreamingSyncLine {
  final String lastOpId;
  final String? writeCheckpoint;
  final List<BucketChecksum> checksums;

  const Checkpoint(
      {required this.lastOpId, required this.checksums, this.writeCheckpoint});

  Checkpoint.fromJson(Map<String, dynamic> json)
      : lastOpId = json['last_op_id'] as String,
        writeCheckpoint = json['write_checkpoint'] as String?,
        checksums = (json['buckets'] as List)
            .map((b) => BucketChecksum.fromJson(b as Map<String, dynamic>))
            .toList();

  Map<String, dynamic> toJson({int? priority}) {
    return {
      'last_op_id': lastOpId,
      'write_checkpoint': writeCheckpoint,
      'buckets': checksums
          .where((c) => priority == null || c.priority <= priority)
          .map((c) => {
                'bucket': c.bucket,
                'checksum': c.checksum,
                'priority': c.priority,
              })
          .toList(growable: false)
    };
  }
}

typedef BucketDescription = ({String name, int priority});

class BucketChecksum {
  final String bucket;
  final int priority;
  final int checksum;

  /// Count is informational only
  final int? count;
  final String? lastOpId;

  const BucketChecksum(
      {required this.bucket,
      required this.priority,
      required this.checksum,
      this.count,
      this.lastOpId});

  BucketChecksum.fromJson(Map<String, dynamic> json)
      : bucket = json['bucket'] as String,
        priority = json['priority'] as int,
        checksum = json['checksum'] as int,
        count = json['count'] as int?,
        lastOpId = json['last_op_id'] as String?;
}

/// A variant of [Checkpoint] that may be sent when the server has already sent
/// a [Checkpoint] message before.
///
/// It has the same conceptual meaning as a [Checkpoint] message, but only
/// contains details about changed buckets as an optimization.
final class StreamingSyncCheckpointDiff extends StreamingSyncLine {
  String lastOpId;
  List<BucketChecksum> updatedBuckets;
  List<String> removedBuckets;
  String? writeCheckpoint;

  StreamingSyncCheckpointDiff(
      this.lastOpId, this.updatedBuckets, this.removedBuckets);

  StreamingSyncCheckpointDiff.fromJson(Map<String, dynamic> json)
      : lastOpId = json['last_op_id'] as String,
        writeCheckpoint = json['write_checkpoint'] as String?,
        updatedBuckets = (json['updated_buckets'] as List)
            .map((e) => BucketChecksum.fromJson(e as Map<String, Object?>))
            .toList(),
        removedBuckets = (json['removed_buckets'] as List).cast();
}

/// Sent after the last [SyncBucketData] message for a checkpoint.
///
/// Since this indicates that we may have a consistent view of the data, the
/// client may make previous [SyncBucketData] rows visible to the application
/// at this point.
final class StreamingSyncCheckpointComplete extends StreamingSyncLine {
  String lastOpId;

  StreamingSyncCheckpointComplete(this.lastOpId);

  StreamingSyncCheckpointComplete.fromJson(Map<String, dynamic> json)
      : lastOpId = json['last_op_id'] as String;
}

/// Sent after all the [SyncBucketData] messages for a given priority within a
/// checkpoint have been sent.
final class StreamingSyncCheckpointPartiallyComplete extends StreamingSyncLine {
  String lastOpId;
  int bucketPriority;

  StreamingSyncCheckpointPartiallyComplete(this.lastOpId, this.bucketPriority);

  StreamingSyncCheckpointPartiallyComplete.fromJson(Map<String, dynamic> json)
      : lastOpId = json['last_op_id'] as String,
        bucketPriority = json['priority'] as int;
}

/// Sent as a periodic ping to keep the connection alive and to notify the
/// client about the remaining lifetime of the JWT.
///
/// When the token is nearing its expiry date, the client may ask for another
/// one and open a new sync session with that token.
final class StreamingSyncKeepalive extends StreamingSyncLine {
  int tokenExpiresIn;

  StreamingSyncKeepalive(this.tokenExpiresIn);

  StreamingSyncKeepalive.fromJson(Map<String, dynamic> json)
      : tokenExpiresIn = json['token_expires_in'] as int;
}

class StreamingSyncRequest {
  List<BucketRequest> buckets;
  bool includeChecksum = true;
  String clientId;
  Map<String, dynamic>? parameters;

  StreamingSyncRequest(this.buckets, this.parameters, this.clientId);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'buckets': buckets,
      'include_checksum': includeChecksum,
      'raw_data': true,
      'client_id': clientId
    };

    if (parameters != null) {
      json['parameters'] = parameters;
    }

    return json;
  }
}

class BucketRequest {
  String name;
  String after;

  BucketRequest(this.name, this.after);

  Map<String, dynamic> toJson() => {
        'name': name,
        'after': after,
      };
}

/// A batch of sync operations being delivered from the sync service.
///
/// Note that the service will always send individual [SyncBucketData] lines,
/// but we group them into [SyncDataBatch]es because writing multiple entries
/// at once improves performance.
final class SyncDataBatch extends StreamingSyncLine {
  List<SyncBucketData> buckets;

  int get totalOperations =>
      buckets.fold(0, (prev, data) => prev + data.data.length);

  SyncDataBatch(this.buckets);
}

final class SyncBucketData {
  final String bucket;
  final List<OplogEntry> data;
  final bool hasMore;
  final String? after;
  final String? nextAfter;

  const SyncBucketData(
      {required this.bucket,
      required this.data,
      this.hasMore = false,
      this.after,
      this.nextAfter});

  SyncBucketData.fromJson(Map<String, dynamic> json)
      : bucket = json['bucket'] as String,
        hasMore = json['has_more'] as bool? ?? false,
        after = json['after'] as String?,
        nextAfter = json['next_after'] as String?,
        data = (json['data'] as List)
            .map((e) => OplogEntry.fromJson(e as Map<String, dynamic>))
            .toList();

  Map<String, dynamic> toJson() {
    return {
      'bucket': bucket,
      'has_more': hasMore,
      'after': after,
      'next_after': nextAfter,
      'data': data
    };
  }
}

class OplogEntry {
  final String opId;

  final OpType? op;

  /// rowType + rowId uniquely identifies an entry in the local database.
  final String? rowType;
  final String? rowId;

  /// Together with rowType and rowId, this uniquely identifies a source entry
  /// per bucket in the oplog. There may be multiple source entries for a single
  /// "rowType + rowId" combination.
  final String? subkey;

  final String? data;
  final int checksum;

  const OplogEntry(
      {required this.opId,
      required this.op,
      this.subkey,
      this.rowType,
      this.rowId,
      this.data,
      required this.checksum});

  OplogEntry.fromJson(Map<String, dynamic> json)
      : opId = json['op_id'] as String,
        op = OpType.fromJson(json['op'] as String),
        rowType = json['object_type'] as String?,
        rowId = json['object_id'] as String?,
        checksum = json['checksum'] as int,
        data = switch (json['data']) {
          String data => data,
          var other => jsonEncode(other),
        },
        subkey = switch (json['subkey']) {
          String subkey => subkey,
          _ => null,
        };

  Map<String, dynamic>? get parsedData {
    return switch (data) {
      final data? => jsonDecode(data) as Map<String, dynamic>,
      null => null,
    };
  }

  /// Key to uniquely represent a source entry in a bucket.
  /// This is used to supersede old entries.
  /// Relevant for put and remove ops.
  String get key {
    return "$rowType/$rowId/$subkey";
  }

  Map<String, dynamic> toJson() {
    return {
      'op_id': opId,
      'op': op?.toJson(),
      'object_type': rowType,
      'object_id': rowId,
      'checksum': checksum,
      'subkey': subkey,
      'data': data
    };
  }
}
