import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_oshiro/main.dart';
import 'package:project_oshiro/models/book.dart';
import 'package:project_oshiro/providers/providers.dart';

void main() {
  testWidgets('Home renders the library with a seeded book', (tester) async {
    const book = Book(
      id: 'new-zest-1',
      name: 'New Zest 1 Language Learning English Basic',
      isbn: '978-85-92799-05-2',
      authors: ['Caroline Pina'],
      coverUrl: '',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override the library streams so the widget tree never touches Isar.
          libraryProvider.overrideWith((ref) => Stream.value(const [book])),
          favoritesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const OshiroApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('New Zest 1 Language Learning English Basic'),
        findsOneWidget);
  });
}
