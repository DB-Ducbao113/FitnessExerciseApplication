# Raw GPS Preservation & No-Cable Export Data Contract (V3)

**Document Identifier:** `AETRON-CONTRACT-RAWGPS-V3`  
**Status:** ARCHITECTURE DESIGN PROPOSAL (PENDING OWNER APPROVAL)  
**Target Workstream:** Raw GPS Preservation & No-Cable Export (RG-1 / RG-2)  
**Parent Strategy:** Lean Field-First v3  
**Decoupled From:** Milestone 2B / EKF Algorithm Research  
**Date:** 2026-10-19  

---

## 1. Scope & System Architecture

This data contract establishes the specifications for:
1. **RG-1:** Durable local raw GPS capture, persistent outbox synchronization, crash-safe journal recovery, and cloud verification.
2. **RG-2:** In-app multi-source reconciled raw GPS export (JSONL and GPX 1.1) using the native iOS Share Sheet, completely cable-free.

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                  MOBILE CLIENT (FLUTTER)                               │
│                                                                                        │
│   [Geolocator Stream (Active)]                                                         │
│                │                                                                       │
│                ▼                                                                       │
│     ┌─────────────────────┐       ┌──────────────────────┐                             │
│     │ Synchronous Journal │ ----> │ Local DB (Isar)      │                             │
│     │ Append (flush:true) │       │ local_gps_point.dart │                             │
│     └──────────┬──────────┘       └──────────┬───────────┘                             │
│                │                             │                                         │
│                ▼                             ▼                                         │
│     ┌────────────────────────────────────────────────────┐                             │
│     │ Persistent SQLite Outbox Queue                     │                             │
│     │ (Chunked batches of 250 with transaction ACK)      │                             │
│     └──────────────────────────┬─────────────────────────┘                             │
│                                │                                                       │
│                                ▼ PostgREST Upsert                                      │
└────────────────────────────────┼───────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               SUPABASE CLOUD INFRASTRUCTURE                            │
│                                                                                        │
│   [public.raw_gps_points]                                                              │
│   • RLS: "raw_gps_points: select own" (Authenticated ws.user_id = auth.uid())          │
│   • Unique: (workout_id, timestamp, latitude, longitude)                               │
│   • On Conflict: ignoreDuplicates: true                                                │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Durable Local Capture & Process Termination Boundaries

### 2.1. Physical Ingestion & Flush Guarantee
- On every position update emitted while the workout session is `active`, the sample is serialized into canonical JSONL and written to `documents/raw_gps_recovery/raw-gps-{workoutId}.jsonl` with `mode: FileMode.append, flush: true`.
- Concurrently, the sample is persisted to the local queryable store (`LocalGPSPoint` in Isar) with `isSynced = false`.

### 2.2. Process Termination Realism (No Unverified Bounds Claims)
- **Termination Boundary:** On mobile operating systems (especially iOS), an application process may be abruptly terminated by the OS kernel without prior lifecycle notifications (`SIGKILL` via `jetsam` under memory pressure, hardware thermal shutdown, instant battery depletion, or force-quitting by the user).
- **Realistic Guarantee:** While `flush: true` forces the runtime to execute a synchronous `fsync`/write-through to the file descriptor, **no claim is made that unpersisted data loss is guaranteed to be zero or less than 1 sample epoch under arbitrary hardware termination**. Any samples queued in Dart RAM microtasks or OS I/O buffers at the instant of a kernel `SIGKILL` may be lost. The system guarantees durability only for bytes successfully committed to physical storage prior to termination.

### 2.3. Pause Privacy Contract
- **Default Privacy Policy:** When the user explicitly pauses a workout, the application **must NOT collect, record, or buffer background location fixes** without an explicit, opt-in product policy or affirmative user consent.
- **Enforcement:** The `WorkoutRecordingCoordinator` suspends raw GPS collection during pause. No background location telemetry is captured or written to disk while paused, preventing unintended location monitoring.

---

