import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  try {
    // Get JWT from Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Create client with user's JWT
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    // Extract user from JWT
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const payload = await req.json();

    // Check if payload is an array (Batch mode) or single object (Legacy support if needed, but we enforce batch)
    if (!Array.isArray(payload)) {
      return new Response(
        JSON.stringify({ error: "Input must be an array of points" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (payload.length === 0) {
      return new Response(
        JSON.stringify({ status: "ok", message: "Empty batch ignored" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // Validate first item to ensure structure
    if (!payload[0].workout_id || !payload[0].latitude || !payload[0].longitude) {
       return new Response(
        JSON.stringify({ error: "Invalid point structure. Required: workout_id, latitude, longitude" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    
    const workoutId = payload[0].workout_id;

    // Prepare data for bulk insert
    // We map the incoming JSON to the table columns
    const pointsToInsert = payload.map((point: any) => ({
      workout_id: point.workout_id,
      timestamp: point.timestamp || new Date().toISOString(),
      // PostGIS Point format: ST_SetSRID(ST_MakePoint(lng, lat), 4326)
      // BUT Supabase JS client handles Geography types if passed as GeoJSON or WKT? 
      // Actually simpler: pass as a string `POINT(lng lat)` and cast it in SQL logic?
      // No, for direct insert to `geography` column via JS client, we usually pass a WKT string.
      location: `POINT(${point.longitude} ${point.latitude})`, 
      altitude: point.altitude,
      speed: point.speed,
      accuracy: point.accuracy,
      heading: point.heading
    }));

    const { error } = await supabase
      .from("gps_points")
      .insert(pointsToInsert);

    if (error) {
      console.error("Insert error:", error);
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ status: "ok", count: pointsToInsert.length }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Server error:", err);
    return new Response(
      JSON.stringify({ error: "Internal Server Error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
