import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database/powersync_database.dart';

/// Implement this to connect an app backend.
///
/// The connector is responsible for:
/// 1. Creating credentials for connecting to the PowerSync service.
/// 2. Applying local changes against the backend application server.
///
/// For production, use a custom implementation.
abstract class PowerSyncBackendConnector {
  PowerSyncCredentials? _cachedCredentials;
  Future<PowerSyncCredentials?>? _fetchRequest;

  /// Get credentials current cached, or fetch new credentials if none are
  /// available.
  ///
  /// These credentials may have expired already.
  Future<PowerSyncCredentials?> getCredentialsCached() {
    if (_cachedCredentials != null) {
      return Future.value(_cachedCredentials);
    }
    return prefetchCredentials();
  }

  /// Immediately invalidate credentials.
  ///
  /// This may be called when the current credentials have expired.
  void invalidateCredentials() async {
    _cachedCredentials = null;
  }

  /// Fetch a new set of credentials and cache it.
  ///
  /// Until this call succeeds, `getCredentialsCached()` will still return the
  /// old credentials.
  ///
  /// This may be called before the current credentials have expired.
  Future<PowerSyncCredentials?> prefetchCredentials() async {
    _fetchRequest ??= fetchCredentials().then((value) {
      _cachedCredentials = value;
      return value;
    }).whenComplete(() {
      _fetchRequest = null;
    });

    return _fetchRequest!;
  }

  /// Get credentials for PowerSync.
  ///
  /// This should always fetch a fresh set of credentials - don't use cached
  /// values.
  ///
  /// Return null if the user is not signed in. Throw an error if credentials
  /// cannot be fetched due to a network error or other temporary error.
  ///
  /// This token is kept for the duration of a sync connection.
  Future<PowerSyncCredentials?> fetchCredentials();

  /// Upload local changes to the app backend.
  ///
  /// Use [PowerSyncDatabase.getCrudBatch] to get a batch of changes to upload.
  ///
  /// Any thrown errors will result in a retry after the configured wait period (default: 5 seconds).
  Future<void> uploadData(PowerSyncDatabase database);
}

/// Temporary credentials to connect to the PowerSync service.
class PowerSyncCredentials {
  /// PowerSync endpoint, e.g. "https://myinstance.powersync.co".
  final String endpoint;

  /// Temporary token to authenticate against the service.
  final String token;

  /// User ID.
  final String? userId;

  /// When the token expires. Only use for debugging purposes.
  final DateTime? expiresAt;

  PowerSyncCredentials(
      {required this.endpoint,
      required this.token,
      this.userId,
      this.expiresAt}) {
    _validateEndpoint();
  }

  factory PowerSyncCredentials.fromJson(Map<String, dynamic> parsed) {
    String token = parsed['token'] as String;
    DateTime? expiresAt = getExpiryDate(token);

    return PowerSyncCredentials(
        endpoint: parsed['endpoint'] as String,
        token: token,
        userId: parsed['user_id'] as String?,
        expiresAt: expiresAt);
  }

