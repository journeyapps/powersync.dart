import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

Future<void> downloadWebAssets(List<String> arguments,
    {bool encryption = false}) async {
  var parser = ArgParser();
  // Add a flag to enable/disable the download of worker (defaults to true)
  // Pass the --no-worker argument to disable the download of the worker
  // dart run powersync:setup_web --no-worker
  parser.addFlag('worker', defaultsTo: true);
  // Add a option to specify the output directory (defaults to web)
  // Pass the --output-dir argument to specify the output directory
  // dart run powersync:setup_web --output-dir assets
  parser.addOption('output-dir', abbr: 'o', defaultsTo: 'web');
  var results = parser.parse(arguments);
  bool downloadWorker = results.flag('worker');
  String outputDir = results.option('output-dir')!;

  final root = Directory.current.uri;
  print('Project root: ${root.toFilePath()}');

  final wasmFileName = encryption ? 'sqlite3mc.wasm' : 'sqlite3.wasm';
  final wasmPath = '${root.toFilePath()}$outputDir/$wasmFileName';

  final workerPath = '${root.toFilePath()}$outputDir/powersync_db.worker.js';
  final syncWorkerPath =
      '${root.toFilePath()}$outputDir/powersync_sync.worker.js';

  final packageConfigFile = File.fromUri(
    root.resolve('.dart_tool/package_config.json'),
  );
  dynamic packageConfig;
  try {
    packageConfig = json.decode(await packageConfigFile.readAsString());
  } on FileSystemException {
    print('Missing .dart_tool/package_config.json');
    print('Run `flutter pub get` first.');
    exit(1);
  } on FormatException {
    print('Invalid .dart_tool/package_config.json');
    print('Run `flutter pub get` first.');
    exit(1);
  }

  if (Platform.environment.containsKey('IS_IN_POWERSYNC_CI')) {
    print('IS_IN_POWERSYNC_CI env variable is set, copying from local build');
    return _copyPrecompiled(Directory.current, wasmFileName, outputDir);
  }

  try {
    final httpClient = HttpClient();
    const sqlitePackageName = 'sqlite3';

    final (tag: powersyncTag, version: powerSyncVersion) =
        await powerSyncVersionOrLatest(
            httpClient, packageConfig, packageConfigFile);
    final firstPowerSyncVersionWithOwnWasm = Version(1, 12, 0);

    if (downloadWorker) {
      final workerUrl =
          'https://github.com/powersync-ja/powersync.dart/releases/download/$powersyncTag/powersync_db.worker.js';
      final syncWorkerUrl =
          'https://github.com/powersync-ja/powersync.dart/releases/download/$powersyncTag/powersync_sync.worker.js';

      await downloadFile(httpClient, workerUrl, workerPath);
      await downloadFile(httpClient, syncWorkerUrl, syncWorkerPath);
    }

    if (powerSyncVersion >= firstPowerSyncVersionWithOwnWasm) {
      final wasmUrl =
          'https://github.com/powersync-ja/powersync.dart/releases/download/powersync-$powersyncTag/$wasmFileName';

      await downloadFile(httpClient, wasmUrl, wasmPath);
    } else {
      final sqlite3Pkg = getPackageFromConfig(packageConfig, sqlitePackageName);

      String sqlite3Version =
          "v${getPubspecVersion(packageConfigFile, sqlite3Pkg, sqlitePackageName)}";

      List<String> tags = await getLatestTagsFromRelease(httpClient);
      String? matchTag = tags.firstWhereOrNull((element) =>
          element.contains(sqlite3Version) && coreVersionIsInRange(element));
      if (matchTag != null) {
        sqlite3Version = matchTag;
      } else {
        throw Exception(
            """No compatible powersync core version found for sqlite3 version $sqlite3Version
          Latest supported sqlite3 versions: ${tags.take(3).map((tag) => tag.split('-')[0]).join(', ')}.
          You can view the full list of releases at https://github.com/powersync-ja/sqlite3.dart/releases""");
      }

      final sqliteUrl =
          'https://github.com/powersync-ja/sqlite3.dart/releases/download/$sqlite3Version/$wasmFileName';

      await downloadFile(httpClient, sqliteUrl, wasmPath);
    }
  } catch (e) {
    print(e);
    exit(1);
  }
}

