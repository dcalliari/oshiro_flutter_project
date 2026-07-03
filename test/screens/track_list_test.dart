import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_oshiro/data/local/entities.dart';
import 'package:project_oshiro/providers/providers.dart';
import 'package:project_oshiro/screens/track_list.dart';

import '../support/book_fixtures.dart';
import '../support/widget_harness.dart';

DownloadedTrack _downloaded(String bookId, String trackId) => DownloadedTrack()
  ..key = '$bookId::$trackId'
  ..bookId = bookId
  ..trackId = trackId
  ..path = '/tmp/$trackId.mp3';

void main() {
  // TrackList (and its MiniPlayer footer) only read these two families plus the
  // (never-ready) audio handler on build, so overriding them keeps the screen
  // off Isar.
  List<Override> overrides({
    List<DownloadedTrack> downloads = const [],
    bool favorite = false,
  }) =>
      [
        downloadsForBookProvider
            .overrideWith((ref, bookId) => Stream.value(downloads)),
        isFavoriteProvider.overrideWith((ref, bookId) => Stream.value(favorite)),
        audioNeverReady,
      ];

  testWidgets('lists the book tracks with a download-all action',
      (tester) async {
    await pumpScreen(tester, TrackList(book: zest1()), overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('Unit 01 - We Are Fans'), findsOneWidget);
    expect(find.text('Unit 01 - Questions'), findsOneWidget);
    expect(find.text('Download all'), findsOneWidget);
    // Nothing downloaded yet: both tracks expose an explicit download action
    // and read as streaming.
    expect(find.byIcon(Icons.download_outlined), findsNWidgets(2));
    expect(find.text('Streaming'), findsNWidgets(2));
  });

  testWidgets('a book without tracks shows the empty message', (tester) async {
    await pumpScreen(tester, TrackList(book: zest2()), overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('No tracks available.'), findsOneWidget);
    // No download-all button when there is nothing to download.
    expect(find.text('Download all'), findsNothing);
  });

  testWidgets('a downloaded track shows the offline indicator', (tester) async {
    await pumpScreen(
      tester,
      TrackList(book: zest1()),
      overrides:
          overrides(downloads: [_downloaded('new-zest-1', 'unit-01-dialogue')]),
    );
    await tester.pumpAndSettle();

    // The downloaded track reads as available offline and drops its download
    // action; the other track still streams.
    expect(find.byIcon(Icons.offline_pin), findsOneWidget);
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
  });

  testWidgets('favorite state drives the bookmark icon', (tester) async {
    await pumpScreen(tester, TrackList(book: zest1()),
        overrides: overrides(favorite: true));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}
