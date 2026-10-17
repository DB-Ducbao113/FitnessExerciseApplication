import 'dart:convert';
import 'dart:io';

import 'package:fitness_exercise_application/features/workout/domain/services/benchmark/gps_benchmark_cli.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CLI writes a coordinate-free report for all approved variants',
    () async {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'aetron-gps-benchmark-',
      );
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      final outputPath = '${tempDirectory.path}/report.json';
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      final code = await runGpsBenchmarkCli(
        [
          '--activity',
          'cycling',
          '--input',
          'test/fixtures/gps/anonymized_raw_gps_trace.jsonl',
          '--output',
          outputPath,
        ],
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
      );

      expect(code, 0);
      expect(stderrBuffer.toString(), isEmpty);
      expect(stdoutBuffer.toString(), contains(outputPath));
      final reportText = File(outputPath).readAsStringSync();
      final report = jsonDecode(reportText) as Map<String, dynamic>;
      expect(report['schema_version'], 2);
      expect(report['evidence_kind'], 'field_development_no_ground_truth');
      expect(report['algorithm_version'], 'phase4a-adaptive-q-turn-motion');
      expect(report['config_fingerprint'], isNotEmpty);
      expect(report['dataset_id'], 'fixture-workout');
      expect(
        DateTime.tryParse(report['generated_at_utc'] as String),
        isNotNull,
      );
      expect((report['variants'] as Map<String, dynamic>), hasLength(4));
      final current =
          (report['variants'] as Map<String, dynamic>)['current']
              as Map<String, dynamic>;
      final latency = current['processing_latency'] as Map<String, dynamic>;
      expect(latency['measured_run_count'], 5);
      expect(latency['median_microseconds_per_point'], greaterThanOrEqualTo(0));
      final ekf =
          (report['variants'] as Map<String, dynamic>)['ekf']
              as Map<String, dynamic>;
      expect(ekf['position_decision_counts'], isNotNull);
      final decisions = ekf['position_decision_counts'] as Map<String, dynamic>;
      expect(decisions.containsKey('normal'), isTrue);
      expect(reportText, isNot(contains('latitude')));
      expect(reportText, isNot(contains('longitude')));

      final traceFile = File('$outputPath.trace.jsonl');
      expect(traceFile.existsSync(), isTrue);
      final traceText = traceFile.readAsStringSync();
      expect(traceText, contains('timestamp'));
      expect(traceText, contains('rejection_reason'));
      expect(traceText, contains('position_decision'));
      expect(traceText, isNot(contains('latitude')));
      expect(traceText, isNot(contains('longitude')));
    },
  );

  test('CLI returns usage error when required arguments are missing', () async {
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final code = await runGpsBenchmarkCli(
      const ['--activity', 'cycling'],
      stdoutSink: stdoutBuffer,
      stderrSink: stderrBuffer,
    );

    expect(code, 64);
    expect(stdoutBuffer.toString(), isEmpty);
    expect(stderrBuffer.toString(), contains('Usage:'));
  });
}
