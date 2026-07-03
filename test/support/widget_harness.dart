import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_oshiro/audio/audio_handler.dart';
import 'package:project_oshiro/models/book.dart';
import 'package:project_oshiro/providers/player_providers.dart';
import 'package:project_oshiro/providers/providers.dart';
import 'package:project_oshiro/repositories/book_repository.dart';

/// Pumps [screen] inside a `ProviderScope` + `MaterialApp`, the minimal shell a
/// screen needs (Navigator, Directionality, theme). Screens that already build
/// their own `MaterialApp` (e.g. `OshiroApp`) should be pumped directly.
Future<void> pumpScreen(
  tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: screen),
    ),
  );
}

/// Keeps the audio handler perpetually "loading" so screens that read
/// `audioHandlerProvider.valueOrNull` see null and never boot just_audio /
/// audio_service (neither runs under `flutter test`).
Override get audioNeverReady =>
    audioHandlerProvider.overrideWith((ref) => Completer<OshiroAudioHandler>().future);

/// A fixed catalog behind the repository providers, so search and detail flows
/// resolve books without Firestore or Isar.
Override booksFrom(List<Book> books) =>
    bookRepositoryProvider.overrideWith((ref) => _StaticBookRepository(books));

class _StaticBookRepository implements BookRepository {
  _StaticBookRepository(this._books);

  final List<Book> _books;

  @override
  Stream<List<Book>> watchBooks() => Stream.value(_books);

  @override
  Future<List<Book>> getBooks() async => _books;

  @override
  Future<Book?> getBook(String id) async {
    for (final b in _books) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<List<Book>> search(String query) async => filterBooks(_books, query);
}
