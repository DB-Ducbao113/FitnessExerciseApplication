import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const payload = await req.json();

    if (!payload.workout_id) {
      return new Response(
        JSON.stringify({ error: "Missing workout_id" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Update workout status and stats
    // In a real scenario, we might trigger a background job to calculate stats from gps_points
    // For now, we accept summary stats from client or just mark as completed
    const { error } = await supabase
      .from("workouts")
      .update({
        status: 'COMPLETED',
        end_time: new Date().toISOString(),
        duration_seconds: payload.duration_seconds,
        distance_meters: payload.distance_meters,
        calories_burned: payload.calories_burned,
        avg_pace: payload.avg_pace,
        elevation_gain: payload.elevation_gain,
        steps_count: payload.steps_count
      })
      .eq('id', payload.workout_id)
      .eq('user_id', user.id);

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ status: "ok" }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    return new Response(
      JSON.stringify({ error: "Internal Server Error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
