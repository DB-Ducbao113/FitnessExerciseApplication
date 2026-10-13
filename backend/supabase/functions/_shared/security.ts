const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const productionResetRedirects = new Set([
  "io.supabase.flutter://callback",
  "https://aetrongps.vercel.app/app",
  "https://aetrongps.vercel.app/app/",
]);

const generatedRequestIds = new WeakMap<Request, string>();

export function isAllowedResetRedirect(
  rawValue: unknown,
  allowLocalhost: boolean,
): boolean {
  if (typeof rawValue !== "string") return false;
  const value = rawValue.trim();
  if (!value || value.length > 2048) return false;
  if (productionResetRedirects.has(value)) return true;

  if (!allowLocalhost) return false;
  try {
    const url = new URL(value);
    return url.protocol === "http:" &&
      (url.hostname === "localhost" || url.hostname === "127.0.0.1") &&
      !url.username && !url.password;
  } catch {
    return false;
  }
}

export function isLocalEnvironment(): boolean {
  const environment = (Deno.env.get("AETRON_ENVIRONMENT") ?? "")
    .trim()
    .toLowerCase();
  return environment === "local" || environment === "development" ||
    environment === "test";
}

export function corsHeadersForRequest(req: Request): Record<string, string> {
  const origin = req.headers.get("origin")?.trim();
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-request-id",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
  if (origin === "https://aetrongps.vercel.app") {
    headers["Access-Control-Allow-Origin"] = origin;
    return headers;
  }
  if (isLocalEnvironment() && origin) {
    try {
      const url = new URL(origin);
      if (
        url.protocol === "http:" &&
        (url.hostname === "localhost" || url.hostname === "127.0.0.1")
      ) {
        headers["Access-Control-Allow-Origin"] = origin;
      }
    } catch {
      // Invalid origins intentionally receive no allow-origin header.
    }
  }
  return headers;
}

export function corsPreflightResponse(req: Request): Response {
  const headers = corsHeadersForRequest(req);
  const origin = req.headers.get("origin");
  if (origin && !headers["Access-Control-Allow-Origin"]) {
    return new Response(null, { status: 403, headers });
  }
  return new Response(null, { status: 204, headers });
}

export function requestIdFor(req: Request): string {
  const supplied = req.headers.get("x-request-id")?.trim();
  if (supplied && /^[A-Za-z0-9._-]{1,128}$/.test(supplied)) return supplied;

  const existing = generatedRequestIds.get(req);
  if (existing) return existing;
  const generated = crypto.randomUUID();
  generatedRequestIds.set(req, generated);
  return generated;
}

export function secureJsonResponse(
  req: Request,
  body: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeadersForRequest(req),
      "Content-Type": "application/json",
      "X-Request-Id": requestIdFor(req),
      ...extraHeaders,
    },
  });
}

export function logSecurityEvent(
  level: "info" | "warn" | "error",
  event: string,
  requestId: string,
  fields: Record<string, string | number | boolean | null> = {},
): void {
  const entry = JSON.stringify({
    level,
    event,
    request_id: requestId,
    timestamp: new Date().toISOString(),
    ...fields,
  });
  if (level === "error") console.error(entry);
  else if (level === "warn") console.warn(entry);
  else console.info(entry);
}

export function clientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return forwarded || req.headers.get("cf-connecting-ip")?.trim() ||
    req.headers.get("x-real-ip")?.trim() || "unknown";
}

export async function readJsonBody(
  req: Request,
  maximumBytes: number,
): Promise<unknown> {
  const declaredLength = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    throw new Error("Payload too large");
  }
  const text = await req.text();
  if (new TextEncoder().encode(text).byteLength > maximumBytes) {
    throw new Error("Payload too large");
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new Error("Invalid JSON");
  }
}

export async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export type RateLimitResult = {
  allowed: boolean;
  retryAfterSeconds: number;
};

type RpcClient = {
  rpc: (
    functionName: string,
    parameters: Record<string, unknown>,
  ) => PromiseLike<{ data: unknown; error: { message?: string } | null }>;
};

export async function consumeRateLimit(
  service: RpcClient,
  scope: string,
  subject: string,
  limit: number,
  windowSeconds: number,
): Promise<RateLimitResult> {
  const keyHash = await sha256Hex(`${scope}:${subject}`);
  const { data, error } = await service.rpc("consume_api_rate_limit", {
    p_scope: scope,
    p_key_hash: keyHash,
    p_limit: limit,
    p_window_seconds: windowSeconds,
  });
  if (error) throw new Error("Rate limit service unavailable");

  const row = Array.isArray(data) ? data[0] : data;
  if (!row || typeof row !== "object") {
    throw new Error("Invalid rate limit response");
  }
  const result = row as Record<string, unknown>;
  return {
    allowed: result.allowed === true,
    retryAfterSeconds: Number(result.retry_after_seconds ?? windowSeconds),
  };
}

