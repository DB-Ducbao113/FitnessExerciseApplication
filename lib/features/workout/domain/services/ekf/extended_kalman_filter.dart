import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fitness_exercise_application/features/workout/domain/services/ekf/matrix_math_4x4.dart';
import 'package:latlong2/latlong.dart';

/// Output estimation from an EKF update cycle
enum EkfMeasurementDecision { normal, downWeighted, rejected }

class EkfUpdateDiagnostics {
  final double? positionInnovationMeters;
  final double? positionNis;
  final double? speedInnovationMs;
  final double? headingInnovationRad;
  final double? speedVariance;
  final double? headingVarianceRad2;
  final bool usedSpeedMeasurement;
  final bool usedHeadingMeasurement;
  final EkfMeasurementDecision positionDecision;
  final double? effectivePositionVariance;
  final bool turnDetected;
  final double? headingDeltaRad;
  final double? headingProcessVariance;
  final double? speedProcessVariance;
  final double? positionProcessVariance;
  final double? effectiveTimeDeltaSec;
  final bool timeDeltaWasSanitized;
  final bool covarianceCorrectionApplied;

  const EkfUpdateDiagnostics({
    this.positionInnovationMeters,
    this.positionNis,
    this.speedInnovationMs,
    this.headingInnovationRad,
    this.speedVariance,
    this.headingVarianceRad2,
    this.usedSpeedMeasurement = false,
    this.usedHeadingMeasurement = false,
    this.positionDecision = EkfMeasurementDecision.normal,
    this.effectivePositionVariance,
    this.turnDetected = false,
    this.headingDeltaRad,
    this.headingProcessVariance,
    this.speedProcessVariance,
    this.positionProcessVariance,
    this.effectiveTimeDeltaSec,
    this.timeDeltaWasSanitized = false,
    this.covarianceCorrectionApplied = false,
  });
}

class EkfEstimate {
  final LatLng position;
  final double speedMs;
  final double headingDeg;
  final double positionVariance;
  final EkfUpdateDiagnostics diagnostics;

  const EkfEstimate({
    required this.position,
    required this.speedMs,
    required this.headingDeg,
    required this.positionVariance,
    required this.diagnostics,
  });
}

/// 4-State Extended Kalman Filter for real-time mobile GPS tracking.
///
/// State vector:
/// x = [ px,   (local East in meters)
///       py,   (local North in meters)
///       v,    (speed along track in m/s)
///       θ ]   (heading in radians, clockwise from North)
class ExtendedKalmanFilter {
  EquirectangularProjection? _projection;

  // State vector x: [px, py, v, theta]
  final Float64List _x = Float64List(4);

  // Error covariance matrix P (4x4)
  Matrix4x4 _p = Matrix4x4.identity();

  // Continuous-time random-walk noise densities. Squaring and multiplying by
  // dt produces Q variances in m², (m/s)² and rad² respectively.
  final double processPosStd; // m/sqrt(s)
  final double processSpeedStd; // (m/s)/sqrt(s)
  final double processHeadingStd; // rad/sqrt(s)
  final double positionAccuracyScale;
  final double nisDownWeightThreshold;
  final double nisRejectThreshold;
  final double maxPositionNoiseScale;
  final double turnThresholdRad;
  final double maxTurnHeadingNoiseScale;
  final double maxAccelerationNoiseScale;

  double? _lastMeasuredHeadingRad;
  double? _lastMeasuredSpeedMs;
  double? _lastEffectiveHeadingRad;
  double? _lastRawZx;
  double? _lastRawZy;
  double? _cogAnchorZx;
  double? _cogAnchorZy;
  bool _covarianceCorrectionAppliedThisUpdate = false;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Read-only covariance snapshot for tests and offline diagnostics.
  List<List<double>> get covariance => List<List<double>>.unmodifiable(
    List<List<double>>.generate(
      4,
      (row) => List<double>.unmodifiable(
        List<double>.generate(4, (column) => _p.get(row, column)),
      ),
    ),
  );

