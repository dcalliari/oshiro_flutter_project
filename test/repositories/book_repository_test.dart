import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_oshiro/models/book.dart';
import 'package:project_oshiro/repositories/book_repository.dart';

import '../support/book_fixtures.dart';

Future<FakeFirebaseFirestore> _seeded(List<Book> books) async {
  final fake = FakeFirebaseFirestore();
  for (final b in books) {
    await fake.collection('books').doc(b.id).set(b.toFirestore());
  }
  return fake;
}

void main() {
  group('FirestoreBookRepository', () {
    test('getBooks parses every seeded doc into the real Book shape', () async {
      final fake = await _seeded(catalog());
      final repo = FirestoreBookRepository(firestore: fake);

      final books = await repo.getBooks();

      expect(books, hasLength(3));
      final zest = books.firstWhere((b) => b.id == 'new-zest-1');
      expect(zest.name, 'New Zest 1 Language Learning English Basic');
      expect(zest.authors, ['Caroline Pina', 'Sylvia Silva']);
      expect(zest.publisher, 'Aquarela Flexográfica');
      // Nested `units` round-trips back to two ordered tracks.
      expect(zest.tracks.map((t) => t.id),
          ['unit-01-dialogue', 'unit-01-question']);
      expect(zest.tracks.first.bookId, 'new-zest-1');
    });

    test('getBook returns the matching book, null when absent', () async {
      final fake = await _seeded(catalog());
      final repo = FirestoreBookRepository(firestore: fake);

      expect((await repo.getBook('moby-dick'))?.name, 'Moby Dick');
      expect(await repo.getBook('does-not-exist'), isNull);
    });

    test('watchBooks emits the catalog and reacts to writes', () async {
      final fake = await _seeded([zest1()]);
      final repo = FirestoreBookRepository(firestore: fake);

      // First non-empty emission reflects the seed.
      final first = await repo.watchBooks().firstWhere((b) => b.isNotEmpty);
      expect(first.map((b) => b.id), ['new-zest-1']);

      // A later emission includes a newly written doc.
      final twoBooks = repo.watchBooks().firstWhere((b) => b.length == 2);
      await fake.collection('books').doc('moby-dick').set(moby().toFirestore());
      expect((await twoBooks).map((b) => b.id),
          containsAll(['new-zest-1', 'moby-dick']));
    });

    test('search delegates to filterBooks over the fetched catalog', () async {
      final fake = await _seeded(catalog());
      final repo = FirestoreBookRepository(firestore: fake);

      expect((await repo.search('melville')).map((b) => b.id), ['moby-dick']);
      expect((await repo.search('9788592799052')).map((b) => b.id),
          ['new-zest-1']);
      expect(await repo.search(''), isEmpty);
    });

    test('tolerates a doc missing every optional field', () async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('books').doc('bare').set({'name': 'Bare'});
      final repo = FirestoreBookRepository(firestore: fake);

      final book = (await repo.getBooks()).single;
      expect(book.name, 'Bare');
      expect(book.isbn, '');
      expect(book.authors, isEmpty);
      expect(book.tracks, isEmpty);
      expect(book.publisher, isNull);
    });
  });

  group('MockBookRepository', () {
    test('defaults to the bundled three-book seed with tracks', () async {
      final repo = MockBookRepository();
      final books = await repo.getBooks();

      expect(books.map((b) => b.id),
          ['new-zest-1', 'new-zest-2', 'new-zest-3']);
      expect(books.every((b) => b.hasTracks), isTrue);
    });

    test('accepts a custom seed and reads back through the API', () async {
      final repo = MockBookRepository(seed: catalog());

      expect((await repo.getBooks()), hasLength(3));
      expect((await repo.getBook('moby-dick'))?.name, 'Moby Dick');
      expect(await repo.getBook('missing'), isNull);
      expect(await repo.watchBooks().first, hasLength(3));
    });

    test('search reuses filterBooks semantics', () async {
      final repo = MockBookRepository(seed: catalog());

      expect((await repo.search('vilhena')).map((b) => b.id), ['new-zest-2']);
      expect(await repo.search(''), isEmpty);
    });

    test('exposes an unmodifiable book list', () async {
      final repo = MockBookRepository(seed: catalog());
      final books = await repo.getBooks();
      expect(() => books.add(moby()), throwsUnsupportedError);
    });
  });
}
