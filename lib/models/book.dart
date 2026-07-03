import 'package:flutter/foundation.dart';

import 'track.dart';

/// A book (audiobook) as stored in the Firestore `books` collection.
///
/// The real schema is loose: only `name`, `isbn`, `authors`, `cover-url` are
/// always present; `publisher`, `published` and `units` may be missing. The
/// parser tolerates every optional field.
@immutable
class Book {
  const Book({
    required this.id,
    required this.name,
    required this.isbn,
    required this.authors,
    required this.coverUrl,
    this.publisher,
    this.published,
    this.tracks = const [],
  });

  final String id;
  final String name;
  final String isbn;
  final List<String> authors;
  final String coverUrl;
  final String? publisher;
  final String? published;
  final List<Track> tracks;

  bool get hasTracks => tracks.isNotEmpty;

  /// Builds a [Book] from a Firestore document id + raw data map.
  factory Book.fromFirestore(String id, Map<String, dynamic> data) {
    return Book(
      id: id,
      name: (data['name'] ?? '') as String,
      isbn: (data['isbn'] ?? '') as String,
      authors: _stringList(data['authors']),
      coverUrl: (data['cover-url'] ?? '') as String,
      publisher: data['publisher'] as String?,
      published: data['published'] as String?,
      tracks: _parseTracks(id, data['units']),
    );
  }

  /// Firestore-shaped map (nested `units`), the inverse of [fromFirestore].
  /// Used to seed `fake_cloud_firestore` and the mock repository.
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'name': name,
      'isbn': isbn,
      'authors': authors,
      'cover-url': coverUrl,
      if (publisher != null) 'publisher': publisher,
      if (published != null) 'published': published,
    };
    if (tracks.isNotEmpty) map['units'] = _tracksToUnits(tracks);
    return map;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  static List<Track> _parseTracks(String bookId, dynamic units) {
    if (units is! Map) return const [];
    final result = <Track>[];
    final unitKeys = units.keys.map((e) => e.toString()).toList()..sort();
    for (final unit in unitKeys) {
      final unitData = units[unit];
      if (unitData is! Map) continue;
      final tracks = unitData['tracks'];
      if (tracks is! Map) continue;
      // Deterministic order: dialogue before question.
      final kinds = tracks.keys.map((e) => e.toString()).toList()..sort();
      for (final kind in kinds) {
        final kindData = tracks[kind];
        if (kindData is! Map) continue;
        final track = kindData['track'];
        if (track is! List || track.length < 2) continue;
        result.add(Track(
          bookId: bookId,
          unit: unit,
          kind: kind,
          title: track[0].toString(),
          url: track[1].toString(),
        ));
      }
    }
    return result;
  }

  static Map<String, dynamic> _tracksToUnits(List<Track> tracks) {
    final units = <String, dynamic>{};
    for (final t in tracks) {
      final unit = units.putIfAbsent(
        t.unit,
        () => <String, dynamic>{'tracks': <String, dynamic>{}},
      ) as Map<String, dynamic>;
      (unit['tracks'] as Map<String, dynamic>)[t.kind] = {
        'track': [t.title, t.url],
      };
    }
    return units;
  }

  @override
  bool operator ==(Object other) => other is Book && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