  /// Returns true if the internal covariance matrix P is positive semi-definite (PSD).
  bool get isCovariancePositiveSemiDefinite => _p.isPositiveSemiDefinite();

  ExtendedKalmanFilter({
    this.processPosStd = 0.75,
    this.processSpeedStd = 1.2,
    this.processHeadingStd = 0.5,
    this.positionAccuracyScale = 0.75,
    this.nisDownWeightThreshold = 5.991,
    this.nisRejectThreshold = 13.816,
    this.maxPositionNoiseScale = 16.0,
    this.turnThresholdRad = 12.0 * math.pi / 180.0,
    this.maxTurnHeadingNoiseScale = 14.0,
    this.maxAccelerationNoiseScale = 4.0,
  }) {
    _validateConfiguration();
  }

  /// Re-seeds or initializes the filter with an initial anchor point.
  void init({
    required LatLng initialPoint,
    double initialAccuracyMeters = 5.0,
    double? initialSpeedMs,
    double? initialHeadingDeg,
  }) {
    _validatePoint(initialPoint, parameterName: 'initialPoint');
    _projection = EquirectangularProjection(initialPoint);
    _x[0] = 0.0; // px
    _x[1] = 0.0; // py
    final validInitialSpeed =
        initialSpeedMs != null && initialSpeedMs.isFinite && initialSpeedMs >= 0
        ? initialSpeedMs
        : null;
    _x[2] = validInitialSpeed ?? 0.0;
    final validInitialHeading =
        validInitialSpeed != null && validInitialSpeed > 0.6
        ? _validHeadingRad(initialHeadingDeg)
        : null;
    _x[3] = validInitialHeading ?? 0.0;

    final accuracy = _validAccuracy(initialAccuracyMeters);
    final posVar = accuracy * accuracy;
    _p = Matrix4x4.diagonal(
      posVar,
      posVar,
      4.0, // initial speed variance (2 m/s std)
      1.0, // initial heading variance (~57 deg std)
    );
    _lastMeasuredSpeedMs = validInitialSpeed;
    _lastMeasuredHeadingRad = validInitialHeading;
    _lastEffectiveHeadingRad = validInitialHeading;
    _lastRawZx = 0.0;
    _lastRawZy = 0.0;
    _cogAnchorZx = null;
    _cogAnchorZy = null;
    _initialized = true;
  }

  /// Resets filter state (e.g. after long GPS blackout > 5s)
  void reset() {
    _initialized = false;
    _projection = null;
    _x.fillRange(0, 4, 0.0);
    _p = Matrix4x4.identity();
    _lastMeasuredHeadingRad = null;
    _lastMeasuredSpeedMs = null;
    _lastEffectiveHeadingRad = null;
    _lastRawZx = null;
    _lastRawZy = null;
    _cogAnchorZx = null;
    _cogAnchorZy = null;
    _covarianceCorrectionAppliedThisUpdate = false;
  }

