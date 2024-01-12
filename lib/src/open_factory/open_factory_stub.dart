import 'package:sqlite_async/sqlite3_common.dart';
import './open_factory_interface.dart' as open_factory;

class PowerSyncOpenFactory extends open_factory.AbstractPowerSyncOpenFactory {
  PowerSyncOpenFactory(
      {required super.path,
      super.sqliteOptions,
      @Deprecated('Override PowerSyncOpenFactory instead')
      // ignore: deprecated_member_use_from_same_package
      open_factory.SqliteConnectionSetup? sqliteSetup});

  void enableExtension() {
    throw UnimplementedError();
  }

  void setupFunctions(CommonDatabase db) {
    throw UnimplementedError();
  }
}
