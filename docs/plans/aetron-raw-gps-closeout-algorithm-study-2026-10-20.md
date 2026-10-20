# AETRON — Raw GPS Closeout → Algorithm Suitability Study (Roadmap V2)
**Date:** 2026-10-20  
**Plan branch:** `plan/raw-gps-closeout-algorithm-study`  
**Base:** `EKF+DBSCAN @ 9b60f6da4e10f63bc7ac984c1adc2eb119aa3710`  
**Foundation branch:** `foundation/raw-gps`  
**Archive branch:** `archive/ekf-dbscan-research`  
**Release decision:** Raw GPS **CODE IMPLEMENTED / CI PASS / PRODUCTION VERIFICATION HOLD**. No release or algorithm migration is authorized by this plan.

## Guiding decision
Stop treating **EKF + DBSCAN** as a preselected production upgrade. Aetron's goal is reliable, accurate, efficient real-world activity tracking. Complete independently verifiable raw-data capture, collect representative field data, then compare candidates. Keep old Phase 5 / D+Opt release gates separate and **HOLD**; do not adjust thresholds merely to pass.

## Platform scope: Native iOS & Android only (iPhone First)
- **Target platforms:** Native iOS and Android only. Research field recording is **iPhone-first**, followed by Android field validation.
- **Flutter Web descoped:** Web raw GPS recording, browser IndexedDB outbox persistence, and Web-based raw recovery are **explicitly removed from RG-F scope**. Web continues using lightweight route snapshots for standard visual UI; Web does not participate in research raw capture or claim research durability.

## Verified implementation (2026-10-20)
- RG-1A native durable capture: Isar + recovery journal, checkpoint/integrity and account isolation, introduced at `b7c24b249aab363eb5497e3281808ca889156076`.
- RG-1B Supabase upload/read-back/recovery: `4e37ce207088348e9d88ffb2c88d70760edaac87`.
- RG-1B.1 reconciliation, manifest verification and upload/recovery hotfix: `9b60f6da4e10f63bc7ac984c1adc2eb119aa3710`.
- GitHub Actions run `39280584458`: 4/4 jobs passed (Flutter; DB/RLS; Deno; dependency/security). CI is **not** an actual Android/iOS or production cloud recovery test.

### Confirmed source-level gaps; do not mark GO
1. **Web capture descope:** Ensure Web gracefully no-ops without asserting raw persistence or logging false errors.
2. **Resume discovery:** `RawGpsCloudOutboxService.resumePendingUploads()` defaults to `LocalDB.getUnsyncedWorkoutsForUser`, filtering on **workout** `isSynced` instead of **raw GPS** pending state. Verify coverage for synced workout + pending raw points, journal-only sessions, restart, reconnect, auth renewal and different accounts.
3. Production Supabase schema/permissions, device lifecycle, and independent post-recovery completeness are not verified by GitHub Actions alone. Real physical device testing is mandatory.

## Phase RG-F — Finish raw GPS capture before research rollout

### RG-F1: Repair pending work discovery (P0, native)
- Make outbox discovery enumerate **user-owned** sessions with unsynced raw GPS and eligible recovery journal data, independent of workout `isSynced`.
- Trigger bounded retry at authenticated startup, return online, token renewal, and after session finalization. Debounce concurrent workers.
- Do not auto-delete journals or local raw records on failed upload, 401, 429, timeout or read-back mismatch. Only label `CLOUD_VERIFIED` after independent count + canonical content/hash verification.
- Tests: synced workout with raw pending; journal-only session; offline → restart → reconnect; retry/idempotency; accounts A/B isolation; no duplicate upload worker; mismatch remains retryable.
- **Acceptance:** all scenarios pass deterministically; no pending raw dataset silently disappears from discovery.

### RG-F2: Descope Web raw capture & enforce native-only boundaries (P0)
- Explicitly **remove** Flutter Web raw GPS recording and browser IndexedDB implementation from RG-F scope.
- RG-F targets native platforms only: **iPhone-first (iOS), followed by Android**.
- On Flutter Web, research raw GPS capture is explicitly disabled and labeled unsupported; Web continues to use lightweight route snapshots for standard UI display without claiming research-grade durability or generating false raw sync events.
- **Acceptance:** Zero Web IndexedDB work; Web runtime explicitly bypasses raw telemetry outbox/recovery without error or false claims; native iOS/Android test suites run cleanly without Web platform contamination.