  /// Performs Predict-Update cycle for a new accepted GPS measurement.
  ///
  /// - [measurementPoint]: raw accepted GPS LatLng
  /// - [accuracyMeters]: GPS reported horizontal accuracy (1-sigma)
  /// - [timeDeltaSec]: elapsed seconds since last update
  /// - [speedMs]: device measured GPS speed (optional)
  /// - [headingDeg]: device measured GPS heading in degrees (optional)
  EkfEstimate update({
    required LatLng measurementPoint,
    required double accuracyMeters,
    required double timeDeltaSec,
    double? speedMs,
    double? headingDeg,
  }) {
    _validatePoint(measurementPoint, parameterName: 'measurementPoint');
    if (!_initialized || _projection == null) {
      init(
        initialPoint: measurementPoint,
        initialAccuracyMeters: accuracyMeters,
        initialSpeedMs: speedMs,
        initialHeadingDeg: headingDeg,
      );
      final effectiveAccuracy = _validAccuracy(accuracyMeters);
      final initialPositionVariance = effectiveAccuracy * effectiveAccuracy;
      return EkfEstimate(
        position: measurementPoint,
        speedMs: _x[2],
        headingDeg: EquirectangularProjection.normalizeAngleDeg(
          _x[3] * EquirectangularProjection.radToDeg,
        ),
        positionVariance: initialPositionVariance,
        diagnostics: EkfUpdateDiagnostics(
          usedSpeedMeasurement: _lastMeasuredSpeedMs != null,
          usedHeadingMeasurement: _lastMeasuredHeadingRad != null,
          effectivePositionVariance: initialPositionVariance,
        ),
      );
    }

    final hasValidTimeDelta = timeDeltaSec.isFinite && timeDeltaSec > 0;
    final dt = hasValidTimeDelta ? timeDeltaSec.clamp(0.05, 5.0) : 1.0;
    final timeDeltaWasSanitized = !hasValidTimeDelta || dt != timeDeltaSec;
    _covarianceCorrectionAppliedThisUpdate = false;

    final validSpeed = speedMs != null && speedMs.isFinite && speedMs >= 0
        ? speedMs
        : null;
    final measuredHeadingRad = validSpeed != null && validSpeed > 0.6
        ? _validHeadingRad(headingDeg)
        : null;
    final (zx, zy) = _projection!.project(measurementPoint);
    final adaptation = _motionAdaptation(
      speedMs: validSpeed,
      headingRad: measuredHeadingRad,
      dt: dt,
      zx: zx,
      zy: zy,
      accuracyMeters: accuracyMeters,
    );

    // 1. PREDICT STEP: x_k|k-1 = f(x_k-1, dt)
    final processNoise = _predict(
      dt,
      speedNoiseScale: adaptation.speedNoiseScale,
      headingNoiseScale: adaptation.headingNoiseScale,
    );

    // 2. UPDATE STEP: calculate Kalman gain K and update with GPS measurement
    final diagnostics = _updateMeasurement(
      measurementPoint: measurementPoint,
      accuracyMeters: accuracyMeters,
      speedMs: speedMs,
      headingDeg: headingDeg,
      dt: dt,
      turnDetected: adaptation.turnDetected,
      headingDeltaRad: adaptation.headingDeltaRad,
      headingProcessVariance: processNoise.headingVariance,
      speedProcessVariance: processNoise.speedVariance,
      positionProcessVariance: processNoise.positionVariance,
      effectiveTimeDeltaSec: dt,
      timeDeltaWasSanitized: timeDeltaWasSanitized,
      zx: zx,
      zy: zy,
    );

    if (validSpeed != null) _lastMeasuredSpeedMs = validSpeed;
    if (measuredHeadingRad != null) {
      _lastMeasuredHeadingRad = measuredHeadingRad;
    }
    if (adaptation.effectiveHeadingRad != null) {
      _lastEffectiveHeadingRad = adaptation.effectiveHeadingRad;
    }
    _lastRawZx = zx;
    _lastRawZy = zy;

    // Ensure speed non-negative
    if (_x[2] < 0.0) _x[2] = 0.0;
    _x[3] = EquirectangularProjection.normalizeAngleRad(_x[3]);

    final estimatedLatLng = _projection!.unproject(_x[0], _x[1]);
    final estimatedHeadingDeg = EquirectangularProjection.normalizeAngleDeg(
      _x[3] * EquirectangularProjection.radToDeg,
    );
    final posVariance = (_p.get(0, 0) + _p.get(1, 1)) / 2.0;

    return EkfEstimate(
      position: estimatedLatLng,
      speedMs: _x[2],
      headingDeg: estimatedHeadingDeg,
      positionVariance: posVariance,
      diagnostics: diagnostics,
    );
  }

