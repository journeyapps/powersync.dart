import 'package:collection/collection.dart';

final class SyncStatus {
  /// true if currently connected.
  ///
  /// This means the PowerSync connection is ready to download, and
  /// [PowerSyncBackendConnector.uploadData] may be called for any local changes.
  final bool connected;

  /// true if the PowerSync connection is busy connecting.
  ///
  /// During this stage, [PowerSyncBackendConnector.uploadData] may already be called,
  /// called, and [uploading] may be true.
  final bool connecting;

  /// true if actively downloading changes.
  ///
  /// This is only true when [connected] is also true.
  final bool downloading;

  /// true if uploading changes
  final bool uploading;

  /// Time that a last sync has fully completed, if any.
  ///
  /// This is null while loading the database.
  final DateTime? lastSyncedAt;

  /// Indicates whether there has been at least one full sync, if any.
  /// Is null when unknown, for example when state is still being loaded from the database.
  final bool? hasSynced;

  /// Error during uploading.
  ///
  /// Cleared on the next successful upload.
  final Object? uploadError;

  /// Error during downloading (including connecting).
  ///
  /// Cleared on the next successful data download.
  final Object? downloadError;

  final List<SyncPriorityStatus> statusInPriority;

  const SyncStatus({
    this.connected = false,
    this.connecting = false,
    this.lastSyncedAt,
    this.hasSynced,
    this.downloading = false,
    this.uploading = false,
    this.downloadError,
    this.uploadError,
    this.statusInPriority = const [],
  });

  @override
  bool operator ==(Object other) {
    return (other is SyncStatus &&
        other.connected == connected &&
        other.downloading == downloading &&
        other.uploading == uploading &&
        other.connecting == connecting &&
        other.downloadError == downloadError &&
        other.uploadError == uploadError &&
        other.lastSyncedAt == lastSyncedAt &&
        other.hasSynced == hasSynced &&
        _statusEquality.equals(other.statusInPriority, statusInPriority));
  }

  SyncStatus copyWith({
    bool? connected,
    bool? downloading,
    bool? uploading,
    bool? connecting,
    Object? uploadError,
    Object? downloadError,
    DateTime? lastSyncedAt,
    bool? hasSynced,
    List<SyncPriorityStatus>? statusInPriority,
  }) {
    return SyncStatus(
      connected: connected ?? this.connected,
      downloading: downloading ?? this.downloading,
      uploading: uploading ?? this.uploading,
      connecting: connecting ?? this.connecting,
      uploadError: uploadError ?? this.uploadError,
      downloadError: downloadError ?? this.downloadError,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      hasSynced: hasSynced ?? this.hasSynced,
      statusInPriority: statusInPriority ?? this.statusInPriority,
    );
  }

  /// Get the current [downloadError] or [uploadError].
  Object? get anyError {
    return downloadError ?? uploadError;
  }

  /// Returns information for [lastSyncedAt] and [hasSynced] information at a
  /// partial sync priority, or `null` if the status for that priority is
  /// unknown.
  ///
  /// The information returned may be more generic than requested. For instance,
  /// a fully-completed sync cycle (as expressed by [lastSyncedAt]) necessarily
  /// includes all buckets across all priorities. So, if no further partial
  /// checkpoints have been received since that complete sync,
  /// [statusForPriority] may return information for that complete sync.
  /// Similarly, requesting the sync status for priority `1` may return
  /// information extracted from the lower priority `2` since each partial sync
  /// in priority `2` necessarily includes a consistent view over data in
  /// priority `1`.
  SyncPriorityStatus statusForPriority(BucketPriority priority) {
    assert(statusInPriority.isSortedByCompare(
        (e) => e.priority, BucketPriority.comparator));

    for (final known in statusInPriority) {
      // Lower-priority buckets are synchronized after higher-priority buckets,
      // and since statusInPriority is sorted we look for the first entry that
      // doesn't have a higher priority.
      if (BucketPriority.comparator(known.priority, priority) <= 0) {
        return known;
      }
    }

    // If we have a complete sync, that necessarily includes all priorities.
    return (
      priority: priority,
      hasSynced: hasSynced,
      lastSyncedAt: lastSyncedAt
    );
  }

  @override
  int get hashCode {
    return Object.hash(
        connected,
        downloading,
        uploading,
        connecting,
        uploadError,
        downloadError,
        lastSyncedAt,
        _statusEquality.hash(statusInPriority));
  }

  @override
  String toString() {
    return "SyncStatus<connected: $connected connecting: $connecting downloading: $downloading uploading: $uploading lastSyncedAt: $lastSyncedAt, hasSynced: $hasSynced, error: $anyError>";
  }

  static const _statusEquality = ListEquality<SyncPriorityStatus>();
}

/// The priority of a PowerSync bucket.
extension type const BucketPriority._(int priorityNumber) {
  static const _highest = 0;

  factory BucketPriority(int i) {
    assert(i >= _highest);
    return BucketPriority._(i);
  }

  /// A [Comparator] instance suitable for comparing [BucketPriority] values.
  static int comparator(BucketPriority a, BucketPriority b) =>
      -a.priorityNumber.compareTo(b.priorityNumber);
}

/// Partial information about the synchronization status for buckets within a
/// priority.
typedef SyncPriorityStatus = ({
  BucketPriority priority,
  DateTime? lastSyncedAt,
  bool? hasSynced,
});

/// Stats of the local upload queue.
class UploadQueueStats {
  /// Number of records in the upload queue.
  int count;

  /// Size of the upload queue in bytes.
  int? size;

  UploadQueueStats({required this.count, this.size});

  @override
  String toString() {
    if (size == null) {
      return "UploadQueueStats<count: $count>";
    } else {
      return "UploadQueueStats<count: $count size: ${size! / 1024}kB>";
    }
  }
}
