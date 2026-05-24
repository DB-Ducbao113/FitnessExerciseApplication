import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// GPS Distance Accuracy Benchmark — Aetron
//
// Benchmark criteria (Scott et al., 2016 — J Strength Cond Res):
//   MAPE < 5%   → Good / Acceptable
//   MAPE 5–10%  → Moderate
//   MAPE > 10%  → Poor
//
// External reference (Gilgen-Ammann et al., 2020 — JMIR mHealth):
//   Commercial GPS watches overall MAPE: 3.2% – 6.1%
//   Urban environment:                  3.9% – 8.9%
//   Track & field (open sky):           0.9% – 4.1%
//
// How to use:
//   1. Measure your route's true distance using Google Maps / certified track.
//   2. Record Aetron's distance for each trial.
//   3. Fill in _trials below and run: flutter test test/gps_accuracy_benchmark_test.dart
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Domain model
// ---------------------------------------------------------------------------

/// One GPS accuracy trial:
///   - [referenceKm] = known true distance of the route (Google Maps / track)
///   - [aetronKm]    = what Aetron recorded for that trial
class GpsTrial {
  final String trialId;
  final String environment; // 'track' | 'park' | 'suburban' | 'urban' | 'forest'
  final String activityType; // 'running' | 'walking' | 'cycling'

  /// True distance of the route — measure once with Google Maps or a
  /// certified athletics track (e.g. 400 m × N laps).
  final double referenceKm;

  /// Distance recorded by Aetron for this trial.
  final double aetronKm;

  const GpsTrial({
    required this.trialId,
    required this.environment,
    required this.activityType,
    required this.referenceKm,
    required this.aetronKm,
  });

  /// |Aetron - reference| in km.
  double get absoluteErrorKm => (aetronKm - referenceKm).abs();

  /// Absolute error in metres.
  double get absoluteErrorMeters => absoluteErrorKm * 1000.0;

  /// Absolute Percentage Error — used to compute MAPE.
  double get ape =>
      referenceKm > 0 ? (absoluteErrorKm / referenceKm) * 100.0 : 0.0;

  /// Signed Percentage Error: positive = over-count, negative = under-count.
  double get signedError =>
      referenceKm > 0
          ? ((aetronKm - referenceKm) / referenceKm) * 100.0
          : 0.0;
}

// ---------------------------------------------------------------------------
// Accuracy classification (Scott et al., 2016)
// ---------------------------------------------------------------------------

enum AccuracyRating { good, moderate, poor }

extension on AccuracyRating {
  String get label {
    switch (this) {
      case AccuracyRating.good:
        return 'GOOD (MAPE < 5%)';
      case AccuracyRating.moderate:
        return 'MODERATE (MAPE 5–10%)';
      case AccuracyRating.poor:
        return 'POOR (MAPE > 10%)';
    }
  }
}

// ---------------------------------------------------------------------------
// Report calculator
// ---------------------------------------------------------------------------

class GpsAccuracyReport {
  final List<GpsTrial> trials;
  final String label;

  const GpsAccuracyReport({required this.trials, required this.label});

  int get n => trials.length;

  // ── Core metrics ──────────────────────────────────────────────────────────

  /// Mean Absolute Percentage Error (MAPE).
  double get mape {
    if (trials.isEmpty) return 0;
    return trials.fold<double>(0.0, (sum, t) => sum + t.ape) / trials.length;
  }

  /// Mean Absolute Error in metres.
  double get maeMeters {
    if (trials.isEmpty) return 0;
    return trials.fold<double>(0.0, (sum, t) => sum + t.absoluteErrorMeters) /
        trials.length;
  }

  /// Bias: mean signed % error.
  /// Positive → Aetron consistently over-counts.
  /// Negative → Aetron consistently under-counts.
  double get bias {
    if (trials.isEmpty) return 0;
    return trials.fold<double>(0.0, (sum, t) => sum + t.signedError) /
        trials.length;
  }

  /// Standard deviation of APE (spread of individual errors).
  double get sdApe {
    if (trials.length < 2) return 0;
    final mean = mape;
    final variance =
        trials.fold<double>(0.0, (sum, t) => sum + math.pow(t.ape - mean, 2)) /
        (trials.length - 1);
    return math.sqrt(variance);
  }

  /// 95% Limits of Agreement (Bland-Altman) on signed % error.
  ({double lower, double upper}) get loa95 {
    if (trials.length < 2) return (lower: bias, upper: bias);
    final mean = bias;
    final variance = trials.fold<double>(
          0.0,
          (sum, t) => sum + math.pow(t.signedError - mean, 2),
        ) /
        (trials.length - 1);
    final sd = math.sqrt(variance);
    return (lower: mean - 1.96 * sd, upper: mean + 1.96 * sd);
  }

