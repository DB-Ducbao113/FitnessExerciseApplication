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
    const { error: updateError } = await supabase
      .from("workout_sessions")
      .update({
        ended_at: endedAt,
        duration_sec: durationSec,
        distance_km: payload.distance_km ?? null,
        avg_speed_kmh: payload.avg_speed_kmh ?? null,
        calories_kcal: payload.calories_kcal ?? null,
        steps: payload.steps ?? null,
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
    return new Response(
      JSON.stringify({
        status: "ok",
        workout_id: payload.workout_id,
        ended_at: endedAt,
        duration_sec: durationSec,
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