## 3. Persistent Outbox, Acknowledgement Semantics & Idempotency

### 3.1. Persistent Outbox Store
- Chunk uploads are managed by a persistent SQLite outbox (`raw_gps_outbox_queue`) that survives app termination.
- Chunks consist of up to 250 samples. Each chunk maintains:
  * `chunk_id`: String (UUID)
  * `workout_id`: String (UUID)
  * `start_timestamp_utc`: ISO-8601 string
  * `end_timestamp_utc`: ISO-8601 string
  * `sample_count`: Integer
  * `status`: `pending` | `in_flight` | `acknowledged` | `failed`
  * `retry_count`: Integer
  * `next_attempt_at`: Timestamp

### 3.2. Transactional Acknowledgement Semantics
- An upload is treated as successful **only when** PostgREST returns HTTP 200/201.
- Upon HTTP ACK, the client executes an atomic local transaction:
  ```dart
  await isar.writeTxn(() async {
    for (final id in acknowledgedIds) {
      final point = await isar.localGPSPoints.get(id);
      if (point != null) {
        point.isSynced = true;
        await isar.localGPSPoints.put(point);
      }
    }
  });
  ```
- If the application crashes while an upload is in-flight, the chunk remains in `in_flight` or reverts to `pending`. Upon restart, the outbox replays the unacknowledged batch.

### 3.3. Idempotent Ingestion
- Supabase enforces a database unique index:
  ```sql
  create unique index if not exists idx_raw_gps_points_unique_sample
    on public.raw_gps_points (workout_id, timestamp, latitude, longitude);
  ```
- Ingestion queries specify `onConflict: 'workout_id,timestamp,latitude,longitude'` with `ignoreDuplicates: true`. Replaying an unacknowledged chunk is guaranteed to be idempotent with zero duplicate rows.

---

## 4. Canonical Identity, Ordering, and Dual Checksum Digests

### 4.1. Canonical Sample Identity
Every GPS point is uniquely identified by the tuple:
$$\text{Identity} = (\text{workout\_id}, \text{timestamp\_microseconds\_utc}, \text{latitude\_float64}, \text{longitude\_float64})$$

### 4.2. Deterministic Ordering
When serializing, verifying, or exporting samples, records are ordered strictly by:
1. `timestamp_microseconds_utc ASC`
2. `latitude_float64 ASC` (secondary tie-breaker)
3. `longitude_float64 ASC` (tertiary tie-breaker)

### 4.3. Dual Checksum Model: Local Full-Fidelity vs Cloud-Compatible

To account for fields present only in local storage versus those supported by the Supabase database schema, two distinct digests are computed:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 1. LOCAL FULL-FIDELITY DIGEST (SHA-256)                                                │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ Hashes the raw un-truncated JSONL representation including all local sensor telemetry: │
│ • workout_id (UUID)                                                                    │
│ • timestamp (ISO-8601 UTC microsecond string)                                          │
│ • latitude, longitude, altitude (IEEE-754 Float64)                                     │
│ • speed, accuracy, heading (IEEE-754 Float64)                                          │
│ • device_source (String)                                                               │
│ • confidence (String: "high", "medium", "low", "unreliable") [LOCAL ONLY]              │
│ • local_sequence_id (Integer) [LOCAL ONLY]                                             │
└────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 2. CLOUD-COMPATIBLE CANONICAL DIGEST (SHA-256)                                         │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ Hashes only fields present in public.raw_gps_points schema in canonical pipe format:   │
│ workout_id|timestamp_utc|lat_hex|lng_hex|alt_hex|speed_hex|acc_hex|head_hex|source     │
│ (Float fields canonicalized as 16-hex Big-Endian IEEE-754 binary64)                    │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Independent Three-Axis Health Status Model

