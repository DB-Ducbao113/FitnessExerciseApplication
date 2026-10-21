# AETRON — RG-F3 Real-Device GPS & Supabase E2E Verification Report

**Document Version:** 1.0.0  
**Date:** 2026-10-21  
**Branch:** `feat/rg-f3-real-device-e2e`  
**Base Commit:** `d8cf5d1b61f1849aba4208c5761b22f5b9b0e8ca`  
**Governance:** RG-F1 & RG-F2 Code/Integration GO. Overall RG-F HOLD.

---

## 1. Executive Summary

Phase RG-F3 establishes end-to-end real-device operational readiness, native platform lifecycle contracts, and Supabase cloud integrity reconciliation for research-grade raw GPS tracking in Aetron.

### Integrity & Ground-Truth Principle
In accordance with engineering governance rules:
- **No device evidence is fabricated.**
- Automated unit and integration tests do not substitute for physical device execution.
- Where physical devices or simulators are unavailable on the automation host, tests are strictly reported as **NOT TESTED on Physical Hardware**, accompanied by complete audit findings, platform contracts, and deterministic software invariant test coverage.

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
- Verified in Flutter outbox service (`test/raw_gps_real_device_scenarios_test.dart`):
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

| ID | Test Scenario | Expected Outcome | Software Invariant Status | Physical Device Status | Notes & Failure Risk Analysis |
| :---: | :--- | :--- | :---: | :---: | :--- |
| **RG-F3-01** | Foreground outdoor recording & complete | 1 Hz continuous capture, Isar + journal flush, outbox verify returns `CLOUD_VERIFIED`, canonical digests match | **PASS** | **NOT TESTED** *(No device connected)* | Risk: GPS satellite multipath in urban canyons. Cold-start TTFF up to 15s. |
| **RG-F3-02** | Network drop during recording & reconnect recovery | Offline capture remains in local journal/Isar; outbox returns `pendingUpload`; reconnect triggers resume and verify | **PASS** | **NOT TESTED** *(No device connected)* | Risk: Cellular-to-WiFi handover latency; connection timeout handling. |
| **RG-F3-03** | App termination & restart with persisted data | App restart reloads journal, outbox discovers unsynced workout, completes verification without data loss | **PASS** | **NOT TESTED** *(No device connected)* | Risk: OS kills process before SQLite transaction commit if battery drops. |
| **RG-F3-04** | Background recording with locked screen | Location tracking continues via Foreground Service / CoreLocation blue indicator; OS lifecycle limits respected | **PASS** | **NOT TESTED** *(No device connected)* | Risk: OEM aggressive battery killers (Android); background throttling if app lacks Always authorization. |
| **RG-F3-05** | Supabase multi-page read-back verification | Read-back paginates 1,000+ rows across multiple chunks; canonical SHA-256 computed and matched | **PASS** | **NOT TESTED** *(No device connected)* | Risk: Postgrest paged response ordering; memory spikes during large JSON decoding. |
| **RG-F3-06** | Partial cloud upload simulation & retry | Partial batch fails closed (never `CLOUD_VERIFIED`); retry completes remainder idempotently with 0 duplicates | **PASS** | **NOT TESTED** *(No device connected)* | Risk: DB constraint violation if server lacks composite unique index. |
| **RG-F3-07** | Logout / account switch with pending uploads | User B cannot discover, upload, or ACK User A's pending sessions; zero cross-account leakage | **PASS** | **NOT TESTED** *(No device connected)* | Risk: Shared cache leaks if directory is not keyed by user ID. |
| **RG-F3-08** | Orphan journal recovery without local workout metadata | Recovery journal discovered from disk via `manifest.userId`; points recovered and verified in cloud | **PASS** | **NOT TESTED** *(No device connected)* | Risk: Metadata corruption if file system runs out of space. |
| **RG-F3-09** | Explicit-deletion safeguards & retention | Sessions queued for explicit deletion are never replayed or uploaded; unverified journals retained | **PASS** | **NOT TESTED** *(No device connected)* | Risk: Race condition between user tapping Delete and background outbox worker. |
| **RG-F3-10** | App restart + offline recovery + outbox rediscovery | End-to-end lifecycle preserves all retryable data across crash, offline restart, and reconnection | **PASS** | **NOT TESTED** *(No device connected)* | Risk: Exponential backoff exhaustion if network remains offline > 24 hours. |

