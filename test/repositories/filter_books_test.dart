import 'package:flutter_test/flutter_test.dart';
import 'package:project_oshiro/repositories/book_repository.dart';

import '../support/book_fixtures.dart';

void main() {
  final books = catalog();

  group('filterBooks', () {
    test('empty / whitespace query returns nothing', () {
      expect(filterBooks(books, ''), isEmpty);
      expect(filterBooks(books, '   '), isEmpty);
    });

    test('matches by title, case-insensitively', () {
      final result = filterBooks(books, 'moby');
      expect(result.map((b) => b.id), ['moby-dick']);

      expect(filterBooks(books, 'MOBY').map((b) => b.id), ['moby-dick']);
    });

    test('matches a partial title substring', () {
      // "Language Learning" appears in both Zest books but not Moby Dick.
      final ids = filterBooks(books, 'language learning').map((b) => b.id);
      expect(ids, containsAll(['new-zest-1', 'new-zest-2']));
      expect(ids, isNot(contains('moby-dick')));
    });

    test('matches by author, case-insensitively and partially', () {
      expect(filterBooks(books, 'melville').map((b) => b.id), ['moby-dick']);

      // Author shared by both Zest books.
      final ids = filterBooks(books, 'caroline').map((b) => b.id);
      expect(ids, containsAll(['new-zest-1', 'new-zest-2']));
      expect(ids, isNot(contains('moby-dick')));

      // A non-first author still matches.
      expect(filterBooks(books, 'vilhena').map((b) => b.id), ['new-zest-2']);
    });

    test('matches ISBN ignoring dashes, both directions', () {
      // Query has dashes, stored value has dashes.
      expect(
        filterBooks(books, '978-85-92799-05-2').map((b) => b.id),
        ['new-zest-1'],
      );
      // Query without dashes still matches a dashed stored ISBN.
      expect(
        filterBooks(books, '9788592799052').map((b) => b.id),
        ['new-zest-1'],
      );
    });

    test('ISBN match is exact, not substring', () {
      // A prefix of a real ISBN must not match (ISBN uses equality, not
      // contains), and it matches no title/author either.
      expect(filterBooks(books, '9788592799').where((b) => b.isbn.isNotEmpty),
          isEmpty);
    });

    test('no match returns an empty list', () {
      expect(filterBooks(books, 'nonexistent-zzz'), isEmpty);
    });

    test('query is trimmed before matching', () {
      expect(filterBooks(books, '  moby  ').map((b) => b.id), ['moby-dick']);
    });
  });
}