  ({double positionVariance, double speedVariance, double headingVariance})
  _predict(
    double dt, {
    required double speedNoiseScale,
    required double headingNoiseScale,
  }) {
    final px = _x[0];
    final py = _x[1];
    final v = _x[2];
    final theta = _x[3];

    final sinTheta = math.sin(theta);
    final cosTheta = math.cos(theta);

    // Non-linear state transition f(x, dt)
    _x[0] = px + v * sinTheta * dt;
    _x[1] = py + v * cosTheta * dt;
    // v and theta are modeled as constant velocity / heading with process noise

    // Jacobian F = df / dx
    final f = Matrix4x4.identity();
    f.set(0, 2, sinTheta * dt);
    f.set(0, 3, v * cosTheta * dt);
    f.set(1, 2, cosTheta * dt);
    f.set(1, 3, -v * sinTheta * dt);

    // Process noise covariance Q
    final qPos = processPosStd * processPosStd * dt;
    final qSpeed = processSpeedStd * processSpeedStd * dt * speedNoiseScale;
    final qHeading =
        processHeadingStd * processHeadingStd * dt * headingNoiseScale;
    final q = Matrix4x4.diagonal(qPos, qPos, qSpeed, qHeading);

    // P = F * P * F^T + Q
    final fTranspose = f.transpose();
    _p = (f * _p * fTranspose) + q;
    _stabilizeCovariance();
    return (
      positionVariance: qPos,
      speedVariance: qSpeed,
      headingVariance: qHeading,
    );
  }

  EkfUpdateDiagnostics _updateMeasurement({
    required LatLng measurementPoint,
    required double accuracyMeters,
    double? speedMs,
    double? headingDeg,
    required double dt,
    required bool turnDetected,
    required double? headingDeltaRad,
    required double headingProcessVariance,
    required double speedProcessVariance,
    required double positionProcessVariance,
    required double effectiveTimeDeltaSec,
    required bool timeDeltaWasSanitized,
    double? zx,
    double? zy,
  }) {
    final (projX, projY) = (zx != null && zy != null)
        ? (zx, zy)
        : _projection!.project(measurementPoint);
    final accuracy = _validAccuracy(accuracyMeters);
    final rPos = accuracy * accuracy;

    final hasValidSpeed = speedMs != null && speedMs.isFinite && speedMs >= 0.0;
    final validHeadingRad = hasValidSpeed && speedMs > 0.6
        ? _validHeadingRad(headingDeg)
        : null;
    final hasValidHeading = validHeadingRad != null;

    final positionDiagnostics = _updatePositionOnly(projX, projY, rPos);
    double? speedInnovation;
    double? speedVariance;
    if (hasValidSpeed) {
      speedInnovation = speedMs - _x[2];
      final speedStd = (math.sqrt(2) * accuracy / dt).clamp(1.0, 8.0);
      speedVariance = speedStd * speedStd;
      _updateScalar(
        stateIndex: 2,
        innovation: speedInnovation,
        measurementVariance: speedVariance,
      );
    }

    double? headingInnovation;
    double? headingVariance;
    if (hasValidHeading) {
      headingInnovation = EquirectangularProjection.normalizeAngleRad(
        validHeadingRad - _x[3],
      );
      final travelledMeters = math.max(1.0, speedMs! * dt);
      final headingStd = math
          .atan2(math.sqrt(2) * accuracy, travelledMeters)
          .clamp(
            5.0 * EquirectangularProjection.degToRad,
            60.0 * EquirectangularProjection.degToRad,
          );
      headingVariance = headingStd * headingStd;
      _updateScalar(
        stateIndex: 3,
        innovation: headingInnovation,
        measurementVariance: headingVariance,
      );
    }

    return EkfUpdateDiagnostics(
      positionInnovationMeters: positionDiagnostics.innovationMeters,
      positionNis: positionDiagnostics.nis,
      speedInnovationMs: speedInnovation,
      headingInnovationRad: headingInnovation,
      speedVariance: speedVariance,
      headingVarianceRad2: headingVariance,
      usedSpeedMeasurement: hasValidSpeed,
      usedHeadingMeasurement: hasValidHeading,
      positionDecision: positionDiagnostics.decision,
      effectivePositionVariance: positionDiagnostics.effectiveVariance,
      turnDetected: turnDetected,
      headingDeltaRad: headingDeltaRad,
      headingProcessVariance: headingProcessVariance,
      speedProcessVariance: speedProcessVariance,
      positionProcessVariance: positionProcessVariance,
      effectiveTimeDeltaSec: effectiveTimeDeltaSec,
      timeDeltaWasSanitized: timeDeltaWasSanitized,
      covarianceCorrectionApplied: _covarianceCorrectionAppliedThisUpdate,
    );
  }