Every workout session independently tracks three orthogonal dimensions of data integrity:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ DIMENSION 1: CAPTURE INTEGRITY                                                         │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • DURABLE_INTACT: Recording finalized normally; all captured points stored locally.    │
│ • INCOMPLETE_CRASH: Process was killed mid-workout; recovered via startup journal.     │
│ • UNKNOWN: Cloud-only session or historical data prior to local audit tracking.        │
└────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────┐
│ DIMENSION 2: CLOUD-BACKUP VERIFICATION                                                 │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • CLOUD_VERIFIED: Cloud read-back count and canonical digest match local manifest.     │
│ • PENDING_UPLOAD: Points persisted locally but awaiting outbox transmission.          │
│ • UNSYNCED_OFFLINE: Device is offline; no remote records confirmed.                    │
└────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────┐
│ DIMENSION 3: GPS TEMPORAL COVERAGE                                                     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • CONTINUOUS: Inter-fix gaps consistently within expected sensor cadence (dt <= 5.0s). │
│ • GAPS_DETECTED: One or more temporal blackout intervals (dt > 5.0s) identified.       │
│ • SPARSE: Average fix rate indicates severe hardware duty-cycling or signal loss.      │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Orphaned Session Recovery Without Speculative Finalization

### 6.1. Startup Reconciler Behavior
When the mobile application initializes (or upon user login), the `RawGpsOutboxService` scans `documents/raw_gps_recovery/*.jsonl`. If an unclosed session journal is discovered:
1. **Account Isolation Guard:** The journal's companion manifest `user_id` is matched against `supabase.auth.currentUser?.id`. If the session belongs to a different account, processing is halted; the file remains locked and isolated.
2. **Reconciliation into Isar:** Valid points are parsed from the journal and inserted into `LocalGPSPoint` in Isar.
3. **Session State Flagging:** The corresponding `LocalWorkout` is updated with `is_completed = false` and `recovery_status = "recovered_unfinalized_crash"`.

### 6.2. Prohibition of Speculative Finalization
- The reconciler **must NOT invent an artificial end time, calculate speculative moving duration, or synthesize summary metrics**.
- The workout appears in the user-facing history with an explicit visual status:  
  **"Incomplete Workout (Recovered after crash)"**
- The user is provided explicit options: *Resume Workout*, *Finalize as Incomplete*, or *Discard*.

---

## 7. Journal Retention, Cleanup & Deletion Policy

### 7.1. Strict Prohibition of Blind TTL
- Under no circumstances shall recovery journal files (`raw-gps-*.jsonl`) be deleted by an automatic time-only rule (such as a 7-day or 30-day blind TTL).
- Un-uploaded local journals represent the sole surviving copy of offline field data and must be preserved until verified.

### 7.2. Safe Journal Deletion Preconditions
A local recovery journal file may be deleted **only when both conditions are satisfied**:
1. **Local Redundancy:** Local Isar contains all points (`isar_count >= manifest.sample_count`).
2. **Cloud Verification:** Cloud read-back confirms row count and digest match:
   $$\text{server\_count} \ge \text{manifest.sample\_count} \quad \wedge \quad \text{server\_digest} = \text{manifest.cloud\_digest}$$

### 7.3. Storage-Constrained User Warning
If mobile storage is critically depleted (<100 MB free) and the user manually initiates cache cleaning, any un-uploaded journals prompt an explicit warning modal:  
*"Storage Notice: 1 un-uploaded workout trace (X samples) has not been backed up to the cloud. Clearing storage will permanently destroy this raw recording. Proceed?"*

### 7.4. Deliberate Deletion Cascade
When a user deliberately deletes a workout session:
- A deletion tombstone is recorded in `pending_workout_sync_store`.
- Local Isar rows for the session are deleted.
- The recovery journal file and companion manifest are immediately deleted from disk.
- Cloud rows in `public.raw_gps_points` are removed via PostgreSQL foreign key `ON DELETE CASCADE`.

---

## 8. Multi-Source Reconciled Export Loader (RG-2)

