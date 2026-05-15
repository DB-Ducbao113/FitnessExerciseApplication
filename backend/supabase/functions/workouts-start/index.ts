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
    if (!payload.activity_type) {
      return new Response(JSON.stringify({ error: "Missing activity_type" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
    const validActivities = [
      "running",
      "walking",
      "cycling",
      "hiking",
      "indoor_workout",
      "other",
    ];
    const activityType = payload.activity_type.toLowerCase();
    if (!validActivities.includes(activityType)) {
      return new Response(
        JSON.stringify({
          error: `Invalid activity_type. Must be one of: ${validActivities.join(", ")}`,
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
    const mode = payload.mode === "indoor" ? "indoor" : "outdoor";
    const startedAt = new Date().toISOString();
    const { data, error } = await supabase
      .from("workout_sessions")
      .insert({
        user_id: user.id,
        activity_type: activityType,
        mode,
        started_at: startedAt,
        processing_status: "client_recording",
        metrics_version: 1,
      })
      .select("id")
      .single();
    if (error) {
      console.error("Insert error:", error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(
      JSON.stringify({
        status: "ok",
        workout_id: data.id,
        started_at: startedAt,
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
