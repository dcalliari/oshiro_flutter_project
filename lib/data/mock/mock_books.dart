import '../../models/book.dart';
import '../../models/track.dart';

/// Rich offline seed: the three real books (metadata copied from the live
/// Firestore dump) plus synthetic tracks so mock mode has something to browse,
/// download and (later) play. In production only `new-zest-1` ships tracks;
/// here every book gets a couple of units so the flows are demoable offline.
List<Book> mockBooks() => [
      Book(
        id: 'new-zest-1',
        name: 'New Zest 1 Language Learning English Basic',
        isbn: '978-85-92799-05-2',
        authors: const [
          'Caroline Pina',
          'Sylvia Silva',
          'Raissa de Vilhena',
          'Rafaela da Silva',
          'Ricardo Pina',
        ],
        publisher: 'Aquarela Flexográfica',
        published: '12/2020',
        coverUrl:
            'https://firebasestorage.googleapis.com/v0/b/project-oshiro-ff1d0.appspot.com/o/books%2Fnew-zest-1%2Fcover-zest-1.jpg?alt=media&token=0b039501-6917-4830-9a63-f99ffab8cf75',
        tracks: _fakeTracks('new-zest-1', const [
          'We Are Fans [p. 008]',
          'At School [p. 016]',
          'My Family [p. 024]',
        ]),
      ),
      Book(
        id: 'new-zest-2',
        name: 'New Zest 2 Language Learning English Intermediate',
        isbn: '978-85-92799-02-1',
        authors: const ['Caroline Pina', 'Sylvia Silva', 'Raissa de Vilhena'],
        publisher: 'Gráfica Santa Cruz',
        published: '12/2020',
        coverUrl:
            'https://firebasestorage.googleapis.com/v0/b/project-oshiro-ff1d0.appspot.com/o/books%2Fnew-zest-2%2Fcover-zest-2.jpg?alt=media&token=a1ece8fa-25ed-4684-a0e9-fe62bae9cfc4',
        tracks: _fakeTracks('new-zest-2', const [
          'Making Plans [p. 010]',
          'Around Town [p. 020]',
        ]),
      ),
      Book(
        id: 'new-zest-3',
        name: 'New Zest 3 Language Learning English Advanced',
        isbn: '978-85-92799-02-1',
        authors: const ['Caroline Pina', 'Sylvia Silva'],
        publisher: 'Aquarela Flexográfica',
        published: '12/2020',
        coverUrl:
            'https://firebasestorage.googleapis.com/v0/b/project-oshiro-ff1d0.appspot.com/o/books%2Fnew-zest-3%2Fcover-zest-3.jpg?alt=media&token=b07f6885-36dd-4b9b-a9d1-3491a9374e5d',
        tracks: _fakeTracks('new-zest-3', const [
          'Debating Ideas [p. 012]',
          'The News [p. 028]',
        ]),
      ),
    ];

/// One dialogue + one question track per unit title. Mock URLs are never hit
/// over the network — [MockStorageRepository] writes a local placeholder file
/// instead.
List<Track> _fakeTracks(String bookId, List<String> titles) {
  final tracks = <Track>[];
  for (var i = 0; i < titles.length; i++) {
    final unit = 'unit-${(i + 1).toString().padLeft(2, '0')}';
    for (final kind in const ['dialogue', 'question']) {
      final label = kind == 'dialogue' ? 'Dialogue' : 'Question';
      tracks.add(Track(
        bookId: bookId,
        unit: unit,
        kind: kind,
        title: 'Unit ${(i + 1).toString().padLeft(2, '0')} - '
            '${titles[i]} ($label)',
        url: 'mock://$bookId/$unit-$kind.mp3',
      ));
    }
  }
  return tracks;
}
