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
  // TrackList only reads these two families plus the (never-ready) audio
  // handler on build, so overriding them keeps the screen off Isar.
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
    await pumpScreen(tester, TrackList(book: zest1()),
        overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('Unit 01 - We Are Fans'), findsOneWidget);
    expect(find.text('Unit 01 - Questions'), findsOneWidget);
    expect(find.text('Baixar todos'), findsOneWidget);
    // Neither track is downloaded yet, so both show the download icon.
    expect(find.byIcon(Icons.download), findsWidgets);
  });

  testWidgets('a book without tracks shows the empty message', (tester) async {
    await pumpScreen(tester, TrackList(book: zest2()),
        overrides: overrides());
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma faixa disponível.'), findsOneWidget);
    // No download-all button when there is nothing to download.
    expect(find.text('Baixar todos'), findsNothing);
  });

  testWidgets('a downloaded track shows the play affordance', (tester) async {
    await pumpScreen(
      tester,
      TrackList(book: zest1()),
      overrides:
          overrides(downloads: [_downloaded('new-zest-1', 'unit-01-dialogue')]),
    );
    await tester.pumpAndSettle();

    // The downloaded track swaps its download icon for the open chevron.
    expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
  });

  testWidgets('favorite state drives the bookmark icon', (tester) async {
    await pumpScreen(tester, TrackList(book: zest1()),
        overrides: overrides(favorite: true));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}
