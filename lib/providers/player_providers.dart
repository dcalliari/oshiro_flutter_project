import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import '../audio/audio_handler.dart';
import 'providers.dart';

/// Whether audio_service (system notification / lock-screen integration) is
/// available on the current platform. Desktop (Linux/Windows) is not covered by
/// audio_service, so there we run the bare [OshiroAudioHandler]: playback still
/// works, only the OS media controls are absent.
bool get _audioServiceSupported {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

/// The single [OshiroAudioHandler], built lazily on first playback. Keeping it
/// lazy leaves `main()` free of audio initialization; the handler (and, where
/// supported, the audio_service isolate) is created only when a track is opened
/// and then cached for the rest of the app's life.
final audioHandlerProvider = FutureProvider<OshiroAudioHandler>((ref) async {
  // just_audio's desktop backend. The call self-guards to Linux/Windows, so it
  // is a no-op on mobile/web where the native backend is used instead.
  JustAudioMediaKit.ensureInitialized();

  final handler = OshiroAudioHandler(ref.watch(localStoreProvider));

  if (_audioServiceSupported) {
    await AudioService.init(
      builder: () => handler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'dev.calliari.oshiro.audio',
        androidNotificationChannelName: 'Oshiro playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  ref.onDispose(handler.dispose);
  return handler;
});