  ({
    double innovationMeters,
    double nis,
    EkfMeasurementDecision decision,
    double effectiveVariance,
  })
  _updatePositionOnly(double zx, double zy, double rPos) {
    final y0 = zx - _x[0];
    final y1 = zy - _x[1];
    final baseSInv = _positionInnovationInverse(rPos);
    final baseNis =
        y0 * (baseSInv.m00 * y0 + baseSInv.m01 * y1) +
        y1 * (baseSInv.m10 * y0 + baseSInv.m11 * y1);
    final finiteNis = baseNis.isFinite
        ? math.max(0.0, baseNis)
        : double.infinity;
    if (finiteNis >= nisRejectThreshold) {
      return (
        innovationMeters: math.sqrt(y0 * y0 + y1 * y1),
        nis: finiteNis,
        decision: EkfMeasurementDecision.rejected,
        effectiveVariance: rPos,
      );
    }

    final decision = finiteNis >= nisDownWeightThreshold
        ? EkfMeasurementDecision.downWeighted
        : EkfMeasurementDecision.normal;
    final noiseScale = decision == EkfMeasurementDecision.downWeighted
        ? (finiteNis / nisDownWeightThreshold).clamp(1.0, maxPositionNoiseScale)
        : 1.0;
    final effectiveRPos = rPos * noiseScale;
    final sInv = noiseScale == 1.0
        ? baseSInv
        : _positionInnovationInverse(effectiveRPos);

    // P * H^T is 4x2 matrix consisting of first two columns of P:
    // Row r: [ P(r, 0), P(r, 1) ]
    // K = (P * H^T) * S^-1 -> 4x2 matrix
    final k00 = _p.get(0, 0) * sInv.m00 + _p.get(0, 1) * sInv.m10;
    final k01 = _p.get(0, 0) * sInv.m01 + _p.get(0, 1) * sInv.m11;

    final k10 = _p.get(1, 0) * sInv.m00 + _p.get(1, 1) * sInv.m10;
    final k11 = _p.get(1, 0) * sInv.m01 + _p.get(1, 1) * sInv.m11;

    final k20 = _p.get(2, 0) * sInv.m00 + _p.get(2, 1) * sInv.m10;
    final k21 = _p.get(2, 0) * sInv.m01 + _p.get(2, 1) * sInv.m11;

    final k30 = _p.get(3, 0) * sInv.m00 + _p.get(3, 1) * sInv.m10;
    final k31 = _p.get(3, 0) * sInv.m01 + _p.get(3, 1) * sInv.m11;

    _x[0] += k00 * y0 + k01 * y1;
    _x[1] += k10 * y0 + k11 * y1;
    _x[2] += k20 * y0 + k21 * y1;
    _x[3] += k30 * y0 + k31 * y1;

    // Joseph form: P = (I - KH) P (I - KH)^T + K R K^T.
    // K H is 4x4 matrix with columns 0 and 1 equal to K, and columns 2 and 3 equal to 0.
    final kh = Matrix4x4.fromList([
      k00,
      k01,
      0.0,
      0.0,
      k10,
      k11,
      0.0,
      0.0,
      k20,
      k21,
      0.0,
      0.0,
      k30,
      k31,
      0.0,
      0.0,
    ]);
    final iMinusKh = Matrix4x4.identity() - kh;
    final krkt = Matrix4x4();
    final firstGain = [k00, k10, k20, k30];
    final secondGain = [k01, k11, k21, k31];
    for (var row = 0; row < 4; row += 1) {
      for (var column = 0; column < 4; column += 1) {
        krkt.set(
          row,
          column,
          effectiveRPos *
              (firstGain[row] * firstGain[column] +
                  secondGain[row] * secondGain[column]),
        );
      }
    }
    _p = (iMinusKh * _p * iMinusKh.transpose()) + krkt;
    _stabilizeCovariance();
    return (
      innovationMeters: math.sqrt(y0 * y0 + y1 * y1),
      nis: finiteNis,
      decision: decision,
      effectiveVariance: effectiveRPos,
    );
  }

