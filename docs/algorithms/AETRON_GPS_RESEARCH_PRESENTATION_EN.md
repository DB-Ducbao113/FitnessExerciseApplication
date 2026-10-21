# Aetron GPS accuracy research — presentation draft

**Purpose:** research progress presentation, 15–20 minutes.

**Evidence status (21 October 2026):** slide draft approved after factual corrections; algorithm deployment remains on HOLD. Phase approval must not be inferred from implemented code or a completed review document.

**Research question:** Can an EKF improve Aetron's GPS tracking accuracy without worsening distance measurement or output availability?

## Slide 1 — Research question

**On slide**

- Aetron records routes, distance, speed, and duration for outdoor activities.
- Phone location estimates can fluctuate because of signal blockage and multipath.
- Smoothing can reduce visible jitter, but may distort turns or behavior after signal gaps.
- Goal: evaluate an Extended Kalman Filter (EKF) against Aetron's current pipeline using controlled benchmarks and field data.

**Speaker notes**

This is a progress report on GPS tracking accuracy in Aetron. I explored several algorithm families, but a more complex method is useful only if a fair evaluation shows a meaningful gain. The current research focus is an EKF tested offline against the existing algorithm. Any production change depends on evidence from independently referenced field trials and predefined quality gates.

## Slide 2 — Current GPS pipeline

**On slide**

1. Acquire latitude, longitude, reported accuracy, speed, and time.
2. Validate incoming points and handle gaps and implausible movement.
3. Smooth accepted positions with confidence based alpha and a turn response rule.
4. Calculate and display route and distance; store workout data.

| Confidence | Alpha |
|---|---:|
| High | 0.72 |
| Medium | 0.52 |
| Low | 0.34 |

When turn conditions are met, alpha rises to at least **0.82**.

**Speaker notes**

The baseline does not treat every incoming point equally. Validation selects points for further processing. A higher alpha follows the new location more closely; a lower alpha gives more weight to the previous smoothed location. The turn rule increases responsiveness when the geometry suggests a significant change of direction. In the inspected production smoothing service, the EKF call is commented out, so this baseline remains the live smoothing path.

## Slide 3 — Why a satellite map is not a road graph

**On slide**

- Aetron displays Esri World Imagery map tiles and a route overlay.
- Imagery tiles show geography; a routable graph encodes road segments, intersections, connections, and direction rules.
- Displaying a road on a map does not give the app a road network suitable for route inference.

**Speaker notes**

A map service provides data for visual display. The satellite layer in Aetron is an imagery tile service. Map matching would need an additional structured road network and routing logic. A road visible in an image does not by itself tell an algorithm how segments connect or whether cycling or walking is permitted along them. The map display and the location estimation problem therefore use different kinds of data.

## Slide 4 — HMM map matching: relevant, but outside this study

**On slide**

- A Hidden Markov Model (HMM) can infer a likely sequence of road segments from noisy GPS samples.
- Emission scores describe how well a candidate road location explains an observed point.
- Transition scores describe how plausible movement is between candidate road locations.
- The method requires suitable road network data and a way to find routes between candidates.

**Speaker notes**

Newson and Krumm's map matching method considers both location noise and road network connectivity. It is a valid research direction, and a road network could be built from open data rather than a commercial routing API. It is not the primary method here because the proposed experiment must also cover activities that may occur off mapped roads, and Aetron's research pipeline does not include a validated road graph. Missing or incorrect paths could force a trace onto the wrong road.

## Slide 5 — How accuracy will be measured

**On slide**

| Data quality and continuity | Accuracy against an independent reference |
|---|---|
| Sampling interval, GPS gaps, point rejection, availability, stationary behavior, recovery | Position RMSE, 95th percentile position error, absolute distance error, signed distance bias |

**Rule:** a phone's reported `accuracy` field is an uncertainty estimate, not ground truth.

**Speaker notes**

Visual smoothness is not enough to establish accuracy. Position RMSE is the square root of mean squared position error and places extra weight on large errors. The 95th percentile describes the upper end of the observed error distribution. Distance error compares an estimated total with an independently measured reference; signed bias shows overcount or undercount. Each availability result needs its exact denominator and output definition. Without time aligned independent position references, field GPS recordings cannot establish field positional RMSE or P95.

