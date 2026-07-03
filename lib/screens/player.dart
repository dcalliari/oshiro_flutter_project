import 'package:flutter/material.dart';

import '../models/track.dart';

/// Placeholder player. The real just_audio + audio_service implementation
/// (playlist, resume, background) lands in Phase 3; this only confirms the
/// track and its downloaded path are wired through correctly.
class Player extends StatelessWidget {
  const Player({super.key, required this.track, required this.path});

  final Track track;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(track.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.audiotrack, size: 96, color: Colors.red),
            const SizedBox(height: 16),
            Text(track.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              path,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            const Text('Reprodução chega na Fase 3.'),
          ],
        ),
      ),
    );
  }
}
