import {
  clientIp,
  corsHeadersForRequest,
  isAllowedResetRedirect,
  readJsonBody,
  requestIdFor,
  validateGpsBatch,
  validateInsightRequest,
  validateWorkoutEndPayload,
  validateWorkoutStartPayload,
} from "./security.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("reset redirect accepts only exact production destinations", () => {
  assertEquals(
    isAllowedResetRedirect("io.supabase.flutter://callback", false),
    true,
  );
  assertEquals(
    isAllowedResetRedirect("https://aetrongps.vercel.app/app/", false),
    true,
  );
  assertEquals(
    isAllowedResetRedirect("https://aetrongps.vercel.app/app", false),
    true,
  );
});

Deno.test("reset redirect rejects prefix confusion, credentials, and localhost in production", () => {
  assertEquals(
    isAllowedResetRedirect(
      "https://aetrongps.vercel.app.evil.example/app/",
      false,
    ),
    false,
  );
  assertEquals(
    isAllowedResetRedirect(
      "https://aetrongps.vercel.app@evil.example/app/",
      false,
    ),
    false,
  );
  assertEquals(
    isAllowedResetRedirect("http://localhost:3000/app/", false),
    false,
  );
  assertEquals(isAllowedResetRedirect("javascript:alert(1)", false), false);
});

Deno.test("reset redirect permits loopback only in explicit local mode", () => {
  assertEquals(
    isAllowedResetRedirect("http://localhost:3000/app/", true),
    true,
  );
  assertEquals(
    isAllowedResetRedirect("http://127.0.0.1:8080/app/", true),
    true,
  );
  assertEquals(
    isAllowedResetRedirect("http://localhost.evil.test/app/", true),
    false,
  );
});

Deno.test("clientIp uses the first forwarded address and strips whitespace", () => {
  const request = new Request("https://example.test", {
    headers: { "x-forwarded-for": " 203.0.113.7, 10.0.0.1 " },
  });
  assertEquals(clientIp(request), "203.0.113.7");
});

Deno.test("request IDs are stable per request and preserve valid supplied IDs", () => {
  const generatedRequest = new Request("https://example.test");
  const first = requestIdFor(generatedRequest);
  assertEquals(requestIdFor(generatedRequest), first);

  const suppliedRequest = new Request("https://example.test", {
    headers: { "x-request-id": "trace_123.test" },
  });
  assertEquals(requestIdFor(suppliedRequest), "trace_123.test");
});

Deno.test("CORS reflects only trusted web origins", () => {
  const trusted = new Request("https://api.example.test", {
    headers: { Origin: "https://aetrongps.vercel.app" },
  });
  const hostile = new Request("https://api.example.test", {
    headers: { Origin: "https://evil.example" },
  });
  assertEquals(
    corsHeadersForRequest(trusted)["Access-Control-Allow-Origin"],
    "https://aetrongps.vercel.app",
  );
  assertEquals(
    corsHeadersForRequest(hostile)["Access-Control-Allow-Origin"],
    undefined,
  );
});

Deno.test("JSON body reader rejects payloads above the configured byte limit", async () => {
  const request = new Request("https://example.test", {
    method: "POST",
    body: JSON.stringify({ value: "1234567890" }),
  });
  let rejected = false;
  try {
    await readJsonBody(request, 8);
  } catch (error) {
    rejected = error instanceof Error && error.message === "Payload too large";
  }
  assertEquals(rejected, true);
});

Deno.test("GPS validation accepts a bounded valid batch", () => {
  const result = validateGpsBatch([
    {
      workout_id: "00000000-0000-4000-8000-000000000001",
      timestamp: "2026-10-13T00:00:00.000Z",
      latitude: 10.762622,
      longitude: 106.660172,
      accuracy: 5,
      speed: 3.5,
    },
    {
      workout_id: "00000000-0000-4000-8000-000000000001",
      timestamp: "2026-10-13T00:00:01.000Z",
      latitude: 10.762623,
      longitude: 106.660173,
    },
  ]);

  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.points.length, 2);
});

Deno.test("GPS validation rejects mixed workout IDs and invalid coordinates", () => {
  const mixed = validateGpsBatch([
    {
      workout_id: "00000000-0000-4000-8000-000000000001",
      latitude: 10,
      longitude: 106,
    },
    {
      workout_id: "00000000-0000-4000-8000-000000000002",
      latitude: 10,
      longitude: 106,
    },
  ]);
  assertEquals(mixed.ok, false);

  const invalid = validateGpsBatch([
    {
      workout_id: "00000000-0000-4000-8000-000000000001",
      latitude: 91,
      longitude: 106,
    },
  ]);
  assertEquals(invalid.ok, false);
});

Deno.test("GPS validation rejects oversized batches", () => {
  const points = Array.from({ length: 501 }, () => ({
    workout_id: "00000000-0000-4000-8000-000000000001",
    latitude: 10,
    longitude: 106,
  }));
  assertEquals(validateGpsBatch(points).ok, false);
});

Deno.test("workout start validation rejects unknown activity and mode", () => {
  assertEquals(
    validateWorkoutStartPayload({ activity_type: "flying", mode: "outdoor" })
      .ok,
    false,
  );
  assertEquals(
    validateWorkoutStartPayload({ activity_type: "running", mode: "space" })
      .ok,
    false,
  );
  assertEquals(
    validateWorkoutStartPayload({ activity_type: "RUNNING", mode: "indoor" })
      .ok,
    true,
  );
});

Deno.test("workout end validation bounds metrics and moving time", () => {
  const id = "00000000-0000-4000-8000-000000000001";
  assertEquals(
    validateWorkoutEndPayload({
      workout_id: id,
      duration_sec: 3600,
      moving_time_sec: 3500,
      distance_km: 10,
      avg_speed_kmh: 10,
      calories_kcal: 600,
      steps: 12000,
    }).ok,
    true,
  );
  assertEquals(
    validateWorkoutEndPayload({
      workout_id: id,
      duration_sec: 100,
      moving_time_sec: 101,
    }).ok,
    false,
  );
  assertEquals(
    validateWorkoutEndPayload({ workout_id: id, distance_km: -1 }).ok,
    false,
  );
});

Deno.test("AI insight validation rejects non-finite or out-of-range signals", () => {
  const workoutId = "00000000-0000-4000-8000-000000000001";
  assertEquals(
    validateInsightRequest({ workout_id: workoutId, language: "vi" }).ok,
    true,
  );
  assertEquals(
    validateInsightRequest({
      workout_id: workoutId,
      signals: {
        pace_fatigue_slope: 0.1,
        pace_consistency_cv: 0.2,
        rest_ratio: 2,
        gps_reliability_score: 0.9,
        baseline_pace_zscore: 0,
        baseline_distance_zscore: 0,
        goal_alignment: "on_track",
        recent_7d_volume_km: 10,
      },
    }).ok,
    false,
  );
});
