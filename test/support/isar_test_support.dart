import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:project_oshiro/data/local/entities.dart';
import 'package:project_oshiro/data/local/local_store.dart';

/// Opens real Isar instances for `LocalStore` tests running under the plain
/// `flutter test` VM (no Flutter engine, so `path_provider` and the bundled
/// native libs are unavailable). It locates the `isar_community_flutter_libs`
/// native library already present in the pub cache and points Isar at it,
/// falling back to Isar's own download. When neither works the `LocalStore`
/// tests skip with a clear reason instead of failing the suite.
///
/// Isar keeps global state, so core initialization happens once per process.
class IsarTestSupport {
  IsarTestSupport._();

  static bool? _available;
  static String? _skipReason;
  static int _counter = 0;

  /// Whether Isar is usable in this environment. Cached after the first call.
  static Future<bool> ensureInitialized() async {
    if (_available != null) return _available!;
    try {
      final lib = _findNativeLib();
      if (lib != null) {
        await Isar.initializeIsarCore(libraries: {Abi.current(): lib});
      } else {
        await Isar.initializeIsarCore(download: true);
      }
      _available = true;
    } catch (e) {
      _available = false;
      _skipReason = 'Isar core unavailable in this environment: $e';
    }
    return _available!;
  }

  /// Human-readable reason to pass to `skip:` when Isar cannot run.
  static String get skipReason =>
      _skipReason ?? 'Isar core could not be initialized';

  /// A fresh, isolated [LocalStore] backed by a temp-dir Isar. Each call uses a
  /// unique instance name so tests never share state. Call [close] in teardown.
  static Future<LocalStore> openStore() async {
    final dir = Directory.systemTemp.createTempSync('oshiro_isar_test');
    final isar = await Isar.open(
      [
        LibraryBookSchema,
        DownloadedTrackSchema,
        TrackProgressSchema,
        PreferencesSchema,
      ],
      directory: dir.path,
      name: 'test_${_counter++}',
    );
    return LocalStore.fromIsar(isar);
  }

  /// Closes the store's Isar and drops its on-disk data.
  static Future<void> close(LocalStore store) async {
    await store.isar.close(deleteFromDisk: true);
  }

  /// Locates the platform native Isar library shipped in the pub cache, or null
  /// if it cannot be found (then the caller falls back to `download: true`).
  static String? _findNativeLib() {
    final (subdir, fileName) = switch (Abi.current()) {
      Abi.linuxX64 || Abi.linuxArm64 => ('linux', 'libisar.so'),
      Abi.macosX64 || Abi.macosArm64 => ('macos', 'libisar.dylib'),
      Abi.windowsX64 || Abi.windowsArm64 => ('windows', 'isar.dll'),
      _ => ('', ''),
    };
    if (subdir.isEmpty) return null;

    for (final root in _pubCacheRoots()) {
      final hosted = Directory('$root/hosted/pub.dev');
      if (!hosted.existsSync()) continue;
      final pkgDirs = hosted
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('isar_community_flutter_libs-'))
          .toList();
      for (final pkg in pkgDirs) {
        final candidate = File('${pkg.path}/$subdir/$fileName');
        if (candidate.existsSync()) return candidate.path;
      }
    }
    return null;
  }

  static List<String> _pubCacheRoots() {
    final env = Platform.environment;
    return [
      if (env['PUB_CACHE'] != null) env['PUB_CACHE']!,
      if (env['HOME'] != null) '${env['HOME']}/.pub-cache',
      if (env['LOCALAPPDATA'] != null) '${env['LOCALAPPDATA']}\\Pub\\Cache',
    ];
  }
}