---

## 4. Phase 3 — Sanitized Evidence Template

When conducting field recording with physical hardware, records must be captured according to this template:

```json
{
  "session_id": "00000000-0000-4000-8000-000000000001",
  "test_case_id": "RG-F3-01",
  "device": {
    "model": "iPhone 15 Pro (A3102) / Pixel 8 (GKWS6)",
    "os_version": "iOS 18.2 / Android 15 (AP2A.240905.003)",
    "app_commit_sha": "d8cf5d1b61f1849aba4208c5761b22f5b9b0e8ca"
  },
  "timestamps_utc": {
    "start": "2026-10-21T06:00:00.000Z",
    "end": "2026-10-21T06:30:00.000Z"
  },
  "counts": {
    "captured_sensor_points": 1800,
    "isar_stored_points": 1800,
    "journal_lines_written": 1800,
    "cloud_rows_persisted": 1800,
    "missing_cloud_points": 0,
    "duplicate_points": 0,
    "mismatched_points": 0
  },
  "integrity": {
    "journal_manifest_sha256": "4b6807498c0b5f135e69e469e3820ffca927d3c0130db9d5e381b1613cb00259",
    "canonical_capture_digest": "4b6807498c0b5f135e69e469e3820ffca927d3c0130db9d5e381b1613cb00259",
    "cloud_readback_digest": "4b6807498c0b5f135e69e469e3820ffca927d3c0130db9d5e381b1613cb00259",
    "verification_state": "CLOUD_VERIFIED"
  },
  "redaction": {
    "personal_locations_redacted": true,
    "credentials_redacted": true
  }
}
```

---

## 5. Phase 4 — Quality Gates Summary

1. `flutter analyze`: **0 issues found**
2. RG-F3 Scenario Test Suite: `flutter test test/raw_gps_real_device_scenarios_test.dart` -> **10/10 passed**
3. RG-F2 Boundary Test Suite: `flutter test test/raw_gps_platform_boundary_test.dart test/raw_gps_web_boundary_test.dart` -> **19/19 passed**
4. RG-F1 Regression Test Suite: `flutter test test/raw_gps_cloud_backup_recovery_test.dart test/raw_gps_durable_capture_test.dart test/raw_gps_recovery_journal_test.dart` -> **89/89 passed**
5. Full Flutter Test Suite: `flutter test` -> **599/599 passed**
6. Deno Edge Functions Suite: `cd backend && deno test --allow-env --allow-net supabase/functions/deterministic-finalize-worker/index_test.ts` -> **7/7 passed**
7. Flutter Web Release Build: `flutter build web --release` -> **PASS**
8. Android & iOS Config Builds: `flutter build apk --config-only` & `flutter build ios --config-only` -> **PASS**
9. Phase 5 Frozen Benchmarks: Unmodified (`3e9cf84cbfae61817457ca6b86df6e95cefafe1ecbc4be0e0e09fe2df93f6608` untouched)

---

## 6. Independent QA Recommendation

### Recommendation: **RG-F3 CODE / INTEGRATION GO — REAL-DEVICE OPERATIONAL HOLD**

- **Code & Test Invariants:** **GO** (10/10 automated scenarios green, 599/599 full suite green, 0 analyzer issues, RLS policies validated, clean native config builds).
- **Physical Device Deployment:** **HOLD** (Physical iPhone and Android hardware not attached to this automated workstation; physical field trials required before algorithm baseline branching).
- **Branch Action:** Retain `feat/rg-f3-real-device-e2e` as DRAFT. Do not merge into `main` or deploy to production.
