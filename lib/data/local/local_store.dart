import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'entities.dart';

String _scopedKey(String bookId, String trackId) => '$bookId::$trackId';

/// Typed facade over Isar. Single source of truth for user-local state:
/// library membership + order, favorites, downloads, playback positions and
/// the list/grid preference. Replaces the old `.txt` FileManager and
/// SharedPreferences.
class LocalStore {
  LocalStore(this._isar);

  final Isar _isar;

  /// Opens the Isar database in the app documents directory.
  static Future<LocalStore> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [
        LibraryBookSchema,
        DownloadedTrackSchema,
        TrackProgressSchema,
        PreferencesSchema,
      ],
      directory: dir.path,
    );
    return LocalStore(isar);
  }

  /// For tests: wraps an already-open (e.g. in-memory) Isar instance.
  LocalStore.fromIsar(this._isar);

  Isar get isar => _isar;

  // ---------------------------------------------------------------- library

  Stream<List<LibraryBook>> watchLibrary() => _isar.libraryBooks
      .where()
      .sortBySortOrder()
      .watch(fireImmediately: true);

  Stream<List<LibraryBook>> watchFavorites() => _isar.libraryBooks
      .filter()
      .favoriteEqualTo(true)
      .sortBySortOrder()
      .watch(fireImmediately: true);

  Future<List<LibraryBook>> getLibrary() =>
      _isar.libraryBooks.where().sortBySortOrder().findAll();

  Future<bool> isInLibrary(String bookId) async {
    final entry =
        await _isar.libraryBooks.filter().bookIdEqualTo(bookId).findFirst();
    return entry != null;
  }

  Future<void> addToLibrary(String bookId) async {
    if (await isInLibrary(bookId)) return;
    final maxOrder = await _isar.libraryBooks.where().sortOrderProperty().max();
    await _isar.writeTxn(() async {
      await _isar.libraryBooks.put(
        LibraryBook()
          ..bookId = bookId
          ..sortOrder = (maxOrder ?? -1) + 1,
      );
    });
  }

  Future<void> removeFromLibrary(String bookId) async {
    await _isar.writeTxn(() async {
      await _isar.libraryBooks.filter().bookIdEqualTo(bookId).deleteAll();
    });
  }

  Future<void> setFavorite(String bookId, bool favorite) async {
    await _isar.writeTxn(() async {
      final entry =
          await _isar.libraryBooks.filter().bookIdEqualTo(bookId).findFirst();
      if (entry == null) return;
      entry.favorite = favorite;
      await _isar.libraryBooks.put(entry);
    });
  }

  Future<bool> isFavorite(String bookId) async {
    final entry =
        await _isar.libraryBooks.filter().bookIdEqualTo(bookId).findFirst();
    return entry?.favorite ?? false;
  }

  /// Persists a new order given the desired sequence of book ids.
  Future<void> reorderLibrary(List<String> orderedBookIds) async {
    await _isar.writeTxn(() async {
      for (var i = 0; i < orderedBookIds.length; i++) {
        final entry = await _isar.libraryBooks
            .filter()
            .bookIdEqualTo(orderedBookIds[i])
            .findFirst();
        if (entry == null) continue;
        entry.sortOrder = i;
        await _isar.libraryBooks.put(entry);
      }
    });
  }

  // -------------------------------------------------------------- downloads

  Stream<List<DownloadedTrack>> watchDownloadsForBook(String bookId) => _isar
      .downloadedTracks
      .filter()
      .bookIdEqualTo(bookId)
      .watch(fireImmediately: true);

  Future<List<DownloadedTrack>> downloadsForBook(String bookId) =>
      _isar.downloadedTracks.filter().bookIdEqualTo(bookId).findAll();

  Future<String?> downloadPath(String bookId, String trackId) async {
    final entry = await _isar.downloadedTracks
        .filter()
        .keyEqualTo(_scopedKey(bookId, trackId))
        .findFirst();
    return entry?.path;
  }

  Future<void> saveDownload(String bookId, String trackId, String path) async {
    await _isar.writeTxn(() async {
      await _isar.downloadedTracks.put(
        DownloadedTrack()
          ..key = _scopedKey(bookId, trackId)
          ..bookId = bookId
          ..trackId = trackId
          ..path = path,
      );
    });
  }

  Future<void> deleteDownload(String bookId, String trackId) async {
    await _isar.writeTxn(() async {
      await _isar.downloadedTracks
          .filter()
          .keyEqualTo(_scopedKey(bookId, trackId))
          .deleteAll();
    });
  }

  Future<void> deleteDownloadsForBook(String bookId) async {
    await _isar.writeTxn(() async {
      await _isar.downloadedTracks.filter().bookIdEqualTo(bookId).deleteAll();
    });
  }

  // --------------------------------------------------------------- progress

  Future<TrackProgress?> playbackProgress(String bookId, String trackId) =>
      _isar.trackProgress
          .filter()
          .trackKeyEqualTo(_scopedKey(bookId, trackId))
          .findFirst();

  Future<void> savePlaybackProgress(
    String bookId,
    String trackId,
    Duration position,
    Duration duration,
  ) async {
    await _isar.writeTxn(() async {
      await _isar.trackProgress.put(
        TrackProgress()
          ..trackKey = _scopedKey(bookId, trackId)
          ..positionMs = position.inMilliseconds
          ..durationMs = duration.inMilliseconds
          ..updatedAt = DateTime.now(),
      );
    });
  }

  // -------------------------------------------------------------- preferences

  Future<Preferences> _prefs() async =>
      await _isar.preferences.get(0) ?? Preferences();

  Future<bool> libraryAsGrid() async => (await _prefs()).libraryAsGrid;

  Stream<bool> watchLibraryAsGrid() async* {
    yield await libraryAsGrid();
    yield* _isar.preferences
        .watchObject(0, fireImmediately: false)
        .map((p) => p?.libraryAsGrid ?? false);
  }

  Future<void> setLibraryAsGrid(bool value) async {
    await _isar.writeTxn(() async {
      final prefs = await _prefs()..libraryAsGrid = value;
      await _isar.preferences.put(prefs);
    });
  }
}
