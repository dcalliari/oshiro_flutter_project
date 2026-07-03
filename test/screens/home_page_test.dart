import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_oshiro/main.dart';
import 'package:project_oshiro/models/book.dart';
import 'package:project_oshiro/providers/providers.dart';

import '../support/book_fixtures.dart';

/// Overrides the three leaf providers HomePage reads, so the screen renders
/// without Isar or Firestore. Any of the library/favorites/grid state can be
/// set per test.
List<Override> _home({
  List<Book> library = const [],
  List<Book> favorites = const [],
  bool asGrid = false,
}) =>
    [
      libraryProvider.overrideWith((ref) => Stream.value(library)),
      favoritesProvider.overrideWith((ref) => Stream.value(favorites)),
      libraryAsGridProvider.overrideWith((ref) => Stream.value(asGrid)),
    ];

Future<void> _pumpHome(tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const OshiroApp()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty library shows the CTA to search', (tester) async {
    await _pumpHome(tester, _home());

    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Search books'), findsOneWidget);
  });

  testWidgets('populated library lists books as a reorderable list',
      (tester) async {
    await _pumpHome(tester, _home(library: [zest1(), moby()]));

    expect(find.text('New Zest 1 Language Learning English Basic'),
        findsOneWidget);
    expect(find.text('Moby Dick'), findsOneWidget);
    // Default (non-grid) view is the reorderable list, not a grid.
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('grid preference renders a GridView instead of the list',
      (tester) async {
    await _pumpHome(tester, _home(library: [zest1()], asGrid: true));

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ReorderableListView), findsNothing);
  });

  testWidgets('switching to the Favorites tab shows favorites', (tester) async {
    await _pumpHome(
      tester,
      _home(library: [zest1(), moby()], favorites: [moby()]),
    );

    // All tab is showing first; Moby appears once there.
    expect(find.text('Moby Dick'), findsOneWidget);

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    // Favorites tab lists only the favorited book, with the bookmark marker.
    expect(find.text('Moby Dick'), findsOneWidget);
    expect(find.text('New Zest 1 Language Learning English Basic'),
        findsNothing);
    expect(find.byIcon(Icons.bookmark), findsWidgets);
  });

  testWidgets('empty Favorites tab shows its own empty state', (tester) async {
    await _pumpHome(tester, _home(library: [zest1()]));

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(find.text('No favorites yet'), findsOneWidget);
  });

  testWidgets('search icon opens the Search screen', (tester) async {
    await _pumpHome(tester, _home(library: [zest1()]));

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // Search screen has its own title and a search input.
    expect(find.text('Search'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