## Slide 6 — Historical field dataset

**On slide**

| Measure | Count |
|---|---:|
| Cycling sessions in this research dataset | 7 |
| Original GPS rows | 10,779 |
| Rows after duplicate removal | 10,730 |
| Accepted by pre validation | 8,137 (75.83%) |
| Rejected by pre validation | 2,593 |

Rejection labels: **tiny segment 2,366**; **low accuracy 128**; **heading spike 97**; **wait for better first fix 2**.

**Speaker notes**

These seven recorded rides support replay and algorithm behavior analysis. Most rejected rows carry the tiny segment label, but a small displacement is not proof that the person was stationary or that the reading was wrong. The dataset does not include an independent, time aligned position reference. Consequently, it can show output differences and failure patterns, but it cannot measure absolute field position error.

## Slide 7 — The EKF being studied

**On slide**

The implemented four dimensional state is

\[
\mathbf{x}=[p_E,\ p_N,\ v,\ \theta]^T,
\]

where `p_E` and `p_N` are local east and north positions in metres, `v` is speed in m/s, and `θ` is heading in radians, clockwise from north.

**Cycle:** predict → compare prediction with the measurement → compute gain → correct state and uncertainty.

**Speaker notes**

Unlike the baseline alpha smoother, the EKF maintains a motion state and an uncertainty matrix. It predicts a new position using speed and heading, then combines that prediction with an accepted GPS observation according to the estimated uncertainties. A poor motion model or long signal loss can cause drift. The specific state vector matters: this implementation stores scalar speed and heading, not independent east and north velocity components.

## Slide 8 — EKF development phases 0–3

**On slide**

- **Phase 0:** baseline, metric definitions, and benchmark protocol.
- **Phase 1:** offline synthetic evaluation of an EKF prototype.
- **Phase 2:** mathematical correctness, noise units, and covariance stability work.
- **Phase 3:** development candidate with normalized innovation squared (NIS) gating and adaptive measurement covariance.

| Phase 1 synthetic metric | Baseline | EKF prototype | Change |
|---|---:|---:|---:|
| Urban RMSE | 3.417 m | 3.172 m | −7.16% |
| Urban P95 | 5.884 m | 4.714 m | −19.89% |
| Turn RMSE | 3.723 m | 3.828 m | +2.81% |

**Speaker notes**

Phase 1 showed a promising synthetic urban result, while the turn metric worsened. Phase 2 corrected implementation and numerical safety issues; its corrected urban RMSE was **3.194 m**, so the Phase 1 number must not be presented as the final EKF result. Phase 3 tested NIS based handling of suspect measurements. These are development results, and the review documents for Phases 2 and 3 still record pending approval. None of them authorizes a production rollout.

## Slide 9 — Phase 4A: why the evaluation protocol matters

**On slide**

Adaptive process noise was evaluated across **108 synthetic scenarios**.

| Protocol | Production baseline RMSE | Candidate RMSE |
|---|---:|---:|
| Paired common samples | 6.27 m | 4.29 m |
| All scheduled samples | 6.26 m | 593.98 m |

**Decision: HOLD.**

**Speaker notes**

The paired protocol compares samples shared by both outputs and looks favorable for the candidate. The all scheduled protocol also scores predicted states at scheduled times without an accepted measurement. Under that protocol the candidate fails badly. This contrast shows why sample selection and output availability must be fixed before interpreting a position metric. The report keeps Phase 4A on hold; the measured difference alone does not isolate a single cause.

## Slide 10 — Phase 5 independent synthetic holdout

**On slide**

D+Opt adds a finite state recovery mechanism. It was evaluated on **108 unseen synthetic scenarios across four new routes**.

| Frozen release gate | Baseline | D+Opt | Gate |
|---|---:|---:|---|
| All scheduled RMSE | 6.873 m | 9.639 m | Fail: candidate must be < 8 m |
| Distance overcount | 0.98% | 3.31% | Fail: must be ≤ 1% |
| Signed distance bias | +0.02% | +3.22% | Fail: must be ≤ 1% |
| Position error P95 | 9 m | 11 m | Pass: must be < 15 m |

