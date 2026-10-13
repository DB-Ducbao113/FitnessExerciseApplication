import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";
import {
  corsPreflightResponse,
  logSecurityEvent,
  readJsonBody,
  requestIdFor,
  secureJsonResponse,
  validateWorkoutEndPayload,
} from "../_shared/security.ts";

Deno.serve(async (req: Request) => {
  const requestId = requestIdFor(req);
  const requestStarted = performance.now();
  if (req.method === "OPTIONS") return corsPreflightResponse(req);
  if (req.method !== "POST") {
    return secureJsonResponse(req, { error: "Method not allowed" }, 405, {
      Allow: "POST, OPTIONS",
      "X-Request-Id": requestId,
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return secureJsonResponse(req, { error: "Unauthorized" }, 401, {
        "X-Request-Id": requestId,
      });
    }
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return secureJsonResponse(req, { error: "Unauthorized" }, 401, {
        "X-Request-Id": requestId,
      });
    }

    let payload: unknown;
    try {
      payload = await readJsonBody(req, 32 * 1024);
    } catch (error) {
      const tooLarge = error instanceof Error &&
        error.message === "Payload too large";
      return secureJsonResponse(
        req,
        { error: tooLarge ? "Payload too large" : "Invalid JSON" },
        tooLarge ? 413 : 400,
        { "X-Request-Id": requestId },
      );
    }
    const validation = validateWorkoutEndPayload(payload);
    if (!validation.ok) {
      return secureJsonResponse(req, { error: validation.error }, 400, {
        "X-Request-Id": requestId,
      });
    }

    const endedAt = new Date().toISOString();
    const { data: existing, error: fetchError } = await supabase
      .from("workout_sessions")
      .select("id, started_at")
      .eq("id", validation.workoutId)
      .eq("user_id", user.id)
      .maybeSingle();
    if (fetchError || !existing) {
      return secureJsonResponse(
        req,
        { error: "Workout session not found or access denied" },
        404,
        { "X-Request-Id": requestId },
      );
    }

    const elapsedSeconds = Math.max(
      0,
      Math.min(
        7 * 24 * 60 * 60,
        Math.round(
          (Date.parse(endedAt) - Date.parse(existing.started_at)) / 1000,
        ),
      ),
    );
    const durationSec = validation.durationSec ?? elapsedSeconds;
    const movingTimeSec = validation.movingTimeSec ?? durationSec;
    if (movingTimeSec > durationSec) {
      return secureJsonResponse(
        req,
        { error: "moving_time_sec exceeds duration_sec" },
        400,
        { "X-Request-Id": requestId },
      );
    }

    const { error: updateError } = await supabase
      .from("workout_sessions")
      .update({
        ended_at: endedAt,
        duration_sec: durationSec,
        moving_time_sec: movingTimeSec,
        distance_km: validation.distanceKm,
        avg_speed_kmh: validation.avgSpeedKmh,
        calories_kcal: validation.caloriesKcal,
        steps: validation.steps,
        processing_status: "client_finished_pending_processing",
      })
      .eq("id", validation.workoutId)
      .eq("user_id", user.id);
    if (updateError) {
      logSecurityEvent("error", "workout_end_update_failed", requestId);
      return secureJsonResponse(
        req,
        { error: "Could not finish workout" },
        500,
        { "X-Request-Id": requestId },
      );
    }

    const { error: jobError } = await supabase
      .from("workout_processing_jobs")
      .insert({
        workout_id: validation.workoutId,
        job_type: "deterministic_finalize",
        status: "queued",
        attempt_count: 0,
      });
    if (jobError && jobError.code !== "23505") {
      logSecurityEvent("error", "workout_job_enqueue_failed", requestId);
      return secureJsonResponse(
        req,
        { error: "Workout saved but processing could not be queued" },
        503,
        { "X-Request-Id": requestId },
      );
    }

    await supabase.from("workout_processing_logs").insert({
      workout_id: validation.workoutId,
      log_level: "info",
      event_type: "edge_finish_enqueued",
      message: "Edge function queued deterministic finalize processing.",
      payload: {
        duration_sec: durationSec,
        moving_time_sec: movingTimeSec,
        distance_km: validation.distanceKm,
        avg_speed_kmh: validation.avgSpeedKmh,
        calories_kcal: validation.caloriesKcal,
        steps: validation.steps,
        request_id: requestId,
      },
    });

    logSecurityEvent("info", "workout_finished", requestId, {
      duration_ms: Math.round(performance.now() - requestStarted),
      processing_job_duplicate: jobError?.code === "23505",
    });
    return secureJsonResponse(
      req,
      {
        status: "ok",
        workout_id: validation.workoutId,
        ended_at: endedAt,
        duration_sec: durationSec,
        moving_time_sec: movingTimeSec,
        processing_status: "client_finished_pending_processing",
      },
      200,
      { "X-Request-Id": requestId },
    );
  } catch {
    logSecurityEvent("error", "workout_end_failed", requestId, {
      duration_ms: Math.round(performance.now() - requestStarted),
    });
    return secureJsonResponse(req, { error: "Internal Server Error" }, 500, {
      "X-Request-Id": requestId,
    });
  }
});