export type ValidatedGpsPoint = {
  workout_id: string;
  timestamp?: string;
  latitude: number;
  longitude: number;
  altitude?: number | null;
  speed?: number | null;
  accuracy?: number | null;
  heading?: number | null;
  device_source?: string | null;
};

export type GpsValidationResult =
  | { ok: true; workoutId: string; points: ValidatedGpsPoint[] }
  | { ok: false; error: string };

function optionalFiniteNumber(
  value: unknown,
  minimum: number,
  maximum: number,
): boolean {
  return value == null ||
    (typeof value === "number" && Number.isFinite(value) && value >= minimum &&
      value <= maximum);
}

export function validateGpsBatch(payload: unknown): GpsValidationResult {
  if (!Array.isArray(payload)) {
    return { ok: false, error: "Input must be an array of points" };
  }
  if (payload.length === 0) {
    return { ok: false, error: "GPS batch must not be empty" };
  }
  if (payload.length > 500) {
    return { ok: false, error: "GPS batch exceeds 500 points" };
  }

  let workoutId = "";
  const points: ValidatedGpsPoint[] = [];
  for (const value of payload) {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      return { ok: false, error: "Every GPS point must be an object" };
    }
    const point = value as Record<string, unknown>;
    if (
      typeof point.workout_id !== "string" ||
      !uuidPattern.test(point.workout_id)
    ) {
      return { ok: false, error: "Invalid workout_id" };
    }
    if (!workoutId) workoutId = point.workout_id;
    if (point.workout_id !== workoutId) {
      return { ok: false, error: "All points must use the same workout_id" };
    }
    if (
      typeof point.latitude !== "number" ||
      !Number.isFinite(point.latitude) || point.latitude < -90 ||
      point.latitude > 90
    ) {
      return { ok: false, error: "Invalid latitude" };
    }
    if (
      typeof point.longitude !== "number" ||
      !Number.isFinite(point.longitude) || point.longitude < -180 ||
      point.longitude > 180
    ) {
      return { ok: false, error: "Invalid longitude" };
    }
    if (
      point.timestamp != null &&
      (typeof point.timestamp !== "string" || point.timestamp.length > 40 ||
        !Number.isFinite(Date.parse(point.timestamp)))
    ) {
      return { ok: false, error: "Invalid timestamp" };
    }
    if (!optionalFiniteNumber(point.altitude, -500, 20_000)) {
      return { ok: false, error: "Invalid altitude" };
    }
    if (!optionalFiniteNumber(point.speed, 0, 150)) {
      return { ok: false, error: "Invalid speed" };
    }
    if (!optionalFiniteNumber(point.accuracy, 0, 10_000)) {
      return { ok: false, error: "Invalid accuracy" };
    }
    if (!optionalFiniteNumber(point.heading, 0, 360)) {
      return { ok: false, error: "Invalid heading" };
    }
    if (
      point.device_source != null &&
      (typeof point.device_source !== "string" ||
        point.device_source.length > 64)
    ) {
      return { ok: false, error: "Invalid device_source" };
    }
    points.push(point as ValidatedGpsPoint);
  }

  return { ok: true, workoutId, points };
}

const workoutActivities = new Set([
  "running",
  "walking",
  "cycling",
  "hiking",
  "indoor_workout",
  "other",
]);

export type WorkoutStartValidation =
  | { ok: true; activityType: string; mode: "indoor" | "outdoor" }
  | { ok: false; error: string };

export function validateWorkoutStartPayload(
  payload: unknown,
): WorkoutStartValidation {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return { ok: false, error: "Invalid request body" };
  }
  const body = payload as Record<string, unknown>;
  if (typeof body.activity_type !== "string") {
    return { ok: false, error: "Missing activity_type" };
  }
  const activityType = body.activity_type.trim().toLowerCase();
  if (!workoutActivities.has(activityType)) {
    return { ok: false, error: "Invalid activity_type" };
  }
  const mode = body.mode == null ? "outdoor" : body.mode;
  if (mode !== "indoor" && mode !== "outdoor") {
    return { ok: false, error: "Invalid mode" };
  }
  return { ok: true, activityType, mode };
}

type WorkoutEndValues = {
  workoutId: string;
  durationSec: number | null;
  movingTimeSec: number | null;
  distanceKm: number | null;
  avgSpeedKmh: number | null;
  caloriesKcal: number | null;
  steps: number | null;
};

export type WorkoutEndValidation =
  | ({ ok: true } & WorkoutEndValues)
  | { ok: false; error: string };

