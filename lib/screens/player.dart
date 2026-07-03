import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/audio_handler.dart';
import '../models/book.dart';
import '../providers/player_providers.dart';
import '../widgets/book_cover.dart';

/// Full-screen player for a book: the whole book is a queue and this screen
/// controls the currently selected track. Playback, metadata and background
/// controls come from [OshiroAudioHandler]; this widget only renders its state.
class Player extends ConsumerStatefulWidget {
  const Player({super.key, required this.book, required this.initialIndex});

  final Book book;
  final int initialIndex;

  @override
  ConsumerState<Player> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<Player> {
  @override
  void initState() {
    super.initState();
    // Build/reuse the handler and start the requested track. Errors surface
    // through the provider's AsyncError below.
    ref.read(audioHandlerProvider.future).then(
          (handler) =>
              handler.setBook(widget.book, initialIndex: widget.initialIndex),
          onError: (_) {},
        );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(audioHandlerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(icon: Icons.error_outline, text: '$e'),
        data: (handler) => _PlayerBody(book: widget.book, handler: handler),
      ),
    );
  }
}

class _PlayerBody extends StatelessWidget {
  const _PlayerBody({required this.book, required this.handler});

  final Book book;
  final OshiroAudioHandler handler;

  AudioPlayer get _player => handler.player;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const Spacer(),
            Expanded(
              flex: 6,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BookCover(url: book.coverUrl),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _TrackTitle(book: book, player: _player),
            const SizedBox(height: 16),
            _SeekBar(handler: handler),
            const SizedBox(height: 8),
            _Controls(handler: handler),
            const SizedBox(height: 12),
            _SpeedSelector(player: _player),
            const SizedBox(height: 8),
            _VolumeSlider(player: _player),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Current track title + book subtitle, following the active queue index.
class _TrackTitle extends StatelessWidget {
  const _TrackTitle({required this.book, required this.player});

  final Book book;
  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<int?>(
      stream: player.currentIndexStream,
      builder: (context, snapshot) {
        final index = snapshot.data ?? 0;
        final title = index < book.tracks.length
            ? book.tracks[index].title
            : book.name;
        return Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              book.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor),
            ),
          ],
        );
      },
    );
  }
}

/// Seek bar with elapsed/total labels. Combines the player's duration and
/// position streams; the slider is draggable and seeks on release.
class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.handler});

  final OshiroAudioHandler handler;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  AudioPlayer get _player => widget.handler.player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: _player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final maxMs = duration.inMilliseconds.toDouble();
            final positionMs =
                position.inMilliseconds.clamp(0, duration.inMilliseconds);
            final value = _dragValue ?? positionMs.toDouble();
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs <= 0 ? 1 : maxMs,
                    value: maxMs <= 0 ? 0 : value.clamp(0, maxMs),
                    onChanged: maxMs <= 0
                        ? null
                        : (v) => setState(() => _dragValue = v),
                    onChangeEnd: maxMs <= 0
                        ? null
                        : (v) {
                            widget.handler
                                .seek(Duration(milliseconds: v.round()));
                            setState(() => _dragValue = null);
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(Duration(milliseconds: value.round()))),
                      Text(_format(duration)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Previous / play-pause / next. The play button shows a spinner while the
/// player is loading or buffering.
class _Controls extends StatelessWidget {
  const _Controls({required this.handler});

  final OshiroAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    final player = handler.player;
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final processing = state?.processingState ?? ProcessingState.idle;
        final playing = state?.playing ?? false;
        final busy = processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StreamBuilder<int?>(
              stream: player.currentIndexStream,
              builder: (context, snap) => IconButton(
                iconSize: 40,
                icon: const Icon(Icons.skip_previous),
                onPressed:
                    (snap.data ?? 0) > 0 ? handler.skipToPrevious : null,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              height: 72,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  : IconButton.filled(
                      iconSize: 44,
                      icon: Icon(
                        processing == ProcessingState.completed
                            ? Icons.replay
                            : (playing ? Icons.pause : Icons.play_arrow),
                      ),
                      onPressed: () {
                        if (processing == ProcessingState.completed) {
                          handler.seek(Duration.zero);
                          handler.play();
                        } else if (playing) {
                          handler.pause();
                        } else {
                          handler.play();
                        }
                      },
                    ),
            ),
            const SizedBox(width: 8),
            StreamBuilder<int?>(
              stream: player.currentIndexStream,
              builder: (context, snap) {
                final index = snap.data ?? 0;
                final count = handler.player.sequence?.length ?? 0;
                final hasNext = index < count - 1;
                return IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.skip_next),
                  onPressed: hasNext ? handler.skipToNext : null,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Playback-speed chips: 0.5x … 2x.
class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.player});

  final AudioPlayer player;

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  static String _label(double speed) =>
      '${speed.toString().replaceAll(RegExp(r'\.0$'), '')}x';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.speedStream,
      builder: (context, snapshot) {
        final current = snapshot.data ?? 1.0;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final speed in _speeds)
              ChoiceChip(
                label: Text(_label(speed)),
                selected: (current - speed).abs() < 0.01,
                onSelected: (_) => player.setSpeed(speed),
              ),
          ],
        );
      },
    );
  }
}

/// Volume control. Useful on desktop and harmless on mobile.
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.volumeStream,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 1.0;
        return Row(
          children: [
            Icon(volume == 0 ? Icons.volume_off : Icons.volume_up, size: 20),
            Expanded(
              child: Slider(
                min: 0,
                max: 1,
                value: volume.clamp(0, 1),
                onChanged: player.setVolume,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _format(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
