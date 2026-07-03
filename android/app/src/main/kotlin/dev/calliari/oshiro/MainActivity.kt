package dev.calliari.oshiro

import com.ryanheise.audioservice.AudioServiceActivity

// Extends AudioServiceActivity (instead of FlutterActivity) so audio_service
// can route media-button intents and reuse this single activity.
class MainActivity: AudioServiceActivity() {
}
