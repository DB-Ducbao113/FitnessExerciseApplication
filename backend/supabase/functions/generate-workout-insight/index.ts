// @deno-types="https://esm.sh/@supabase/supabase-js@2.105.1"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface NextSessionSuggestion {
  recommended_activity: string;
  target_duration_min: number;
  target_intensity: string;
  reason: string;
}

interface InsightJson {
  headline: string;
  main_insight: string;
  strengths: string[];
  watchouts: string[];
  next_session_suggestion: NextSessionSuggestion;
  used_signals: string[];
}

interface WorkoutSignals {
  pace_fatigue_slope: number;
  pace_consistency_cv: number;
  rest_ratio: number;
  gps_reliability_score: number;
  baseline_pace_zscore: number;
  baseline_distance_zscore: number;
  goal_alignment: string;
  recent_7d_volume_km: number;
}

// Medical & safety guardrail blacklist keywords (VI & EN)
const MEDICAL_BLACKLIST = [
  "chữa trị",
  "kê đơn",
  "gãy xương",
  "bệnh tim",
  "thuốc đặc trị",
  "chẩn đoán y khoa",
  "bác sĩ điều trị",
  "prescription",
  "prescribe",
  "diagnose",
  "diagnosis",
  "fracture",
  "cardiovascular disease",
  "medication",
];

// Simple SHA-256 hashing for payload hash / deduplication
async function computeHash(text: string): Promise<string> {
  const msgUint8 = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgUint8);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Rule-based Fallback Generator (Supports both EN and VI)
