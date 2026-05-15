(A) CREATE WORKOUT
POST /workouts/start

Request

{
  "activity_type": "running",
  "mode": "outdoor"
}

Response

{
  "status": "ok",
  "workout_id": "uuid",
  "started_at": "timestamp"
}

Notes

- Creates a `workout_sessions` shell row
- Sets `processing_status = client_recording`
- Returns the canonical `workout_id` used by the rest of the flow

(B) SEND GPS BATCH
POST /gps/track

Request

[
  {
    "workout_id": "uuid",
    "latitude": 10.762622,
    "longitude": 106.660172,
    "timestamp": "2026-02-04T10:20:30Z",
    "accuracy": 8.5,
    "speed": 2.4,
    "heading": 182.0,
    "device_source": "mobile"
  }
]

Response

{
  "status": "ok",
  "count": 1
}

Notes

- Appends raw points to `raw_gps_points`
- Does not finalize distance or route quality

(C) END WORKOUT
POST /workouts/end

Request

{
  "workout_id": "uuid",
  "duration_sec": 1800,
  "distance_km": 4.2,
  "avg_speed_kmh": 8.4,
  "calories_kcal": 312,
  "steps": 5300
}

Response

{
  "status": "ok",
  "workout_id": "uuid",
  "ended_at": "timestamp",
  "duration_sec": 1800,
  "processing_status": "client_finished_pending_processing"
}

Notes

- Saves the client stop snapshot as a provisional canonical summary
- Queues `workout_processing_jobs.job_type = deterministic_finalize`
- Final metrics may still be recomputed by backend workers

(D) PROCESS WORKOUT
POST /functions/v1/deterministic-finalize-worker

Request

{
  "workout_id": "uuid"
}

Response

{
  "status": "completed",
  "workout_id": "uuid",
  "job_id": "uuid",
  "metrics": {
    "distanceKm": 4.18,
    "avgSpeedKmh": 8.36,
    "dataQualityScore": 91.5,
    "suspiciousDistanceRatio": 0.12,
    "workoutValidityStatus": "partial"
  }
}

Notes

- Reads `raw_gps_points` and `raw_step_intervals`
- Recomputes deterministic canonical metrics from valid segments only
- Writes `workout_segment_audits` for segment-level validity evidence
- Flags suspicious fast cycling segments, including fast movement followed by idle time
- Updates `workout_sessions`
- Marks the job completed and writes processing logs

(E) GET HISTORY
GET /workouts/{user_id}

Response

[
  {
    "workout_id": "uuid",
    "type": "walking",
    "distance_km": 2.1,
    "calories_kcal": 120,
    "created_at": "timestamp",
    "processing_status": "client_finalized"
  }
]

Notes

- Clients should prefer canonical reads from `workout_sessions`
- `processing_status` helps the UI distinguish provisional vs finalized summaries