  /// % of trials within ±5% error (Gilgen-Ammann 2020 criterion ≥ 75%).
  double get pctWithin5 {
    if (trials.isEmpty) return 0;
    return trials.where((t) => t.ape <= 5.0).length / trials.length;
  }

  /// % of trials within ±3% error (stricter threshold).
  double get pctWithin3 {
    if (trials.isEmpty) return 0;
    return trials.where((t) => t.ape <= 3.0).length / trials.length;
  }

  /// Max single-trial APE (worst case).
  double get maxApe {
    if (trials.isEmpty) return 0;
    return trials.map((t) => t.ape).reduce(math.max);
  }

  AccuracyRating get rating {
    if (mape < 5.0) return AccuracyRating.good;
    if (mape <= 10.0) return AccuracyRating.moderate;
    return AccuracyRating.poor;
  }

  // ── Reporting ─────────────────────────────────────────────────────────────

  void printSummary() {
    final l = loa95;
    // ignore: avoid_print
    print('''
┌─────────────────────────────────────────────────────────────────┐
│  GPS Accuracy Report — $label
├─────────────────────────────────────────────────────────────────┤
│  n (trials)              : $n
│  MAPE                    : ${mape.toStringAsFixed(2)}%
│  MAE                     : ${maeMeters.toStringAsFixed(1)} m
│  Bias (mean signed err)  : ${bias.toStringAsFixed(2)}%  (${bias >= 0 ? '+: over-count' : '−: under-count'})
│  SD of APE               : ${sdApe.toStringAsFixed(2)}%
│  Max APE (worst trial)   : ${maxApe.toStringAsFixed(2)}%
│  95% LoA                 : [${l.lower.toStringAsFixed(2)}%, ${l.upper.toStringAsFixed(2)}%]
│  Within ±5%              : ${(pctWithin5 * 100).toStringAsFixed(1)}%  (≥ 75% required)
│  Within ±3%              : ${(pctWithin3 * 100).toStringAsFixed(1)}%
│  Rating (Scott 2016)     : ${rating.label}
└─────────────────────────────────────────────────────────────────┘''');
  }

  void printDetailTable() {
    // ignore: avoid_print
    print(
      '\n${'ID'.padRight(6)} ${'Env'.padRight(10)} ${'Act'.padRight(10)} '
      '${'Ref(km)'.padRight(9)} ${'Aetron(km)'.padRight(12)} '
      '${'APE%'.padRight(7)} ${'Signed%'.padRight(10)} ${'MAE(m)'.padRight(8)}',
    );
    // ignore: avoid_print
    print('─' * 75);
    for (final t in trials) {
      final direction = t.signedError >= 0 ? '+' : '';
      // ignore: avoid_print
      print(
        '${t.trialId.padRight(6)} '
        '${t.environment.padRight(10)} '
        '${t.activityType.padRight(10)} '
        '${t.referenceKm.toStringAsFixed(3).padRight(9)} '
        '${t.aetronKm.toStringAsFixed(3).padRight(12)} '
        '${t.ape.toStringAsFixed(2).padRight(7)} '
        '$direction${t.signedError.toStringAsFixed(2).padRight(9)} '
        '${t.absoluteErrorMeters.toStringAsFixed(1)}',
      );
    }
    // ignore: avoid_print
    print('─' * 75);
  }
}

// ---------------------------------------------------------------------------
// Test data — fill in YOUR actual measurements
//
// [referenceKm] = the TRUE distance of the route you ran:
//   • Google Maps → draw your exact route → copy the km value
//   • Athletics track → 400 m per lap (e.g. 2 laps = 0.8 km)
//   • Certified race course → use the official distance
//
// [aetronKm] = what Aetron showed at the end of that trial
//
// Example: your thesis image shows an urban route where Aetron recorded
// 0.52 km across 5 trials. Fill in the reference distance below.
// ---------------------------------------------------------------------------

