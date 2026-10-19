# Phase 5 Final QA Package & Verification Report (V4 Reconciled)

**Document ID:** `AETRON-QA-PHASE5-FINAL-004`  
**Target Candidate:** `D+Opt` (Optimized EKF Gap-Recovery FSM)  
**Production Baseline:** `Main` (`GpsSmoothingService` + Rolling Average Filter)  
**Research Branch:** `EKF+DBSCAN`  
**Research HEAD:** `4502775b94ee25e5de0e252f4e7ebd87ea18217d`  
**Date:** 2026-10-19  
**Governing Strategy:** Balanced R&D — Lean Field-First v3 (Approved by Owner)  
**Official Release Verdict:** **NO-GO for current D+Opt**  
**Milestone 2B / Production Algorithm Rollout:** **HOLD**  

---

## 1. Executive Summary & Release Verdict

Phase 5 concluded an independent verification program for the proposed 4-state Extended Kalman Filter (EKF) gap-recovery finite state machine (`D+Opt`). The candidate algorithm was evaluated across:
1. **108 synthetic benchmark scenarios** (75,600 epochs per configuration; 378,000 total epochs).
2. **108 independent holdout scenarios** across four unseen routes, three disjoint seeds, and three holdout noise profiles.
3. **Cross-platform execution environments** (macOS ARM64 local vs. Ubuntu Linux x86_64 CI).
4. **Supplemental zero-fix GPS blackout outages** (evaluating inter-fix reacquisition dynamics).

### Formal Verdict: NO-GO
The `D+Opt` algorithmic candidate **failed three mandatory Phase 5 frozen release gates**:
- **All-Scheduled RMSE:** Observed **$9.638879\text{ m}$** on holdout vs **$6.873024\text{ m}$** exact baseline (delta **$+2.765855\text{ m}$** vs exact baseline; delta **$+2.768879\text{ m}$** vs historical $6.87\text{ m}$ rounded reference; Gate: $< 8.00\text{ m}$ → **FAIL**).
- **Distance Overcount:** Observed **$3.314631\%$** on holdout vs **$0.980000\%$** on baseline (delta **$+2.334631\%$**; Gate: $\le 1.00\%$ → **FAIL**).
- **Signed Distance Bias:** Observed **$+3.220419\%$** on holdout vs **$+0.020000\%$** on baseline (delta **$+3.200419\%$**; Gate: $\le 1.00\%$ → **FAIL**).

In accordance with Owner directives:
- **Milestone 2B and all production algorithm deployments remain on HOLD**.
- Further synthetic parameter tuning is terminated.
- The **Raw GPS Preservation & No-Cable Export workstream (RG-1 / RG-2)** is decoupled into an independent engineering track under the **Lean Field-First v3** policy to capture real-world ground-truth field traces.

---

## 2. Reconciled Historical Evidence & Cryptographic SHA Fingerprints

All historical artifacts generated across Phase 5 Tasks 1–5 have been audited and fingerprinted with immutable SHA-256 digests:

