import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type WorkoutRow = {
  id: string;
  user_id: string;
  activity_type: string;
  mode: string;
  started_at: string;
  ended_at: string | null;
  duration_sec: number | null;
  moving_time_sec: number | null;
  distance_km: number | null;
  avg_speed_kmh: number | null;
  calories_kcal: number | null;
  steps: number | null;
};

type ProcessingJobRow = {
  id: string;
  workout_id: string;
  attempt_count: number | null;
};

type RawGpsPoint = {
  timestamp: string;
  latitude: number;
  longitude: number;
  altitude: number | null;
  speed: number | null;
  accuracy: number | null;
  heading: number | null;
  device_source: string | null;
};

type RawStepInterval = {
  interval_start: string;
  interval_end: string;
  steps_count: number;
};

type UserProfileRow = {
  weight_kg: number | null;
  gender: string | null;
};

type RoutePoint = {
  lat: number;
  lng: number;
  timestamp: string;
};

type CandidateSegment = {
  from: RoutePoint;
  to: RoutePoint;
  durationSec: number;
  distanceM: number;
};

type SegmentAuditRow = {
  segmentIndex: number;
  startedAt: string;
  endedAt: string;
  durationSec: number;
  distanceM: number;
  paceSecPerKm: number | null;
  avgSpeedKmh: number;
  maxSpeedKmh: number;
  avgAccuracyM: number | null;
  status: "valid" | "suspicious" | "invalid";
  reason: string;
  features: Record<string, unknown>;
};

type MovementLeg = CandidateSegment & {
  avgAccuracy: number;
  speedMs: number;
};

type CanonicalMetrics = {
  durationSec: number;
  movingTimeSec: number;
  distanceKm: number;
  avgSpeedKmh: number;
  caloriesKcal: number;
  steps: number;
  lapSplits: Array<{
    index: number;
    distanceKm: number;
    durationSeconds: number;
    paceMinPerKm: number;
  }>;
  filteredRouteJson: RoutePoint[][];
  dataQualityScore: number;
  routeMatchStatus: string;
  routeDistanceSource: string;
  routeMatchMetricsJson: Record<string, unknown>;
  segmentAudits: SegmentAuditRow[];
  logSummary: Record<string, unknown>;
};

type SupabaseAdminClient = any;

const JOB_TYPE = "deterministic_finalize";
const METRICS_VERSION = 2;
const MAX_ATTEMPTS = 3;
const GAP_THRESHOLD_SEC = 5;
const HARD_GAP_THRESHOLD_SEC = 90;
const HIGH_ACCURACY_METERS = 20;
const POOR_ACCURACY_METERS = 50;
const MAX_ACCURACY_METERS = 100;
const MIN_SEGMENT_DISTANCE_M = 0.75;

const corsHeaders = {
  "Content-Type": "application/json",
};

if (import.meta.main) {
  Deno.serve(handleRequest);
}

