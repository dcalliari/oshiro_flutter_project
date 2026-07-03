import 'package:project_oshiro/models/book.dart';
import 'package:project_oshiro/models/track.dart';

/// Small, shared catalog for the search/repository/widget tests. Values mirror
/// the real Firestore shape (dashed ISBNs, multiple authors, `unit-XX` tracks).
///
/// Cover URLs are intentionally empty: in widget tests a non-empty URL makes
/// `BookCover`/`CachedNetworkImage` show a perpetual loading spinner, which
/// hangs `pumpAndSettle`. The placeholder path has no animation.
Book zest1() => Book(
      id: 'new-zest-1',
      name: 'New Zest 1 Language Learning English Basic',
      isbn: '978-85-92799-05-2',
      authors: const ['Caroline Pina', 'Sylvia Silva'],
      publisher: 'Aquarela Flexográfica',
      published: '12/2020',
      coverUrl: '',
      tracks: [
        const Track(
          bookId: 'new-zest-1',
          unit: 'unit-01',
          kind: 'dialogue',
          title: 'Unit 01 - We Are Fans',
          url: 'https://example.com/z1-u1-d.mp3',
        ),
        const Track(
          bookId: 'new-zest-1',
          unit: 'unit-01',
          kind: 'question',
          title: 'Unit 01 - Questions',
          url: 'https://example.com/z1-u1-q.mp3',
        ),
      ],
    );

Book zest2() => Book(
      id: 'new-zest-2',
      name: 'New Zest 2 Language Learning English Intermediate',
      isbn: '978-85-92799-02-1',
      authors: const ['Caroline Pina', 'Raissa de Vilhena'],
      coverUrl: '',
    );

Book moby() => Book(
      id: 'moby-dick',
      name: 'Moby Dick',
      isbn: '111-22-33333-44-5',
      authors: const ['Herman Melville'],
      coverUrl: '',
    );

List<Book> catalog() => [zest1(), zest2(), moby()];