| Task | Historical Artifact Path | Provenance Base Commit | Artifact File SHA-256 | Verification Audit Status |
|:---|:---|:---:|:---|:---:|
| **Task 1** | `test/artifacts/metric_accumulator_report.json` | `dda19dd` / `3debccc` | `dd28f70c01890d66d87c9cefd4cb55c0c2b6f6c30db85783496466ac0baaec12` | **VERIFIED PASS** (Global SSE $3.571\times 10^6\text{ m}^2$ & stratification invariants reconciled 100%) |
| **Task 2** | `test/artifacts/phase5_task2_availability_report.json` | `3debccc` | `33942d6438982fe992e39baf45b48491d300a5dedc232f952f448cd946bd7bb0` | **VERIFIED AUDITED** (Legacy 99.93% PASS; Validated 98.92% Audited; P95 Latency 22.0s PASS) |
| **Task 3** | `test/artifacts/phase5_task3_covariance_report.json` | `486a8bf` | `35dcd6ed5692ce31732420a8ca5a4f75b5cde8a97e95df2c8ef8597f2d68d2a1` | **VERIFIED PASS** (100% PSD stability across 378k epochs; zero non-finite/asymmetry defects) |
| **Task 4** | `test/artifacts/phase5_task4_fingerprint_report.json` | `4744496` | `c4b62c09bf6ef3ee2ac66d97921e946e3d4f8002474df1e30d0ea585ce8b283a` | **TECHNICAL PASS** (Local bit-exact 100% on macOS ARM64; cross-platform INCONCLUSIVE; root cause UNDETERMINED) |
| **Task 4 (CI)**| `test/artifacts/cross_platform_evidence/linux/phase5_task4_fingerprint_report.json` | `4744496` | `1ff2bf31932435106d53afbf1593c1f770472d282abf9cfe95048f62fd3bf844` | **VERIFIED RETRIEVED** (GitHub Actions run `39205324325` Ubuntu artifact) |
| **Task 5** | `test/artifacts/phase5_task5_holdout_report.json` | `a685fc6` | `dbb5a25673cf2059ea07d52a0cf1c36aaf2fecf79a515cd96d8155a57dade217` | **VERIFIED FAIL** (108 holdout scenarios evaluated; 3 frozen release gates breached) |
| **Task 5 (Supp)**| `test/artifacts/phase5_task5_supplemental_outage_report.json` | `a685fc6` | `9a65d19105c67d1974db8282f0560990d7b39a4f8c144d676eaf9c4564ec39ef` | **VERIFIED AUDITED** (Deterministic 31s inter-fix true-outage recovery; 0.0m jump on reacquisition) |

### Task 6 Governance Documents
The governing release decision and failure records for Task 6 are tracked under version-controlled repository paths without circular self-referencing checksums:
- **Release Decision:** `test/artifacts/phase5_release_decision.json` (mirrored at `docs/algorithms/phase5_release_decision.json`)
- **Failure Register:** `test/artifacts/phase5_failure_register.json` (mirrored at `docs/algorithms/phase5_failure_register.json`)

---

## 3. Separation of Observed Metrics, Kinematic Labels, and Unproven Hypotheses

To preserve scientific rigor, this evaluation strictly separates:
1. **Observed Quantitative Metrics** directly measured from scenario execution.
2. **Kinematic Motion-Phase Labels** assigned by the benchmark generator.
3. **Unproven Causal Hypotheses** regarding internal filter mechanics.
4. **Frozen Release Gates** established prior to holdout evaluation.
5. **Supplemental Diagnostic Metrics** recorded for observability.

### 3.1. Frozen Release Gates vs Supplemental Diagnostic Metrics

| Metric | Target Threshold | Baseline 108 Result | Holdout 108 Result | Arithmetic Delta | Gate Status | Metric Classification |
|:---|:---:|:---:|:---:|:---:|:---:|:---|
| **All-Scheduled RMSE** | $< 8.00\text{ m}$ | $6.873024\text{ m}$ *(exact)*<br>$6.87\text{ m}$ *(rounded ref)* | **$9.638879\text{ m}$** | $+2.765855\text{ m}$ *(vs exact)*<br>$+2.768879\text{ m}$ *(vs rounded)* | 🔴 **FAIL** | **Frozen Release Gate** |
| **Distance Overcount** | $\le 1.00\%$ | $0.980000\%$ | **$3.314631\%$** | $+2.334631\%$ | 🔴 **FAIL** | **Frozen Release Gate** |
| **Signed Distance Bias** | $\le 1.00\%$ | $+0.020000\%$ | **$+3.220419\%$** | $+3.200419\%$ | 🔴 **FAIL** | **Frozen Release Gate** |
| **P95 Position Error** | $< 15.00\text{ m}$ | $9.000000\text{ m}$ | **$11.000000\text{ m}$** | $+2.000000\text{ m}$ | 🟢 **PASS** | **Frozen Release Gate** |
| **Legacy Availability** | $\ge 99.00\%$ | $99.931217\%$ | **$99.993386\%$** | $+0.062169\%$ | 🟢 **PASS** | **Frozen Release Gate** |
| **Recovery Latency P95** | $\le 30.0\text{ s}$ | $22.000000\text{ s}$ | **$22.000000\text{ s}$** | $0.000000\text{ s}$ | 🟢 **PASS** | **Frozen Release Gate** |
| **Covariance PSD** | $100.0\%$ | $100.000000\%$ | **$100.000000\%$** | $0.000000\%$ | 🟢 **PASS** | **Frozen Release Gate** |
| *Measurement-Validated Availability* | *(Audited)* | $98.923280\%$ | $99.890212\%$ | $+0.966931\%$ | *(Diagnostic)* | *Supplemental Diagnostic Metric* |

