# AETRON — ALG-0 Real Historical Raw GPS Dataset Inventory & Quality Baseline

**Document Version:** 1.1.0  
**Date:** 2026-10-21  
**Target:** Algorithm Research Common Baseline (Phase ALG-0 Closeout)  
**Branch:** `feat/rg-f4-dataset-export`  
**Tooling:** [`tooling/inventory_historical_datasets.dart`](file:///Users/baobungbu/Aetron/tooling/inventory_historical_datasets.dart)  
**Governance:** RG-F4 Code/Integration GO. Overall RG-F HOLD (Pending physical multi-device GPS validation). PR #11 remains DRAFT.

---

## 1. Executive Summary & Core Mission

Phase **ALG-0** establishes the authenticated real historical raw GPS dataset baseline and inventory for Aetron. Prior to evaluating algorithm candidates (such as Extended Kalman Filter, DBSCAN stop-detection, Hidden Markov Model map-matching, or IMU Pedestrian Dead Reckoning), all existing datasets must be inventoried, classified by data quality, and labeled with unambiguous provenance.

A database-level project aggregate has confirmed that the Aetron Supabase database contains **10,907 raw GPS samples across 11 sessions belonging to two distinct user accounts**. These represent global project totals, **not** confirmed totals for the currently authenticated user session.

### Core Scientific Principles & Security Invariants
1. **Zero Unfounded Error Claims (Anti-Fabrication):**
   > [!IMPORTANT]
   > Ground-truth positional error (RMSE and P95) is **STRICTLY REFUSED** and marked `groundTruthErrorDisallowed: true`. Without an independent survey-grade reference track (e.g., dual-frequency RTK-GNSS rover or known surveyed geometry), raw smartphone GPS cannot be treated as its own ground truth.
2. **Authenticated Discovery & Row Level Security (ALG-0.1):**
   - Discovery is strictly scoped to the authenticated user via Supabase Auth and RLS (`auth.uid() = user_id`).
   - Admin/service-role credentials must **never** be used to fabricate an allegedly user-scoped dataset.
   - Comprehensive discovery auditing tracks discovered, GPS-bearing, exported, missing, and denied sessions without silent error suppression.
3. **Rigorous Provenance Verification (ALG-0.2):**
   - Sessions are labeled `device_journal_verified` **only** when accompanied by a signed manifest containing matching owner ID, matching byte SHA-256, and canonical capture digest.
   - Sessions without full local cryptographic proof are labeled conservatively (`device_recovered_unverified` or `cloud_only_unverified`).
   - Synthetic test fixtures (`synthetic_fixture`) and algorithm-filtered tracks (`algorithm_filtered`) are explicitly identified and **strictly excluded from field-research aggregate statistics**.
4. **Lossless Master Export & Parity Replay (ALG-0.3):**
   - Master exports are deterministic JSONL with companion CSV, GPX 1.1, and JSON manifests.
   - Every export bundle automatically verifies 100% field parity through lossless round-trip replay ([`RawGpsDatasetExporter.verifyJsonlLosslessReplay`](file:///Users/baobungbu/Aetron/lib/features/workout/domain/services/raw_gps_dataset_exporter.dart)).
5. **Path Traversal & Secrets Hardening:**
   - All session IDs are validated against strict alphanumeric/hyphen/underscore patterns (`^[a-zA-Z0-9_\-]+$`) before being used in output file paths.
   - Hardcoded commit fallbacks are eliminated; raw coordinates and JWT authentication tokens are prevented from entering CI logs.

---

## 2. Statistical Profiling & Quality Baseline Methodology

The automated analyzer ([`RawGpsQualityAnalyzer`](file:///Users/baobungbu/Aetron/lib/features/workout/domain/services/raw_gps_quality_analyzer.dart)) evaluates each session across quantitative telemetry dimensions:

| Dimension | Metric Evaluated | Healthy Baseline Threshold | Degradation Indicator |
|---|---|:---:|:---:|
| **Sampling Interval** | Delta-t ($\Delta t$) between successive points | $1.0\text{s} \pm 0.15\text{s}$ (Median & P95 reported) | Jitter $> 0.5\text{s}$, non-monotonic timestamps |
| **Outage Gaps** | Signal loss gaps $> 15.0\text{s}$ and $> 30.0\text{s}$ | $0$ gaps | Gaps $> 30\text{s}$ (degraded), $> 300\text{s}$ (unusable) |
| **Speed Bounds** | Instantaneous ground speed | $0.5 - 15.0\text{ m/s}$ ($1.8 - 54\text{ km/h}$) | Negative speed or $> 45\text{ m/s}$ ($>162\text{ km/h}$) |
| **Horizontal Accuracy** | Reported GPS estimated accuracy | Mean $< 8\text{m}$, P95 $< 15\text{m}$ | P95 $> 25\text{m}$ (multipath/urban canyon) |
| **Stationary Drift** | Displacement radius while dwelling ($v \le 0.4\text{m/s}$) | Radius $< 5.0\text{m}$ | Wandering radius $> 15.0\text{m}$ during stops |
| **Route Distance** | Raw cumulative route distance | Consistent with session duration | GPS jumps / teleportation |
| **Missing Telemetry** | Unpopulated altitude, speed, accuracy, heading, source | 0 missing core values | High missing telemetry counts |
| **Identity Integrity** | Uniqueness of $(t, \text{lat}, \text{lng})$ | 0 duplicates | Replayed or duplicate observations |

### Quality Classification Matrix
- **`EXCELLENT`:** Regular ~1Hz sampling (mean $0.85-1.25\text{s}$), zero outages $>15\text{s}$, high accuracy (P95 $< 10\text{m}$), zero duplicate/non-monotonic timestamps.
- **`GOOD`:** Regular sampling with minor gaps ($<30\text{s}$), acceptable accuracy (P95 $< 20\text{m}$).
- **`DEGRADED`:** Outage gaps $>30\text{s}$, multipath noise (P95 accuracy $>25\text{m}$), duplicate observations $>10\%$, or elevated stationary drift.
- **`UNUSABLE`:** Insufficient sample count ($<10$ points), massive outage ($>300\text{s}$), or $>20\%$ corrupted/non-monotonic timestamps.

---

## 3. Dataset Inventory & Authentication Status

### 3.1 Authenticated Discovery Audit (ALG-0.1)

```
========================================================================
 🛰️  AETRON ALG-0 AUTHENTICATED DISCOVERY AUDIT & INVENTORY
========================================================================
Total Sessions Discovered:     0 (Developer workstation has no active end-user session)
Sessions with Raw GPS:         0
Successfully Exported:         0
Missing Sessions:              0
Denied Sessions:               0
Failure Count:                 0
------------------------------------------------------------------------
AUTHENTICATION STATE & RLS STATUS:
• Supabase database contains 10,907 raw GPS samples across 11 sessions globally,
  partitioned between 2 distinct user accounts.
• Row Level Security (RLS) restricts row access strictly to auth.uid() == user_id.
• No active end-user JWT token exists in workstation developer environment.
• Admin/service-role credentials are NOT used (violates ALG-0.1 security gate).
========================================================================
```

> [!WARNING]
> In local workstation CI/development environments without an active end-user login session, queries to `workout_sessions` correctly return empty sets due to strict RLS enforcement. Synthetic test fixtures are strictly separated and **never substituted** for real field data in research aggregates.

---

## 4. Owner-Side Export Procedure

To export the authenticated user's real historical sessions for algorithm research:

### Option A: In-App Native Share Sheet (Recommended for End-Users)
1. Open the Aetron mobile application (iOS or Android) logged in as the account owner.
2. Navigate to **Workout History** -> Select a completed workout.
3. Tap **Export Research Dataset**.
4. The system prepares the 4-file bundle in temporary app storage:
   - `<workout_id>.raw.jsonl` (application/x-ndjson)
   - `<workout_id>.raw.csv` (text/csv)
   - `<workout_id>.raw.gpx` (application/gpx+xml)
   - `<workout_id>.manifest.json` (application/json)
5. The native system Share Sheet opens, allowing direct transfer to AirDrop, Google Drive, Files, or Mail. Pre-flight file hash validation and deferred cleanup ensure attachments are received intact without race conditions.

### Option B: Authenticated CLI Tooling (Automated Research Ingestion)
To discover and export all user-owned sessions directly from Supabase:
```bash
# 1. Obtain authenticated user JWT (e.g. from app auth session or Supabase Auth OTP)
export AETRON_USER_TOKEN="<user_session_jwt>"
export SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_ANON_KEY="<anon_public_key>"

# 2. Run authenticated discovery and export under RLS
dart run tooling/inventory_historical_datasets.dart \
  --user-token "$AETRON_USER_TOKEN" \
  --supabase-url "$SUPABASE_URL" \
  --supabase-anon-key "$SUPABASE_ANON_KEY" \
  --output-dir exports/historical
```
The script will:
- Query `/rest/v1/workout_sessions` with `Authorization: Bearer $AETRON_USER_TOKEN` (RLS enforced).
- Query and page all `/rest/v1/raw_gps_points` with pagination over 1,000 points.
- Verify lossless round-trip JSONL replay.
- Calculate telemetry metrics, outage intervals (>15s and >30s), missing telemetry counts, and cumulative track distance.
- Export lossless JSONL, CSV, GPX 1.1, and manifests into `exports/historical/`.
- Record full discovery audit metrics into `exports/historical/inventory_report.json`.

---

## 5. Physical Hardware & E2E Validation Status

| Dimension | Execution Status | Device / Environment |
|---|:---:|---|
| **Automated Unit & Quality Analysis Tests** | 🟢 PASS | macOS Workstation (Dart VM) |
| **Lossless JSONL Replay Parity** | 🟢 PASS | Memory & Replay Engine |
| **Path Traversal Session ID Validation** | 🟢 PASS | Security Guard Tests |
| **Export Bundle File Hash Verification** | 🟢 PASS | Local Disk & Pre-Flight Hash Verification |
| **Discovery Audit Error Tracking** | 🟢 PASS | Test Suite Mock & RLS Gates |
| **Physical iPhone Foreground Capture** | 🟡 **NOT TESTED** | Pending Physical iPhone Field Test |
| **Physical iPhone Offline Disconnect / Reconnect** | 🟡 **NOT TESTED** | Pending Physical iPhone Field Test |
| **Physical iPhone Kill & Restart Recovery** | 🟡 **NOT TESTED** | Pending Physical iPhone Field Test |
| **Physical iPhone Background Lock-Screen Tracking** | 🟡 **NOT TESTED** | Pending Physical iPhone Field Test |
| **Physical iPhone Share Sheet AirDrop / Files Export** | 🟡 **NOT TESTED** | Pending Physical iPhone Field Test |

---

## 6. Verification & Quality Gates Summary

- `flutter analyze`: **0 issues found** (Clean).
- `flutter test test/raw_gps_dataset_inventory_test.dart test/raw_gps_dataset_export_test.dart`: **26/26 passed**.
- `flutter test`: **617/617 passed** (full suite green).
- Standalone CLI Tool: `dart run tooling/inventory_historical_datasets.dart` **SUCCEEDED**.
- Phase 5 Frozen Benchmarks: **100% byte & hash parity, 0 diff churn**.
- PR #11 remains in **DRAFT** status; no algorithm modifications or merge allowed.