function generateFallbackInsight(
  activityType: string,
  signals: WorkoutSignals,
  language: string = "en"
): InsightJson {
  const isVi = language.toLowerCase() === "vi";
  const isRunning = activityType.toLowerCase() === "running";
  const isWalking = activityType.toLowerCase() === "walking";
  const strengths: string[] = [];
  const watchouts: string[] = [];

  if (isVi) {
    if (signals.pace_consistency_cv < 0.10 && signals.pace_consistency_cv > 0) {
      strengths.push("Duy trì tốc độ rất đều đặn trong suốt buổi tập.");
    } else {
      watchouts.push("Tốc độ có sự biến động nhẹ giữa các chặng.");
    }

    if (signals.pace_fatigue_slope > 0.08) {
      watchouts.push("Tốc độ giảm dần ở chặng cuối (dấu hiệu xuống sức).");
    } else if (signals.pace_fatigue_slope < -0.02) {
      strengths.push("Tăng tốc tốt về cuối buổi tập (negative split).");
    }

    if (signals.rest_ratio > 0.15) {
      watchouts.push("Thời gian nghỉ chiếm hơn 15% tổng buổi tập.");
    }

    if (signals.gps_reliability_score < 0.8) {
      watchouts.push("Tín hiệu GPS có độ nhiễu nhẹ.");
    }

    if (strengths.length === 0) {
      strengths.push("Hoàn thành buổi tập đúng thời lượng dự kiến.");
    }
    if (watchouts.length === 0) {
      watchouts.push("Hãy chú ý bổ sung đủ nước sau khi hoàn thành.");
    }
  } else {
    // English Fallback
    if (signals.pace_consistency_cv < 0.10 && signals.pace_consistency_cv > 0) {
      strengths.push("Maintained a highly consistent pace throughout the workout.");
    } else {
      watchouts.push("Pace showed minor fluctuations across lap splits.");
    }

    if (signals.pace_fatigue_slope > 0.08) {
      watchouts.push("Pace slowed down in the final split (sign of muscular fatigue).");
    } else if (signals.pace_fatigue_slope < -0.02) {
      strengths.push("Strong finishing kick with positive acceleration (negative split).");
    }

    if (signals.rest_ratio > 0.15) {
      watchouts.push("Rest duration accounted for over 15% of the total session.");
    }

    if (signals.gps_reliability_score < 0.8) {
      watchouts.push("GPS signal quality had minor telemetry noise.");
    }

    if (strengths.length === 0) {
      strengths.push("Successfully completed the workout within targeted duration.");
    }
    if (watchouts.length === 0) {
      watchouts.push("Ensure proper hydration and post-workout stretching.");
    }
  }

  let nextActivity = "walking";
  let targetMin = 30;
  let intensity = "recovery";
  let reason = isVi
    ? "Buổi tập nhẹ nhàng giúp cơ bắp phục hồi."
    : "Light recovery session to help muscles relax and recover.";

  if (signals.pace_fatigue_slope > 0.10) {
    nextActivity = "walking";
    targetMin = 25;
    intensity = "recovery";
    reason = isVi
      ? "Dành thời gian đi bộ thả lỏng do phát hiện dấu hiệu mỏi cơ chặng cuối."
      : "Schedule an easy walk to facilitate recovery after late-session fatigue.";
  } else if (isRunning) {
    nextActivity = "running";
    targetMin = 35;
    intensity = "aerobic";
    reason = isVi
      ? "Thể lực tốt, duy trì nhịp tập aerobic trung bình cho buổi tới."
      : "Solid aerobic base; maintain a steady aerobic endurance run next.";
  } else if (isWalking) {
    nextActivity = "running";
    targetMin = 20;
    intensity = "aerobic";
    reason = isVi
      ? "Thử sức với chặng chạy ngắn để cải thiện sức bền tim mạch."
      : "Try a short run session to challenge your cardiovascular endurance.";
  }

  const actCapitalized = activityType.charAt(0).toUpperCase() + activityType.slice(1);
  const headline = isVi
    ? `Đánh giá buổi ${activityType}`
    : `${actCapitalized} Workout Performance Recap`;

  const mainInsight = isVi
    ? (isRunning
        ? "Buổi chạy thể hiện nhịp độ ổn định. Tốc độ di chuyển và lượng calo tiêu thụ đạt mức tối ưu cho sức bền."
        : "Hoàn thành buổi tập thành công. Khả năng duy trì nhịp vận động phù hợp với mục tiêu thể lực.")
    : (isRunning
        ? "Solid running session with well-balanced pacing. Your moving velocity and energy expenditure matched your endurance baseline."
        : "Workout successfully completed. Moving rhythm and physiological exertion were well-aligned with your fitness level.");

  return {
    headline,
    main_insight: mainInsight,
    strengths,
    watchouts,
    next_session_suggestion: {
      recommended_activity: nextActivity,
      target_duration_min: targetMin,
      target_intensity: intensity,
      reason,
    },
    used_signals: [
      "pace_fatigue_slope",
      "pace_consistency_cv",
      "rest_ratio",
      "gps_reliability_score",
    ],
  };
}