### RG-F3: Native E2E and production-like Supabase proof (P0, iPhone First)
- Test an authenticated physical iPhone (primary) and Android device with explicit test account and a non-sensitive test route. Record raw timestamp (UTC), latitude/longitude, optional altitude, speed, horizontal accuracy, heading, device source, workout/session ID.
- Test normal workout, temporary signal loss, airplane mode, app kill/restart, reconnect, interrupted upload, token expiry, data reconciliation, new-device restore, and account switch.
- Produce for each run: `captured_count`, `isar_count`, `journal_count`, `cloud_count`, missing/duplicate counts, source/canonical SHA-256, reconciliation state, CI SHA, and timestamp. Exclude raw coordinates from public CI logs.
- Verify deployed Supabase migration/RLS/ownership and read-back with the real test account; local DB/RLS CI alone cannot prove deployment.
- For independent device-B recovery without source manifest, use `RESTORED_UNVERIFIED`, not `CLOUD_VERIFIED`.
- **Acceptance:** no unexplained sample loss; actual cloud read-back matches independent source manifest where available; retained journals for unverified data; all 4 CI jobs pass on the **same exact head SHA**; signed E2E physical device evidence attached. Else HOLD.

### RG-F4: Research-grade dataset export (P1, Cable-free JSONL/GPX)
- Implement cable-free export directly from the device via iOS Share Sheet / native sharing sheet:
  - **JSONL:** Full-fidelity raw telemetry stream with microseconds UTC, accuracy, altitude, speed, heading, and sensor provenance.
  - **CSV:** Tabular format of immutable original GPS samples for statistical tooling.
  - **GPX:** Standard GPX format for immediate visualization in GIS/mapping software.
- Keep original raw GPS samples immutable and separated from filtered/corrected tracks.
- Include platform/model, timestamp precision, expected sampling, accuracy units, telemetry null semantics, source version, consent flag, collection scenario, start/end, gaps and provenance.
- Apply minimal-privilege access, retention/deletion policy, and anonymization for shared research. Do not commit personal raw GPS traces or credentials into Git.
- **Acceptance:** an exported trace round-trips via AirDrop/Share Sheet, has stable schema/hash/count and can be replayed without invoking the live GPS sensor.

### RG-F release gate
`GO` only if native capture is demonstrably durable on real devices (iPhone first), resumed/recovered without loss, cloud-verified with independent evidence, cable-free export (JSONL/GPX) works on-device, 4/4 CI jobs pass on exact SHA, and Web is cleanly descoped. Any missing device/production evidence means `HOLD`; do not merge to production merely because unit tests passed.

## Algorithm Branch Strategy & Common Baseline

### Strategy
Do not implement algorithm candidates or prematurely branch before RG-F reaches verified GO. Once RG-F achieves a verified and frozen common baseline, create the following dedicated branches from the **SAME baseline commit/tag**:
- `research/ekf` — Extended Kalman Filter in isolation.
- `research/dbscan` — DBSCAN stop-detection / outlier clustering in isolation.
- `research/hmm-map-matching` — Hidden Markov Model map matching against road networks.
- `research/imu-pdr` — Pedestrian Dead Reckoning fusing synchronized IMU sensors.

### Branch constraints
- **Identical baseline:** All research branches stem from the same tagged RG-F baseline SHA.
- **Shared immutable datasets:** All branches evaluate against the exact same held-out field recordings.
- **Strict isolation:** Candidates run in isolation; baseline (raw / current production) and candidate outputs remain separate. No algorithm combinations (e.g. EKF+DBSCAN) unless explicitly authorized after individual evaluation.
- **Zero production modification:** Research branches must not alter production tracking by default.
- **Independent QA gates:** Each algorithm branch maintains its own benchmarks, evaluation evidence, and QA acceptance criteria.

