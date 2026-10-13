import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";
import {
  corsPreflightResponse,
  logSecurityEvent,
  readJsonBody,
  requestIdFor,
  secureJsonResponse,
  validateGpsBatch,
} from "../_shared/security.ts";

Deno.serve(async (req: Request) => {
  const requestId = requestIdFor(req);
  const startedAt = performance.now();
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
      payload = await readJsonBody(req, 512 * 1024);
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
    const validation = validateGpsBatch(payload);
    if (!validation.ok) {
      return secureJsonResponse(req, { error: validation.error }, 400, {
        "X-Request-Id": requestId,
      });
    }

    const { data: session, error: sessionError } = await supabase
      .from("workout_sessions")
      .select("id")
      .eq("id", validation.workoutId)
      .eq("user_id", user.id)
      .maybeSingle();
    if (sessionError || !session) {
      return secureJsonResponse(
        req,
        { error: "Workout session not found or access denied" },
        404,
        { "X-Request-Id": requestId },
      );
    }

    const pointsToInsert = validation.points.map((point) => ({
      workout_id: validation.workoutId,
      timestamp: point.timestamp ?? new Date().toISOString(),
      latitude: point.latitude,
      longitude: point.longitude,
      altitude: point.altitude ?? null,
      speed: point.speed ?? null,
      accuracy: point.accuracy ?? null,
      heading: point.heading ?? null,
      device_source: point.device_source ?? "edge_function",
    }));
    const { error } = await supabase.from("raw_gps_points").insert(
      pointsToInsert,
    );
    if (error) {
      logSecurityEvent("error", "gps_batch_insert_failed", requestId, {
        point_count: pointsToInsert.length,
      });
      return secureJsonResponse(
        req,
        { error: "Could not store GPS data" },
        500,
        { "X-Request-Id": requestId },
      );
    }
    logSecurityEvent("info", "gps_batch_stored", requestId, {
      point_count: pointsToInsert.length,
      duration_ms: Math.round(performance.now() - startedAt),
    });
    return secureJsonResponse(
      req,
      { status: "ok", count: pointsToInsert.length },
      200,
      { "X-Request-Id": requestId },
    );
  } catch {
    logSecurityEvent("error", "gps_request_failed", requestId, {
      duration_ms: Math.round(performance.now() - startedAt),
    });
    return secureJsonResponse(req, { error: "Internal Server Error" }, 500, {
      "X-Request-Id": requestId,
    });
  }
});