const List<GpsTrial> _trials = [
  // ── Urban route — 5 trials ───────────────────────────────────────────────
  // TODO: Replace referenceKm with the true distance of YOUR urban route
  //       (measure once with Google Maps or GPS wheel).
  // The image shows Aetron = 0.52 km with accuracy -1.2%, so:
  //   0.52 / (1 - 0.012) ≈ 0.526 km → that is approximately the reference
  GpsTrial(
    trialId: 'T01',
    environment: 'urban',
    activityType: 'running',
    referenceKm: 0.526, // ← replace with your Google Maps measurement
    aetronKm: 0.52,
  ),
  // GpsTrial(
  //   trialId: 'T02',
  //   environment: 'urban',
  //   activityType: 'running',
  //   referenceKm: 0.526,
  //   aetronKm: X.XXX, // ← your actual Aetron result for trial 2
  // ),
  // GpsTrial(
  //   trialId: 'T03',
  //   environment: 'urban',
  //   activityType: 'running',
  //   referenceKm: 0.526,
  //   aetronKm: X.XXX,
  // ),
  // GpsTrial(
  //   trialId: 'T04',
  //   environment: 'urban',
  //   activityType: 'running',
  //   referenceKm: 0.526,
  //   aetronKm: X.XXX,
  // ),
  // GpsTrial(
  //   trialId: 'T05',
  //   environment: 'urban',
  //   activityType: 'running',
  //   referenceKm: 0.526,
  //   aetronKm: X.XXX,
  // ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<GpsTrial> _byActivity(String a) =>
    _trials.where((t) => t.activityType == a).toList();

List<GpsTrial> _byEnvironment(String e) =>
    _trials.where((t) => t.environment == e).toList();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Print detail table at startup ─────────────────────────────────────────
  setUpAll(() {
    GpsAccuracyReport(trials: _trials, label: 'ALL').printDetailTable();
  });

  // ── 1. Overall accuracy ──────────────────────────────────────────────────
  group('1. Overall GPS Accuracy — Scott et al. (2016)', () {
    late GpsAccuracyReport r;

    setUpAll(() {
      r = GpsAccuracyReport(trials: _trials, label: 'All trials');
      r.printSummary();
    });

    test('MAPE < 5% → rated Good', () {
      expect(
        r.mape,
        lessThan(5.0),
        reason: 'MAPE=${r.mape.toStringAsFixed(2)}% '
            '— must be < 5% to qualify as "Good" (Scott et al., 2016)',
      );
    });

    test('MAE ≤ 250 m per trial', () {
      expect(
        r.maeMeters,
        lessThanOrEqualTo(250.0),
        reason: 'MAE=${r.maeMeters.toStringAsFixed(1)} m '
            '— ≤ 250 m is acceptable for a fitness app',
      );
    });

    test('≥ 75% of trials within ±5% (Gilgen-Ammann 2020)', () {
      expect(
        r.pctWithin5,
        greaterThanOrEqualTo(0.75),
        reason: '${(r.pctWithin5 * 100).toStringAsFixed(1)}% within ±5% '
            '— must be ≥ 75%',
      );
    });

    test('Bias (systematic error) within ±3%', () {
      expect(
        r.bias.abs(),
        lessThanOrEqualTo(3.0),
        reason: 'Bias=${r.bias.toStringAsFixed(2)}% '
            '— ±3% max indicates acceptable directional drift',
      );
    });

    test('Max single-trial APE < 10% (no extreme outlier)', () {
      expect(
        r.maxApe,
        lessThan(10.0),
        reason: 'Worst trial APE=${r.maxApe.toStringAsFixed(2)}% '
            '— any trial > 10% indicates a serious GPS failure',
      );
    });
  });

  // ── 2. Per-environment breakdown ─────────────────────────────────────────
  group('2. Per-Environment Accuracy — Gilgen-Ammann (2020)', () {
    // Gilgen-Ammann 2020 MAPE thresholds by environment:
    const thresholds = {
      'track': 5.0,     // open sky — best GPS conditions
      'park': 7.0,      // semi-open
      'suburban': 7.0,
      'urban': 8.9,     // Gilgen-Ammann urban worst-case for commercial watches
      'forest': 10.0,
    };

    for (final entry in thresholds.entries) {
      final env = entry.key;
      final limit = entry.value;
      final samples = _byEnvironment(env);
      if (samples.isEmpty) continue;

      test('$env: MAPE < $limit% (Gilgen-Ammann 2020 threshold)', () {
        final r = GpsAccuracyReport(trials: samples, label: env);
        r.printSummary();

        expect(
          r.mape,
          lessThan(limit),
          reason: '$env MAPE=${r.mape.toStringAsFixed(2)}% '
              '— expected < $limit% (Gilgen-Ammann 2020)',
        );
      });
    }
  });

  // ── 3. Per-activity breakdown ─────────────────────────────────────────────
  group('3. Per-Activity Accuracy — Scott et al. (2016)', () {
    for (final activity in ['running', 'walking', 'cycling']) {
      final samples = _byActivity(activity);
      if (samples.isEmpty) continue;

      test('$activity: MAPE < 5% → Good', () {
        final r = GpsAccuracyReport(trials: samples, label: activity);
        r.printSummary();

        expect(
          r.mape,
          lessThan(5.0),
          reason: '$activity MAPE=${r.mape.toStringAsFixed(2)}% '
              '— must be < 5% (Scott et al., 2016)',
        );
      });
    }
  });

  // ── 4. Comparison vs. commercial GPS watches ──────────────────────────────
  group('4. vs. Gilgen-Ammann 2020 Commercial GPS Watch Baseline', () {
    // Best GPS watches (Polar): MAPE < 5%
    // Average across 8 watches:  MAPE 3.2% – 6.1%
    // Urban worst case:          MAPE 8.9%

    test('MAPE ≤ 6.1% (Gilgen-Ammann average upper bound)', () {
      final r = GpsAccuracyReport(trials: _trials, label: 'vs upper bound');
      expect(
        r.mape,
        lessThanOrEqualTo(6.1),
        reason: 'Aetron MAPE=${r.mape.toStringAsFixed(2)}% should be ≤ 6.1% '
            '(worst-case commercial GPS watch, Gilgen-Ammann 2020)',
      );
    });

    test('MAPE ≤ 5% (competitive with top GPS watches)', () {
      final r = GpsAccuracyReport(trials: _trials, label: 'vs top watches');
      expect(
        r.mape,
        lessThanOrEqualTo(5.0),
        reason: 'Aetron MAPE=${r.mape.toStringAsFixed(2)}% should be ≤ 5% '
            '(Scott 2016 "Good" — competitive with Polar/Garmin class devices)',
      );
    });
  });

  // ── 5. Data integrity checks ──────────────────────────────────────────────
  group('5. Data Integrity', () {
    test('all trial distances are plausible (0.01 – 100 km)', () {
      for (final t in _trials) {
        expect(t.referenceKm, inInclusiveRange(0.01, 100.0),
            reason: '${t.trialId}: referenceKm ${t.referenceKm} out of range');
        expect(t.aetronKm, inInclusiveRange(0.01, 100.0),
            reason: '${t.trialId}: aetronKm ${t.aetronKm} out of range');
      }
    });

    test('no duplicate trial IDs', () {
      final ids = _trials.map((t) => t.trialId).toList();
      expect(ids.length, ids.toSet().length,
          reason: 'Duplicate IDs: '
              '${ids.where((id) => ids.where((x) => x == id).length > 1).toSet()}');
    });

    test('all activity types are valid', () {
      const valid = {'running', 'walking', 'cycling'};
      for (final t in _trials) {
        expect(valid, contains(t.activityType),
            reason: '${t.trialId}: unknown activityType "${t.activityType}"');
      }
    });

    test('all environments are valid', () {
      const valid = {'track', 'park', 'suburban', 'urban', 'forest'};
      for (final t in _trials) {
        expect(valid, contains(t.environment),
            reason: '${t.trialId}: unknown environment "${t.environment}"');
      }
    });
  });

  // ── 6. Thesis summary ─────────────────────────────────────────────────────
  group('6. Thesis Summary', () {
    test('generate thesis paragraph', () {
      final r = GpsAccuracyReport(trials: _trials, label: 'ALL SESSIONS');
      r.printSummary();

      final l = r.loa95;
      // ignore: avoid_print
      print('''
══════════════════════════════════════════════════════════════════
THESIS PARAGRAPH — GPS Accuracy (Section 4.x):
──────────────────────────────────────────────────────────────────
"GPS distance measurement accuracy was evaluated by comparing
Aetron's recorded distances against a reference distance measured
using Google Maps for each test route. Accuracy was quantified
using the Mean Absolute Percentage Error (MAPE), following the
classification proposed by Scott et al. (2016): MAPE < 5%
indicates good accuracy, 5–10% moderate, and > 10% poor.

Across ${r.n} trial(s) on an urban route, Aetron achieved a MAPE of
${r.mape.toStringAsFixed(2)}% (MAE = ${r.maeMeters.toStringAsFixed(1)} m,
bias = ${r.bias.toStringAsFixed(2)}%, SD = ${r.sdApe.toStringAsFixed(2)}%,
95% LoA = [${l.lower.toStringAsFixed(2)}%, ${l.upper.toStringAsFixed(2)}%]),
placing it within the ${r.rating.label} accuracy range.
${(r.pctWithin5 * 100).toStringAsFixed(1)}% of trials fell within ±5%
of the reference distance, ${r.pctWithin5 >= 0.75 ? 'meeting' : 'below'} the
75% criterion adopted from Gilgen-Ammann et al. (2020), who reported
MAPEs of 3.2%–6.1% for eight commercial GNSS sport watches under
comparable outdoor conditions."
══════════════════════════════════════════════════════════════════''');

      expect(r.n, greaterThan(0));
      expect(r.mape, allOf(greaterThanOrEqualTo(0), lessThan(double.infinity)));
    });
  });
}