*Explicit RMSE Arithmetic Note:*  
- Exact baseline RMSE: $6.873023525418226\text{ m}$ ($\approx 6.873024\text{ m}$).  
- Exact holdout RMSE: $9.638879054018128\text{ m}$ ($\approx 9.638879\text{ m}$).  
- Exact arithmetic delta: $9.638879054018128 - 6.873023525418226 = \mathbf{+2.765855\text{ m}}$.  
- The historical delta recorded in Task 5 JSON ($+2.768879\text{ m}$) was computed against the historical 2-decimal rounded reference ($6.87\text{ m}$): $9.638879054018128 - 6.87 = \mathbf{+2.768879\text{ m}}$. Both calculations confirm that holdout RMSE severely breached the $<8.00\text{ m}$ threshold.

---

### 3.2. Observed Holdout Route Metrics (Actual JSON Data)

The holdout dataset contains four distinct routes evaluated across 108 scenarios:

| Route ID | Route Name | Total Epochs | RMSE | P95 Error | Gross Overcount | Signed Bias | Turn Excess Distance |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Route A** | Coastal Straight Highway | 18,900 | $10.872990\text{ m}$ | $12.0\text{ m}$ | $3.027594\%$ | $+2.922976\%$ | $487.27\text{ m}$ |
| **Route B** | Mountain Hairpin Switchbacks | 18,900 | $8.992890\text{ m}$ | $11.0\text{ m}$ | $2.762709\%$ | $+2.617608\%$ | $1,668.58\text{ m}$ |
| **Route C** | Urban Grid with Stop-and-Go | 18,900 | $9.728154\text{ m}$ | $10.0\text{ m}$ | $5.024532\%$ | $+5.024532\%$ | $1,013.89\text{ m}$ |
| **Route D** | Figure-8 Athletic Loop | 18,900 | $8.826155\text{ m}$ | $11.0\text{ m}$ | $3.421650\%$ | $+3.344813\%$ | $2,218.01\text{ m}$ |

*Key Empirical Observations:*
- **Highest RMSE:** Occurred on **Route A (Coastal Straight Highway)** at $10.87\text{ m}$, driven by high-speed segments under multipath and heading dropout.
- **Highest Distance Inflation:** Occurred on **Route C (Urban Grid with Stop-and-Go)** at $+5.02\%$ gross overcount and signed bias, driven by frequent stop-and-go acceleration cycles.
- **Highest Turn-Labelled Bias:** Occurred on **Route D (Figure-8 Athletic Loop)** at $2,218.01\text{ m}$, where high-curvature loops dominate trajectory geometry.

---

### 3.3. Kinematic Motion-Phase Partition of Net Distance Bias

The holdout benchmark computes an epoch-by-epoch motion-phase partitioning. **This metric partitions NET DISTANCE BIAS ($+9,145.54\text{ m}$), NOT position RMSE or gross overcount:**

$$\text{Net Distance Bias} = \text{Total Accumulated Distance} - \text{Total Ground Truth Distance} = 293,131.54\text{ m} - 283,986.00\text{ m} = +9,145.54\text{ m}$$

