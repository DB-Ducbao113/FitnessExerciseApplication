import 'package:flutter/foundation.dart';

/// Enables relaxed location filtering in debug.
const bool kDebugLocationMode = bool.fromEnvironment(
  'FLOWFIT_DEBUG_LOCATION',
  defaultValue: kDebugMode,
);

/// Bypasses smoothing for mock playback.
const bool kDebugMockPlaybackMode = bool.fromEnvironment(
  'FLOWFIT_DEBUG_MOCK_PLAYBACK',
  defaultValue: false,
);