  /// Get an expiry date from a JWT token, if specified.
  ///
  /// The token is not validated in any way.
  static DateTime? getExpiryDate(String token) {
    try {
      List<String> parts = token.split('.');
      if (parts.length == 3) {
        // dart:convert doesn't like missing padding
        final rawData = base64Url.decode(base64.normalize(parts[1]));
        final text = Utf8Decoder().convert(rawData);
        final payload = jsonDecode(text) as Map<String, dynamic>;
        if (payload['exp'] case int exp) {
          return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  toString() {
    return "PowerSyncCredentials<endpoint: $endpoint userId: $userId expiresAt: $expiresAt>";
  }

  /// Resolve an endpoint path against the endpoint URI.
  Uri endpointUri(String path) {
    return Uri.parse(endpoint).resolve(path);
  }

  void _validateEndpoint() {
    final parsed = Uri.parse(endpoint);
    if ((!parsed.isScheme('http') && !parsed.isScheme('https')) ||
        parsed.host.isEmpty) {
      throw ArgumentError.value(
          endpoint, 'PowerSync endpoint must be a valid URL');
    }
  }
}

/// Credentials used to connect to the PowerSync dev API.
///
/// Used by [DevConnector].
///
/// These cannot be used for the main PowerSync APIs. [DevConnector] uses these
/// credentials to automatically fetch [PowerSyncCredentials].
@Deprecated('We will be removing this in version 2.')
class DevCredentials {
  /// Dev endpoint.
  String endpoint;

  /// Dev token.
  String? token;

  /// User id.
  String? userId;

  DevCredentials({required this.endpoint, this.token, this.userId});

  factory DevCredentials.fromJson(Map<String, dynamic> parsed) {
    return DevCredentials(
        endpoint: parsed['endpoint'] as String,
        token: parsed['token'] as String?,
        userId: parsed['user_id'] as String?);
  }

  factory DevCredentials.fromString(String credentials) {
    var parsed = jsonDecode(credentials);
    return DevCredentials.fromJson(parsed as Map<String, dynamic>);
  }

  static DevCredentials? fromOptionalString(String? credentials) {
    if (credentials == null) {
      return null;
    }
    return DevCredentials.fromString(credentials);
  }

  Map<String, dynamic> toJson() {
    return {'endpoint': endpoint, 'token': token, 'user_id': userId};
  }
}

/// Connects to the PowerSync service in development mode.
///
/// Development mode has the following functionality:
///   1. Login using static username & password combinations, returning [DevCredentials].
///   2. Refresh PowerSync token using [DevCredentials].
///   3. Write directly to the SQL database using a basic update endpoint.
///
/// By default, credentials are stored in memory only. Subclass and override
/// [DevConnector.storeDevCredentials] and [DevConnector.loadDevCredentials] to use persistent storage.
///
/// Development mode is intended to get up and running quickly, but is not for
/// production use. For production, write a custom connector.
@Deprecated('We will be removing this in version 2.')
class DevConnector extends PowerSyncBackendConnector {
  DevCredentials? _inMemoryDevCredentials;

  /// Store the credentials after login, or when clearing / changing it.
  ///
  /// Default implementation stores in memory - override to use persistent storage.
  Future<void> storeDevCredentials(DevCredentials credentials) async {
    _inMemoryDevCredentials = credentials;
  }

  /// Load the stored credentials.
  ///
  /// Default implementation stores in memory - override to use persistent storage.
  Future<DevCredentials?> loadDevCredentials() async {
    return _inMemoryDevCredentials;
  }

  /// Get the user id associated with the dev credentials.
  Future<String?> getUserId() async {
    final credentials = await loadDevCredentials();
    return credentials?.userId;
  }

  /// Get the dev endpoint associated with the dev credentials.
  Future<String?> getEndpoint() async {
    final credentials = await loadDevCredentials();
    return credentials?.endpoint;
  }

  /// Clear the dev token.
  ///
  /// Use this if the user logged out, or authentication fails.
  Future<void> clearDevToken() async {
    var existing = await loadDevCredentials();
    if (existing != null) {
      existing.token = null;
      storeDevCredentials(existing);
    }
  }

  /// Whether a dev token is available.
  Future<bool> hasCredentials() async {
    final devCredentials = await loadDevCredentials();
    return devCredentials?.token != null;
  }

  /// Use the PowerSync dev API to log in.
  Future<void> devLogin(
      {required String endpoint,
      required String user,
      required String password}) async {
    final uri = Uri.parse(endpoint).resolve('dev/auth.json');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user': user, 'password': password}));

    if (res.statusCode == 200) {
      var parsed = jsonDecode(res.body);
      var data = parsed['data'] as Map<String, dynamic>;

      storeDevCredentials(DevCredentials(
          endpoint: endpoint,
          token: data['token'] as String?,
          userId: data['user_id'] as String?));
    } else {
      throw http.ClientException(res.reasonPhrase ?? 'Request failed', uri);
    }
  }

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final devCredentials = await loadDevCredentials();
    if (devCredentials?.token == null) {
      // Not signed in
      return null;
    }
    final uri = Uri.parse(devCredentials!.endpoint).resolve('dev/token.json');
    final res = await http
        .post(uri, headers: {'Authorization': 'Token ${devCredentials.token}'});
    if (res.statusCode == 401) {
      clearDevToken();
    }
    if (res.statusCode != 200) {
      throw http.ClientException(res.reasonPhrase ?? 'Request failed', uri);
    }

    return PowerSyncCredentials.fromJson(
        jsonDecode(res.body)['data'] as Map<String, dynamic>);
  }

  /// Upload changes using the PowerSync dev API.
  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final batch = await database.getCrudBatch();
    if (batch == null) {
      return;
    }

    final credentials = await getCredentialsCached();
    if (credentials == null) {
      throw AssertionError("Not logged in");
    }
    final uri = credentials.endpointUri('crud.json');

    final response = await http.post(uri,
        headers: {
          'Content-Type': 'application/json',
          'User-Id': credentials.userId ?? '',
          'Authorization': "Token ${credentials.token}"
        },
        body: jsonEncode({'data': batch.crud, 'write_checkpoint': true}));

    if (response.statusCode == 401) {
      // Credentials have expired - fetch a new token on the next call
      invalidateCredentials();
    }

    if (response.statusCode != 200) {
      throw http.ClientException(
          response.reasonPhrase ?? "Failed due to server error.", uri);
    }

    final body = jsonDecode(response.body);
    // writeCheckpoint is optional, but reduces latency between writing,
    // and reading back the same change.
    final writeCheckpoint = body['data']['write_checkpoint'] as String?;
    await batch.complete(writeCheckpoint: writeCheckpoint);
  }
}