**Formal decision: NO-GO for D+Opt; rollout remains on HOLD.**

**Speaker notes**

The holdout separates this evaluation from the development scenarios. D+Opt passes the P95 gate but fails three other mandatory gates. A passing value for one metric does not override the failures. This is a decision about the tested D+Opt configuration; it is not proof that every EKF design fails.

## Slide 11 — Where D+Opt's synthetic distance bias appeared

**On slide**

**Observed net signed distance bias:** +9,145.54 m across the holdout.

| Motion label | Share of net bias |
|---|---:|
| Turn or curvature epochs | 58.9% |
| Straight epochs | 41.1% |
| Stationary epochs | 0% |

**Possible mechanisms to test:** measurement gating during turns; mismatch between the motion model and curved paths; noise accumulating in polyline length.

**Speaker notes**

This table partitions signed aggregate distance bias by the motion labels assigned in the benchmark. It does not partition position RMSE or gross overcount. The result identifies where excess distance occurred; it does not prove which internal component caused it. An ablation test would be needed to attribute the effect to a particular feature.

## Slide 12 — Replay of seven historical rides

**On slide**

| Reported output | Total distance |
|---|---:|
| App baseline distance | 58,036.58 m |
| Current displayed route | 57,068.79 m |
| EKF only displayed route | 57,662.43 m |
| DBSCAN only displayed route | 57,881.95 m |
| D+Opt distance | 58,695.91 m |

One ride with frequent gaps had a **D+Opt distance 9.52% above the app baseline**.

**Speaker notes**

These are output totals from a replay of the same recorded inputs. The report calls the first row *app baseline distance* and labels the EKF and DBSCAN rows as *displayed route distance*. Those output definitions differ, so the simple percentage between them should not be interpreted as an isolated algorithm effect. The current displayed route is shown for context. Neither baseline is independent ground truth. The large D+Opt divergence on one ride is a warning signal, not a measured real world accuracy error.

## Slide 13 — Why focus on EKF only

**On slide**

| Approach | Research implication |
|---|---|
| EKF | Existing implementation and tests; estimates motion state continuously |
| DBSCAN | Useful for dense clusters or stops; does not estimate a continuous motion state |
| HMM map matching | Requires a suitable routable network and path coverage |
| IMU fusion | Requires synchronized inertial data and calibration |

**Next research candidate: EKF only, evaluated offline.**

**Speaker notes**

The choice narrows the experiment. It does not assert that EKF is already the best method. EKF has a working prototype, development benchmarks, and identifiable failure cases. HMM map matching and inertial fusion would add major data requirements. DBSCAN remains relevant to stop behavior, but it answers a different question from continuous state estimation. The central question is whether a carefully evaluated EKF can improve Aetron's GPS output under the conditions we can actually measure.

## Slide 14 — Preserving raw GPS research evidence

**On slide**

- Raw point capture and a local recovery journal.
- A persistent upload path and authenticated Supabase read back.
- JSONL, CSV, and GPX export code with integrity checks.
- Automated code and integration tests are present.
- Full physical device and production data verification remain open.

**Speaker notes**

Reliable algorithm comparisons need the unfiltered location sequence and its provenance. The repository contains code for raw data preservation, recovery, cloud access, and research export. The architecture contract explicitly does not guarantee recovery of all historical workouts; that would require a live database audit. Physical device acceptance and end to end cloud verification should be reported separately from automated tests. The field benchmark report records a separate security hold concerning a historical raw GPS file in a public Git branch; it does not document completed history remediation. Presentation materials should show aggregate results or anonymized examples, not personal coordinates or raw export files.

## Slide 15 — Controlled EKF only evaluation

**On slide**

1. Audit the raw GPS input and define the evaluation unit.
2. Prepare an independently measured route distance.
3. If position RMSE or P95 is a target, record independent, time aligned reference positions.
4. Replay baseline and EKF only on identical input.
5. Compare distance error, position error where valid, availability, turns, and gap recovery.
6. Evaluate once on an untouched holdout set using predefined gates.