function boundedMetric(
  value: unknown,
  maximum: number,
  integer = false,
): number | null | undefined {
  if (value == null) return null;
  if (
    typeof value !== "number" || !Number.isFinite(value) || value < 0 ||
    value > maximum || (integer && !Number.isInteger(value))
  ) {
    return undefined;
  }
  return value;
}

export function validateWorkoutEndPayload(
  payload: unknown,
): WorkoutEndValidation {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return { ok: false, error: "Invalid request body" };
  }
  const body = payload as Record<string, unknown>;
  if (
    typeof body.workout_id !== "string" ||
    !uuidPattern.test(body.workout_id)
  ) {
    return { ok: false, error: "Invalid workout_id" };
  }
  const durationSec = boundedMetric(body.duration_sec, 7 * 24 * 60 * 60, true);
  const movingTimeSec = boundedMetric(
    body.moving_time_sec,
    7 * 24 * 60 * 60,
    true,
  );
  const distanceKm = boundedMetric(body.distance_km, 2_000);
  const avgSpeedKmh = boundedMetric(body.avg_speed_kmh, 200);
  const caloriesKcal = boundedMetric(body.calories_kcal, 100_000);
  const steps = boundedMetric(body.steps, 1_000_000, true);
  if (
    [
      durationSec,
      movingTimeSec,
      distanceKm,
      avgSpeedKmh,
      caloriesKcal,
      steps,
    ].some((value) => value === undefined)
  ) {
    return { ok: false, error: "Invalid workout metrics" };
  }
  if (
    durationSec != null && movingTimeSec != null &&
    movingTimeSec > durationSec
  ) {
    return { ok: false, error: "moving_time_sec exceeds duration_sec" };
  }
  return {
    ok: true,
    workoutId: body.workout_id,
    durationSec: durationSec!,
    movingTimeSec: movingTimeSec!,
    distanceKm: distanceKm!,
    avgSpeedKmh: avgSpeedKmh!,
    caloriesKcal: caloriesKcal!,
    steps: steps!,
  };
}

export type ValidatedInsightSignals = {
  pace_fatigue_slope: number;
  pace_consistency_cv: number;
  rest_ratio: number;
  gps_reliability_score: number;
  baseline_pace_zscore: number;
  baseline_distance_zscore: number;
  goal_alignment: string;
  recent_7d_volume_km: number;
};

export type InsightRequestValidation =
  | {
    ok: true;
    workoutId: string;
    language: "vi" | "en";
    signals: ValidatedInsightSignals;
  }
  | { ok: false; error: string };

const defaultInsightSignals: ValidatedInsightSignals = {
  pace_fatigue_slope: 0.02,
  pace_consistency_cv: 0.06,
  rest_ratio: 0.02,
  gps_reliability_score: 0.95,
  baseline_pace_zscore: 0,
  baseline_distance_zscore: 0,
  goal_alignment: "on_track",
  recent_7d_volume_km: 15,
};

export function validateInsightRequest(
  payload: unknown,
): InsightRequestValidation {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return { ok: false, error: "Invalid request body" };
  }
  const body = payload as Record<string, unknown>;
  if (
    typeof body.workout_id !== "string" ||
    !uuidPattern.test(body.workout_id)
  ) {
    return { ok: false, error: "Invalid workout_id" };
  }
  const language = body.language == null
    ? "en"
    : String(body.language).trim().toLowerCase();
  if (language !== "en" && language !== "vi") {
    return { ok: false, error: "Invalid language" };
  }
  if (body.signals == null) {
    return {
      ok: true,
      workoutId: body.workout_id,
      language,
      signals: { ...defaultInsightSignals },
    };
  }
  if (typeof body.signals !== "object" || Array.isArray(body.signals)) {
    return { ok: false, error: "Invalid signals" };
  }
  const signals = body.signals as Record<string, unknown>;
  const ranges: Record<string, [number, number]> = {
    pace_fatigue_slope: [-10, 10],
    pace_consistency_cv: [0, 10],
    rest_ratio: [0, 1],
    gps_reliability_score: [0, 1],
    baseline_pace_zscore: [-20, 20],
    baseline_distance_zscore: [-20, 20],
    recent_7d_volume_km: [0, 1_000],
  };
  for (const [key, [minimum, maximum]] of Object.entries(ranges)) {
    const value = signals[key];
    if (
      typeof value !== "number" || !Number.isFinite(value) ||
      value < minimum || value > maximum
    ) {
      return { ok: false, error: `Invalid signal: ${key}` };
    }
  }
  if (
    typeof signals.goal_alignment !== "string" ||
    !/^[a-z0-9_-]{1,32}$/i.test(signals.goal_alignment)
  ) {
    return { ok: false, error: "Invalid signal: goal_alignment" };
  }
  return {
    ok: true,
    workoutId: body.workout_id,
    language,
    signals: signals as ValidatedInsightSignals,
  };
}
