import { computeCanonicalMetrics } from "./index.ts";

function assert(condition: unknown, message = "Assertion failed") {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}

const workout = {
  id: "00000000-0000-0000-0000-000000000001",
  user_id: "00000000-0000-0000-0000-000000000002",
  activity_type: "cycling",
  mode: "outdoor",
  started_at: "2026-04-26T00:00:00.000Z",
  ended_at: "2026-04-26T00:05:00.000Z",
  duration_sec: 300,
  moving_time_sec: null,
  distance_km: null,
  avg_speed_kmh: null,
  calories_kcal: null,
  steps: null,
};

function gpsPoint(seconds: number, northMeters: number) {
  return {
    timestamp: new Date(Date.parse(workout.started_at) + seconds * 1000)
      .toISOString(),
    latitude: northMeters / 111_320,
    longitude: 0,
    altitude: null,
    speed: null,
    accuracy: 8,
    heading: null,
    device_source: "test",
  };
}

Deno.test("cycling at allowed 3:00/km or slower remains valid", () => {
  const metrics = computeCanonicalMetrics({
    workout,
    rawGpsPoints: [
      gpsPoint(0, 0),
      gpsPoint(5, 25),
      gpsPoint(10, 50),
      gpsPoint(15, 75),
      gpsPoint(20, 100),
      gpsPoint(25, 125),
      gpsPoint(30, 150),
      gpsPoint(35, 175),
      gpsPoint(40, 200),
    ],
    rawStepIntervals: [],
    userProfile: null,
  });

  assert(metrics.distanceKm > 0.15);
  assertEquals(metrics.segmentAudits.every((audit) => audit.status === "valid"), true);
  assertEquals(metrics.routeMatchMetricsJson.suspicious_segment_count, 0);
});

Deno.test("cycling at 2:00/km is flagged and excluded from canonical distance", () => {
  const metrics = computeCanonicalMetrics({
    workout,
    rawGpsPoints: [
      gpsPoint(0, 0),
      gpsPoint(5, 41.67),
      gpsPoint(10, 83.34),
      gpsPoint(15, 125.01),
      gpsPoint(20, 166.68),
    ],
    rawStepIntervals: [],
    userProfile: null,
  });

  assertEquals(metrics.distanceKm, 0);
  assertEquals(metrics.segmentAudits[0].status, "suspicious");
  assertEquals(metrics.segmentAudits[0].reason, "suspicious_fast_for_cycling");
  assertEquals(metrics.routeMatchMetricsJson.suspicious_segment_count, 2);
  assertEquals(metrics.logSummary.workoutValidityStatus, "unverified");
});

Deno.test("fast cycling followed by idle time remains flagged", () => {
  const idlePoints = Array.from({ length: 13 }, (_, index) =>
    gpsPoint(15 + index * 5, 125.01)
  );
  const metrics = computeCanonicalMetrics({
    workout: { ...workout, duration_sec: 180 },
    rawGpsPoints: [
      gpsPoint(0, 0),
      gpsPoint(5, 41.67),
      gpsPoint(10, 83.34),
      gpsPoint(15, 125.01),
      ...idlePoints,
    ],
    rawStepIntervals: [],
    userProfile: null,
  });

  assertEquals(metrics.distanceKm, 0);
  assertEquals(metrics.segmentAudits[0].status, "suspicious");
  assertEquals(metrics.routeMatchMetricsJson.suspicious_segment_count, 1);
  assert(
    Number(metrics.routeMatchMetricsJson.rest_after_fast_duration_sec ?? 0) >=
      60,
  );
});