### Baseline tagging procedure
1. Complete all RG-F acceptance criteria (RG-F1 through RG-F4).
2. Execute real physical device E2E verification on iPhone and Android with cloud read-back.
3. Verify all 4 CI workflows pass on the exact candidate commit.
4. Obtain formal QA GO decision lifting the RG-F HOLD.
5. Create annotated git tag: `git tag -a rgf-baseline -m "RG-F common baseline verified on native iOS/Android"`
6. Push tag to remote: `git push origin rgf-baseline`
7. Spawn `research/*` branches directly from `rgf-baseline`.

## Phase ALG-0 — Real-world dataset (after RG-F GO)
- Collect repeatable walking/running traces with consent across open sky, tree cover/parks, urban canyon, intersections/parallel roads, pauses/slow speed, tunnels or outages where safe, and phone-in-pocket movement.
- Use the same raw recordings for all algorithms. For accuracy metrics obtain a **separate reference track/known distances**; raw GPS alone is not ground truth.
- Maintain train/tune vs held-out evaluation routes/devices; log sensor sampling and ground-truth uncertainty. Include at least 2 device classes if available (iPhone + Android).
- Do not use synthetic traces as the only evidence for production decisions.

## Phase ALG-1 — Baseline first (no algorithm upgrade)
- Evaluate raw GPS and the existing production pipeline unchanged: position error RMSE and P95 (only with ground truth), relative distance error, signed distance bias, false movement during stops, point availability, dropouts, CPU/energy, latency and crash rate.
- Stratify by scenario and GPS accuracy; publish sample counts, failure cases and limitations.
- Record older D+Opt candidate gates separately: scheduled RMSE 9.638879 m vs <8 m, overcount 3.314631% vs <=1%, signed bias +3.220419% vs <=1%: previous candidate remains **NO-GO**; do not transfer simulated results to field deployment uncritically.

## Phase ALG-2 — Isolated candidate evaluations
| Candidate | Hypothesis | What it needs | Special limitation |
|---|---|---|---|
| Current filtering / light robust filter | Best complexity/performance baseline | GPS | Cannot infer road topology |
| EKF | May improve dynamic position/speed estimation | GPS + measured noise/model | Model tuning can increase delay or distance bias |
| DBSCAN | May flag outlier clusters / stop artifacts | GPS windows | Not a continuous state estimator or universal smoothing method |
| HMM map matching | May improve routing **on mapped roads** | Road-network graph (e.g. OSM), matching engine; paid map API is **optional** | Can force an incorrect route for missing park trails/off-road running |
| IMU/PDR | May bridge short GPS outages | **Additional timestamp-synchronized accelerometer/gyroscope/heading data**, calibration and sensor fusion | Drifts over time; cannot be fairly benchmarked from GPS-only data |

- Run single techniques separately, against the identical held-out traces, before trying combinations. Combination experiments need their own hypothesis and pre-registered acceptance thresholds.
- Map visual tiles / satellite imagery are **not** a road-network graph. If choosing HMM, separately audit local OSM coverage, route legality, graph freshness and offline/server cost.
- For IMU/PDR, make sensor capture a separately consented engineering milestone; never invent missing IMU data.

## Phase ALG-3 — Decision and controlled implementation
- Select the candidate with the best **measured trade-off** across accuracy, distance, false movement, availability, latency, power, map dependency and operating cost. Baseline may win.
- Freeze thresholds before running held-out tests. Block regressions in important scenarios even if overall average improves.
- Only then build a feature-flagged implementation, shadow compare, rollback, and staged release. Do not automatically combine EKF+DBSCAN.

## Agent execution contract
1. Work from dedicated branches; keep `main` untouched.
2. Complete **RG-F1 → RG-F2 → RG-F3 → RG-F4** and attach machine-checkable evidence.
3. After **each push**, check Flutter/DB-RLS/Deno/security jobs for the **exact pushed SHA**, inspect logs and report PASS/FAIL. A green badge from another SHA is insufficient.
4. Follow QA/Tester GO/NO-GO rules: no claim of real-device or production verification without real evidence, no bypasses, no fabricated benchmarks, no release on HOLD.
5. Deliver a raw-capture closeout report first. Then tag baseline and branch `research/*` candidates after RG-F GO.

**Current decision:** RG-F `HOLD`, experiment planning authorized, algorithm replacement/deployment **NOT AUTHORIZED**.
