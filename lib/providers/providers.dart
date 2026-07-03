import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_mode.dart';
import '../data/local/entities.dart';
import '../data/local/local_store.dart';
import '../models/book.dart';
import '../models/track.dart';
import '../repositories/book_repository.dart';
import '../repositories/storage_repository.dart';

// --------------------------------------------------------------- foundation

/// Overridden in `main()` with the opened instance.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('localStoreProvider must be overridden'),
);

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => useMock ? MockBookRepository() : FirestoreBookRepository(),
);

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => useMock ? MockStorageRepository() : FileStorageRepository(),
);

// -------------------------------------------------------------------- books

/// The whole catalog.
final booksProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(bookRepositoryProvider).watchBooks(),
);

final bookProvider = FutureProvider.autoDispose.family<Book?, String>(
  (ref, id) => ref.watch(bookRepositoryProvider).getBook(id),
);

// ------------------------------------------------------------------ library

/// Library books in user order. The user's entries (id + order) come from the
/// local store; metadata is joined in memory against the streamed [booksProvider]
/// catalog, so there is no per-entry `getBook` round-trip.
final libraryProvider = StreamProvider<List<Book>>((ref) {
  final store = ref.watch(localStoreProvider);
  final catalog = ref.watch(booksProvider).valueOrNull ?? const <Book>[];
  return store.watchLibrary().map((entries) => _joinCatalog(entries, catalog));
});

/// Favorite subset, in user order.
final favoritesProvider = StreamProvider<List<Book>>((ref) {
  final store = ref.watch(localStoreProvider);
  final catalog = ref.watch(booksProvider).valueOrNull ?? const <Book>[];
  return store.watchFavorites().map((entries) => _joinCatalog(entries, catalog));
});

/// Whether a given book is already in the library (reactive).
final isInLibraryProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, bookId) {
  final store = ref.watch(localStoreProvider);
  return store.watchLibrary().map(
        (entries) => entries.any((e) => e.bookId == bookId),
      );
});

/// Whether a given book is favorited (reactive).
final isFavoriteProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, bookId) {
  final store = ref.watch(localStoreProvider);
  return store.watchLibrary().map(
        (entries) => entries.any((e) => e.bookId == bookId && e.favorite),
      );
});

/// Joins ordered library entries to catalog metadata, dropping orphans (a book
/// that vanished from the catalog) so a stale local entry never crashes a list.
List<Book> _joinCatalog(List<LibraryBook> entries, List<Book> catalog) {
  final byId = {for (final b in catalog) b.id: b};
  final books = <Book>[];
  for (final e in entries) {
    final book = byId[e.bookId];
    if (book == null) {
      debugPrint('libraryProvider: no catalog book "${e.bookId}"; '
          'skipping orphan library entry.');
      continue;
    }
    books.add(book);
  }
  return books;
}

/// Mutations on the library; the streams above reflect the changes.
final libraryControllerProvider = Provider<LibraryController>(
  (ref) => LibraryController(ref.watch(localStoreProvider)),
);

class LibraryController {
  LibraryController(this._store);

  final LocalStore _store;

  Future<void> add(String bookId) => _store.addToLibrary(bookId);
  Future<void> remove(String bookId) => _store.removeFromLibrary(bookId);
  Future<void> setFavorite(String bookId, bool value) =>
      _store.setFavorite(bookId, value);
  Future<void> reorder(List<String> orderedBookIds) =>
      _store.reorderLibrary(orderedBookIds);
}

// ------------------------------------------------------------------- search

// autoDispose so query + results reset when the Search screen closes, instead
// of leaking the previous session's text into the next open.
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<List<Book>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const [];

  // Debounce: a keystroke re-runs this provider and disposes the prior run;
  // bail after the delay if superseded, so only the settled query does work.
  var active = true;
  ref.onDispose(() => active = false);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (!active) return const [];

  // Filter the already-streamed catalog instead of re-fetching per keystroke.
  final catalog = ref.read(booksProvider).valueOrNull ??
      await ref.read(bookRepositoryProvider).getBooks();
  return filterBooks(catalog, query);
});

// ---------------------------------------------------------------- downloads

/// Downloaded tracks for a book (reactive).
final downloadsForBookProvider =
    StreamProvider.autoDispose.family<List<DownloadedTrack>, String>(
  (ref, bookId) => ref.watch(localStoreProvider).watchDownloadsForBook(bookId),
);

/// Coordinates the storage repository (file IO) with the local store (records).
final downloadControllerProvider = Provider<DownloadController>(
  (ref) => DownloadController(
    ref.watch(storageRepositoryProvider),
    ref.watch(localStoreProvider),
  ),
);

class DownloadController {
  DownloadController(this._storage, this._store);

  final StorageRepository _storage;
  final LocalStore _store;

  /// Downloads a single track and records its local path.
  Future<void> download(Track track, {ProgressCallback? onProgress}) async {
    final path = await _storage.download(track, onProgress: onProgress);
    await _store.saveDownload(track.bookId, track.id, path);
  }

  Future<void> deleteTrack(Track track) async {
    await _storage.delete(track);
    await _store.deleteDownload(track.bookId, track.id);
  }

  Future<void> deleteBook(String bookId) async {
    await _storage.deleteBook(bookId);
    await _store.deleteDownloadsForBook(bookId);
  }
}

// -------------------------------------------------------------- preferences

final libraryAsGridProvider = StreamProvider<bool>(
  (ref) => ref.watch(localStoreProvider).watchLibraryAsGrid(),
);
