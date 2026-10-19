import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Utilities for canonical IEEE-754 floating-point serialization.
class CanonicalFloatHelper {
  /// Converts a 64-bit double to a 16-character uppercase hexadecimal string
  /// representing its exact IEEE-754 binary64 representation in big-endian byte order.
  ///
  /// Canonicalization rules:
  /// - Any NaN is normalized to canonical quiet NaN `7FF8000000000000`.
  /// - Both +0.0 and -0.0 are normalized to `0000000000000000`.
  /// - All finite numbers and infinities preserve their exact 64-bit bit pattern.
  static String doubleToHex(double value) {
    if (value.isNaN) {
      return '7FF8000000000000';
    }
    if (value == 0.0) {
      return '0000000000000000';
    }
    final byteData = ByteData(8);
    byteData.setFloat64(0, value, Endian.big);
    final high = byteData.getUint32(0, Endian.big).toRadixString(16).toUpperCase().padLeft(8, '0');
    final low = byteData.getUint32(4, Endian.big).toRadixString(16).toUpperCase().padLeft(8, '0');
    return '$high$low';
  }

  /// Parses a 16-character hex string back into an IEEE-754 64-bit double.
  static double hexToDouble(String hex) {
    final byteData = ByteData(8);
    final high = int.parse(hex.substring(0, 8), radix: 16);
    final low = int.parse(hex.substring(8, 16), radix: 16);
    byteData.setUint32(0, high, Endian.big);
    byteData.setUint32(4, low, Endian.big);
    return byteData.getFloat64(0, Endian.big);
  }
}

/// Represents a single scheduled benchmark epoch record in canonical format.
class CanonicalEpochRecord {
  final String configId;
  final int scenarioId;
  final int sampleIndex;
  final int elapsedMs;
  final double latitude;
  final double longitude;
  final String fsmState;
  final String measurementDecision;
  final double addedDistanceMeters;
  final double accumulatedDistanceMeters;
  final bool wasResetApplied;
  final bool wasRollbackApplied;
  final double estimatedSpeedMs;
  final double estimatedHeadingDeg;
  final double positionVariance;

  const CanonicalEpochRecord({
    required this.configId,
    required this.scenarioId,
    required this.sampleIndex,
    required this.elapsedMs,
    required this.latitude,
    required this.longitude,
    required this.fsmState,
    required this.measurementDecision,
    required this.addedDistanceMeters,
    required this.accumulatedDistanceMeters,
    required this.wasResetApplied,
    required this.wasRollbackApplied,
    required this.estimatedSpeedMs,
    required this.estimatedHeadingDeg,
    required this.positionVariance,
  });

  /// Canonical pipe-delimited encoding with explicit field order and IEEE-754 hex representations:
  /// `E|<configId>|<scenarioId>|<sampleIndex>|<elapsedMs>|<latHex>|<lngHex>|<fsmState>|<decision>|<addedDistHex>|<accumDistHex>|<resetApplied>|<rollbackApplied>|<speedHex>|<headingHex>|<posVarHex>\n`
  String toCanonicalString() {
    return 'E|$configId|$scenarioId|$sampleIndex|$elapsedMs|'
        '${CanonicalFloatHelper.doubleToHex(latitude)}|'
        '${CanonicalFloatHelper.doubleToHex(longitude)}|'
        '$fsmState|$measurementDecision|'
        '${CanonicalFloatHelper.doubleToHex(addedDistanceMeters)}|'
        '${CanonicalFloatHelper.doubleToHex(accumulatedDistanceMeters)}|'
        '${wasResetApplied ? 1 : 0}|${wasRollbackApplied ? 1 : 0}|'
        '${CanonicalFloatHelper.doubleToHex(estimatedSpeedMs)}|'
        '${CanonicalFloatHelper.doubleToHex(estimatedHeadingDeg)}|'
        '${CanonicalFloatHelper.doubleToHex(positionVariance)}\n';
  }
}

/// Detailed fingerprint result for a single scenario (600 seconds).
class ScenarioFingerprint {
  final int scenarioId;
  final String description;
  final int sampleCount;
  final String canonicalSha256;
  final String legacyRoundedSha256;
  final double finalDistance;
  final String finalDistanceHex;

  const ScenarioFingerprint({
    required this.scenarioId,
    required this.description,
    required this.sampleCount,
    required this.canonicalSha256,
    required this.legacyRoundedSha256,
    required this.finalDistance,
    required this.finalDistanceHex,
  });

  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        'description': description,
        'sample_count': sampleCount,
        'canonical_sha256': canonicalSha256,
        'legacy_rounded_sha256': legacyRoundedSha256,
        'final_distance_meters': finalDistance,
        'final_distance_hex': finalDistanceHex,
      };
}

/// Detailed fingerprint result for a complete benchmark configuration (108 scenarios / 75,600 epochs).
class ConfigurationFingerprint {
  final String configId;
  final String configName;
  final int totalScenarios;
  final int totalScheduledEpochs;
  final String canonicalEpochStreamSha256;
  final String canonicalScenarioCompositeSha256;
  final String legacyRoundedSha256;
  final List<ScenarioFingerprint> scenarioFingerprints;