async function handleRequest(req: Request): Promise<Response> {
  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const payload = await req.json().catch(() => ({}));
    const workoutId = payload.workout_id as string | undefined;
    const jobId = payload.job_id as string | undefined;

    if (!workoutId && !jobId) {
      return json({ error: "Missing workout_id or job_id" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      authHeader
        ? { global: { headers: { Authorization: authHeader } } }
        : undefined,
    );

    const job = await fetchQueuedJob(supabase, { workoutId, jobId });
    if (!job) {
      return json({ status: "noop", reason: "job_not_found" });
    }

    await markJobStarted(supabase, job.id);

    const workout = await fetchWorkout(supabase, job.workout_id);
    if (!workout) {
      await failJob(supabase, job.id, "workout_not_found");
      return json({ status: "failed", reason: "workout_not_found" }, 404);
    }

    const [rawGpsPoints, rawStepIntervals, userProfile] = await Promise.all([
      fetchRawGpsPoints(supabase, workout.id),
      fetchRawStepIntervals(supabase, workout.id),
      fetchUserProfile(supabase, workout.user_id),
    ]);

    const metrics = computeCanonicalMetrics({
      workout,
      rawGpsPoints,
      rawStepIntervals,
      userProfile,
    });

    await persistMetrics(supabase, workout.id, metrics);
    await persistSegmentAudits(supabase, workout.id, metrics.segmentAudits);
    await insertLog(
      supabase,
      workout.id,
      job.id,
      "info",
      "deterministic_finalize_completed",
      "Deterministic finalize recomputed canonical workout metrics.",
      metrics.logSummary,
    );
    await completeJob(supabase, job.id);

    return json({
      status: "completed",
      workout_id: workout.id,
      job_id: job.id,
      metrics: metrics.logSummary,
    });
  } catch (error) {
    console.error("[deterministic-finalize-worker] fatal error", error);
    return json(
      {
        error: error instanceof Error ? error.message : "Internal error",
      },
      500,
    );
  }
}

async function fetchQueuedJob(
  supabase: SupabaseAdminClient,
  input: { workoutId?: string; jobId?: string },
): Promise<ProcessingJobRow | null> {
  let query = supabase
    .from("workout_processing_jobs")
    .select("id, workout_id, attempt_count")
    .eq("job_type", JOB_TYPE)
    .eq("status", "queued")
    .lt("attempt_count", MAX_ATTEMPTS)
    .order("created_at", { ascending: true })
    .limit(1);

  if (input.jobId) {
    query = query.eq("id", input.jobId);
  } else if (input.workoutId) {
    query = query.eq("workout_id", input.workoutId);
  }

  const { data, error } = await query.maybeSingle();
  if (error) throw error;
  return data;
}

async function fetchWorkout(
  supabase: SupabaseAdminClient,
  workoutId: string,
): Promise<WorkoutRow | null> {
  const { data, error } = await supabase
    .from("workout_sessions")
    .select(
      "id, user_id, activity_type, mode, started_at, ended_at, duration_sec, moving_time_sec, distance_km, avg_speed_kmh, calories_kcal, steps",
    )
    .eq("id", workoutId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function fetchRawGpsPoints(
  supabase: SupabaseAdminClient,
  workoutId: string,
): Promise<RawGpsPoint[]> {
  const { data, error } = await supabase
    .from("raw_gps_points")
    .select(
      "timestamp, latitude, longitude, altitude, speed, accuracy, heading, device_source",
    )
    .eq("workout_id", workoutId)
    .order("timestamp", { ascending: true });
  if (error) throw error;
  return data ?? [];
}

async function fetchRawStepIntervals(
  supabase: SupabaseAdminClient,
  workoutId: string,
): Promise<RawStepInterval[]> {
  const { data, error } = await supabase
    .from("raw_step_intervals")
    .select("interval_start, interval_end, steps_count")
    .eq("workout_id", workoutId)
    .order("interval_start", { ascending: true });
  if (error) throw error;
  return data ?? [];
}

async function fetchUserProfile(
  supabase: SupabaseAdminClient,
  userId: string,
): Promise<UserProfileRow | null> {
  const { data, error } = await supabase
    .from("user_profiles")
    .select("weight_kg, gender")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function markJobStarted(
  supabase: SupabaseAdminClient,
  jobId: string,
) {
  const { data: current, error: currentError } = await supabase
    .from("workout_processing_jobs")
    .select("attempt_count")
    .eq("id", jobId)
    .maybeSingle();
  if (currentError) throw currentError;

  const { error } = await supabase
    .from("workout_processing_jobs")
    .update({
      status: "running",
      started_at: new Date().toISOString(),
      attempt_count: Number(current?.attempt_count ?? 0) + 1,
      finished_at: null,
      error_message: null,
    })
    .eq("id", jobId);
  if (error) throw error;
}

async function completeJob(
  supabase: SupabaseAdminClient,
  jobId: string,
) {
  const { error } = await supabase
    .from("workout_processing_jobs")
    .update({
      status: "completed",
      finished_at: new Date().toISOString(),
      error_message: null,
    })
    .eq("id", jobId);
  if (error) throw error;
}

async function failJob(
  supabase: SupabaseAdminClient,
  jobId: string,
  errorMessage: string,
) {
  const { error } = await supabase
    .from("workout_processing_jobs")
    .update({
      status: "failed",
      finished_at: new Date().toISOString(),
      error_message: errorMessage,
    })
    .eq("id", jobId);
  if (error) throw error;
}

async function persistMetrics(
  supabase: SupabaseAdminClient,
  workoutId: string,
  metrics: CanonicalMetrics,
) {
  const { error } = await supabase
    .from("workout_sessions")
    .update({
      duration_sec: metrics.durationSec,
      moving_time_sec: metrics.movingTimeSec,
      distance_km: metrics.distanceKm,
      avg_speed_kmh: metrics.avgSpeedKmh,
      calories_kcal: metrics.caloriesKcal,
      steps: metrics.steps,
      lap_splits: metrics.lapSplits,
      filtered_route_json: metrics.filteredRouteJson,
      processing_status: "client_finalized",
      data_quality_score: metrics.dataQualityScore,
      metrics_version: METRICS_VERSION,
      route_match_status: metrics.routeMatchStatus,
      route_distance_source: metrics.routeDistanceSource,
      route_match_metrics_json: metrics.routeMatchMetricsJson,
    })
    .eq("id", workoutId);
  if (error) throw error;
}

async function insertLog(
  supabase: SupabaseAdminClient,
  workoutId: string,
  jobId: string,
  logLevel: string,
  eventType: string,
  message: string,
  payload: Record<string, unknown>,
) {
  const { error } = await supabase
    .from("workout_processing_logs")
    .insert({
      workout_id: workoutId,
      job_id: jobId,
      log_level: logLevel,
      event_type: eventType,
      message,
      payload,
    });
  if (error) throw error;
}

async function persistSegmentAudits(
  supabase: SupabaseAdminClient,
  workoutId: string,
  segmentAudits: SegmentAuditRow[],
) {
  const { error: deleteError } = await supabase
    .from("workout_segment_audits")
    .delete()
    .eq("workout_id", workoutId);
  if (deleteError) throw deleteError;

  if (segmentAudits.length === 0) return;

  const rows = segmentAudits.map((audit) => ({
    workout_id: workoutId,
    segment_index: audit.segmentIndex,
    started_at: audit.startedAt,
    ended_at: audit.endedAt,
    duration_sec: audit.durationSec,
    distance_m: audit.distanceM,
    pace_sec_per_km: audit.paceSecPerKm,
    avg_speed_kmh: audit.avgSpeedKmh,
    max_speed_kmh: audit.maxSpeedKmh,
    avg_accuracy_m: audit.avgAccuracyM,
    status: audit.status,
    reason: audit.reason,
    features: audit.features,
  }));

  const { error } = await supabase.from("workout_segment_audits").insert(rows);
  if (error) throw error;
}

export function computeCanonicalMetrics(input: {
  workout: WorkoutRow;
  rawGpsPoints: RawGpsPoint[];
  rawStepIntervals: RawStepInterval[];
  userProfile: UserProfileRow | null;
}): CanonicalMetrics {
  const durationSec = resolveDurationSec(input.workout, input.rawGpsPoints);
  const stepCount = resolveSteps(input.rawStepIntervals, input.workout.steps);

  if (input.workout.mode === "indoor") {
    const indoorDistanceKm = sanitizeNonNegative(input.workout.distance_km);
    const indoorAvgSpeedKmh = durationSec > 0
      ? round2(indoorDistanceKm / (durationSec / 3600))
      : 0;
    const indoorCaloriesKcal = resolveCaloriesKcal({
      activityType: input.workout.activity_type,
      weightKg: input.userProfile?.weight_kg ?? null,
      gender: input.userProfile?.gender ?? null,
      distanceKm: indoorDistanceKm,
      avgSpeedKmh: indoorAvgSpeedKmh,
      fallbackCalories: input.workout.calories_kcal,
    });
    return {
      durationSec,
      movingTimeSec: durationSec,
      distanceKm: indoorDistanceKm,
      avgSpeedKmh: indoorAvgSpeedKmh,
      caloriesKcal: indoorCaloriesKcal,
      steps: stepCount,
      lapSplits: [],
      filteredRouteJson: [],
      dataQualityScore: round2(stepCount > 0 ? 92 : 72),
      routeMatchStatus: "not_requested",
      routeDistanceSource: "filtered",
      segmentAudits: [],
      routeMatchMetricsJson: {
        mode: "indoor",
        rawGpsPointCount: input.rawGpsPoints.length,
        rawStepIntervalCount: input.rawStepIntervals.length,
      },
      logSummary: {
        mode: "indoor",
        durationSec,
        movingTimeSec: durationSec,
        distanceKm: indoorDistanceKm,
        steps: stepCount,
        rawGpsPointCount: input.rawGpsPoints.length,
        rawStepIntervalCount: input.rawStepIntervals.length,
      },
    };
  }

  const processedGps = processRawGpsPoints(
    input.rawGpsPoints,
    input.workout.activity_type,
  );
  const fallbackDistanceKm = sanitizeNonNegative(input.workout.distance_km);
  const distanceKm = processedGps.distanceKm > 0
    ? processedGps.distanceKm
    : fallbackDistanceKm;
  const avgSpeedKmh = durationSec > 0
    ? round2(distanceKm / (durationSec / 3600))
    : 0;
  const caloriesKcal = resolveCaloriesKcal({
    activityType: input.workout.activity_type,
    weightKg: input.userProfile?.weight_kg ?? null,
    gender: input.userProfile?.gender ?? null,
    distanceKm,
    avgSpeedKmh,
    fallbackCalories: input.workout.calories_kcal,
  });
  const lapSplits = buildLapSplits(processedGps.acceptedSegments);
  const movingTimeSec = resolveMovingTimeSec({
    persistedMovingTimeSec: input.workout.moving_time_sec,
    durationSec,
    mode: input.workout.mode,
    restDurationSec: processedGps.restDurationSec,
  });
  const dataQualityScore = computeDataQualityScore({
    rawPointCount: input.rawGpsPoints.length,
    acceptedPointCount: processedGps.acceptedPointCount,
    suspiciousSegmentCount: processedGps.suspiciousSegmentCount,
    droppedSegmentCount: processedGps.droppedSegmentCount,
    invalidSegmentCount: processedGps.invalidSegmentCount,
    gpsGapCount: processedGps.gpsGapCount,
    poorAccuracyPointCount: processedGps.poorAccuracyPointCount,
  });

  return {
    durationSec,
    movingTimeSec,
    distanceKm,
    avgSpeedKmh,
    caloriesKcal,
    steps: stepCount,
    lapSplits,
    filteredRouteJson: processedGps.filteredRoute,
    dataQualityScore,
    routeMatchStatus: processedGps.filteredRoute.flat().length >= 10
      ? "pending"
      : "not_requested",
    routeDistanceSource: "filtered",
    segmentAudits: processedGps.segmentAudits,
    routeMatchMetricsJson: {
      gps_gap_count: processedGps.gpsGapCount,
      gps_gap_duration_sec: processedGps.gpsGapDurationSec,
      accepted_point_count: processedGps.acceptedPointCount,
      suspicious_segment_count: processedGps.suspiciousSegmentCount,
      dropped_segment_count: processedGps.droppedSegmentCount,
      invalid_segment_count: processedGps.invalidSegmentCount,
      valid_distance_km: processedGps.distanceKm,
      suspicious_distance_km: processedGps.suspiciousDistanceKm,
      invalid_distance_km: processedGps.invalidDistanceKm,
      suspicious_distance_ratio: processedGps.suspiciousDistanceRatio,
      workout_validity_status: processedGps.suspiciousDistanceRatio > 0.3
        ? "unverified"
        : processedGps.suspiciousDistanceRatio > 0.1
        ? "partial"
        : "verified",
      rest_after_fast_duration_sec: processedGps.restAfterFastDurationSec,
      max_segment_speed_kmh: processedGps.maxSegmentSpeedKmh,
      median_segment_speed_kmh: processedGps.medianSegmentSpeedKmh,
      poor_accuracy_point_count: processedGps.poorAccuracyPointCount,
      recovery_break_count: processedGps.recoveryBreakCount,
      raw_gps_point_count: input.rawGpsPoints.length,
      finalized_by: JOB_TYPE,
      finalized_metrics_version: METRICS_VERSION,
    },
    logSummary: {
      mode: "outdoor",
      durationSec,
      movingTimeSec,
      distanceKm,
      avgSpeedKmh,
      caloriesKcal,
      steps: stepCount,
      rawGpsPointCount: input.rawGpsPoints.length,
      acceptedPointCount: processedGps.acceptedPointCount,
      suspiciousSegmentCount: processedGps.suspiciousSegmentCount,
      droppedSegmentCount: processedGps.droppedSegmentCount,
      invalidSegmentCount: processedGps.invalidSegmentCount,
      validDistanceKm: processedGps.distanceKm,
      suspiciousDistanceKm: processedGps.suspiciousDistanceKm,
      invalidDistanceKm: processedGps.invalidDistanceKm,
      suspiciousDistanceRatio: processedGps.suspiciousDistanceRatio,
      workoutValidityStatus: processedGps.suspiciousDistanceRatio > 0.3
        ? "unverified"
        : processedGps.suspiciousDistanceRatio > 0.1
        ? "partial"
        : "verified",
      restAfterFastDurationSec: processedGps.restAfterFastDurationSec,
      gpsGapCount: processedGps.gpsGapCount,
      gpsGapDurationSec: processedGps.gpsGapDurationSec,
      recoveryBreakCount: processedGps.recoveryBreakCount,
      dataQualityScore,
    },
  };
}

function resolveDurationSec(workout: WorkoutRow, rawGpsPoints: RawGpsPoint[]): number {
  if (typeof workout.duration_sec === "number" && workout.duration_sec >= 0) {
    return Math.round(workout.duration_sec);
  }

  if (workout.started_at && workout.ended_at) {
    const diffSec =
      (Date.parse(workout.ended_at) - Date.parse(workout.started_at)) / 1000;
    if (Number.isFinite(diffSec) && diffSec >= 0) {
      return Math.round(diffSec);
    }
  }

  if (rawGpsPoints.length >= 2) {
    const diffSec =
      (Date.parse(rawGpsPoints.at(-1)!.timestamp) -
        Date.parse(rawGpsPoints[0].timestamp)) / 1000;
    if (Number.isFinite(diffSec) && diffSec >= 0) {
      return Math.round(diffSec);
    }
  }

  return 0;
}

function resolveSteps(
  rawStepIntervals: RawStepInterval[],
  fallbackSteps: number | null,
): number {
  const rawSteps = rawStepIntervals.reduce((sum, interval) => {
    const safeSteps = Number(interval.steps_count);
    return sum + (Number.isFinite(safeSteps) && safeSteps > 0 ? safeSteps : 0);
  }, 0);
  if (rawSteps > 0) return rawSteps;
  return Math.max(0, Math.round(Number(fallbackSteps ?? 0)));
}

function resolveMovingTimeSec(input: {
  persistedMovingTimeSec: number | null;
  durationSec: number;
  mode: string;
  restDurationSec: number;
}): number {
  const persisted = Number(input.persistedMovingTimeSec ?? 0);
  if (Number.isFinite(persisted) && persisted > 0) {
    return Math.max(0, Math.min(input.durationSec, Math.round(persisted)));
  }

  if (input.mode === "indoor") {
    return input.durationSec;
  }

  return Math.max(
    0,
    Math.min(input.durationSec, Math.round(input.durationSec - input.restDurationSec)),
  );
}

function processRawGpsPoints(rawPoints: RawGpsPoint[], activityType: string) {
  const normalized = rawPoints
    .map((point) => ({
      timestamp: point.timestamp,
      latitude: Number(point.latitude),
      longitude: Number(point.longitude),
      accuracy: point.accuracy == null ? null : Number(point.accuracy),
      deviceSource: point.device_source,
    }))
    .filter((point) =>
      Number.isFinite(Date.parse(point.timestamp)) &&
      Number.isFinite(point.latitude) &&
      Number.isFinite(point.longitude) &&
      Math.abs(point.latitude) <= 90 &&
      Math.abs(point.longitude) <= 180
    )
    .sort((a, b) => Date.parse(a.timestamp) - Date.parse(b.timestamp));

  const deduped = normalized.filter((point, index, points) => {
    if (index === 0) return true;
    const prev = points[index - 1];
    return !(
      prev.timestamp === point.timestamp &&
      prev.latitude === point.latitude &&
      prev.longitude === point.longitude
    );
  });

  const maxSpeedMs = maxExpectedSpeedMs(activityType);
  const validLegs: MovementLeg[] = [];
  const filteredRoute: RoutePoint[][] = [];
  let acceptedPointCount = deduped.length > 0 ? 1 : 0;
  let suspiciousSegmentCount = 0;
  let invalidSegmentCount = 0;
  let droppedSegmentCount = 0;
  let poorAccuracyPointCount = 0;
  let gpsGapCount = 0;
  let gpsGapDurationSec = 0;
  let recoveryBreakCount = 0;
  let restDurationSec = 0;
  let validDistanceM = 0;
  let suspiciousDistanceM = 0;
  let invalidDistanceM = 0;
  let restAfterFastDurationSec = 0;
  let lastAuditWasFast = false;

  const rawLegs: MovementLeg[] = [];

  for (let i = 0; i < deduped.length; i += 1) {
    const point = deduped[i];
    if ((point.accuracy ?? 0) > POOR_ACCURACY_METERS) {
      poorAccuracyPointCount += 1;
    }

    const routePoint: RoutePoint = {
      lat: point.latitude,
      lng: point.longitude,
      timestamp: new Date(point.timestamp).toISOString(),
    };

    if (i === 0) continue;

    const prev = deduped[i - 1];
    const prevRoutePoint = {
      lat: prev.latitude,
      lng: prev.longitude,
      timestamp: new Date(prev.timestamp).toISOString(),
    };
    const durationSec = (Date.parse(point.timestamp) - Date.parse(prev.timestamp)) /
      1000;
    const distanceM = haversineMeters(
      { lat: prev.latitude, lng: prev.longitude },
      { lat: point.latitude, lng: point.longitude },
    );
    const avgAccuracy = averageNullable(prev.accuracy, point.accuracy);
    const speedMs = durationSec > 0 ? distanceM / durationSec : Number.POSITIVE_INFINITY;
    const deviceRequestedBreak =
      (point.deviceSource ?? "").includes("recovery") ||
      (prev.deviceSource ?? "").includes("recovery");

    if (!Number.isFinite(durationSec) || durationSec <= 0) {
      droppedSegmentCount += 1;
      continue;
    }

    if (deviceRequestedBreak) {
      recoveryBreakCount += 1;
      acceptedPointCount += 1;
      continue;
    }

    if (durationSec > GAP_THRESHOLD_SEC) {
      gpsGapCount += 1;
      gpsGapDurationSec += Math.round(durationSec);
      acceptedPointCount += 1;
      continue;
    }

    if (distanceM < MIN_SEGMENT_DISTANCE_M && speedMs < 0.3) {
      restDurationSec += durationSec;
      acceptedPointCount += 1;
      rawLegs.push({
        from: prevRoutePoint,
        to: routePoint,
        durationSec,
        distanceM: 0,
        avgAccuracy,
        speedMs: 0,
      });
      continue;
    }

    if (
      durationSec > HARD_GAP_THRESHOLD_SEC ||
      avgAccuracy > MAX_ACCURACY_METERS ||
      distanceM < MIN_SEGMENT_DISTANCE_M ||
      speedMs > maxSpeedMs * 1.35
    ) {
      droppedSegmentCount += 1;
      acceptedPointCount += 1;
      continue;
    }

    if (distanceM < 1.0 || speedMs < 0.3) {
      restDurationSec += durationSec;
    }

    acceptedPointCount += 1;
    rawLegs.push({
      from: prevRoutePoint,
      to: routePoint,
      durationSec,
      distanceM,
      avgAccuracy,
      speedMs,
    });
  }

  const segmentAudits = buildSegmentAudits(rawLegs, activityType);
  for (const audit of segmentAudits) {
    const isIdleAudit = audit.avgSpeedKmh < 1 ||
      audit.reason === "stationary_or_too_short" ||
      audit.reason === "pace_too_slow";
    if (lastAuditWasFast && isIdleAudit) {
      restAfterFastDurationSec += audit.durationSec;
    }

    if (audit.status === "valid") {
      const segmentLegs = rawLegs.slice(
        Number(audit.features.start_leg_index ?? 0),
        Number(audit.features.end_leg_index ?? -1) + 1,
      );
      validLegs.push(...segmentLegs);
      validDistanceM += audit.distanceM;
      appendValidRouteSegment(filteredRoute, segmentLegs);
      lastAuditWasFast = false;
    } else if (audit.status === "suspicious") {
      suspiciousSegmentCount += 1;
      suspiciousDistanceM += audit.distanceM;
      lastAuditWasFast = audit.reason.includes("fast");
    } else {
      invalidSegmentCount += 1;
      invalidDistanceM += audit.distanceM;
      lastAuditWasFast = lastAuditWasFast && isIdleAudit;
    }
  }

  const speedSamplesKmh = segmentAudits
    .map((audit) => audit.avgSpeedKmh)
    .filter((value) => Number.isFinite(value) && value > 0)
    .sort((a, b) => a - b);
  const totalClassifiedDistanceM = validDistanceM + suspiciousDistanceM +
    invalidDistanceM;

  return {
    acceptedSegments: validLegs,
    filteredRoute,
    segmentAudits,
    distanceKm: round3(validDistanceM / 1000),
    suspiciousDistanceKm: round3(suspiciousDistanceM / 1000),
    invalidDistanceKm: round3(invalidDistanceM / 1000),
    suspiciousDistanceRatio: totalClassifiedDistanceM > 0
      ? round3(suspiciousDistanceM / totalClassifiedDistanceM)
      : 0,
    restDurationSec: Math.round(restDurationSec >= 60 ? restDurationSec : 0),
    restAfterFastDurationSec,
    acceptedPointCount,
    suspiciousSegmentCount,
    invalidSegmentCount,
    droppedSegmentCount,
    poorAccuracyPointCount,
    gpsGapCount,
    gpsGapDurationSec,
    recoveryBreakCount,
    maxSegmentSpeedKmh: speedSamplesKmh.length > 0
      ? round2(Math.max(...speedSamplesKmh))
      : 0,
    medianSegmentSpeedKmh: median(speedSamplesKmh),
  };
}

function buildSegmentAudits(
  legs: MovementLeg[],
  activityType: string,
): SegmentAuditRow[] {
  const audits: SegmentAuditRow[] = [];
  let bucket: MovementLeg[] = [];
  let bucketDistanceM = 0;
  let bucketDurationSec = 0;
  let bucketStartLegIndex = 0;

  for (let i = 0; i < legs.length; i += 1) {
    const leg = legs[i];
    if (bucket.length === 0) bucketStartLegIndex = i;

    bucket.push(leg);
    bucketDistanceM += leg.distanceM;
    bucketDurationSec += leg.durationSec;

    if (bucketDistanceM >= 100 || bucketDurationSec >= 30) {
      audits.push(classifySegmentAudit({
        legs: bucket,
        activityType,
        segmentIndex: audits.length,
        startLegIndex: bucketStartLegIndex,
        endLegIndex: i,
      }));
      bucket = [];
      bucketDistanceM = 0;
      bucketDurationSec = 0;
    }
  }

  if (bucket.length > 0) {
    audits.push(classifySegmentAudit({
      legs: bucket,
      activityType,
      segmentIndex: audits.length,
      startLegIndex: bucketStartLegIndex,
      endLegIndex: legs.length - 1,
    }));
  }

  return audits;
}

function classifySegmentAudit(input: {
  legs: MovementLeg[];
  activityType: string;
  segmentIndex: number;
  startLegIndex: number;
  endLegIndex: number;
}): SegmentAuditRow {
  const distanceM = input.legs.reduce((sum, leg) => sum + leg.distanceM, 0);
  const durationSec = input.legs.reduce((sum, leg) => sum + leg.durationSec, 0);
  const avgSpeedKmh = durationSec > 0 ? (distanceM / durationSec) * 3.6 : 0;
  const maxSpeedKmh = input.legs.reduce(
    (max, leg) => Math.max(max, leg.speedMs * 3.6),
    0,
  );
  const avgAccuracyM = averageNumbers(input.legs.map((leg) => leg.avgAccuracy));
  const paceSecPerKm = distanceM > 0 ? durationSec / (distanceM / 1000) : null;
  const thresholds = segmentThresholdForActivity(input.activityType);
  let status: "valid" | "suspicious" | "invalid" = "valid";
  let reason = "valid";

  if (distanceM < MIN_SEGMENT_DISTANCE_M) {
    status = "invalid";
    reason = "stationary_or_too_short";
  } else if ((avgAccuracyM ?? 0) > MAX_ACCURACY_METERS) {
    status = "invalid";
    reason = "low_gps_accuracy";
  } else if (paceSecPerKm != null && paceSecPerKm < thresholds.minPaceSecPerKm) {
    status = "suspicious";
    reason = input.activityType.toLowerCase() === "cycling"
      ? "suspicious_fast_for_cycling"
      : "pace_too_fast";
  } else if (maxSpeedKmh > thresholds.maxSpeedKmh) {
    status = "suspicious";
    reason = input.activityType.toLowerCase() === "cycling"
      ? "suspicious_fast_for_cycling"
      : "speed_too_fast";
  } else if (paceSecPerKm != null && paceSecPerKm > thresholds.maxPaceSecPerKm) {
    status = "invalid";
    reason = "pace_too_slow";
  }

  const first = input.legs[0];
  const last = input.legs.at(-1)!;
  return {
    segmentIndex: input.segmentIndex,
    startedAt: first.from.timestamp,
    endedAt: last.to.timestamp,
    durationSec: Math.max(0, Math.round(durationSec)),
    distanceM: round2(distanceM),
    paceSecPerKm: paceSecPerKm == null ? null : round2(paceSecPerKm),
    avgSpeedKmh: round2(avgSpeedKmh),
    maxSpeedKmh: round2(maxSpeedKmh),
    avgAccuracyM: avgAccuracyM == null ? null : round2(avgAccuracyM),
    status,
    reason,
    features: {
      activity_type: input.activityType,
      start_leg_index: input.startLegIndex,
      end_leg_index: input.endLegIndex,
      leg_count: input.legs.length,
      min_pace_sec_per_km: thresholds.minPaceSecPerKm,
      max_pace_sec_per_km: thresholds.maxPaceSecPerKm,
      max_speed_kmh_threshold: thresholds.maxSpeedKmh,
    },
  };
}

function segmentThresholdForActivity(activityType: string) {
  switch (activityType.toLowerCase()) {
    case "cycling":
      return {
        minPaceSecPerKm: 180,
        maxPaceSecPerKm: 900,
        maxSpeedKmh: 20,
      };
    case "walking":
      return {
        minPaceSecPerKm: 300,
        maxPaceSecPerKm: 1800,
        maxSpeedKmh: 9,
      };
    case "hiking":
      return {
        minPaceSecPerKm: 240,
        maxPaceSecPerKm: 2400,
        maxSpeedKmh: 12,
      };
    case "running":
    default:
      return {
        minPaceSecPerKm: 150,
        maxPaceSecPerKm: 720,
        maxSpeedKmh: 24,
      };
  }
}

function appendValidRouteSegment(
  filteredRoute: RoutePoint[][],
  legs: MovementLeg[],
) {
  if (legs.length === 0) return;
  const route = [legs[0].from, ...legs.map((leg) => leg.to)];
  if (route.length >= 2) filteredRoute.push(route);
}

function buildLapSplits(segments: CandidateSegment[]) {
  const splits: Array<{
    index: number;
    distanceKm: number;
    durationSeconds: number;
    paceMinPerKm: number;
  }> = [];
  let cumulativeDistanceM = 0;
  let cumulativeDurationSec = 0;
  let splitStartDistanceM = 0;
  let splitStartDurationSec = 0;
  let nextLapBoundaryM = 1000;
  let lapIndex = 1;

  for (const segment of segments) {
    cumulativeDistanceM += segment.distanceM;
    cumulativeDurationSec += segment.durationSec;

    while (cumulativeDistanceM >= nextLapBoundaryM) {
      const lapDurationSec = Math.max(
        1,
        Math.round(cumulativeDurationSec - splitStartDurationSec),
      );
      splits.push({
        index: lapIndex,
        distanceKm: 1,
        durationSeconds: lapDurationSec,
        paceMinPerKm: round2(lapDurationSec / 60),
      });
      splitStartDistanceM = nextLapBoundaryM;
      splitStartDurationSec = cumulativeDurationSec;
      nextLapBoundaryM += 1000;
      lapIndex += 1;
    }
  }

  const trailingDistanceKm = (cumulativeDistanceM - splitStartDistanceM) / 1000;
  const trailingDurationSec = cumulativeDurationSec - splitStartDurationSec;
  if (trailingDistanceKm >= 0.25 && trailingDurationSec > 0) {
    splits.push({
      index: lapIndex,
      distanceKm: round2(trailingDistanceKm),
      durationSeconds: Math.round(trailingDurationSec),
      paceMinPerKm: round2((trailingDurationSec / 60) / trailingDistanceKm),
    });
  }

  return splits;
}

function computeDataQualityScore(input: {
  rawPointCount: number;
  acceptedPointCount: number;
  suspiciousSegmentCount: number;
  droppedSegmentCount: number;
  invalidSegmentCount: number;
  gpsGapCount: number;
  poorAccuracyPointCount: number;
}): number {
  if (input.rawPointCount === 0) return 35;

  const acceptanceRatio = input.acceptedPointCount / input.rawPointCount;
  let score = 100;
  score -= (1 - acceptanceRatio) * 35;
  score -= input.suspiciousSegmentCount * 3.5;
  score -= input.droppedSegmentCount * 4.5;
  score -= input.invalidSegmentCount * 6.5;
  score -= input.gpsGapCount * 6;
  score -= (input.poorAccuracyPointCount / input.rawPointCount) * 15;
  return round2(Math.max(0, Math.min(100, score)));
}

function resolveCaloriesKcal(input: {
  activityType: string;
  weightKg: number | null;
  gender: string | null;
  distanceKm: number;
  avgSpeedKmh: number;
  fallbackCalories: number | null;
}): number {
  const safeDistanceKm = sanitizeNonNegative(input.distanceKm);
  if (safeDistanceKm <= 0) return 0;

  if (!input.weightKg || input.weightKg <= 0) {
    return Math.max(0, Math.round(Number(input.fallbackCalories ?? 0)));
  }

  const isRunning = input.activityType.toLowerCase().includes("run");
  let factor = isRunning ? 1.05 : 0.92;
  if (input.avgSpeedKmh > 10) factor += 0.05;
  if (input.avgSpeedKmh > 15) factor += 0.05;
  const genderFactor = input.gender?.toLowerCase() === "female" ? 0.95 : 1.0;
  return Math.round(input.weightKg * safeDistanceKm * factor * genderFactor);
}

function maxExpectedSpeedMs(activityType: string): number {
  switch (activityType.toLowerCase()) {
    case "walking":
      return 3.0;
    case "hiking":
      return 2.7;
    case "running":
      return 7.2;
    case "cycling":
      return 20;
    default:
      return 8;
  }
}

function averageNullable(a: number | null, b: number | null): number {
  if (a == null && b == null) return 0;
  if (a == null) return b ?? 0;
  if (b == null) return a;
  return (a + b) / 2;
}

function averageNumbers(values: number[]): number | null {
  const safe = values.filter((value) => Number.isFinite(value));
  if (safe.length === 0) return null;
  return safe.reduce((sum, value) => sum + value, 0) / safe.length;
}

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const middle = Math.floor(values.length / 2);
  if (values.length % 2 === 1) return round2(values[middle]);
  return round2((values[middle - 1] + values[middle]) / 2);
}

function sanitizeNonNegative(value: number | null | undefined): number {
  const safe = Number(value ?? 0);
  if (!Number.isFinite(safe) || safe < 0) return 0;
  return safe;
}

function haversineMeters(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
  const earthRadiusMeters = 6371000;
  const dLat = toRadians(b.lat - a.lat);
  const dLng = toRadians(b.lng - a.lng);
  const lat1 = toRadians(a.lat);
  const lat2 = toRadians(b.lat);
  const hav = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLng / 2) * Math.sin(dLng / 2) * Math.cos(lat1) * Math.cos(lat2);
  const c = 2 * Math.atan2(Math.sqrt(hav), Math.sqrt(1 - hav));
  return earthRadiusMeters * c;
}

function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

function round3(value: number): number {
  return Math.round(value * 1000) / 1000;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}