Future<({String tag, Version version})> powerSyncVersionOrLatest(
    HttpClient client, dynamic packageConfig, File packageConfigFile) async {
  const powersyncPackageName = 'powersync';
  // Don't require powersync dependency. The user has one if running this script
  // and we also want to support powersync_sqlcipher (for which we download
  // the latest versions).
  final powersyncPkg = getPackageFromConfig(packageConfig, powersyncPackageName,
      required: false);
  if (powersyncPkg == null) {
    final [tag, ...] =
        await getLatestTagsFromRelease(client, repo: 'powersync.dart');

    return (
      tag: tag,
      version: Version.parse(tag.substring('powersync-v'.length))
    );
  }

  final powersyncVersion =
      getPubspecVersion(packageConfigFile, powersyncPkg, powersyncPackageName);
  return (
    tag: 'powersync-v$powersyncVersion',
    version: Version.parse(powersyncVersion),
  );
}

bool coreVersionIsInRange(String tag) {
  // Sets the range of powersync core version that is compatible with the sqlite3 version
  // We're a little more selective in the versions chosen here than the range
  // we're compatible with.
  VersionConstraint constraint = VersionConstraint.parse('>=0.3.10 <0.4.0');
  List<String> parts = tag.split('-');
  String powersyncPart = parts[1];

  List<String> versionParts = powersyncPart.split('.');
  String extractedVersion =
      versionParts.sublist(versionParts.length - 3).join('.');
  final coreVersion = Version.parse(extractedVersion);
  if (constraint.allows(coreVersion)) {
    return true;
  }
  return false;
}

dynamic getPackageFromConfig(dynamic packageConfig, String packageName,
    {bool required = false}) {
  final pkg = (packageConfig['packages'] as List? ?? <dynamic>[]).firstWhere(
    (dynamic e) => e['name'] == packageName,
    orElse: () => null,
  );
  if (pkg == null && required) {
    throw Exception('Dependency on package:$packageName is required');
  }
  return pkg;
}

String getPubspecVersion(
    File packageConfigFile, dynamic package, String packageName) {
  final rootUri =
      packageConfigFile.uri.resolve(package['rootUri'] as String? ?? '');
  print('Using package:$packageName from ${rootUri.toFilePath()}');

  String pubspec =
      File('${rootUri.toFilePath()}/pubspec.yaml').readAsStringSync();
  Pubspec parsed = Pubspec.parse(pubspec);
  final version = parsed.version?.toString();
  if (version == null) {
    throw Exception(
        "${capitalize(packageName)} version not found. Run `flutter pub get` first.");
  }
  return version;
}

String capitalize(String s) => s[0].toUpperCase() + s.substring(1);

Future<List<String>> getLatestTagsFromRelease(HttpClient httpClient,
    {String repo = 'sqlite3.dart'}) async {
  var request = await httpClient.getUrl(
      Uri.parse("https://api.github.com/repos/powersync-ja/$repo/releases"));
  var response = await request.close();
  if (response.statusCode == HttpStatus.ok) {
    var res = await response.transform(utf8.decoder).join();
    var jsonObj = json.decode(res) as List<dynamic>;
    List<String> tags = [];
    for (dynamic obj in jsonObj) {
      final tagName = obj['tag_name'] as String;
      if (!tagName.contains("powersync")) continue;
      tags.add(tagName);
    }
    return tags;
  } else {
    throw Exception("Failed to fetch GitHub releases and tags");
  }
}

Future<void> downloadFile(
    HttpClient httpClient, String url, String savePath) async {
  print('Downloading: $url');
  var request = await httpClient.getUrl(Uri.parse(url));
  var response = await request.close();
  if (response.statusCode == HttpStatus.ok) {
    var file = File(savePath);
    await response.pipe(file.openWrite());
  } else {
    throw Exception(
        'Failed to download file: ${response.statusCode} ${response.reasonPhrase}');
  }
}

/// Copies WebAssembly modules from `packages/sqlite3_wasm_build/dist` into
/// `web/`.
///
/// When we're running this setup script as part of our CI, a previous action
/// (`.github/actions/prepare/`) will have put compiled assets into that folder.
/// Copying from there ensures we run web tests against our current SQLite web
/// build and avoids downloading from GitHub releases for every package we test.
Future<void> _copyPrecompiled(
    Directory project, String wasmFile, String outputDir) async {
  // Keep going up until we see the melos.yaml file indicating the workspace
  // root.
  var dir = project;
  while (!await File(p.join(dir.path, 'melos.yaml')).exists()) {
    print('Looking for melos workspace in $dir');
    final parent = dir.parent;
    if (p.equals(parent.path, dir.path)) {
      throw 'Melos workspace not found';
    }

    dir = parent;
  }

  // In the CI, an earlier step will have put these files into the prepared
  // sqlite3_wasm_build package.
  final destination = p.join(project.path, outputDir);
  final wasmSource = p.join(dir.path, 'packages', 'sqlite3_wasm_build', 'dist');
  print('Copying $wasmFile from $wasmSource to $destination');
  await File(p.join(wasmSource, wasmFile)).copy(p.join(destination, wasmFile));
}
