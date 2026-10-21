# AETRON — RG-F3 Real-Device GPS & Supabase E2E Verification Report

**Document Version:** 1.1.0  
**Date:** 2026-10-21  
**Branch:** `feat/rg-f3-real-device-e2e`  
**Base Commit:** `fa08471f723f1e44b0796a508f705e770265919b`  
**Runbook Document:** [rg_f3_field_test_runbook.md](file:///Users/baobungbu/Aetron/docs/operations/rg_f3_field_test_runbook.md)  
**Verification Tooling:** [verify_field_evidence.dart](file:///Users/baobungbu/Aetron/tooling/verify_field_evidence.dart)  
**Governance:** RG-F1 & RG-F2 Code/Integration GO. Overall RG-F HOLD.

---

## 1. Executive Summary

Phase RG-F3 establishes end-to-end real-device operational readiness, native platform lifecycle contracts, and Supabase cloud integrity reconciliation for research-grade raw GPS tracking in Aetron.

### Ground-Truth & Anti-Fabrication Principles
1. **No Simulated Data as Field Evidence:** Simulated in-memory mock runs verify software invariants and state machine transitions, but must NEVER be claimed as physical device proof.
2. **Explicit Separation of Results:** Every scenario strictly separates automated simulated test results from physical-device field measurements.
3. **Hardware Availability:** Physical iPhone and Android hardware are not connected to this automated workstation. Physical execution is explicitly reported as **NOT TESTED on Physical Hardware (Pending Field Execution)**.
4. **Independent Cryptographic Proofs:** The raw JSONL file checksum (`file_sha256`) and the versioned canonical capture digest (`canonical_capture_digest`) are kept strictly separate.

---

## 2. Phase 1 — Test Readiness Audit

### 2.1 Native iOS and Android Permissions, Modes & Lifecycle

| Dimension | iOS Native Audit | Android Native Audit |
| :--- | :--- | :--- |
| **Permissions Declared** | `NSLocationWhenInUseUsageDescription`<br>`NSLocationAlwaysAndWhenInUseUsageDescription`<br>`NSLocationAlwaysUsageDescription`<br>`NSMotionUsageDescription` | `ACCESS_FINE_LOCATION`<br>`ACCESS_COARSE_LOCATION`<br>`ACCESS_BACKGROUND_LOCATION`<br>`ACTIVITY_RECOGNITION`<br>`FOREGROUND_SERVICE`<br>`FOREGROUND_SERVICE_LOCATION`<br>`FOREGROUND_SERVICE_HEALTH`<br>`WAKE_LOCK`<br>`RECEIVE_BOOT_COMPLETED` |
| **Background Modes** | `UIBackgroundModes`: `location`, `processing`<br>`NSSupportsLiveActivities`: `true`<br>`NSSupportsLiveActivitiesFrequentUpdates`: `true` | `ForegroundNotificationConfig`: Ongoing notification titled *'Fitness Tracker'* with `enableWakeLock: true` |
| **Location Settings** | `AppleSettings`:<br>• `accuracy: LocationAccuracy.bestForNavigation`<br>• `distanceFilter: 0`<br>• `activityType: ActivityType.fitness`<br>• `pauseLocationUpdatesAutomatically: false`<br>• `allowBackgroundLocationUpdates: true`<br>• `showBackgroundLocationIndicator: true` (Blue status pill) | `AndroidSettings`:<br>• `accuracy: LocationAccuracy.bestForNavigation`<br>• `distanceFilter: 0`<br>• `intervalDuration: 500ms`<br>• `forceLocationManager: false` (uses FusedLocationProviderClient) |
| **Local Storage Path** | Application Documents Directory (`path_provider`):<br>`<Application_Home>/Documents/raw_gps_recovery/` | Scoped Internal Storage:<br>`/data/user/0/com.aetron.app/app_flutter/raw_gps_recovery/` |
| **Storage Engines** | • Isar DB: `workout_gps_point` local cache<br>• Write-Ahead Journal: Append-only JSONL files + `.manifest.json`<br>• SQLite: `LocalWorkout` metadata & outbox tracking | • Isar DB: `workout_gps_point` local cache<br>• Write-Ahead Journal: Append-only JSONL files + `.manifest.json`<br>• SQLite: `LocalWorkout` metadata & outbox tracking |
| **Process Termination Contract** | **Background Execution:** Permitted while active session runs with blue indicator.<br>**Termination:** If user force-quits app (swipes away in app switcher) or iOS jetsam OOM-kills the process, the Dart VM terminates immediately. In-flight memory points are dropped; previously flushed points in WAL/journal survive. | **Background Execution:** Permitted via Foreground Service with ongoing notification.<br>**Termination:** If app is swiped away from recents or killed by aggressive OEM battery managers (e.g., Xiaomi MIUI / Samsung OneUI), background capture ceases. Durably persisted journal records survive. |

---

### 2.2 Supabase Test Environment & RLS Audit

1. **Table Schema (`public.raw_gps_points`):**
   - Columns: `id (bigint generated)`, `workout_id (uuid)`, `user_id (uuid)`, `timestamp (timestamptz)`, `latitude (float8)`, `longitude (float8)`, `altitude (float8)`, `speed (float8)`, `accuracy (float8)`, `heading (float8)`, `device_source (text)`, `created_at (timestamptz)`.
   - Idempotency Constraint: `idx_raw_gps_points_unique_sample UNIQUE (workout_id, timestamp, latitude, longitude)`.
   - Indexes: `idx_raw_gps_points_workout (workout_id)`, `idx_raw_gps_points_workout_timestamp (workout_id, timestamp)`.

2. **Row-Level Security (RLS) Policies:**
   - `alter table public.raw_gps_points enable row level security;`
   - **SELECT Policy:** `raw_gps_points: select own` (`where exists (select 1 from workout_sessions ws where ws.id = raw_gps_points.workout_id and ws.user_id = auth.uid())`).
   - **INSERT Policy:** `raw_gps_points: insert own` (`where exists (select 1 from workout_sessions ws where ws.id = raw_gps_points.workout_id and ws.user_id = auth.uid())`).
   - **DELETE Policy:** `raw_gps_points: delete own` (`where exists (select 1 from workout_sessions ws where ws.id = raw_gps_points.workout_id and ws.user_id = auth.uid())`).

3. **Backend Tests:**
   - Database migrations and RLS policies tested via `backend/supabase/tests/database_rls_test.sql` in CI container.
   - Edge function `deterministic-finalize-worker` tests pass (7/7 tests green).

---

### 2.3 Test-Account Isolation Audit

- Verified in SQL integration tests (`backend/supabase/tests/database_rls_test.sql`):
  - User A authenticated query sees 0 rows from User B.
  - User A attempt to insert raw GPS point into User B's workout session is rejected with `insufficient_privilege`.
  - User A attempt to delete User B's raw GPS points affects 0 rows.
- Verified in Flutter outbox service ([test/raw_gps_real_device_scenarios_test.dart](file:///Users/baobungbu/Aetron/test/raw_gps_real_device_scenarios_test.dart)):
  - Outbox session discovery explicitly checks `manifest.userId == currentUserId`.
  - If a journal belongs to a foreign user, it is rejected and excluded from the upload queue.
  - Foreign sessions cannot be claimed, replayed, or acknowledged.

---

### 2.4 Native Build and Signing Configuration

1. **iOS Signing & Configuration:**
   - Bundle ID: `com.aetron.app`
   - Development Team: `ZDR9AX4U8V`
   - Build Verification: `flutter build ios --config-only` **SUCCEEDED** (Exit Code 0).
   - Prerequisite Note: Installing to an untethered physical iPhone requires an active Apple Developer Certificate and registered device provisioning profile in Xcode.

2. **Android Signing & Configuration:**
   - Application ID: `com.aetron.app`
   - SDK Target: `compileSdk 36`, `targetSdk 36`, `minSdk 24`
   - Build Verification: `flutter build apk --config-only` **SUCCEEDED** (Exit Code 0).
   - Signing Configuration: `key.properties` is omitted from repo (standard security practice); builds automatically fall back to debug signing (`signingConfigs.debug`).

---

### 2.5 Automated Host Toolchain Prerequisites Report

```
Host Operating System: macOS 27.0.1 26A434 (darwin-arm64)
Flutter SDK: 3.47.1 (Channel stable, Dart 3.13.1)
Xcode: 27.1 (Build 27A9275)

[!] Connected Physical Devices:
    • macOS (desktop)  -> Desktop runner available
    • Chrome (web)     -> Browser runner available
    • iPhone Physical  -> NOT CONNECTED
    • Android Physical -> NOT CONNECTED
    • ADB Tool         -> NOT INSTALLED (zsh: command not found: adb)
    • iOS 27.1 Sim     -> NOT INSTALLED (Xcode simulator runtime missing)
    • Docker Engine    -> INACTIVE on host (docker.sock not found)
```

> [!WARNING]
> **Prerequisites That Cannot Be Fulfilled Automatically:**
> 1. Physical iPhone and Android hardware must be physically connected to the developer workstation via USB/wireless debugging with active location permissions granted.
> 2. Real physical device testing (outdoor movement, screen locks, airplane mode toggles) requires human physical interaction in the field.
> 3. These scenarios are marked **NOT TESTED on Physical Hardware** below. Software invariants have been 100% verified via automated scenario testing.

---

## 3. Phase 2 — Real-Device Test Matrix

| ID | Test Scenario | Expected Outcome | Simulated Invariant Test (CI) | Physical Device Field Execution | Notes & Failure Risk Analysis |
| :---: | :--- | :--- | :---: | :---: | :--- |
| **RG-F3-01** | Foreground outdoor recording & complete | 1 Hz continuous capture, Isar + journal flush, outbox verify returns `CLOUD_VERIFIED`, canonical digests match | **PASS** *(60/60 points)* | **NOT TESTED** *(Pending Field Run)* | Risk: GPS satellite multipath in urban canyons. Cold-start TTFF up to 15s. |
| **RG-F3-02** | Network drop during recording & reconnect recovery | Offline capture remains in local journal/Isar; outbox returns `pendingUpload`; reconnect triggers resume and verify | **PASS** *(30/30 points)* | **NOT TESTED** *(Pending Field Run)* | Risk: Cellular-to-WiFi handover latency; connection timeout handling. |
| **RG-F3-03** | App termination & restart with persisted data | App restart reloads journal, outbox discovers unsynced workout, completes verification without data loss | **PASS** *(20/20 points)* | **NOT TESTED** *(Pending Field Run)* | Risk: OS kills process before SQLite transaction commit if battery drops. |
| **RG-F3-04** | Background recording with locked screen | Location tracking continues via Foreground Service / CoreLocation blue indicator; OS lifecycle limits respected | **PASS** *(Contract verified)* | **NOT TESTED** *(Pending Field Run)* | Risk: OEM aggressive battery killers (Android); background throttling if app lacks Always authorization. |
| **RG-F3-05** | Supabase multi-page read-back verification | Read-back paginates 1,200 rows across multiple chunks; canonical SHA-256 computed and matched | **PASS** *(1,200/1,200 points)* | **NOT TESTED** *(Pending Field Run)* | Risk: Postgrest paged response ordering; memory spikes during large JSON decoding. |
| **RG-F3-06** | Partial cloud upload simulation & retry | Partial batch fails closed (never `CLOUD_VERIFIED`); retry completes remainder idempotently with 0 duplicates | **PASS** *(50/50 points, 0 dupes)* | **NOT TESTED** *(Pending Field Run)* | Risk: DB constraint violation if server lacks composite unique index. |
| **RG-F3-07** | Logout / account switch with pending uploads | User B cannot discover, upload, or ACK User A's pending sessions; zero cross-account leakage | **PASS** *(0 leaked sessions)* | **NOT TESTED** *(Pending Field Run)* | Risk: Shared cache leaks if directory is not keyed by user ID. |
| **RG-F3-08** | Orphan journal recovery without local workout metadata | Recovery journal discovered from disk via `manifest.userId`; points recovered and verified in cloud | **PASS** *(25/25 points)* | **NOT TESTED** *(Pending Field Run)* | Risk: Metadata corruption if file system runs out of space. |
| **RG-F3-09** | Explicit-deletion safeguards & retention | Sessions queued for explicit deletion are never replayed or uploaded; unverified journals retained | **PASS** *(0 replayed deletions)* | **NOT TESTED** *(Pending Field Run)* | Risk: Race condition between user tapping Delete and background outbox worker. |
| **RG-F3-10** | App restart + offline recovery + outbox rediscovery | End-to-end lifecycle preserves all retryable data across crash, offline restart, and reconnection | **PASS** *(40/40 points)* | **NOT TESTED** *(Pending Field Run)* | Risk: Exponential backoff exhaustion if network remains offline > 24 hours. |

---

## 4. Phase 3 — Sanitized Field Evidence Template

When conducting field recording with physical hardware, records must be captured according to this template using explicit placeholders (populated via `tooling/verify_field_evidence.dart`):

```json
{
  "session_id": "<SESSION_UUID>",
  "test_case_id": "<RG-F3-01..10>",
  "device": {
    "model": "<PHYSICAL_DEVICE_MODEL>",
    "os_version": "<DEVICE_OS_VERSION>",
    "app_commit_sha": "<APP_COMMIT_SHA>"
  },
  "timestamps_utc": {
    "start": "<START_TIMESTAMP_UTC_ISO8601>",
    "end": "<END_TIMESTAMP_UTC_ISO8601>"
  },
  "counts": {
    "captured_sensor_points": "<ACTUAL_CAPTURED_POINT_COUNT>",
    "isar_stored_points": "<ACTUAL_ISAR_STORED_COUNT>",
    "journal_lines_written": "<ACTUAL_JOURNAL_LINE_COUNT>",
    "cloud_rows_persisted": "<ACTUAL_SUPABASE_ROW_COUNT>",
    "missing_cloud_points": 0,
    "duplicate_cloud_points": 0,
    "mismatched_points": 0
  },
  "integrity": {
    "raw_jsonl_file_sha256": "<RAW_JSONL_FILE_BYTE_SHA256_HEX>",
    "manifest_file_sha256": "<MANIFEST_FILE_SHA256_HEX>",
    "raw_file_sha_matches_manifest": true,
    "canonical_capture_digest": "<CANONICAL_CAPTURE_DIGEST_SHA256_HEX>",
    "manifest_capture_digest": "<MANIFEST_CANONICAL_CAPTURE_DIGEST_HEX>",
    "manifest_capture_digest_valid": true,
    "cloud_readback_digest": "<CLOUD_READBACK_CANONICAL_DIGEST_HEX>",
    "cloud_digest_matches_capture": true,
    "verification_state": "CLOUD_VERIFIED"
  },
  "redaction": {
    "personal_locations_redacted": true,
    "credentials_redacted": true
  }
}
```

> [!NOTE]
> **Integrity Separation Note:**
> `raw_jsonl_file_sha256` represents the cryptographic SHA-256 byte checksum of the physical `.jsonl` file on local flash storage.
> `canonical_capture_digest` represents the versioned canonical SHA-256 digest of the sorted canonical telemetry lines (`v1|workout_id|timestamp|lat|lng|alt|speed|acc|head|src`).
> These two hashes are distinct and must never be conflated.

---

## 5. Phase 4 — Quality Gates Summary

1. `flutter analyze`: **0 issues found**
2. RG-F3 Scenario Test Suite: [test/raw_gps_real_device_scenarios_test.dart](file:///Users/baobungbu/Aetron/test/raw_gps_real_device_scenarios_test.dart) -> **10/10 passed**
3. RG-F2 Boundary Test Suite: `test/raw_gps_platform_boundary_test.dart test/raw_gps_web_boundary_test.dart` -> **19/19 passed**
4. RG-F1 Regression Test Suite: `test/raw_gps_cloud_backup_recovery_test.dart test/raw_gps_durable_capture_test.dart test/raw_gps_recovery_journal_test.dart` -> **89/89 passed**
5. Full Flutter Test Suite: `flutter test` -> **599/599 passed**
6. Deno Edge Functions Suite: `cd backend && deno test --allow-env --allow-net supabase/functions/deterministic-finalize-worker/index_test.ts` -> **7/7 passed**
7. Flutter Web Release Build: `flutter build web --release` -> **PASS**
8. Android & iOS Config Builds: `flutter build apk --config-only` & `flutter build ios --config-only` -> **PASS**
9. Standalone Verification CLI Tool: [tooling/verify_field_evidence.dart](file:///Users/baobungbu/Aetron/tooling/verify_field_evidence.dart) -> **PASS**
10. GitHub Actions CI Run: [39531710480](https://github.com/DB-Ducbao113/FitnessExerciseApplication/actions/runs/39531710480) on exact commit `fa08471f723f1e44b0796a508f705e770265919b`:
    - `Database migrations, lint and RLS tests`: **success** 🟢
    - `Flutter analyze and test`: **success** 🟢
    - `Deno lint, type-check and test`: **success** 🟢
    - `Dependency, secret and config scan`: **success** 🟢
11. Phase 5 Frozen Benchmarks: Unmodified (`3e9cf84cbfae61817457ca6b86df6e95cefafe1ecbc4be0e0e09fe2df93f6608` untouched).

---

## 6. Independent QA Recommendation

### Recommendation: **RG-F3 CODE / INTEGRATION GO — REAL-DEVICE OPERATIONAL HOLD**

- **Code & Test Invariants:** **GO** (10/10 automated scenarios green, 599/599 full suite green, 0 analyzer issues, RLS policies validated, clean native config builds, CLI verification tool available).
- **Physical Device Deployment:** **HOLD** (Physical iPhone and Android hardware not attached to this automated workstation; physical field trials required following [rg_f3_field_test_runbook.md](file:///Users/baobungbu/Aetron/docs/operations/rg_f3_field_test_runbook.md) before lifting the RG-F HOLD or proceeding with algorithm baseline branching).
- **Branch Action:** Retain `feat/rg-f3-real-device-e2e` and stacked [PR #10](https://github.com/DB-Ducbao113/FitnessExerciseApplication/pull/10) as DRAFT. Do not merge into `main` or deploy to production.
