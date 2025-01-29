// This file performs setup of the PowerSync database
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trelloappclone_flutter/models/user.dart';

import '../models/schema.dart';

final log = Logger('powersync-supabase');

/// Postgres Response codes that we cannot recover from by retrying.
final List<RegExp> fatalResponseCodes = [
  // Class 22 — Data Exception
  // Examples include data type mismatch.
  RegExp(r'^22...$'),
  // Class 23 — Integrity Constraint Violation.
  // Examples include NOT NULL, FOREIGN KEY and UNIQUE violations.
  RegExp(r'^23...$'),
  // INSUFFICIENT PRIVILEGE - typically a row-level security violation
  RegExp(r'^42501$'),
];

/// Use Supabase for authentication and data upload.
class SupabaseConnector extends PowerSyncBackendConnector {
  PowerSyncDatabase db;

  Future<void>? _refreshFuture;

  SupabaseConnector(this.db);

  /// Get a Supabase token to authenticate against the PowerSync instance.
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // Wait for pending session refresh if any
    await _refreshFuture;

    // Use Supabase token for PowerSync
    final existingSession = Supabase.instance.client.auth.currentSession;
    if (existingSession?.accessToken == null) {
      // Not logged in
      return null;
    }

    // Force session refresh.
    final authResponse = await Supabase.instance.client.auth.refreshSession();
    final session = authResponse.session;
    if (session == null) {
      // Probably shouldn't happen
      return null;
    }

    // Use the access token to authenticate against PowerSync
    final token = session.accessToken;

    // userId and expiresAt are for debugging purposes only
    final userId = session.user.id;
    final expiresAt = session.expiresAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    return PowerSyncCredentials(
        endpoint: dotenv.env['POWERSYNC_URL']!,
        token: token,
        userId: userId,
        expiresAt: expiresAt);
  }

  @override
  void invalidateCredentials() {
    // Trigger a session refresh if auth fails on PowerSync.
    // Generally, sessions should be refreshed automatically by Supabase.
    // However, in some cases it can be a while before the session refresh is
    // retried. We attempt to trigger the refresh as soon as we get an auth
    // failure on PowerSync.
    //
    // This could happen if the device was offline for a while and the session
    // expired, and nothing else attempt to use the session it in the meantime.
    //
    // Timeout the refresh call to avoid waiting for long retries,
    // and ignore any errors. Errors will surface as expired tokens.
    _refreshFuture = Supabase.instance.client.auth
        .refreshSession()
        .timeout(const Duration(seconds: 5))
        .then((response) => null, onError: (error) => null);
  }

  // Upload pending changes to Supabase.
  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    // This function is called whenever there is data to upload, whether the
    // device is online or offline.
    // If this call throws an error, it is retried periodically.
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) {
      return;
    }

    final rest = Supabase.instance.client.rest;
    CrudEntry? lastOp;
    try {
      // Note: If transactional consistency is important, use database functions
      // or edge functions to process the entire transaction in a single call.
      for (var op in transaction.crud) {
        lastOp = op;

        final table = rest.from(op.table);
        if (op.op == UpdateType.put) {
          var data = Map<String, dynamic>.of(op.opData!);
          data['id'] = op.id;
          await table.upsert(data);
        } else if (op.op == UpdateType.patch) {
          await table.update(op.opData!).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          await table.delete().eq('id', op.id);
        }
      }

      // All operations successful.
      await transaction.complete();
    } on PostgrestException catch (e) {
      if (e.code != null &&
          fatalResponseCodes.any((re) => re.hasMatch(e.code!))) {
        /// Instead of blocking the queue with these errors,
        /// discard the (rest of the) transaction.
        ///
        /// Note that these errors typically indicate a bug in the application.
        /// If protecting against data loss is important, save the failing records
        /// elsewhere instead of discarding, and/or notify the user.
        log.severe('Data upload error - discarding $lastOp', e);
        await transaction.complete();
      } else {
        // Error may be retryable - e.g. network error or temporary server error.
        // Throwing an error here causes this call to be retried after a delay.
        rethrow;
      }
    }
  }
}

class PowerSyncClient {
  PowerSyncClient._();

  static final PowerSyncClient _instance = PowerSyncClient._();

  bool _isInitialized = false;
  bool _offlineMode = false;

  late final PowerSyncDatabase _db;

  factory PowerSyncClient() {
    return _instance;
  }

  Future<void> initialize({bool offlineMode = false}) async {
    if (!_isInitialized) {
      _offlineMode = offlineMode;
      await dotenv.load(fileName: '.env');
      await _openDatabase();
      _isInitialized = true;
    }
  }

  PowerSyncDatabase getDBExecutor() {
    if (!_isInitialized) {
      throw Exception(
          'PowerSyncDatabase not initialized. Call initialize() first.');
    }
    return _db;
  }

  bool isLoggedIn() {
    return Supabase.instance.client.auth.currentSession?.accessToken != null;
  }

  /// id of the user currently logged in
  String? getUserId() {
    return Supabase.instance.client.auth.currentSession?.user.id;
  }

  Future<String> getDatabasePath() async {
    final dir = await getApplicationSupportDirectory();
    return join(dir.path, 'powersync-trello-demo.db');
  }

  _loadSupabase() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  Future<void> _openDatabase() async {
    // Open the local database
    _db = PowerSyncDatabase(schema: schema, path: await getDatabasePath());
    await _db.initialize();

    await _loadSupabase();

    if (isLoggedIn() && !_offlineMode) {
      // If the user is already logged in, connect immediately.
      // Otherwise, connect once logged in.
      _db.connect(connector: SupabaseConnector(_db));
    }

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        // Connect to PowerSync when the user is signed in
        _db.connect(connector: SupabaseConnector(_db));
      } else if (event == AuthChangeEvent.signedOut) {
        // Implicit sign out - disconnect, but don't delete data
        await _db.disconnect();
      }
    });
  }

  bool isOfflineMode() {
    return _offlineMode;
  }

  Future<void> switchToOfflineMode() async {
    log.info('Switching to Offline mode');
    _offlineMode = true;
    await _db.disconnect();
  }

  Future<void> switchToOnlineMode() async {
    log.info('Switching to Online mode');
    _offlineMode = false;
    if (isLoggedIn()) {
      _db.connect(connector: SupabaseConnector(_db));
    }
  }

  Future<TrelloUser> signupWithEmail(
      String name, String email, String password) async {
    AuthResponse authResponse = await Supabase.instance.client.auth
        .signUp(email: email, password: password);

    return TrelloUser(
        id: authResponse.user!.id,
        name: name,
        email: email,
        password: password);
  }

  Future<String> loginWithEmail(String email, String password) async {
    AuthResponse authResponse = await Supabase.instance.client.auth
        .signInWithPassword(email: email, password: password);

    return authResponse.user!.id;
  }

  /// Explicit sign out - clear database and log out.
  Future<void> logout() async {
    if (!_isInitialized) {
      throw Exception(
          'PowerSyncClient not initialized. Call initialize() first.');
    }
    await Supabase.instance.client.auth.signOut();
    await _db.disconnectAndClear();
  }

  /// Getting current connection status
  SyncStatus get currentStatus => _db.currentStatus;
  Stream<SyncStatus> get statusStream => _db.statusStream;
}