  const ConfigurationFingerprint({
    required this.configId,
    required this.configName,
    required this.totalScenarios,
    required this.totalScheduledEpochs,
    required this.canonicalEpochStreamSha256,
    required this.canonicalScenarioCompositeSha256,
    required this.legacyRoundedSha256,
    required this.scenarioFingerprints,
  });

  Map<String, dynamic> toJson() => {
        'config_id': configId,
        'config_name': configName,
        'total_scenarios': totalScenarios,
        'total_scheduled_epochs': totalScheduledEpochs,
        'canonical_epoch_stream_sha256': canonicalEpochStreamSha256,
        'canonical_scenario_composite_sha256': canonicalScenarioCompositeSha256,
        'legacy_rounded_sha256': legacyRoundedSha256,
        'scenario_fingerprints':
            scenarioFingerprints.map((s) => s.toJson()).toList(),
      };
}

/// Fingerprint accumulator for a single configuration during benchmark execution.
class ConfigurationFingerprintAccumulator {
  final String configId;
  final String configName;

  final StringBuffer _canonicalStreamBuffer = StringBuffer();
  final StringBuffer _legacyBuffer = StringBuffer();

  final List<ScenarioFingerprint> _scenarios = [];
  StringBuffer _currentScenarioCanonicalBuffer = StringBuffer();
  StringBuffer _currentScenarioLegacyBuffer = StringBuffer();
  int _currentScenarioSampleCount = 0;

  ConfigurationFingerprintAccumulator({
    required this.configId,
    required this.configName,
  });

  void startScenario(int scenarioId) {
    _currentScenarioCanonicalBuffer = StringBuffer();
    _currentScenarioLegacyBuffer = StringBuffer();
    _currentScenarioSampleCount = 0;
  }

  void recordEpoch(CanonicalEpochRecord record) {
    final canonicalLine = record.toCanonicalString();
    _currentScenarioCanonicalBuffer.write(canonicalLine);
    _canonicalStreamBuffer.write(canonicalLine);
    _currentScenarioSampleCount++;

    // Mirror legacy rounded hashing: lat.toStringAsFixed(5),lng.toStringAsFixed(5);
    final legacyChunk = '${record.latitude.toStringAsFixed(5)},'
        '${record.longitude.toStringAsFixed(5)};';
    _currentScenarioLegacyBuffer.write(legacyChunk);
    _legacyBuffer.write(legacyChunk);
  }

  void endScenario({
    required int scenarioId,
    required String description,
    required double finalDistanceMeters,
  }) {
    // Append scenario suffix to legacy buffer: S$scenarioId:${finalDist.toStringAsFixed(2)};
    final legacySuffix = 'S$scenarioId:${finalDistanceMeters.toStringAsFixed(2)};';
    _currentScenarioLegacyBuffer.write(legacySuffix);
    _legacyBuffer.write(legacySuffix);

    final scenCanonicalSha = sha256
        .convert(utf8.encode(_currentScenarioCanonicalBuffer.toString()))
        .toString();
    final scenLegacySha = sha256
        .convert(utf8.encode(_currentScenarioLegacyBuffer.toString()))
        .toString();

    _scenarios.add(ScenarioFingerprint(
      scenarioId: scenarioId,
      description: description,
      sampleCount: _currentScenarioSampleCount,
      canonicalSha256: scenCanonicalSha,
      legacyRoundedSha256: scenLegacySha,
      finalDistance: finalDistanceMeters,
      finalDistanceHex: CanonicalFloatHelper.doubleToHex(finalDistanceMeters),
    ));
  }

  ConfigurationFingerprint finalizeFingerprint() {
    // Direct stream hash across all 75,600 canonical epoch records
    final streamSha256 = sha256
        .convert(utf8.encode(_canonicalStreamBuffer.toString()))
        .toString();

    // Composite hash across ordered scenario hashes:
    // sha256(scenHash_1\nscenHash_2\n...\nscenHash_108\n)
    final compositeBuffer = StringBuffer();
    for (final s in _scenarios) {
      compositeBuffer.write('${s.canonicalSha256}\n');
    }
    final compositeSha256 =
        sha256.convert(utf8.encode(compositeBuffer.toString())).toString();

    // Legacy rounded digest
    final legacySha256 =
        sha256.convert(utf8.encode(_legacyBuffer.toString())).toString();

    return ConfigurationFingerprint(
      configId: configId,
      configName: configName,
      totalScenarios: _scenarios.length,
      totalScheduledEpochs:
          _scenarios.fold(0, (acc, s) => acc + s.sampleCount),
      canonicalEpochStreamSha256: streamSha256,
      canonicalScenarioCompositeSha256: compositeSha256,
      legacyRoundedSha256: legacySha256,
      scenarioFingerprints: List.unmodifiable(_scenarios),
    );
  }
}
