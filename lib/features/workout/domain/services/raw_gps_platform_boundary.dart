import 'package:flutter/foundation.dart';

/// Target platforms evaluated for research-grade raw GPS capture and recovery.
enum RawGpsTargetPlatform {
  android,
  ios,
  web,
  other;

  String get label => switch (this) {
    RawGpsTargetPlatform.android => 'Android',
    RawGpsTargetPlatform.ios => 'iOS',
    RawGpsTargetPlatform.web => 'Flutter Web',
    RawGpsTargetPlatform.other => 'Desktop / Other',
  };
}

/// Platform capability and boundary descriptor for research-grade raw GPS operations (RG-F2).
///
/// Guarantees:
/// - iOS: Primary target. Durable raw GPS capture (Isar + JSONL journal), background tracking
///   with AppleSettings, foreground/startup outbox sync, local recovery, cable-free export.
/// - Android: Secondary native target. Durable capture, foreground notification + wakelock,
///   outbox sync, local recovery.
/// - Flutter Web: UNSUPPORTED for research-grade raw GPS capture. No local Isar database, no
///   direct JSONL filesystem journal, no background execution. Web uses lightweight route
///   snapshots for UI display without claiming durable raw persistence or false cloud verification.
class RawGpsPlatformCapability {
  final RawGpsTargetPlatform platform;
  final bool isResearchGradeCaptureSupported;
  final bool supportsDurableIsar;
  final bool supportsRecoveryJournal;
  final bool supportsBackgroundLocation;
  final bool supportsCloudOutbox;
  final bool supportsLocalRecovery;
  final String description;
  final String backgroundExecutionContract;

  const RawGpsPlatformCapability({
    required this.platform,
    required this.isResearchGradeCaptureSupported,
    required this.supportsDurableIsar,
    required this.supportsRecoveryJournal,
    required this.supportsBackgroundLocation,
    required this.supportsCloudOutbox,
    required this.supportsLocalRecovery,
    required this.description,
    required this.backgroundExecutionContract,
  });

  /// Current platform capabilities determined at runtime.
  static RawGpsPlatformCapability get current {
    if (kIsWeb) {
      return forPlatform(RawGpsTargetPlatform.web);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return forPlatform(RawGpsTargetPlatform.ios);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return forPlatform(RawGpsTargetPlatform.android);
    }
    return forPlatform(RawGpsTargetPlatform.other);
  }

  /// Capability matrix entry for [platform].
  static RawGpsPlatformCapability forPlatform(RawGpsTargetPlatform platform) {
    return switch (platform) {
      RawGpsTargetPlatform.ios => const RawGpsPlatformCapability(
        platform: RawGpsTargetPlatform.ios,
        isResearchGradeCaptureSupported: true,
        supportsDurableIsar: true,
        supportsRecoveryJournal: true,
        supportsBackgroundLocation: true,
        supportsCloudOutbox: true,
        supportsLocalRecovery: true,
        description:
            'iOS: Primary target. Full research-grade raw GPS pipeline with dual local persistence (Isar + JSONL), AppleSettings background tracking, outbox sync, and canonical verification.',
        backgroundExecutionContract:
            'CoreLocation background mode with AppleSettings. Background execution is platform-dependent and is NOT guaranteed if the user force-quits the app from the app switcher or the OS terminates the process under severe memory pressure.',
      ),
      RawGpsTargetPlatform.android => const RawGpsPlatformCapability(
        platform: RawGpsTargetPlatform.android,
        isResearchGradeCaptureSupported: true,
        supportsDurableIsar: true,
        supportsRecoveryJournal: true,
        supportsBackgroundLocation: true,
        supportsCloudOutbox: true,
        supportsLocalRecovery: true,
        description:
            'Android: Secondary native target. Full raw GPS pipeline with Isar + JSONL persistence, foreground notification wakelock, outbox sync, and canonical verification.',
        backgroundExecutionContract:
            'Foreground Service notification and partial wakelock. Background execution is platform-dependent and is NOT guaranteed if the app is swiped away from recents or terminated by aggressive OEM battery optimization.',
      ),
      RawGpsTargetPlatform.web => const RawGpsPlatformCapability(
        platform: RawGpsTargetPlatform.web,
        isResearchGradeCaptureSupported: false,
        supportsDurableIsar: false,
        supportsRecoveryJournal: false,
        supportsBackgroundLocation: false,
        supportsCloudOutbox: false,
        supportsLocalRecovery: false,
        description:
            'Flutter Web: Explicitly descoped. Local Isar, file system journals, and background tracking are unavailable. Standard workout recording continues via lightweight route snapshots without claiming raw GPS durability.',
        backgroundExecutionContract:
            'Flutter Web does not support background location execution. Browser tabs are aggressively throttled or suspended when minimized or hidden, and no OS background service capability exists.',
      ),
      RawGpsTargetPlatform.other => const RawGpsPlatformCapability(
        platform: RawGpsTargetPlatform.other,
        isResearchGradeCaptureSupported: false,
        supportsDurableIsar: false,
        supportsRecoveryJournal: false,
        supportsBackgroundLocation: false,
        supportsCloudOutbox: false,
        supportsLocalRecovery: false,
        description:
            'Desktop / Other: Fallback platform. Research-grade raw GPS capture is disabled.',
        backgroundExecutionContract:
            'Desktop platforms do not provide mobile background location services.',
      ),
    };
  }

  /// Full platform support matrix for auditing and documentation.
  static Map<RawGpsTargetPlatform, RawGpsPlatformCapability> get supportMatrix => {
    for (final p in RawGpsTargetPlatform.values) p: forPlatform(p),
  };

  Map<String, dynamic> toJson() => {
    'platform': platform.name,
    'label': platform.label,
    'research_grade_supported': isResearchGradeCaptureSupported,
    'durable_isar': supportsDurableIsar,
    'recovery_journal': supportsRecoveryJournal,
    'background_location': supportsBackgroundLocation,
    'cloud_outbox': supportsCloudOutbox,
    'local_recovery': supportsLocalRecovery,
    'description': description,
    'background_execution_contract': backgroundExecutionContract,
  };
}
