import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

final stepTrackingServiceProvider = Provider((ref) => StepTrackingService());

// ─── Step throttle ────────────────────────────────────────────────────────────

/// Emit at most once per this interval to avoid per-step state rebuilds.
const Duration _kStepThrottle = Duration(milliseconds: 500);

// ─── Service ──────────────────────────────────────────────────────────────────

class StepTrackingService {
  StreamSubscription<StepCount>? _stepSub;
  final _stepController = StreamController<int>.broadcast();

  int _initialSteps = -1;
  bool _isRunning = false;

  // Throttle: track last emit time
  DateTime? _lastEmit;

  Stream<int> get stepStream => _stepController.stream;
  bool get isRunning => _isRunning;

  /// Requests ACTIVITY_RECOGNITION permission on Android 10+.
  /// Returns true if granted (or not required on this OS version).
  Future<bool> requestActivityPermission() async {
    debugPrint('[Steps] requesting ACTIVITY_RECOGNITION permission…');
    final status = await Permission.activityRecognition.request();
    debugPrint('[Steps] ACTIVITY_RECOGNITION status: $status');
    return status.isGranted || status.isLimited;
  }

  /// Starts the pedometer subscription.
  /// Returns immediately (non-blocking) after setting up the subscription.
  /// Emits the cumulative session step count (relative to session start).
  Future<void> startTracking() async {
    debugPrint('[Steps] startTracking called at ${DateTime.now()}');
    _isRunning = true;
    _initialSteps = -1;
    _lastEmit = null;

    // Check permission first (Android 10+)
    final hasPermission = await requestActivityPermission();
    if (!hasPermission) {
      debugPrint(
        '[Steps] ACTIVITY_RECOGNITION denied — step tracking disabled',
      );
      // Don't crash the app: just don't subscribe pedometer
      // The notifier will still function, steps just stay at 0
      _isRunning = false;
      return;
    }

    debugPrint('[Steps] subscribing to Pedometer.stepCountStream…');

    _stepSub?.cancel();
    _stepSub = Pedometer.stepCountStream.listen(
      (StepCount event) {
        debugPrint(
          '[Steps] first/event: steps=${event.steps} t=${event.timeStamp}',
        );

        // Set baseline on first event
        if (_initialSteps == -1) {
          _initialSteps = event.steps;
          debugPrint('[Steps] baseline set to $_initialSteps');
        }

        final sessionSteps = event.steps - _initialSteps;

        // Throttle: only emit if _kStepThrottle has passed
        final now = DateTime.now();
        if (_lastEmit != null && now.difference(_lastEmit!) < _kStepThrottle) {
          return;
        }
        _lastEmit = now;

        if (!_stepController.isClosed) {
          _stepController.add(sessionSteps);
        }
      },
      onError: (error) {
        debugPrint('[Steps] pedometer error: $error');
        // Don't propagate the error to the stream — let the app keep running
        // steps just won't update
      },
      cancelOnError: false, // keep subscription alive after errors
    );

    debugPrint('[Steps] subscription active');
  }

  void stopTracking() {
    debugPrint('[Steps] stopTracking');
    _isRunning = false;
    _stepSub?.cancel();
    _stepSub = null;
    _initialSteps = -1;
  }
}