  Matrix2x2 _positionInnovationInverse(double positionVariance) {
    final s00 = _p.get(0, 0) + positionVariance;
    final s01 = _p.get(0, 1);
    final s10 = _p.get(1, 0);
    final s11 = _p.get(1, 1) + positionVariance;
    try {
      return Matrix2x2(s00, s01, s10, s11).invert();
    } on StateError {
      _covarianceCorrectionAppliedThisUpdate = true;
      return Matrix2x2(s00 + 1e-4, s01, s10, s11 + 1e-4).invert();
    }
  }

  void _updateScalar({
    required int stateIndex,
    required double innovation,
    required double measurementVariance,
  }) {
    final prior = _p;
    final innovationVariance =
        prior.get(stateIndex, stateIndex) + measurementVariance;
    if (!innovationVariance.isFinite || innovationVariance <= 1e-12) {
      throw StateError(
        'Invalid scalar innovation variance at state index $stateIndex: '
        '$innovationVariance',
      );
    }

    final gain = List<double>.generate(
      4,
      (row) => prior.get(row, stateIndex) / innovationVariance,
    );
    for (var row = 0; row < 4; row += 1) {
      _x[row] += gain[row] * innovation;
    }

    final kh = Matrix4x4();
    for (var row = 0; row < 4; row += 1) {
      kh.set(row, stateIndex, gain[row]);
    }
    final iMinusKh = Matrix4x4.identity() - kh;
    final krkt = Matrix4x4();
    for (var row = 0; row < 4; row += 1) {
      for (var column = 0; column < 4; column += 1) {
        krkt.set(row, column, measurementVariance * gain[row] * gain[column]);
      }
    }
    _p = (iMinusKh * prior * iMinusKh.transpose()) + krkt;
    _stabilizeCovariance();
  }

  void _stabilizeCovariance() {
    for (final value in _p.storage) {
      if (!value.isFinite) {
        throw StateError('EKF covariance contains a non-finite value');
      }
    }

    for (var row = 0; row < 4; row += 1) {
      for (var column = row; column < 4; column += 1) {
        final a = _p.get(row, column);
        final b = _p.get(column, row);
        final scale = math.max(1.0, math.max(a.abs(), b.abs()));
        if ((a - b).abs() > 1e-10 * scale) {
          _covarianceCorrectionAppliedThisUpdate = true;
        }
        final symmetric = (a + b) / 2.0;
        _p.set(row, column, symmetric);
        _p.set(column, row, symmetric);
      }
      final diagonal = _p.get(row, row);
      final clamped = diagonal.clamp(1e-9, 1e12);
      if (clamped != diagonal) {
        _covarianceCorrectionAppliedThisUpdate = true;
        _p.set(row, row, clamped);
      }
    }

    // Ensure 2x2 principal minors are non-negative (Cauchy-Schwarz correlation bound)
    for (var row = 0; row < 4; row += 1) {
      for (var column = row + 1; column < 4; column += 1) {
        final maxCross = math.sqrt(_p.get(row, row) * _p.get(column, column));
        final val = _p.get(row, column);
        if (val.abs() >= maxCross) {
          _covarianceCorrectionAppliedThisUpdate = true;
          final clampedCross =
              (val.isNegative ? -1.0 : 1.0) * maxCross * (1.0 - 1e-12);
          _p.set(row, column, clampedCross);
          _p.set(column, row, clampedCross);
        }
      }
    }
  }

