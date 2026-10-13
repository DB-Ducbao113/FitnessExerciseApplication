import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";
import {
  corsPreflightResponse,
  logSecurityEvent,
  readJsonBody,
  requestIdFor,
  secureJsonResponse,
  validateWorkoutStartPayload,
} from "../_shared/security.ts";

Deno.serve(async (req: Request) => {
  const requestId = requestIdFor(req);
  const started = performance.now();
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
      payload = await readJsonBody(req, 16 * 1024);
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
    const validation = validateWorkoutStartPayload(payload);
    if (!validation.ok) {
      return secureJsonResponse(req, { error: validation.error }, 400, {
        "X-Request-Id": requestId,
      });
    }

    const startedAt = new Date().toISOString();
    const { data, error } = await supabase
      .from("workout_sessions")
      .insert({
        user_id: user.id,
        activity_type: validation.activityType,
        mode: validation.mode,
        started_at: startedAt,
        processing_status: "client_recording",
        metrics_version: 1,
      })
      .select("id")
      .single();
    if (error) {
      logSecurityEvent("error", "workout_start_insert_failed", requestId);
      return secureJsonResponse(
        req,
        { error: "Could not start workout" },
        500,
        { "X-Request-Id": requestId },
      );
    }
    logSecurityEvent("info", "workout_started", requestId, {
      activity_type: validation.activityType,
      mode: validation.mode,
      duration_ms: Math.round(performance.now() - started),
    });
    return secureJsonResponse(
      req,
      { status: "ok", workout_id: data.id, started_at: startedAt },
      200,
      { "X-Request-Id": requestId },
    );
  } catch {
    logSecurityEvent("error", "workout_start_failed", requestId, {
      duration_ms: Math.round(performance.now() - started),
    });
    return secureJsonResponse(req, { error: "Internal Server Error" }, 500, {
      "X-Request-Id": requestId,
    });
  }
});
