import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_oshiro/data/local/local_store.dart';
import 'package:project_oshiro/providers/providers.dart';
import 'package:project_oshiro/screens/book_selected.dart';

import '../support/book_fixtures.dart';
import '../support/widget_harness.dart';

/// In-memory stand-in for [LocalStore] that records library additions. Using a
/// fake (instead of a real Isar) keeps the widget test off native async, which
/// the fake-async zone of `testWidgets` cannot drive. Only `addToLibrary` is
/// exercised here; every other member routes through `noSuchMethod` and is
/// never called because the screens' other reads are overridden below.
class _RecordingStore implements LocalStore {
  final List<String> added = [];

  @override
  Future<void> addToLibrary(String bookId) async => added.add(bookId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  late _RecordingStore fakeStore;

  setUp(() => fakeStore = _RecordingStore());

  // TrackList (pushed after "Add") reads these; overriding them keeps it off
  // the fake store's unimplemented members.
  List<Override> overrides() => [
        localStoreProvider.overrideWithValue(fakeStore),
        booksFrom(catalog()),
        downloadsForBookProvider
            .overrideWith((ref, bookId) => Stream.value(const [])),
        isFavoriteProvider.overrideWith((ref, bookId) => Stream.value(false)),
        audioNeverReady,
      ];

  testWidgets('renders book metadata and an add action', (tester) async {
    await pumpScreen(tester, BookSelected(book: zest1()),
        overrides: overrides());
    await tester.pumpAndSettle();

    // Appears twice now: once in the AppBar title, once in the body heading.
    expect(find.text('New Zest 1 Language Learning English Basic'),
        findsWidgets);
    expect(find.textContaining('Caroline Pina'), findsOneWidget);
    expect(find.text('978-85-92799-05-2'), findsOneWidget);
    expect(find.text('Add to library'), findsOneWidget);
  });

  testWidgets('Add to library records the book and opens its track list',
      (tester) async {
    await pumpScreen(tester, BookSelected(book: zest1()),
        overrides: overrides());
    await tester.pumpAndSettle();

    expect(fakeStore.added, isEmpty);

    await tester.tap(find.text('Add to library'));
    await tester.pumpAndSettle();

    // The book was added and the track list replaced the detail screen.
    expect(fakeStore.added, ['new-zest-1']);
    expect(find.text('Tracks'), findsOneWidget);
  });
}
