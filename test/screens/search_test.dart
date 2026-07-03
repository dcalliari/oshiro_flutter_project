import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_oshiro/providers/providers.dart';
import 'package:project_oshiro/screens/search.dart';

import '../support/book_fixtures.dart';
import '../support/widget_harness.dart';

void main() {
  // The catalog is served from the harness repository; `isInLibrary` is forced
  // false so result tiles render the "add" affordance without touching Isar.
  List<Override> overrides() => [
        booksFrom(catalog()),
        isInLibraryProvider.overrideWith((ref, id) => Stream.value(false)),
      ];

  testWidgets('empty query shows the intro empty state', (tester) async {
    await pumpScreen(tester, const Search(), overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('Find your next audiobook'), findsOneWidget);
  });

  testWidgets('typing a matching query lists results', (tester) async {
    await pumpScreen(tester, const Search(), overrides: overrides());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'moby');
    await tester.pumpAndSettle();

    expect(find.text('Moby Dick'), findsOneWidget);
    expect(find.text('New Zest 1 Language Learning English Basic'),
        findsNothing);
  });

  testWidgets('an author query matches too', (tester) async {
    await pumpScreen(tester, const Search(), overrides: overrides());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'caroline');
    await tester.pumpAndSettle();

    expect(find.text('New Zest 1 Language Learning English Basic'),
        findsOneWidget);
    expect(find.text('New Zest 2 Language Learning English Intermediate'),
        findsOneWidget);
    expect(find.text('Moby Dick'), findsNothing);
  });

  testWidgets('a non-matching query shows the no-results state',
      (tester) async {
    await pumpScreen(tester, const Search(), overrides: overrides());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz-nothing');
    await tester.pumpAndSettle();

    expect(find.text('No results'), findsOneWidget);
    // The subtitle echoes the query. (The TextField also holds it, so match the
    // full message rather than a bare substring.)
    expect(find.text('Nothing matched "zzz-nothing".'), findsOneWidget);
  });
}
