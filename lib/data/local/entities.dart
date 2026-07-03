import 'package:isar_community/isar.dart';

part 'entities.g.dart';

/// A book the user added to their library. Metadata is not duplicated here;
/// it is resolved from the [BookRepository] by [bookId]. This collection owns
/// only user state: order and favorite flag.
@collection
class LibraryBook {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String bookId;

  /// Position in the library list; lower comes first.
  late int sortOrder;

  bool favorite = false;

  DateTime addedAt = DateTime.now();
}

/// A track whose MP3 has been downloaded to disk. Scoped by book so two books
/// can each have a `dialogue`/`question` track without colliding.
@collection
class DownloadedTrack {
  Id id = Isar.autoIncrement;

  /// `$bookId::$trackId` — unique per (book, track).
  @Index(unique: true, replace: true)
  late String key;

  @Index()
  late String bookId;

  late String trackId;

  /// Absolute path of the downloaded file.
  late String path;
}

/// Last known playback position for a track (used to resume in Phase 3).
@collection
class TrackProgress {
  Id id = Isar.autoIncrement;

  /// `$bookId::$trackId`.
  @Index(unique: true, replace: true)
  late String trackKey;

  int positionMs = 0;
  int durationMs = 0;
  DateTime updatedAt = DateTime.now();
}

/// Single-row app preferences (id is fixed at 0).
@collection
class Preferences {
  Id id = 0;

  /// Library shown as grid (true) or list (false).
  bool libraryAsGrid = false;
}
