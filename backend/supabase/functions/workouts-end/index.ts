import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
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
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
    const payload = await req.json();
    if (!payload.workout_id) {
      return new Response(JSON.stringify({ error: "Missing workout_id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
    const endedAt = new Date().toISOString();
    const { data: existing, error: fetchError } = await supabase
      .from("workout_sessions")
      .select("id, user_id, started_at")
      .eq("id", payload.workout_id)
      .eq("user_id", user.id)
      .maybeSingle();
    if (fetchError || !existing) {
      return new Response(
        JSON.stringify({ error: "Workout session not found or access denied" }),
        {
          status: 404,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
    let durationSec = payload.duration_sec ?? null;
    if (!durationSec && existing.started_at) {
      const startMs = new Date(existing.started_at).getTime();
      const endMs = new Date(endedAt).getTime();
      durationSec = Math.round((endMs - startMs) / 1000);
    }
    const movingTimeSec = payload.moving_time_sec ?? durationSec ?? 0;
    const { error: updateError } = await supabase
      .from("workout_sessions")
      .update({
        ended_at: endedAt,
        duration_sec: durationSec,
        moving_time_sec: movingTimeSec,
        distance_km: payload.distance_km ?? null,
        avg_speed_kmh: payload.avg_speed_kmh ?? null,
        calories_kcal: payload.calories_kcal ?? null,
        steps: payload.steps ?? null,
        processing_status: "client_finished_pending_processing",
      })
      .eq("id", payload.workout_id)
      .eq("user_id", user.id);
    if (updateError) {
      console.error("Update error:", updateError);
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { error: jobError } = await supabase
      .from("workout_processing_jobs")
      .insert({
        workout_id: payload.workout_id,
        job_type: "deterministic_finalize",
        status: "queued",
        attempt_count: 0,
      });
    if (jobError) {
      console.error("Job enqueue error:", jobError);
      return new Response(JSON.stringify({ error: jobError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    await supabase
      .from("workout_processing_logs")
      .insert({
        workout_id: payload.workout_id,
        log_level: "info",
        event_type: "edge_finish_enqueued",
        message: "Edge function queued deterministic finalize processing.",
        payload: {
          duration_sec: durationSec,
          moving_time_sec: movingTimeSec,
          distance_km: payload.distance_km ?? null,
          avg_speed_kmh: payload.avg_speed_kmh ?? null,
          calories_kcal: payload.calories_kcal ?? null,
          steps: payload.steps ?? null,
        },
      });

    return new Response(
      JSON.stringify({
        status: "ok",
        workout_id: payload.workout_id,
        ended_at: endedAt,
        duration_sec: durationSec,
        moving_time_sec: movingTimeSec,
        processing_status: "client_finished_pending_processing",
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Server error:", err);
    return new Response(JSON.stringify({ error: "Internal Server Error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