// Guardrail & Schema Validator
function validateAndSanitizeInsight(
  parsed: any,
  activityType: string,
  signals: WorkoutSignals,
  language: string = "en"
): { valid: boolean; data?: InsightJson; reason?: string } {
  if (!parsed || typeof parsed !== "object") {
    return { valid: false, reason: "invalid_json" };
  }

  const isVi = language.toLowerCase() === "vi";
  const defaultHeadline = isVi
    ? `Đánh giá buổi ${activityType}`
    : `${activityType.charAt(0).toUpperCase() + activityType.slice(1)} Session Recap`;

  const headline = typeof parsed.headline === "string" && parsed.headline.trim().length > 0
    ? parsed.headline.trim()
    : defaultHeadline;

  const mainInsight = typeof parsed.main_insight === "string" && parsed.main_insight.trim().length > 0
    ? parsed.main_insight.trim()
    : "";

  if (!mainInsight) {
    return { valid: false, reason: "schema_fail" };
  }

  // Check medical keyword guardrail
  const combinedText = `${headline} ${mainInsight}`.toLowerCase();
  for (const keyword of MEDICAL_BLACKLIST) {
    if (combinedText.includes(keyword)) {
      return { valid: false, reason: "medical_keyword" };
    }
  }

  const defaultStrength = isVi ? "Hoàn thành buổi tập đúng mục tiêu." : "Successfully met the workout target.";
  const defaultWatchout = isVi ? "Chú ý bổ sung nước đầy đủ." : "Keep hydrated and recover properly.";

  const strengths = Array.isArray(parsed.strengths)
    ? parsed.strengths.filter((s: any) => typeof s === "string" && s.trim().length > 0).map((s: string) => s.trim())
    : [defaultStrength];

  const watchouts = Array.isArray(parsed.watchouts)
    ? parsed.watchouts.filter((w: any) => typeof w === "string" && w.trim().length > 0).map((w: string) => w.trim())
    : [defaultWatchout];

  const rawSuggestion = parsed.next_session_suggestion ?? {};
  const validActivities = ["running", "walking", "cycling", "rest"];
  const validIntensities = ["recovery", "aerobic", "tempo", "interval"];

  const recActivity = validActivities.includes((rawSuggestion.recommended_activity ?? "").toLowerCase())
    ? rawSuggestion.recommended_activity.toLowerCase()
    : (activityType.toLowerCase() === "running" ? "running" : "walking");

  let targetDuration = typeof rawSuggestion.target_duration_min === "number"
    ? Math.round(rawSuggestion.target_duration_min)
    : 30;
  // Safety clamp: 10 min to 120 min
  targetDuration = Math.max(10, Math.min(120, targetDuration));

  const targetIntensity = validIntensities.includes((rawSuggestion.target_intensity ?? "").toLowerCase())
    ? rawSuggestion.target_intensity.toLowerCase()
    : "aerobic";

  const defaultReason = isVi ? "Duy trì thể lực và phục hồi cơ bắp." : "Maintain cardiovascular endurance and muscle recovery.";
  const reason = typeof rawSuggestion.reason === "string" && rawSuggestion.reason.trim().length > 0
    ? rawSuggestion.reason.trim()
    : defaultReason;

  const usedSignals = Array.isArray(parsed.used_signals)
    ? parsed.used_signals.filter((u: any) => typeof u === "string")
    : ["pace_fatigue_slope", "pace_consistency_cv"];

  return {
    valid: true,
    data: {
      headline,
      main_insight: mainInsight,
      strengths,
      watchouts,
      next_session_suggestion: {
        recommended_activity: recActivity,
        target_duration_min: targetDuration,
        target_intensity: targetIntensity,
        reason,
      },
      used_signals: usedSignals,
    },
  };
}

