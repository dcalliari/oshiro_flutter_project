import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_handler.dart';
import '../models/book.dart';
import '../models/track.dart';
import '../providers/player_providers.dart';
import '../providers/providers.dart';
import '../widgets/book_cover.dart';
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

  Future<void> _download(Track track) async {
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

  Future<void> _downloadAll() async {
    for (final track in book.tracks) {
      final path = await ref
          .read(localStoreProvider)
          .downloadPath(book.id, track.id);
      if (path == null) await _download(track);
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsForBookProvider(book.id));
    final isFavorite =
        ref.watch(isFavoriteProvider(book.id)).valueOrNull ?? false;
    final handler = ref.watch(audioHandlerProvider).valueOrNull;
    final downloadedIds = downloads.valueOrNull
            ?.map((d) => d.trackId)
            .toSet() ??
        const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Faixas'),
        centerTitle: true,
      ),
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
                ? const Center(child: Text('Nenhuma faixa disponível.'))
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
                        onPlay: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                Player(book: book, initialIndex: index),
                          ),
                        ),
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
                        label: const Text('Baixar todos'),
                        onPressed: onDownloadAll,
                      ),
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.bookmark : Icons.bookmark_add_outlined,
                        color: Colors.red,
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
    return ListTile(
      leading: _nowPlayingIndicator(),
      title: Text(track.title),
      subtitle: progress != null
          ? LinearProgressIndicator(value: progress == 0 ? null : progress)
          : null,
      trailing: downloaded
          ? const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 20)
          : const Icon(Icons.download, color: Colors.red),
      onTap: downloaded ? onPlay : (progress == null ? onDownload : null),
    );
  }

  /// An equalizer glyph on the track currently loaded in the player, so the
  /// list reflects what is playing. Absent until playback has started.
  Widget? _nowPlayingIndicator() {
    final handler = this.handler;
    if (handler == null || handler.loadedBookId != track.bookId) return null;
    return StreamBuilder<int?>(
      stream: handler.player.currentIndexStream,
      builder: (context, snapshot) => snapshot.data == index
          ? const Icon(Icons.graphic_eq, color: Colors.red)
          : const SizedBox(width: 24),
    );
  }
}
