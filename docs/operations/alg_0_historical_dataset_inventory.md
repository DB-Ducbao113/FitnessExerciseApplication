# AETRON — ALG-0 Historical Raw GPS Dataset Inventory & Quality Report

**Document Version:** 1.0.0  
**Date:** 2026-10-21  
**Target:** Algorithm Research Common Baseline (Phase ALG-0)  
**Code Baseline Commit:** `b002dbce7293641d561f804eba7eb260d756a3c5`  
**Branch:** `feat/rg-f4-dataset-export`  
**Tooling:** [`tooling/inventory_historical_datasets.dart`](file:///Users/baobungbu/Aetron/tooling/inventory_historical_datasets.dart)  
**Governance:** RG-F4 Code/Integration GO. Overall RG-F HOLD (Pending physical multi-device GPS validation).

---

## 1. Executive Summary & Purpose

Phase **ALG-0** establishes an immutable, account-scoped inventory of historical and baseline raw GPS datasets in Aetron. Prior to evaluating algorithm candidates (such as Extended Kalman Filter, DBSCAN stop-detection, Hidden Markov Model map-matching, or IMU Pedestrian Dead Reckoning), all existing datasets must be inventoried, classified by data quality, and labeled with unambiguous provenance.

### Core Scientific Principles & Ground-Truth Invariants
1. **Zero Unfounded Error Claims:**
   > [!IMPORTANT]
   > Ground-truth positional error (RMSE and P95) is **STRICTLY REFUSED** and marked `groundTruthErrorDisallowed: true`. Without an independent survey-grade reference track (e.g., dual-frequency RTK-GNSS rover or known surveyed geometry), raw smartphone GPS cannot be treated as ground truth.
2. **Accurate Provenance Labeling:**
   - Sessions recorded locally with verified capture proof: `device_journal_verified`.
   - Recovered orphan journals without complete proof: `device_recovered_unverified`.
   - Historical cloud recordings without local manifests: `cloud_only_unverified`.
   - Synthetic generator traces: `synthetic_fixture` (strictly separated from real-world datasets).
   - Filtered/smoothed traces: `algorithm_filtered` (strictly separated from raw sensor telemetry).
3. **Data Privacy & Immutability:**
   - Raw source datasets remain immutable and private.
   - Summaries and reports contain statistical metrics, cryptographic hashes, and counts; zero personal residence coordinates or auth credentials are committed to git.

---

## 2. Statistical Profiling & Quality Methodology

The automated analyzer ([`RawGpsQualityAnalyzer`](file:///Users/baobungbu/Aetron/lib/features/workout/domain/services/raw_gps_quality_analyzer.dart)) evaluates each session across 6 quantitative dimensions:

| Dimension | Metric Evaluated | Healthy Baseline Threshold | Degradation Indicator |
|---|---|:---:|:---:|
| **Sampling Interval** | Delta-t ($\Delta t$) between successive points | $1.0\text{s} \pm 0.15\text{s}$ | Jitter $> 0.5\text{s}$, non-monotonic timestamps |
| **Outage Gaps** | Signal loss gaps $> 15.0\text{s}$ | $0$ gaps | Gaps $> 30\text{s}$ (degraded), $> 300\text{s}$ (unusable) |
| **Speed Bounds** | Instantaneous ground speed | $0.5 - 15.0\text{ m/s}$ ($1.8 - 54\text{ km/h}$) | Negative speed or $> 45\text{ m/s}$ ($>162\text{ km/h}$) |
| **Horizontal Accuracy** | Reported GPS estimated accuracy | Mean $< 8\text{m}$, P95 $< 15\text{m}$ | P95 $> 25\text{m}$ (multipath/urban canyon) |
| **Stationary Drift** | Displacement radius while dwelling ($v \le 0.4\text{m/s}$) | Radius $< 5.0\text{m}$ | Wandering radius $> 15.0\text{m}$ during stops |
| **Identity Integrity** | Uniqueness of $(t, \text{lat}, \text{lng})$ | 0 duplicates | Replayed or duplicate observations |

### Quality Classification Matrix
- **`EXCELLENT`:** Regular ~1Hz sampling, zero outages $>15\text{s}$, high accuracy (P95 $< 10\text{m}$), zero duplicate/non-monotonic timestamps.
- **`GOOD`:** Regular sampling with minor gaps ($<30\text{s}$), acceptable accuracy (P95 $< 20\text{m}$).
- **`DEGRADED`:** Outage gaps $>30\text{s}$, multipath noise (P95 accuracy $>25\text{m}$), or elevated stationary drift.
- **`UNUSABLE`:** Insufficient sample count ($<10$ points), massive outage ($>300\text{s}$), or $>20\%$ corrupted timestamps.

---

## 3. Dataset Inventory Summary

### 3.1 Repository Inventory Breakdown

```
========================================================================
 🛰️  AETRON ALG-0 HISTORICAL RAW GPS DATASET INVENTORY
========================================================================
Total Sessions Inventoried:    1
Total Raw Sensor Points:       4
Real-World Field Sessions:     0
Synthetic Fixture Sessions:    1
Algorithm-Filtered Sessions:   0
Mean Sampling Interval:        1.000s
Mean Horizontal Accuracy:      7.50m
Total Signal Outages (>15s):   0
Total Outage Duration:         0.0s
========================================================================
PROVENANCE & INTEGRITY ENFORCEMENT:
• Real-world field sessions vs. synthetic test fixtures: 100% ISOLATED.
• Ground-truth positional error (RMSE/P95): STRICTLY REFUSED.
========================================================================
```

### 3.2 Detailed Session Catalog

| Session ID | Provenance Kind | Classification | Point Count | Duration | Mean $\Delta t$ | P95 Acc | Max Drift | Lossless Hash (JSONL SHA-256) |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| `fixture-workout` | `synthetic_fixture` | `UNUSABLE` ($<10$ pts) | 4 | 2.0s | 1.000s | 9.00m | 0.0m | `216e908c3c46efc91bff147f1839682fa36f80cf083ac5bf930d04f0d79f821b` |

*Note: In local workstation development environments, no active physical user workouts are stored in `path_provider` application directories. Remote Supabase sessions are accessible through authenticated user queries via `RawGpsExportService.inventoryUserSessions()`.*

---

## 4. Task A — Share Sheet Attachment Integrity & Cleanup Safety

### 4.1 Identified Native Platform Behavior
On mobile operating systems (iOS and Android), sharing multiple files via `Share.shareXFiles` has platform-dependent completion semantics:
1. **Android Chooser Behavior:** `context.startActivity(chooserIntent)` dispatches the system picker and returns immediately. If files are deleted synchronously in `finally`, the destination application (e.g. Google Drive, Gmail, Slack) receives invalid file URIs to deleted files.
2. **iOS Activity Controller Behavior:** While `UIActivityViewController` fires a completion handler on dismissal, external activities (AirDrop, Save to Files, Mail) stream or copy files asynchronously. Immediate synchronous deletion causes race conditions and missing or 0-byte attachments.

### 4.2 Implemented Resolution
- **Explicit MIME Types & Names:** Extended `XFile` with exact MIME types:
  - `.raw.jsonl`: `application/x-ndjson`
  - `.raw.csv`: `text/csv`
  - `.raw.gpx`: `application/gpx+xml`
  - `.manifest.json`: `application/json`
- **Hash Pre-Flight Verification:** Added [`RawGpsExportService.verifyExportFiles()`](file:///Users/baobungbu/Aetron/lib/features/workout/data/services/raw_gps_export_service.dart#L235-L283), asserting that the exact byte stream on disk matches `export_jsonl_sha256`, `export_csv_sha256`, and `export_gpx_sha256`.
- **Safe Lifecycle & Deferred Cleanup:** Stale export directories (`aetron_export_*`) older than 15 minutes are purged on startup and export preparation. Immediate deletion in `shareExportBundle` is deferred by 5 minutes to allow asynchronous native receivers to complete reading without attachment loss.

---

## 5. Physical Hardware Status

| Test Dimension | Execution Status | Device / Environment |
|---|:---:|---|
| **Automated Unit & Quality Analysis Tests** | 🟢 PASS | macOS Workstation (Dart VM) |
| **Export Bundle File Hash Verification** | 🟢 PASS | Local Disk & File Verification |
| **Physical iPhone Foreground Capture** | 🟡 **NOT TESTED** | Pending Physical iPhone Field Test |
| **Physical iPhone Offline Disconnect / Reconnect** | 🟡 **NOT TESTED** | Pending Physical iPhone Field Test |
| **Physical iPhone Kill & Restart Recovery** | 🟡 **NOT TESTED** | Pending Physical iPhone Field Test |
| **Physical iPhone Background Lock-Screen Tracking** | 🟡 **NOT TESTED** | Pending Physical iPhone Field Test |
| **Physical iPhone Share Sheet AirDrop / Files Export** | 🟡 **NOT TESTED** | Pending Physical iPhone Field Test |

---

## 6. Verification & Quality Gates

- `flutter analyze`: **0 issues found** (Clean).
- `flutter test test/raw_gps_dataset_inventory_test.dart test/raw_gps_dataset_export_test.dart`: **22/22 passed**.
- `flutter test`: **613/613 passed** (full suite green).
- Phase 5 Frozen Benchmarks: **100% hash match, 0 diff churn**.
- Web Release Build: `flutter build web --release` **SUCCEEDED**.
- Standalone CLI Tool: `dart run tooling/inventory_historical_datasets.dart` **SUCCEEDED**.