// Google Gemini API Caller (Language Aware)
async function callGeminiLlm(
  apiKey: string,
  activityType: string,
  workout: any,
  signals: WorkoutSignals,
  language: string = "en"
): Promise<InsightJson> {
  const isVi = language.toLowerCase() === "vi";

  const systemInstruction = isVi
    ? `Bạn là Aetron AI Coach - Huấn luyện viên thể thao cá nhân thông minh.
Nhiệm vụ của bạn là phân tích kết quả buổi tập (${activityType}) dựa trên các tín hiệu số học (signals) được cung cấp.

QUY TẮC AN TOÀN & CHUYÊN MÔN:
1. KHÔNG tự ý bịa đặt số liệu không có trong signals.
2. KHÔNG đưa ra chẩn đoán y tế hoặc kê đơn thuốc.
3. Nhận xét súc tích, mang tính khích lệ, cá nhân hóa, định hướng hành động bằng TIẾNG VIỆT.
4. Phải trả về DUY NHẤT một chuỗi JSON hợp lệ theo cấu trúc sau (không kèm markdown format ngoài):
{
  "headline": "Tiêu đề ngắn gọn tóm tắt buổi tập (Tiếng Việt)",
  "main_insight": "Phân tích 1-2 câu về hiệu suất, nhịp độ và thể lực (Tiếng Việt)",
  "strengths": ["Điểm nổi bật 1", "Điểm nổi bật 2"],
  "watchouts": ["Lưu ý cần cải thiện 1"],
  "next_session_suggestion": {
    "recommended_activity": "running | walking | cycling | rest",
    "target_duration_min": 30,
    "target_intensity": "recovery | aerobic | tempo | interval",
    "reason": "Lý do gợi ý buổi tập tiếp theo (Tiếng Việt)"
  },
  "used_signals": ["pace_fatigue_slope", "pace_consistency_cv"]
}`
    : `You are Aetron AI Coach - an elite athletic performance intelligence coach.
Your mission is to analyze the athlete's ${activityType} workout session using ONLY the provided mathematical telemetry signals.

STRICT COACHING & SAFETY RULES:
1. NEVER hallucinate or invent metrics not found in signals.
2. NEVER give medical diagnoses, injury assessments, or drug prescriptions.
3. Provide concise, actionable, encouraging, data-driven coaching feedback in fluent, natural ENGLISH.
4. Output MUST BE strictly valid JSON matching this exact schema:
{
  "headline": "Punchy 3-6 word summary headline (English)",
  "main_insight": "1-2 sentences analyzing pacing efficiency, fatigue progression, and cardiovascular load (English)",
  "strengths": ["Key strength 1", "Key strength 2"],
  "watchouts": ["Actionable focus area or recovery reminder"],
  "next_session_suggestion": {
    "recommended_activity": "running | walking | cycling | rest",
    "target_duration_min": 30,
    "target_intensity": "recovery | aerobic | tempo | interval",
    "reason": "Clear coaching rationale for the next workout (English)"
  },
  "used_signals": ["pace_fatigue_slope", "pace_consistency_cv"]
}`;

  const userPrompt = JSON.stringify({
    activity_type: activityType,
    duration_minutes: Math.round((workout.duration_sec ?? 0) / 60),
    distance_km: workout.distance_km ?? 0,
    calories_kcal: workout.calories_kcal ?? 0,
    language: language,
    signals: signals,
  });

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 4500); // 4.5s timeout

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: controller.signal,
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: systemInstruction }],
        },
        contents: [
          {
            role: "user",
            parts: [{ text: userPrompt }],
          },
        ],
        generationConfig: {
          temperature: 0.3,
          responseMimeType: "application/json",
        },
      }),
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`Gemini API returned status ${response.status}`);
    }

    const data = await response.json();
    const candidateText = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!candidateText) {
      throw new Error("Empty response from Gemini API");
    }

    const parsed = JSON.parse(candidateText);
    const validation = validateAndSanitizeInsight(parsed, activityType, signals, language);
    if (!validation.valid || !validation.data) {
      throw new Error(validation.reason || "guardrail_reject_signals");
    }

    return validation.data;
  } finally {
    clearTimeout(timeoutId);
  }
}

