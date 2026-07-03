import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_handler.dart';
import '../models/book.dart';
import '../models/track.dart';
import '../providers/player_providers.dart';
import '../providers/providers.dart';
import '../widgets/book_cover.dart';
import '../widgets/mini_player.dart';
import 'player.dart';

class TrackList extends ConsumerStatefulWidget {
  const TrackList({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<TrackList> createState() => _TrackListState();
}

class _TrackListState extends ConsumerState<TrackList> {
  /// Live download progress by track id (absent when not downloading).
  final Map<String, double> _progress = {};

  Book get book => widget.book;

  /// Runs a download and streams its progress into [_progress]. Throws on
  /// failure so callers can decide how to report it.
  Future<void> _runDownload(Track track) async {
    setState(() => _progress[track.id] = 0);
    try {
      await ref.read(downloadControllerProvider).download(
            track,
            onProgress: (p) {
              if (mounted) setState(() => _progress[track.id] = p);
            },
          );
    } finally {
      if (mounted) setState(() => _progress.remove(track.id));
    }
  }

  /// User-initiated single download: reports failure with a retryable snackbar.
  Future<void> _download(Track track) async {
    try {
      await _runDownload(track);
    } catch (_) {
      if (mounted) {
        _showSnack(
          'Couldn\'t download "${track.title}".',
          onRetry: () => _download(track),
        );
      }
    }
  }

  Future<void> _downloadAll() async {
    var failures = 0;
    for (final track in book.tracks) {
      if (_progress.containsKey(track.id)) continue;
      final path =
          await ref.read(localStoreProvider).downloadPath(book.id, track.id);
      if (path != null) continue;
      try {
        await _runDownload(track);
      } catch (_) {
        failures++;
      }
    }
    if (!mounted) return;
    _showSnack(
      failures == 0
          ? 'All tracks downloaded.'
          : "$failures track(s) couldn't be downloaded.",
    );
  }

  void _showSnack(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: onRetry == null
            ? null
            : SnackBarAction(label: 'Retry', onPressed: onRetry),
      ),
    );
  }

  void _openPlayer(int index) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Player(book: book, initialIndex: index),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsForBookProvider(book.id));
    final isFavorite =
        ref.watch(isFavoriteProvider(book.id)).valueOrNull ?? false;
    final handler = ref.watch(audioHandlerProvider).valueOrNull;
    final downloadedIds =
        downloads.valueOrNull?.map((d) => d.trackId).toSet() ??
            const <String>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Tracks'), centerTitle: true),
      bottomNavigationBar: const MiniPlayer(),
      body: Column(
        children: [
          _Header(
            book: book,
            isFavorite: isFavorite,
            onToggleFavorite: () => ref
                .read(libraryControllerProvider)
                .setFavorite(book.id, !isFavorite),
            onDownloadAll: book.hasTracks ? _downloadAll : null,
          ),
          const Divider(height: 1),
          Expanded(
            child: book.tracks.isEmpty
                ? const Center(child: Text('No tracks available.'))
                : ListView.builder(
                    itemCount: book.tracks.length,
                    itemBuilder: (context, index) {
                      final track = book.tracks[index];
                      return _TrackTile(
                        track: track,
                        index: index,
                        handler: handler,
                        downloaded: downloadedIds.contains(track.id),
                        progress: _progress[track.id],
                        onDownload: () => _download(track),
                        onPlay: () => _openPlayer(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.book,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onDownloadAll,
  });

  final Book book;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onDownloadAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, height: 120, child: BookCover(url: book.coverUrl)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.name, maxLines: 4, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onDownloadAll != null)
                      TextButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Download all'),
                        onPressed: onDownloadAll,
                      ),
                    IconButton(
                      icon: Icon(
                        isFavorite
                            ? Icons.bookmark
                            : Icons.bookmark_add_outlined,
                        color: scheme.primary,
                      ),
                      onPressed: onToggleFavorite,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A track row. Tapping anywhere plays the track (the handler resolves the
/// source: downloaded file, then mock sample, then streaming URL). Downloading
/// is an explicit trailing action; the leading icon shows offline availability
/// or, when this track is the one playing, an equalizer glyph.
class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.index,
    required this.handler,
    required this.downloaded,
    required this.progress,
    required this.onDownload,
    required this.onPlay,
  });

  final Track track;
  final int index;
  final OshiroAudioHandler? handler;
  final bool downloaded;
  final double? progress;
  final VoidCallback onDownload;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _leading(scheme),
      title: Text(track.title),
      subtitle: Text(
        downloaded ? 'Downloaded' : 'Streaming',
        style: TextStyle(color: scheme.outline, fontSize: 12),
      ),
      trailing: _trailing(scheme),
      onTap: onPlay,
    );
  }

  Widget _leading(ColorScheme scheme) {
    final handler = this.handler;
    if (handler != null && handler.loadedBookId == track.bookId) {
      return StreamBuilder<int?>(
        stream: handler.player.currentIndexStream,
        builder: (context, snapshot) => snapshot.data == index
            ? Icon(Icons.graphic_eq, color: scheme.primary)
            : _availabilityIcon(scheme),
      );
    }
    return _availabilityIcon(scheme);
  }

  Widget _availabilityIcon(ColorScheme scheme) => Icon(
        downloaded ? Icons.offline_pin : Icons.cloud_outlined,
        color: downloaded ? scheme.primary : scheme.outline,
      );

  Widget? _trailing(ColorScheme scheme) {
    if (progress != null) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: progress == 0 ? null : progress,
        ),
      );
    }
    if (downloaded) return null;
    return IconButton(
      icon: const Icon(Icons.download_outlined),
      color: scheme.primary,
      tooltip: 'Download',
      onPressed: onDownload,
    );
  }
}
