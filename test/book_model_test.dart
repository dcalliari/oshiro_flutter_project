import 'package:flutter_test/flutter_test.dart';
import 'package:project_oshiro/models/book.dart';

void main() {
  group('Book.fromFirestore', () {
    test('parses the real new-zest-1 shape (nested units)', () {
      final data = {
        'name': 'New Zest 1',
        'isbn': '978-85-92799-05-2',
        'authors': ['Caroline Pina', 'Sylvia Silva'],
        'cover-url': 'https://example.com/cover.jpg',
        'publisher': 'Aquarela',
        'published': '12/2020',
        'units': {
          'unit-01': {
            'tracks': {
              'dialogue': {
                'track': ['Unit 01 - We Are Fans', 'https://example.com/a.mp3'],
              },
              // Empty question map, as in production — must be tolerated.
              'question': <String, dynamic>{},
            },
          },
        },
      };

      final book = Book.fromFirestore('new-zest-1', data);

      expect(book.id, 'new-zest-1');
      expect(book.authors, hasLength(2));
      expect(book.tracks, hasLength(1));
      final track = book.tracks.single;
      expect(track.id, 'unit-01-dialogue');
      expect(track.bookId, 'new-zest-1');
      expect(track.title, 'Unit 01 - We Are Fans');
      expect(track.url, 'https://example.com/a.mp3');
    });

    test('tolerates books without a units field', () {
      final book = Book.fromFirestore('new-zest-2', {
        'name': 'New Zest 2',
        'isbn': '978-85-92799-02-1',
        'authors': ['Caroline Pina'],
        'cover-url': 'https://example.com/c2.jpg',
      });

      expect(book.tracks, isEmpty);
      expect(book.publisher, isNull);
      expect(book.hasTracks, isFalse);
    });

    test('round-trips through toFirestore', () {
      final data = {
        'name': 'Round Trip',
        'isbn': '123',
        'authors': ['A'],
        'cover-url': 'u',
        'units': {
          'unit-01': {
            'tracks': {
              'dialogue': {
                'track': ['T', 'url'],
              },
            },
          },
        },
      };

      final again =
          Book.fromFirestore('x', Book.fromFirestore('x', data).toFirestore());
      expect(again.tracks.single.title, 'T');
      expect(again.tracks.single.url, 'url');
    });
  });
}
