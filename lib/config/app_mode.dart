import 'package:flutter/foundation.dart';

const bool _useMockDefine = bool.fromEnvironment('USE_MOCK', defaultValue: false);

/// Firebase is configured for Android, iOS and Web (see [DefaultFirebaseOptions]).
/// Desktop (Linux/macOS/Windows) has no runtime Firebase support here.
bool get _firebaseSupported {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Whether the app runs against mock data instead of Firebase. Enabled either
/// explicitly (`--dart-define=USE_MOCK=true`) or automatically on platforms
/// without Firebase support (the Linux desktop demo).
bool get useMock => _useMockDefine || !_firebaseSupported;
