import 'package:flutter_test/flutter_test.dart';
import 'package:project_oshiro/data/local/local_store.dart';

import '../support/isar_test_support.dart';

void main() {
  late bool isarAvailable;

  setUpAll(() async {
    isarAvailable = await IsarTestSupport.ensureInitialized();
  });

  // Opens a fresh store per test; null when Isar is unavailable so the guard in
  // each test can skip with a clear reason.
  LocalStore? store;

  setUp(() async {
    store = isarAvailable ? await IsarTestSupport.openStore() : null;
  });

  tearDown(() async {
    if (store != null) await IsarTestSupport.close(store!);
    store = null;
  });

  // Non-null once the notReady() guard at the top of each test has passed.
  LocalStore requireStore() => store!;

  // Skips (with reason) and signals the test body to return early when Isar
  // could not be loaded in this environment.
  bool notReady() {
    if (!isarAvailable) {
      markTestSkipped(IsarTestSupport.skipReason);
      return true;
    }
    return false;
  }

  group('LocalStore library', () {
    test('adds books and preserves insertion order', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.addToLibrary('a');
      await s.addToLibrary('b');
      await s.addToLibrary('c');

      final lib = await s.getLibrary();
      expect(lib.map((e) => e.bookId), ['a', 'b', 'c']);
      expect(lib.map((e) => e.sortOrder), [0, 1, 2]);
    });

    test('addToLibrary is idempotent', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.addToLibrary('a');
      await s.addToLibrary('a');

      expect(await s.getLibrary(), hasLength(1));
      expect(await s.isInLibrary('a'), isTrue);
      expect(await s.isInLibrary('z'), isFalse);
    });

    test('removeFromLibrary drops only the target', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.addToLibrary('a');
      await s.addToLibrary('b');

      await s.removeFromLibrary('a');

      expect((await s.getLibrary()).map((e) => e.bookId), ['b']);
      expect(await s.isInLibrary('a'), isFalse);
    });

    test('watchLibrary fires immediately and on change', () async {
      if (notReady()) return;
      final s = requireStore();
      final first = await s.watchLibrary().first;
      expect(first, isEmpty);

      final next = s.watchLibrary().firstWhere((l) => l.isNotEmpty);
      await s.addToLibrary('a');
      expect((await next).single.bookId, 'a');
    });

    test('reorderLibrary persists the new sequence', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.addToLibrary('a');
      await s.addToLibrary('b');
      await s.addToLibrary('c');

      await s.reorderLibrary(['c', 'a', 'b']);

      expect((await s.getLibrary()).map((e) => e.bookId), ['c', 'a', 'b']);
    });
  });

  group('LocalStore favorites', () {
    test('setFavorite toggles and is readable', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.addToLibrary('a');

      expect(await s.isFavorite('a'), isFalse);
      await s.setFavorite('a', true);
      expect(await s.isFavorite('a'), isTrue);
      await s.setFavorite('a', false);
      expect(await s.isFavorite('a'), isFalse);
    });

    test('setFavorite is a no-op for a book not in the library', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.setFavorite('ghost', true);
      expect(await s.isFavorite('ghost'), isFalse);
      expect(await s.isInLibrary('ghost'), isFalse);
    });

    test('watchFavorites returns only favorited books, in order', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.addToLibrary('a');
      await s.addToLibrary('b');
      await s.addToLibrary('c');
      await s.setFavorite('a', true);
      await s.setFavorite('c', true);

      final favs = await s.watchFavorites().first;
      expect(favs.map((e) => e.bookId), ['a', 'c']);
    });
  });

  group('LocalStore downloads', () {
    test('saves and reads a scoped download path', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.saveDownload('book-a', 'unit-01-dialogue', '/tmp/a.mp3');

      expect(await s.downloadPath('book-a', 'unit-01-dialogue'), '/tmp/a.mp3');
      expect(await s.downloadPath('book-a', 'missing'), isNull);
    });

    test('same track id in two books does not collide', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.saveDownload('book-a', 'unit-01-dialogue', '/a/x.mp3');
      await s.saveDownload('book-b', 'unit-01-dialogue', '/b/x.mp3');

      expect(await s.downloadPath('book-a', 'unit-01-dialogue'), '/a/x.mp3');
      expect(await s.downloadPath('book-b', 'unit-01-dialogue'), '/b/x.mp3');
      expect(await s.downloadsForBook('book-a'), hasLength(1));
    });

    test('re-saving the same key replaces the path', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.saveDownload('book-a', 't', '/old.mp3');
      await s.saveDownload('book-a', 't', '/new.mp3');

      expect(await s.downloadPath('book-a', 't'), '/new.mp3');
      expect(await s.downloadsForBook('book-a'), hasLength(1));
    });

    test('deleteDownload removes a single track record', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.saveDownload('book-a', 't1', '/1.mp3');
      await s.saveDownload('book-a', 't2', '/2.mp3');

      await s.deleteDownload('book-a', 't1');

      expect(await s.downloadPath('book-a', 't1'), isNull);
      expect(await s.downloadPath('book-a', 't2'), '/2.mp3');
    });

    test('deleteDownloadsForBook clears just that book', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.saveDownload('book-a', 't1', '/1.mp3');
      await s.saveDownload('book-a', 't2', '/2.mp3');
      await s.saveDownload('book-b', 't1', '/b.mp3');

      await s.deleteDownloadsForBook('book-a');

      expect(await s.downloadsForBook('book-a'), isEmpty);
      expect(await s.downloadsForBook('book-b'), hasLength(1));
    });

    test('watchDownloadsForBook reacts to saves', () async {
      if (notReady()) return;
      final s = requireStore();
      final next =
          s.watchDownloadsForBook('book-a').firstWhere((l) => l.isNotEmpty);
      await s.saveDownload('book-a', 't1', '/1.mp3');
      expect((await next).single.trackId, 't1');
    });
  });

  group('LocalStore playback progress', () {
    test('saves and reads back a scoped position', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.savePlaybackProgress(
        'book-a',
        'unit-01-dialogue',
        const Duration(seconds: 30),
        const Duration(minutes: 3),
      );

      final progress = await s.playbackProgress('book-a', 'unit-01-dialogue');
      expect(progress, isNotNull);
      expect(progress!.positionMs, 30000);
      expect(progress.durationMs, 180000);
    });

    test('returns null for a track never played', () async {
      if (notReady()) return;
      final s = requireStore();
      expect(await s.playbackProgress('book-a', 'never'), isNull);
    });

    test('re-saving updates the stored position', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.savePlaybackProgress(
          'b', 't', const Duration(seconds: 5), const Duration(minutes: 1));
      await s.savePlaybackProgress(
          'b', 't', const Duration(seconds: 42), const Duration(minutes: 1));

      expect((await s.playbackProgress('b', 't'))!.positionMs, 42000);
    });
  });

  group('LocalStore preferences', () {
    test('libraryAsGrid defaults to false and toggles', () async {
      if (notReady()) return;
      final s = requireStore();
      expect(await s.libraryAsGrid(), isFalse);

      await s.setLibraryAsGrid(true);
      expect(await s.libraryAsGrid(), isTrue);
    });

    test('watchLibraryAsGrid emits the current value first', () async {
      if (notReady()) return;
      final s = requireStore();
      await s.setLibraryAsGrid(true);
      expect(await s.watchLibraryAsGrid().first, isTrue);
    });
  });
}