  void _validateConfiguration() {
    _requireFiniteNonNegative(processPosStd, 'processPosStd');
    _requireFiniteNonNegative(processSpeedStd, 'processSpeedStd');
    _requireFiniteNonNegative(processHeadingStd, 'processHeadingStd');
    _requireFinitePositive(positionAccuracyScale, 'positionAccuracyScale');
    _requireFinitePositive(nisDownWeightThreshold, 'nisDownWeightThreshold');
    _requireFinitePositive(nisRejectThreshold, 'nisRejectThreshold');
    if (nisRejectThreshold <= nisDownWeightThreshold) {
      throw ArgumentError.value(
        nisRejectThreshold,
        'nisRejectThreshold',
        'must be greater than nisDownWeightThreshold',
      );
    }
    _requireFiniteAtLeastOne(maxPositionNoiseScale, 'maxPositionNoiseScale');
    _requireFiniteAtLeastOne(
      maxTurnHeadingNoiseScale,
      'maxTurnHeadingNoiseScale',
    );
    _requireFiniteAtLeastOne(
      maxAccelerationNoiseScale,
      'maxAccelerationNoiseScale',
    );
    if (!turnThresholdRad.isFinite ||
        turnThresholdRad <= 0 ||
        turnThresholdRad >= math.pi / 2) {
      throw ArgumentError.value(
        turnThresholdRad,
        'turnThresholdRad',
        'must be finite and in the interval (0, pi/2)',
      );
    }
  }

