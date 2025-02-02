import 'dart:js_interop';

import 'package:powersync_core/src/open_factory/common_db_functions.dart';
import 'package:sqlite_async/sqlite3_wasm.dart';
import 'package:sqlite_async/sqlite3_web.dart';
import 'package:sqlite_async/sqlite3_web_worker.dart';
import 'package:uuid/uuid.dart';

final class PowerSyncAsyncSqliteController extends AsyncSqliteController {
  @override
  Future<WorkerDatabase> openDatabase(WasmSqlite3 sqlite3, String path,
      String vfs, JSAny? additionalData) async {
    final asyncDb =
        await super.openDatabase(sqlite3, path, vfs, additionalData);
    setupPowerSyncDatabase(asyncDb.database);
    return asyncDb;
  }

  @override
  CommonDatabase openUnderlying(
      WasmSqlite3 sqlite3, String path, String vfs, JSAny? additionalData) {
    final options = additionalData == null
        ? null
        : additionalData as PowerSyncAdditionalOpenOptions;
    if (options != null && options.useMultipleCiphersVfs) {
      vfs = 'multipleciphers-$vfs';
    }

    return sqlite3.open(path, vfs: vfs);
  }

  @override
  Future<JSAny?> handleCustomRequest(
      ClientConnection connection, JSAny? request) {
    throw UnimplementedError();
  }
}

@JS()
@anonymous
extension type PowerSyncAdditionalOpenOptions._(JSObject _)
    implements JSObject {
  external factory PowerSyncAdditionalOpenOptions({
    required bool useMultipleCiphersVfs,
  });

  external bool get useMultipleCiphersVfs;
}

// Registers custom SQLite functions for the SQLite connection
void setupPowerSyncDatabase(CommonDatabase database) {
  setupCommonDBFunctions(database);
  final uuid = Uuid();

  database.createFunction(
    functionName: 'uuid',
    argumentCount: const AllowedArgumentCount(0),
    function: (args) {
      return uuid.v4();
    },
  );
  database.createFunction(
    // Postgres compatibility
    functionName: 'gen_random_uuid',
    argumentCount: const AllowedArgumentCount(0),
    function: (args) => uuid.v4(),
  );
  database.createFunction(
    functionName: 'powersync_sleep',
    argumentCount: const AllowedArgumentCount(1),
    function: (args) {
      // Can't perform synchronous sleep on web
      final millis = args[0] as int;
      return millis;
    },
  );

  database.createFunction(
    functionName: 'powersync_connection_name',
    argumentCount: const AllowedArgumentCount(0),
    function: (args) {
      return 'N/A';
    },
  );
}