| Motion Phase Label | Excess Distance Contribution | Relative Share of Net Distance Bias | Accounting Invariant Status |
|:---|:---:|:---:|:---:|
| **Turn / Curvature Sections** | **$+5,387.753046\text{ m}$** | **$58.911375\%$ ($\approx 58.9\%$)** | Exact epoch-by-epoch sum |
| **Normal Straight Sections** | **$+3,757.786308\text{ m}$** | **$41.088625\%$ ($\approx 41.1\%$)** | Exact epoch-by-epoch sum |
| **Stationary Dwell Periods** | **$0.000000\text{ m}$** | **$0.000000\%$ ($0.0\%$)** | Zero accumulation while stopped |
| **Total Reconciled Net Bias** | **$+9,145.539354\text{ m}$** | **$100.000000\%$ ($100.0\%$)** | Residual: $4.91\times 10^{-10}\text{ m}$ (Exact Zero Match) |

*Empirical Conclusion:* Turn-labelled epochs account for **$58.9\%$** of net distance bias, while straight-labelled epochs account for **$41.1\%$**. Stationary dwell periods contribute zero bias ($0.0\%$).

---

### 3.4. Unproven Causal Hypotheses (Awaiting Field Ground Truth)

The following mechanisms are **hypotheses** consistent with observed data, but **have NOT been quantitatively proven or isolated at the trace level**:
1. *Hypothesis 1 (Innovation Gating Disconnection):* Hypothesized that position innovations during high turn rates exceed Chi-square thresholds ($NIS \ge G_2$), disconnecting measurement updates and causing predict-only coasting away from the true turn arc. (*Status: Unproven hypothesis; requires step-level innovation logging on physical hardware.*)
2. *Hypothesis 2 (Tangential Chord Projection):* Hypothesized that velocity integration along straight chords during predict-only coasting over-estimates circular arc length. (*Status: Unproven hypothesis; geometric chord attribution requires wheel-sensor synchronization.*)
3. *Hypothesis 3 (Non-Negative Noise Rectification):* Hypothesized that because Euclidean distance increments $d = \sqrt{\Delta x^2 + \Delta y^2} \ge 0$, zero-mean lateral sensor noise rectifies into positive distance drift. (*Status: Unproven hypothesis; theoretical statistical mechanism.*)

---

## 4. Task 4 Restored Provenance & Cross-Platform Assessment

The historical Task 4 report has been preserved in its immutable state (`c4b62c0`):
- **Local Repeatability:** **TECHNICAL PASS**. 108/108 scenarios bit-exact identical across repeated runs on macOS ARM64. Proved 100% sensitivity to sub-centimeter mutations.
- **Cross-Platform Verification (macOS ARM64 vs Linux x86_64 CI):**
  - Legacy 2-decimal rounded hashes matched: **$540 / 540$ ($100.0\%$)**.
  - Canonical Float64 big-endian byte hashes matched: **$0 / 540$ ($0.0\%$)**.
  - Maximum final distance difference: $2.825\times 10^{-7}\text{ m}$ ($0.28\ \mu\text{m}$).
  - Mean final distance difference: $7.416\times 10^{-9}\text{ m}$ ($7.4\text{ nm}$).
- **Evaluation:** **INCONCLUSIVE**. Cross-platform numerical equivalence is physically consistent at sub-micrometer levels, but strictly mismatched at binary byte-digest level. The exact root cause of cross-platform floating-point differences is **UNDETERMINED** (hypothesized to relate to standard C/runtime math library implementations of `sin`/`cos`/`sqrt` and compiler FMA utilization between ARM64 and x86_64).

---

## 5. Strategic Alignment & Owner Sign-Off

1. **Synthetic Optimization Concluded:** Continued parameter tuning on synthetic trajectories is terminated.
2. **Lean Field-First v3 Activated:**
   - Production remains on the verified Main baseline.
   - Milestone 2B is on **HOLD**.
   - Immediate engineering priority pivots entirely to the **Raw GPS Preservation & No-Cable Export (RG-1 / RG-2)** workstream.
   - Real-world field traces collected from outdoor cycling devices across diverse environments will provide the empirical ground-truth required for future algorithm development.