  static void _validatePoint(LatLng point, {required String parameterName}) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude < -90.0 ||
        point.latitude > 90.0 ||
        point.longitude < -180.0 ||
        point.longitude > 180.0) {
      throw ArgumentError.value(
        point,
        parameterName,
        'latitude must be in [-90, 90] and longitude in [-180, 180]',
      );
    }
  }

  static void _requireFiniteNonNegative(double value, String name) {
    if (!value.isFinite || value < 0.0) {
      throw ArgumentError.value(value, name, 'must be finite and >= 0');
    }
  }

  static void _requireFinitePositive(double value, String name) {
    if (!value.isFinite || value <= 0.0) {
      throw ArgumentError.value(value, name, 'must be finite and > 0');
    }
  }

  static void _requireFiniteAtLeastOne(double value, String name) {
    if (!value.isFinite || value < 1.0) {
      throw ArgumentError.value(value, name, 'must be finite and >= 1');
    }
  }

  ({
    double speedNoiseScale,
    double headingNoiseScale,
    bool turnDetected,
    double? headingDeltaRad,
    double? effectiveHeadingRad,
  })
  _motionAdaptation({
    required double? speedMs,
    required double? headingRad,
    required double dt,
    required double zx,
    required double zy,
    required double accuracyMeters,
  }) {
    double? effectiveHeading = headingRad;
    double? effectiveSpeed = speedMs;

    if (_lastRawZx != null && _lastRawZy != null && dt > 0) {
      final dx = zx - _lastRawZx!;
      final dy = zy - _lastRawZy!;
      final displacementMeters = math.sqrt(dx * dx + dy * dy);

      if (effectiveSpeed == null && displacementMeters > 0) {
        effectiveSpeed = (displacementMeters / dt).clamp(0.0, 20.0);
      }
    }

    final currentSpeed = effectiveSpeed ?? _x[2];
    final isStationary = currentSpeed < 0.8;

    // Accuracy-aware course-over-ground fallback when heading sensor is missing
    if (effectiveHeading != null) {
      // Device heading provided: sync anchor to current filtered position
      _cogAnchorZx = _x[0];
      _cogAnchorZy = _x[1];
    } else if (isStationary) {
      // Stationary: reset anchor to avoid drift accumulation while stopped
      _cogAnchorZx = _x[0];
      _cogAnchorZy = _x[1];
      effectiveHeading = _lastEffectiveHeadingRad;
    } else {
      // Heading dropout while in motion:
      if (_cogAnchorZx == null || _cogAnchorZy == null) {
        _cogAnchorZx = _x[0];
        _cogAnchorZy = _x[1];
        effectiveHeading = _lastEffectiveHeadingRad;
      } else {
        final anchorDx = _x[0] - _cogAnchorZx!;
        final anchorDy = _x[1] - _cogAnchorZy!;
        final anchorDist = math.sqrt(anchorDx * anchorDx + anchorDy * anchorDy);
        // Minimum displacement to overcome GNSS lateral noise:
        // Filtered position has standard deviation ~1.0-1.5m.
        // Requiring anchorDist >= max(5.0, 1.25 * accuracyMeters) ensures angular noise < 15°.
        final minAnchorDist = math.max(5.0, 1.25 * accuracyMeters);
        if (anchorDist >= minAnchorDist && currentSpeed >= 1.0) {
          effectiveHeading = EquirectangularProjection.normalizeAngleRad(
            math.atan2(anchorDx, anchorDy),
          );
          _cogAnchorZx = _x[0];
          _cogAnchorZy = _x[1];
        } else {
          // Keep previous validated heading while within noise circle
          effectiveHeading = _lastEffectiveHeadingRad;
        }
      }
    }

    double? headingDelta;
    bool turnDetected = false;
    double headingScale = 1.0;

    final referenceHeading =
        _lastEffectiveHeadingRad ?? _lastMeasuredHeadingRad;
    if (!isStationary &&
        effectiveHeading != null &&
        referenceHeading != null) {
      headingDelta = EquirectangularProjection.normalizeAngleRad(
        effectiveHeading - referenceHeading,
      ).abs();
      turnDetected = headingDelta >= turnThresholdRad;
      if (turnDetected) {
        final turnStrength = ((headingDelta - turnThresholdRad) /
                (math.pi / 2 - turnThresholdRad))
            .clamp(0.0, 1.0);
        headingScale =
            1.0 + (maxTurnHeadingNoiseScale - 1.0) * turnStrength;
      }
    }

    final speedReference = _lastMeasuredSpeedMs;
    final rawAcceleration = (effectiveSpeed == null || speedReference == null)
        ? 0.0
        : (effectiveSpeed - speedReference).abs() / dt;
    final plausibleAcceleration = rawAcceleration.clamp(0.0, 5.0);
    final accelerationStrength = (plausibleAcceleration / 3.0).clamp(0.0, 1.0);
    final speedScale =
        1.0 + (maxAccelerationNoiseScale - 1.0) * accelerationStrength;
    return (
      speedNoiseScale: speedScale,
      headingNoiseScale: headingScale,
      turnDetected: turnDetected,
      headingDeltaRad: headingDelta,
      effectiveHeadingRad: effectiveHeading,
    );
  }

  double _validAccuracy(double accuracyMeters) {
    if (!accuracyMeters.isFinite || accuracyMeters <= 0) return 5.0;
    return (accuracyMeters * positionAccuracyScale).clamp(1.5, 100.0);
  }

  static double? _validHeadingRad(double? headingDeg) {
    if (headingDeg == null ||
        !headingDeg.isFinite ||
        headingDeg < 0 ||
        headingDeg >= 360) {
      return null;
    }
    return EquirectangularProjection.normalizeAngleRad(
      headingDeg * EquirectangularProjection.degToRad,
    );
  }
}
