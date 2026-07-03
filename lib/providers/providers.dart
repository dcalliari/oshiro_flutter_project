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

final bookProvider = FutureProvider.family<Book?, String>(
  (ref, id) => ref.watch(bookRepositoryProvider).getBook(id),
);

// ------------------------------------------------------------------ library

/// Library books in user order, joined from local entries + catalog metadata.
final libraryProvider = StreamProvider<List<Book>>((ref) async* {
  final store = ref.watch(localStoreProvider);
  final repo = ref.watch(bookRepositoryProvider);
  await for (final entries in store.watchLibrary()) {
    yield await _resolve(repo, entries);
  }
});

/// Favorite subset, in user order.
final favoritesProvider = StreamProvider<List<Book>>((ref) async* {
  final store = ref.watch(localStoreProvider);
  final repo = ref.watch(bookRepositoryProvider);
  await for (final entries in store.watchFavorites()) {
    yield await _resolve(repo, entries);
  }
});

/// Whether a given book is already in the library (reactive).
final isInLibraryProvider = StreamProvider.family<bool, String>((ref, bookId) {
  final store = ref.watch(localStoreProvider);
  return store.watchLibrary().map(
        (entries) => entries.any((e) => e.bookId == bookId),
      );
});

/// Whether a given book is favorited (reactive).
final isFavoriteProvider = StreamProvider.family<bool, String>((ref, bookId) {
  final store = ref.watch(localStoreProvider);
  return store.watchLibrary().map(
        (entries) => entries.any((e) => e.bookId == bookId && e.favorite),
      );
});

Future<List<Book>> _resolve(
  BookRepository repo,
  List<LibraryBook> entries,
) async {
  final books = <Book>[];
  for (final e in entries) {
    final book = await repo.getBook(e.bookId);
    if (book != null) books.add(book);
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

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Book>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const [];
  return ref.watch(bookRepositoryProvider).search(query);
});

// ---------------------------------------------------------------- downloads

/// Downloaded tracks for a book (reactive).
final downloadsForBookProvider =
    StreamProvider.family<List<DownloadedTrack>, String>(
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