// OpenAI API Caller (Language Aware)
async function callOpenAiLlm(
  apiKey: string,
  activityType: string,
  workout: any,
  signals: WorkoutSignals,
  language: string = "en"
): Promise<InsightJson> {
  const isVi = language.toLowerCase() === "vi";

  const systemInstruction = isVi
    ? `Bạn là Aetron AI Coach. Phân tích buổi tập ${activityType} dựa trên signals được cung cấp. Trả lời bằng Tiếng Việt.
Không bịa đặt số liệu. Không chẩn đoán y tế. Trả về JSON hợp lệ: headline, main_insight, strengths, watchouts, next_session_suggestion (recommended_activity, target_duration_min, target_intensity, reason), used_signals.`
    : `You are Aetron AI Coach. Analyze this ${activityType} workout based on the telemetry signals in English.
No hallucinations. No medical diagnoses. Return valid JSON with: headline, main_insight, strengths, watchouts, next_session_suggestion (recommended_activity, target_duration_min, target_intensity, reason), used_signals.`;

  const userPrompt = JSON.stringify({
    activity_type: activityType,
    duration_minutes: Math.round((workout.duration_sec ?? 0) / 60),
    distance_km: workout.distance_km ?? 0,
    language: language,
    signals: signals,
  });

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 4500);

  try {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      signal: controller.signal,
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: systemInstruction },
          { role: "user", content: userPrompt },
        ],
        response_format: { type: "json_object" },
        temperature: 0.3,
      }),
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`OpenAI API returned status ${response.status}`);
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content;
    if (!content) {
      throw new Error("Empty response from OpenAI API");
    }

    const parsed = JSON.parse(content);
    const validation = validateAndSanitizeInsight(parsed, activityType, signals, language);
    if (!validation.valid || !validation.data) {
      throw new Error(validation.reason || "guardrail_reject_signals");
    }

    return validation.data;
  } finally {
    clearTimeout(timeoutId);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const workoutId = body.workout_id;
    const language = (body.language ?? "en").toString().toLowerCase() === "vi" ? "vi" : "en";

    if (!workoutId) {
      return new Response(JSON.stringify({ error: "Missing workout_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch workout session
    const { data: workout, error: workoutError } = await supabase
      .from("workout_sessions")
      .select("*")
      .eq("id", workoutId)
      .eq("user_id", user.id)
      .maybeSingle();

    if (workoutError || !workout) {
      return new Response(JSON.stringify({ error: "Workout not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Extract or compute signals
    const signals: WorkoutSignals = body.signals ?? {
      pace_fatigue_slope: 0.02,
      pace_consistency_cv: 0.06,
      rest_ratio: 0.02,
      gps_reliability_score: 0.95,
      baseline_pace_zscore: 0.0,
      baseline_distance_zscore: 0.0,
      goal_alignment: "on_track",
      recent_7d_volume_km: 15.0,
    };

    // Compute deterministic payload hash for caching (includes language)
    const payloadString = JSON.stringify({
      workout_id: workout.id,
      activity_type: workout.activity_type,
      distance_km: workout.distance_km,
      duration_sec: workout.duration_sec,
      language,
      signals,
    });

    const payloadHash = await computeHash(payloadString);

    // Check if insight is already cached in DB for this exact payload and language
    const { data: cachedInsight } = await supabase
      .from("workout_ai_insights")
      .select("*")
      .eq("payload_hash", payloadHash)
      .maybeSingle();

    if (cachedInsight) {
      return new Response(JSON.stringify(cachedInsight), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Attempt LLM call
    let insightJson: InsightJson | null = null;
    let source = "fallback_rule";
    let fallbackReason = "none";

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    const openAiKey = Deno.env.get("OPENAI_API_KEY");

    if (geminiKey) {
      try {
        insightJson = await callGeminiLlm(geminiKey, workout.activity_type, workout, signals, language);
        source = "llm";
        fallbackReason = "none";
      } catch (err: any) {
        source = "fallback_rule";
        if (err.name === "AbortError") {
          fallbackReason = "timeout";
        } else if (err.message === "medical_keyword") {
          fallbackReason = "medical_keyword";
        } else if (err.message === "schema_fail" || err.message === "invalid_json") {
          fallbackReason = err.message;
        } else {
          fallbackReason = "provider_error";
        }
        insightJson = generateFallbackInsight(workout.activity_type, signals, language);
      }
    } else if (openAiKey) {
      try {
        insightJson = await callOpenAiLlm(openAiKey, workout.activity_type, workout, signals, language);
        source = "llm";
        fallbackReason = "none";
      } catch (err: any) {
        source = "fallback_rule";
        if (err.name === "AbortError") {
          fallbackReason = "timeout";
        } else {
          fallbackReason = "provider_error";
        }
        insightJson = generateFallbackInsight(workout.activity_type, signals, language);
      }
    } else {
      source = "fallback_rule";
      fallbackReason = "none";
      insightJson = generateFallbackInsight(workout.activity_type, signals, language);
    }

    // Save generated insight to DB
    const { data: inserted, error: insertError } = await supabase
      .from("workout_ai_insights")
      .insert({
        workout_id: workout.id,
        user_id: user.id,
        source,
        confidence: source === "llm" ? 0.95 : 1.0,
        insight_json: insightJson,
        payload_hash: payloadHash,
        fallback_reason: fallbackReason,
      })
      .select()
      .single();

    if (insertError) {
      // Return insight even if DB cache insert fails
      return new Response(
        JSON.stringify({
          workout_id: workout.id,
          user_id: user.id,
          source,
          confidence: source === "llm" ? 0.95 : 1.0,
          insight_json: insightJson,
          payload_hash: payloadHash,
          fallback_reason: fallbackReason,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(JSON.stringify(inserted), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