**Speaker notes**

The next experiment will use a controlled comparison. A trustworthy route length supports distance error, but not pointwise position error. Position RMSE and P95 require independent locations matched to the same times as the app's outputs. Repeated trials and a held out test set reduce the risk of tuning to one route. Before examining the holdout, I will define the metrics, sample denominator, thresholds, and failure rules.

## Slide 16 — Progress and next steps

**On slide**

**Completed:** baseline pipeline; EKF development studies; Phase 4A analysis; Phase 5 D+Opt NO-GO; historical ride replays; raw GPS infrastructure work.

**Target through 30 November 2026:** verify recoverable raw data; collect an independent route reference; run controlled EKF only field evaluation; state the result with its limits; complete the thesis and appendices.

**Current decision:** continue EKF only research offline; keep the production baseline.

**Speaker notes**

The strongest outcome so far is a clear decision against deploying the tested D+Opt configuration after independent holdout failure. The remaining work is a field experiment with an independent reference. If EKF meets the predefined gates, I will propose a separate, controlled integration decision. If it does not, I will retain the baseline and document the failure cases. Thank you; I welcome feedback on the evaluation protocol.

## Appendix — Short answers to likely questions

| Term | Meaning |
|---|---|
| RMSE | Square root of mean squared position error against a time aligned reference. |
| P95 | The 95th percentile of an explicitly defined error distribution. |
| NIS | Innovation weighted by its expected covariance; used to assess whether a measurement is surprising under the model. |
| Covariance / PSD | Covariance describes uncertainty and relationships between state errors; a valid covariance matrix is positive semidefinite. |
| Q / R | Process noise covariance / measurement noise covariance. |
| Holdout | Evaluation data kept separate from development and tuning. |
| Ground truth | Independent reference data with known measurement limits. |
| GPS gap | A period between samples exceeding the protocol's time threshold. |
| Signed distance bias | Estimated distance minus reference distance, with its sign retained. |
| Distance overcount | A benchmark specific measure of distance recorded above the reference; quote its exact definition. |
| Stationary drift | Apparent movement or accumulated distance while the device is stationary. |
| Availability | Fraction of expected samples or times with valid output; specify denominator and output type. |
| Synthetic benchmark | Simulated inputs with a known generated trajectory. |
| Field replay | Processing previously recorded GPS data again; it does not automatically provide ground truth. |
| Field reference evaluation | Field trial using an independent measured reference. |

## Evidence and references for slide creation

- Baseline code: `lib/features/workout/domain/services/gps_smoothing_service.dart`; map tiles: `lib/features/workout/presentation/widgets/record/tracking_map_widget.dart`.
- EKF state: `lib/features/workout/domain/services/ekf/extended_kalman_filter.dart`.
- Development results: `GPS_EKF_DBSCAN_PHASE_1_REVIEW.md`, `GPS_EKF_DBSCAN_PHASE_2_REVIEW.md`, `GPS_EKF_DBSCAN_PHASE_3_REVIEW.md`, `GPS_EKF_DBSCAN_PHASE_4A_REVIEW.md`.
- Holdout: `phase5_final_qa_report.md`, `phase5_release_decision.json`.
- Field replay: `REAL_GPS_ALGORITHM_BENCHMARK_REPORT_VI.md`, `../benchmarks/real_gps_research_benchmark.json`.
- Raw data architecture: `../architecture/RAW_GPS_PRESERVATION_CONTRACT_V3.md`; export code: `lib/features/workout/domain/services/raw_gps_dataset_exporter.dart`.
- GPS signal limitations: <https://www.gps.gov/gps-accuracy-0>.
- HMM map matching: Newson & Krumm (2009), <https://www.microsoft.com/en-us/research/publication/hidden-markov-map-matching-noise-sparseness/>.
- Phone reported horizontal accuracy is an estimate: <https://developer.android.com/reference/android/location/Location#getAccuracy()>.
- Esri imagery tile service background: <https://developers.arcgis.com/javascript/latest/sample-code/layers-imagerytilelayer/>.
