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
    if (!Array.isArray(payload)) {
      return new Response(
        JSON.stringify({ error: "Input must be an array of points" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
    if (payload.length === 0) {
      return new Response(
        JSON.stringify({ status: "ok", message: "Empty batch ignored" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }
    const first = payload[0];
    if (!first.workout_id || first.latitude == null || first.longitude == null) {
      return new Response(
        JSON.stringify({
          error:
              "Invalid point structure. Required: workout_id, latitude, longitude",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
    const workoutId = first.workout_id;
    const { data: session, error: sessionError } = await supabase
      .from("workout_sessions")
      .select("id")
      .eq("id", workoutId)
      .eq("user_id", user.id)
      .maybeSingle();
    if (sessionError || !session) {
      return new Response(
        JSON.stringify({ error: "Workout session not found or access denied" }),
        {
          status: 404,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
    const pointsToInsert = payload.map((point: any) => ({
      workout_id: point.workout_id,
      timestamp: point.timestamp ?? new Date().toISOString(),
      latitude: point.latitude,
      longitude: point.longitude,
      altitude: point.altitude ?? null,
      speed: point.speed ?? null,
      accuracy: point.accuracy ?? null,
      heading: point.heading ?? null,
      device_source: point.device_source ?? 'edge_function',
    }));
    const { error } = await supabase.from("raw_gps_points").insert(pointsToInsert);
    if (error) {
      console.error("Insert error:", error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(
      JSON.stringify({ status: "ok", count: pointsToInsert.length }),
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
