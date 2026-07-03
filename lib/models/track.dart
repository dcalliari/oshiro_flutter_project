import 'package:flutter/foundation.dart';

/// A single audio track belonging to a [Book].
///
/// In Firestore a track lives at
/// `units.{unit}.tracks.{kind}.track = [title, url]`, so its identity is the
/// (unit, kind) pair. [id] encodes that pair and is unique *within a book*,
/// which lets downloads be scoped per book and avoids the historical
/// "two books both have 01.mp3" collision.
@immutable
class Track {
  const Track({
    required this.bookId,
    required this.unit,
    required this.kind,
    required this.title,
    required this.url,
  });

  final String bookId;

  /// Firestore unit key, e.g. `unit-01`.
  final String unit;

  /// `dialogue` or `question`.
  final String kind;
  final String title;

  /// Remote MP3 URL.
  final String url;

  /// Stable id within a book, e.g. `unit-01-dialogue`.
  String get id => '$unit-$kind';

  /// Filename used for the on-disk copy, scoped by book via the directory.
  String get fileName => '$id.mp3';

  @override
  bool operator ==(Object other) =>
      other is Track && other.bookId == bookId && other.id == id;

  @override
  int get hashCode => Object.hash(bookId, id);
}
