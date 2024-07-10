import 'dart:async';
import 'dart:math';

import 'package:powersync/powersync.dart';
import 'package:test/test.dart';

import 'test_server.dart';
import 'util.dart';

class TestConnector extends PowerSyncBackendConnector {
  final Function _fetchCredentials;

  TestConnector(this._fetchCredentials);

  @override
  Future<PowerSyncCredentials?> fetchCredentials() {
    return _fetchCredentials();
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {}
}

void main() {
  group('Streaming Sync Test', () {
    late String path;

    setUp(() async {
      path = dbPath();
      await cleanDb(path: path);
    });

    tearDown(() async {
      await cleanDb(path: path);
    });

    test('full powersync reconnect', () async {
      // Test repeatedly creating new PowerSync connections, then disconnect
      // and close the connection.
      final random = Random();

      for (var i = 0; i < 10; i++) {
        var server = await createServer();

        credentialsCallback() async {
          return PowerSyncCredentials(
              endpoint: server.endpoint, token: 'token');
        }

        final pdb = await setupPowerSync(path: path);
        pdb.retryDelay = Duration(milliseconds: 5000);
        var connector = TestConnector(credentialsCallback);
        pdb.connect(connector: connector);

        await Future.delayed(Duration(milliseconds: random.nextInt(100)));
        if (random.nextBool()) {
          server.close();
        }

        await pdb.close();

        // Give some time for connections to close
        final watch = Stopwatch()..start();
        while (server.connectionCount != 0 && watch.elapsedMilliseconds < 100) {
          await Future.delayed(Duration(milliseconds: random.nextInt(10)));
        }

        expect(server.connectionCount, equals(0));
        expect(server.maxConnectionCount, lessThanOrEqualTo(1));

        server.close();
      }
    });

    test('powersync connection errors', () async {
      // Test repeatedly killing the streaming connection
      // Errors like this are expected:
      //
      //   [PowerSync] WARNING: 2023-06-29 16:05:24.810002: Sync error
      //   Connection closed while receiving data
      //   Write failed
      //   Connection refused
      //
      // Errors like this are not okay:
      // [PowerSync] WARNING: 2023-06-29 16:10:17.667537: Sync Isolate error
      // [Connection closed while receiving data, #0      IOClient.send.<anonymous closure> (package:http/src/io_client.dart:76:13)

      TestServer? server;

      credentialsCallback() async {
        if (server == null) {
          throw AssertionError('No active server');
        }
        return PowerSyncCredentials(endpoint: server.endpoint, token: 'token');
      }

      final pdb = await setupPowerSync(path: path);
      pdb.retryDelay = const Duration(milliseconds: 5);
      var connector = TestConnector(credentialsCallback);
      pdb.connect(connector: connector);

      for (var i = 0; i < 10; i++) {
        server = await createServer();

        // var stream = impl.streamingSyncRequest(StreamingSyncRequest([]));
        // 2ms: HttpException: HttpServer is not bound to a socket
        // 20ms: Connection closed while receiving data
        await Future.delayed(Duration(milliseconds: 20));
        server.close();
      }
      await pdb.close();
    });

    test('multiple connect calls', () async {
      // Test calling connect() multiple times.
      // We check that this does not cause multiple connections to be opened concurrently.
      final random = Random();
      var server = await createServer();

      credentialsCallback() async {
        return PowerSyncCredentials(endpoint: server.endpoint, token: 'token');
      }

      final pdb = await setupPowerSync(path: path);
      pdb.retryDelay = Duration(milliseconds: 5000);
      var connector = TestConnector(credentialsCallback);
      pdb.connect(connector: connector);
      pdb.connect(connector: connector);

      final watch = Stopwatch()..start();

      // Wait for at least one connection
      while (server.connectionCount < 1 && watch.elapsedMilliseconds < 500) {
        await Future.delayed(Duration(milliseconds: random.nextInt(10)));
      }
      // Give some time for a second connection if any
      await Future.delayed(Duration(milliseconds: random.nextInt(50)));

      await pdb.close();

      // Give some time for connections to close
      while (server.connectionCount != 0 && watch.elapsedMilliseconds < 1000) {
        await Future.delayed(Duration(milliseconds: random.nextInt(10)));
      }

      expect(server.connectionCount, equals(0));
      expect(server.maxConnectionCount, equals(1));

      server.close();
    });
  });
}
