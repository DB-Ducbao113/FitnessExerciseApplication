import 'package:flutter/foundation.dart';

/// Enabled by default in debug builds so Android Emulator route playback works.
/// Override with `--dart-define=FLOWFIT_DEBUG_LOCATION=false` when needed.
/// Release builds stay strict unless explicitly overridden.
const bool kDebugLocationMode = bool.fromEnvironment(
  'FLOWFIT_DEBUG_LOCATION',
  defaultValue: kDebugMode,
);
