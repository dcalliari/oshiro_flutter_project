import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/audio_handler.dart';
import '../providers/player_providers.dart';
import '../providers/providers.dart';
import '../screens/player.dart';
import 'book_cover.dart';

/// Persistent playback bar shown above the bottom of a screen while a book is
/// loaded in the audio handler. Self-contained (no required parameters) so it
/// can drop into any Scaffold's `bottomNavigationBar`; it renders nothing until
/// there is something playing, and tapping it opens the full [Player].
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `valueOrNull` avoids booting the handler's loading/error UI here: until a
    // track is opened the provider is loading and this collapses to nothing.
    final handler = ref.watch(audioHandlerProvider).valueOrNull;
    if (handler == null) return const SizedBox.shrink();

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();
        return _Bar(handler: handler, item: item);
      },
    );
  }
}

class _Bar extends ConsumerWidget {
  const _Bar({required this.handler, required this.item});

  final OshiroAudioHandler handler;
  final MediaItem item;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final bookId = handler.loadedBookId;
    if (bookId == null) return;
    final book = await ref.read(bookProvider(bookId).future);
    if (book == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Player(
          book: book,
          initialIndex: handler.player.currentIndex ?? 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverUrl = item.artUri?.toString() ?? '';

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => _open(context, ref),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProgressLine(player: handler.player),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: BookCover(url: coverUrl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (item.album != null)
                            Text(
                              item.album!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _PlayPauseButton(handler: handler),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin playback progress line spanning the top of the bar.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final value = duration.inMilliseconds <= 0
                ? 0.0
                : (position.inMilliseconds / duration.inMilliseconds)
                    .clamp(0.0, 1.0);
            return LinearProgressIndicator(
              value: value,
              minHeight: 2,
              backgroundColor: Colors.transparent,
            );
          },
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.handler});

  final OshiroAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: handler.player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final processing = state?.processingState ?? ProcessingState.idle;
        final playing = state?.playing ?? false;
        final busy = processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;

        if (busy) {
          return const SizedBox(
            width: 48,
            height: 48,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final completed = processing == ProcessingState.completed;
        return IconButton(
          iconSize: 32,
          tooltip: playing ? 'Pause' : 'Play',
          icon: Icon(
            completed
                ? Icons.replay
                : (playing ? Icons.pause : Icons.play_arrow),
          ),
          onPressed: () {
            if (completed) {
              handler.seek(Duration.zero);
              handler.play();
            } else if (playing) {
              handler.pause();
            } else {
              handler.play();
            }
          },
        );
      },
    );
  }
}
