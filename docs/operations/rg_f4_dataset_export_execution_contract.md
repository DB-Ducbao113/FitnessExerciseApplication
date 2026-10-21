# AETRON — RG-F4 Research-Grade GPS Dataset Export · Execution Contract
Date: 2026-10-21
Branch: `feat/rg-f4-dataset-export`
Base: `feat/rg-f3-real-device-e2e@4e741a32d3718cf8e0a9a60b41d4b6679130dab4`
Status: CODE/INTEGRATION VERIFIED — PENDING PHYSICAL SHARE SHEET EXECUTION & QA. RG-F overall HOLD.

## Purpose and sequencing
Owner-directed priority: implement RG-F4 export code now; perform physical RG-F3 tests after RG-F4 code/integration acceptance. No production deployment, merge to main, or research baseline tag while RG-F3 physical verification remains HOLD. After F4 + physical F3, use the owner's authentic historical route recordings (only with verified ownership and consent) for algorithm suitability research, not fabricated/benchmark simulation tracks.

## Export surfaces
1. **On-device (iOS first, Android next)**: export user-owned persisted sessions without USB by native Share Sheet / secure file picker. Raw journal & Isar remain unchanged. Share sheet must not imply verification. Web remains unsupported for research-grade raw GPS.
2. **Historical/cloud-only recordings**: some existing sessions may be in Supabase `public.raw_gps_points` without local JSONL/manifest from the original recording. Provide an *explicitly labeled* authenticated, RLS-scoped cloud export route, never classify it as independent local capture or `CLOUD_VERIFIED` from a nonexistent original manifest. Do not use the Supabase admin SQL connection, service-role key, or all-user query as a client export mechanism. Keep sessions isolated to `auth.uid()`.
3. Export formats:
   - JSONL: research master, one unmodified source sample per line; UTC microsecond time, lat/lon, accuracy, altitude, speed, heading, device_source, workout/session provenance. Preserve nulls and original precision. Preserve original raw bytes separately if available.
   - CSV: RFC4180, stable header and numeric formatting, UTC timestamps and explicit null handling.
   - GPX 1.1: standard `trk/trkseg/trkpt`, ISO 8601 UTC, latitude/longitude, elevation/time. Place accuracy/speed/heading/source in namespaced extensions or accompanying JSONL; GPX alone is not lossless. Split on documented GPS gaps. Sanitize XML and validate schema.
   - manifest.json: `schema_version`, `source_kind` (`device_journal_verified` | `device_recovered_unverified` | `cloud_only_unverified`), `user_scoped`, `workout_id`, `export_generated_at_utc`, `app_commit`, `record_count`, `first/last_sample_utc`, `timestamp_precision`, `units`, `null_semantics`, `duplicate_count`, `gap_summary`, `raw_jsonl_byte_sha256` (only for original file), `canonical_capture_digest` (only when backed by independent trusted original capture evidence), `export_jsonl_sha256`, `export_csv_sha256`, `export_gpx_sha256`, and `consent_scope`. Never fabricate absent hashes; record null / NOT_AVAILABLE.

## Safety and research gates
- Only authenticated account-owned workouts. Verify RLS against actual user identity. Fail closed on unknown ownership, signed-out state, account switch or missing permissions. Never expose another user's GPS data.
- No upload to third parties by default; no auto-commit/upload of personal GPS or auth tokens. Make `field_evidence/` / exports ignored locally, not published in CI. Avoid printing coordinates in logs.
- Source samples are immutable. Never replace raw tracks with `filtered_route_json`, `matched_route_json`, or map-matched roads. Keep raw, filtered, corrected, and reference tracks as separate labeled datasets.
- No GPS-only trace is an independent ground-truth trajectory. For position RMSE/P95, obtain an independently measured reference or report NOT MEASURABLE. Descriptive GPS metrics, completeness, outages, speed/time availability and route visualization can be researched without reference.
- No change to EKF, DBSCAN, HMM, current production algorithms, Phase 5 frozen benchmarks, or `main`.
- Existing raw cloud records in Supabase are a potential dataset, **not proof** of original sensor provenance or completeness. First inventory only aggregated counts; never imply all stored rows belong to one person.

## Build sequence and acceptance
- F4-A: implementation audit, owner-scoped source selection, source type and explicit verification state; handle manifest v1/v2, partial, corrupted, stale and orphan without promoting to verified.
- F4-B: deterministic and memory-bounded JSONL/CSV/GPX serializers, canonical hashing parity tests against existing `RawGpsCanonicalVerification` and `tooling/verify_field_evidence.dart`. Page long cloud sessions deterministically with stable ordering and no truncated 1000-row exports.
- F4-C: native iOS/Android share integration using app-owned temporary files, explicit consent, cleanup after sharing (never delete originals), and non-sensitive error state. No Web IndexedDB fallback.
- F4-D: historical Supabase account-owned export, clearly `cloud_only_unverified`, with pagination and RLS isolation. No service-role in client.
- F4-E: tests for 0/1/1000/1200+ points, missing optional telemetry, duplicate identity, timestamps across time zones, XML characters, corrupted journal, restricted owner, logout mid-export, crash/retry, session and sample sorting, SHA-256 determinism, GPX parse and JSONL full-fidelity replay. Test round-trip comparisons based on JSONL, not GPX.
- Run `flutter analyze`, focused/full Flutter tests, Web build unaffected, all 4 GitHub CI jobs on pushed SHA. Execute native Share Sheet on physical iPhone and Android when hardware available. Separate code/integration GO from hardware operational GO.

## Research handoff after export
1. After F4 code GO, remind owner to complete RG-F3 physical device field cases and authenticated Supabase read-back.
2. Then collect **only their own** existing recorded workout sessions through the authenticated exporter; keep private and version the dataset manifest locally.
3. Audit retention/duplicates/gaps/accuracy, choose representative routes, separate train/tune from held-out tests, and obtain independent reference tracks where accuracy metrics are needed.
4. Measure raw/current pipeline baseline first, then isolated EKF, DBSCAN, HMM road-graph, or IMU/PDR candidates *only where input data requirements are met*. Do not assume new algorithms improve accuracy.

**Closeout:** F4 code/integration can be reviewed while F3 field work is pending, but RG-F overall HOLD until actual device/cloud/Share Sheet evidence and owner QA approval.