### 8.1. Reconciled Multi-Source Ingestion
The export loader **must NOT return early** simply because local Isar contains at least one point. When the user selects "Export Raw GPS", the loader concurrently queries:
1. **Source A (Local Isar):** `LocalDB.getPointsForSession(workoutId)`
2. **Source B (Local Recovery Journal):** `RawGpsRecoveryJournal.readPoints(workoutId)`
3. **Source C (Supabase Cloud):** `RawTrackingRemoteDataSource.getRawGpsPointsPaginated(workoutId)` via `.range(start, end)` in 1,000-row chunks.

### 8.2. Deduplication & Synthesis
- Points from all three sources are merged using the canonical sample key `(timestamp_microseconds_utc, latitude, longitude)`.
- If local storage contains partial points (e.g. 1,200 points on a secondary device) and cloud contains the full trace (3,600 points), the reconciled export produces the complete 3,600-point dataset.
- The export manifest records source attribution:  
  `sources_reconciled: ["local_isar", "supabase_cloud"]`

### 8.3. Partial Data Warning
If the reconciled sample count is incomplete relative to the session manifest or exhibits temporal blackout gaps ($> 5.0\text{ s}$), an informative warning modal is presented prior to export:  
*"Partial Data Notice: Only X verified GPS points are available for this session. Coverage gaps were detected. Export anyway?"*

---

## 9. Cable-Free Native iOS Export Specifications

### 9.1. Full-Fidelity JSONL Export
- Preserves full IEEE-754 64-bit precision without decimal rounding.
- Outputs line-delimited JSON with an embedded header manifest:
  ```json
  {"_type":"manifest","schema":"aetron.raw_gps.export.v3","workout_id":"4fa85f64-5717-4562-b3fc-2c963f66afa6","sample_count":3612,"sha256":"[PLACEHOLDER_SHA256_EXAMPLE_NOT_VERIFIED]","capture_integrity":"DURABLE_INTACT","cloud_backup_verification":"CLOUD_VERIFIED","gps_temporal_coverage":"CONTINUOUS"}
  {"timestamp":"2026-10-19T06:15:23.418123Z","latitude":10.77688912345678,"longitude":106.70089123456789,"altitude":12.456,"speed":5.234,"accuracy":4.12,"heading":182.45,"device_source":"geolocator_position_stream","confidence":"high"}
  ```

### 9.2. GPX 1.1 Interoperability Export
- Conforms strictly to TopoGrafix GPX 1.1 schema for compatibility with GIS tools, Strava, and GoldenCheetah.
- Serializes coordinates, timestamps, elevations, and sensor extensions (`speed`, `accuracy`, `heading`).

### 9.3. Native iOS Share Sheet Integration
- The serialized export is written to an application sandbox temporary file:
  `tempDir/aetron_raw_gps_{workoutId}.{gpx|jsonl}`
- Shared using `Share.shareXFiles([XFile(...)], sharePositionOrigin: origin)`.
- On iOS, `UIActivityViewController` natively provides:
  * **Save to Files (Lưu vào Tệp)** — Direct save to iCloud Drive or local "On My iPhone" without USB cables.
  * **AirDrop** — Direct wireless transfer to macOS or iOS devices.
  * **Mail, Messages, Third-Party Storage**.

### 9.4. Security, Account Isolation & Privacy
- **Account Isolation:** Queries enforce Supabase RLS `ws.user_id = auth.uid()`. Cross-user data retrieval is rejected by the database engine.
- **PII Scrubbing:** User IDs, email addresses, and auth tokens are strictly omitted from export manifests and files.
- **Log Hygiene:** Raw coordinates are **NEVER written to standard output, application crash logs, or analytics trackers**.

---

## 10. Live Database Reality & Verification Disclaimer

> [!CAUTION]
> **Live Data Recoverability Reality:**  
> This contract defines client and server data protocols. **It does not claim that existing historical workouts in production are 100% recoverable.**  
> The actual recoverability of past workouts recorded prior to this specification depends on whether client uploads succeeded, whether devices were reinstalled, and whether background execution limits interrupted transmission. A comprehensive recoverability assessment requires a live production database audit under explicit user consent.
