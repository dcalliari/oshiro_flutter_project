import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../data/local/local_store.dart';
import '../models/book.dart';
import '../models/track.dart';

/// Audio backend for the app. Wraps a single [just_audio] player as an
/// [audio_service] handler, so on-screen playback, the notification/lock-screen
/// controls and background audio all share one source of truth.
///
/// A "queue" here is the ordered track list of one book: each track plays from
/// its downloaded file when present, otherwise it streams from the remote URL
/// (or, in mock mode, from a bundled sample — see [_resolveSource]).
///
/// Playback position is persisted per track in [LocalStore]. Resume applies to
/// the track a user explicitly opens via [setBook]: it starts from the last
/// saved position. Moving on with next/previous or letting a track auto-advance
/// starts the following track from its beginning (not from its saved position),
/// which keeps sequential listening predictable.
class OshiroAudioHandler extends BaseAudioHandler with SeekHandler {
  OshiroAudioHandler(this._store) {
    _wirePlayerToService();
  }

  final LocalStore _store;
  final AudioPlayer _player = AudioPlayer();

  /// Tracks of the currently loaded book, index-aligned with the player queue.
  List<Track> _tracks = const [];
  String? _bookId;

  Timer? _saveTimer;

  /// The underlying player, so the UI can subscribe to its
  /// position/duration/state streams directly.
  AudioPlayer get player => _player;

  /// Id of the book currently loaded into the queue, if any.
  String? get loadedBookId => _bookId;

  // ------------------------------------------------------------------ queue

  /// Loads [book]'s tracks as the queue and starts playing [initialIndex],
  /// resuming that track from its last saved position. Re-selecting the book
  /// that is already loaded just moves to the requested track (from its start).
  Future<void> setBook(Book book, {int initialIndex = 0}) async {
    if (_bookId == book.id && _tracks.length == book.tracks.length) {
      if (_player.currentIndex != initialIndex) {
        await skipToQueueItem(initialIndex);
      }
      await _player.play();
      return;
    }

    _bookId = book.id;
    _tracks = book.tracks;

    final items = <MediaItem>[];
    final sources = <AudioSource>[];
    for (final track in book.tracks) {
      final item = _mediaItemFor(track, book);
      items.add(item);
      sources.add(await _resolveSource(track, item));
    }
    queue.add(items);

    final resumeFrom =
        await _savedPosition(book.id, book.tracks[initialIndex].id);
    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: initialIndex,
      initialPosition: resumeFrom,
    );
    _startSaveTimer();
    await _player.play();
  }

  Future<AudioSource> _resolveSource(Track track, MediaItem item) async {
    final path = await _store.downloadPath(track.bookId, track.id);
    if (path != null && File(path).existsSync()) {
      return AudioSource.file(path, tag: item);
    }
    if (track.url.startsWith('mock://')) {
      // Mock mode has no reachable URL; play the bundled demo sample so the
      // player is audible without a backend (see MockStorageRepository).
      return AudioSource.asset('assets/audio/mock_sample.mp3', tag: item);
    }
    return AudioSource.uri(Uri.parse(track.url), tag: item);
  }

  MediaItem _mediaItemFor(Track track, Book book) => MediaItem(
        id: track.id,
        album: book.name,
        title: track.title,
        artist: book.authors.isEmpty ? null : book.authors.join(', '),
        artUri: book.coverUrl.isEmpty ? null : Uri.tryParse(book.coverUrl),
      );

  /// The last saved position for a track, or null to start from the beginning.
  /// A position within the final few seconds is treated as finished.
  Future<Duration?> _savedPosition(String bookId, String trackId) async {
    final progress = await _store.playbackProgress(bookId, trackId);
    if (progress == null) return null;
    final position = Duration(milliseconds: progress.positionMs);
    final duration = Duration(milliseconds: progress.durationMs);
    if (duration > Duration.zero &&
        duration - position < const Duration(seconds: 5)) {
      return Duration.zero;
    }
    return position;
  }

  // ------------------------------------------------- audio_service controls

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() async {
    await _player.pause();
    await _saveProgress();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() async {
    await _saveProgress();
    _saveTimer?.cancel();
    await _player.stop();
    await super.stop();
  }

  Future<void> dispose() async {
    await _saveProgress();
    _saveTimer?.cancel();
    await _player.dispose();
  }

  // ------------------------------------------------------- progress saving

  void _startSaveTimer() {
    _saveTimer?.cancel();
    _saveTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
  }

  Future<void> _saveProgress() async {
    final index = _player.currentIndex;
    if (_bookId == null || index == null || index >= _tracks.length) return;
    final position = _player.position;
    if (position <= Duration.zero) return;
    await _store.savePlaybackProgress(
      _bookId!,
      _tracks[index].id,
      position,
      _player.duration ?? Duration.zero,
    );
  }

  // ---------------------------------------------- player <-> service wiring

  void _wirePlayerToService() {
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace _) => _broadcastError(e),
    );
    _player.currentIndexStream.listen((index) {
      final items = queue.value;
      if (index != null && index < items.length) mediaItem.add(items[index]);
    });
    // Persist the position when a track finishes so it isn't left mid-way.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _saveProgress();
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  void _broadcastError(Object error) {
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.error,
      errorMessage: error.toString(),
    ));
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}
