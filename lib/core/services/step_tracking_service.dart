import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

final stepTrackingServiceProvider = Provider((ref) => StepTrackingService());

// Constants

/// Max valid step rate.
const double _kMaxStepsPerSec = 4.5;

/// Emit throttle.
const Duration _kEmitThrottle = Duration(milliseconds: 500);

// Service

/// Session-based pedometer wrapper.
class StepTrackingService {
  // Stream state
  StreamSubscription<StepCount>? _pedometerSub;
  final _outController = StreamController<int>.broadcast();

  Stream<int> get stepStream => _outController.stream;

  // Session state
  bool _isTracking = false;

  /// First raw step count in the session.
  int _baselineSteps = -1;

  /// Last valid session step count.
  int _lastSessionSteps = 0;

  // Spike filter
  DateTime? _lastEventTime;
  int _lastRawSteps = -1;
  DateTime? _lastEmit;

  // Permission

  Future<bool> _requestActivityPermission() async {
    final permission = Platform.isIOS
        ? Permission.sensors
        : Permission.activityRecognition;
    debugPrint('[Steps] requesting $permission...');
    final status = await permission.request();
    debugPrint('[Steps] $permission: $status');
    return status.isGranted || status.isLimited;
  }

  // Public API

  /// Starts a new pedometer session.
  Future<void> startTracking() async {
    // Ignore duplicate starts.
    if (_isTracking) {
      debugPrint('[Steps] startTracking ignored — already tracking');
      return;
    }
    _isTracking = true;

    // Reset session state.
    _baselineSteps = -1;
    _lastSessionSteps = 0;
    _lastEventTime = null;
    _lastRawSteps = -1;
    _lastEmit = null;

    debugPrint('[Steps] startTracking at ${DateTime.now()}');

    final hasPermission = await _requestActivityPermission();
    if (!hasPermission) {
      debugPrint('[Steps] permission denied — steps will remain 0');
      _isTracking = false;
      return;
    }

    // Cancel old subscription.
    await _pedometerSub?.cancel();
    _pedometerSub = null;

    debugPrint('[Steps] subscribing to Pedometer.stepCountStream…');

    _pedometerSub = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (e) => debugPrint('[Steps] stream error: $e'),
      cancelOnError: false,
    );

    debugPrint('[Steps] subscription active');
  }

  void stopTracking() {
    debugPrint('[Steps] stopTracking (baseline was $_baselineSteps)');
    _isTracking = false;
    _pedometerSub?.cancel();
    _pedometerSub = null;
    _baselineSteps = -1;
    _lastSessionSteps = 0;
    _lastEventTime = null;
    _lastRawSteps = -1;
    _lastEmit = null;
  }

  // Events

  void _onStepCount(StepCount event) {
    if (!_isTracking) return;

    final rawSteps = event.steps;
    final now = DateTime.now();

    // Capture baseline on the first sample.
    if (_baselineSteps == -1) {
      _baselineSteps = rawSteps;
      _lastRawSteps = rawSteps;
      _lastEventTime = now;
      debugPrint('[Steps] baseline=$_baselineSteps at $now');
      _emit(0, now);
      return;
    }

    // Compute delta for spike filtering.
    final rawDelta = rawSteps - _lastRawSteps;

    if (rawDelta < 0) {
      // Handle counter reset.
      debugPrint(
        '[Steps] counter reset detected (rawDelta=$rawDelta), adjusting baseline',
      );
      _baselineSteps = rawSteps - _lastSessionSteps;
      _lastRawSteps = rawSteps;
      _lastEventTime = now;
      return;
    }

    if (rawDelta == 0) return;

    // Drop unrealistic spikes.
    if (_lastEventTime != null) {
      final elapsedSec =
          now.difference(_lastEventTime!).inMilliseconds / 1000.0;
      if (elapsedSec > 0) {
        final stepsPerSec = rawDelta / elapsedSec;
        if (stepsPerSec > _kMaxStepsPerSec) {
          debugPrint(
            '[Steps] SPIKE DISCARDED: rawDelta=$rawDelta '
            'in ${elapsedSec.toStringAsFixed(2)}s '
            '= ${stepsPerSec.toStringAsFixed(1)} steps/s > $_kMaxStepsPerSec',
          );
          _lastRawSteps = rawSteps;
          _lastEventTime = now;
          return;
        }
      }
    }

    // Convert raw steps to session steps.
    final sessionSteps = rawSteps - _baselineSteps;
    _lastSessionSteps = sessionSteps;
    _lastRawSteps = rawSteps;
    _lastEventTime = now;

    debugPrint(
      '[Steps] raw=$rawSteps baseline=$_baselineSteps '
      'session=$sessionSteps delta=$rawDelta',
    );

    _emit(sessionSteps, now);
  }

  void _emit(int sessionSteps, DateTime now) {
    // Throttle UI updates.
    if (_lastEmit != null && now.difference(_lastEmit!) < _kEmitThrottle) {
      return;
    }
    _lastEmit = now;

    if (!_outController.isClosed) {
      _outController.add(sessionSteps);
    }
  }
}
