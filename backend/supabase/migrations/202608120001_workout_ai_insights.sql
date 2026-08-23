-- Migration: Add workout_ai_insights table for AI Post-Workout Insights
-- Date: 2026-08-12

CREATE TABLE IF NOT EXISTS public.workout_ai_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_id UUID NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    source TEXT NOT NULL CHECK (source IN ('llm', 'fallback_rule')),
    confidence NUMERIC(3,2) NOT NULL DEFAULT 1.00 CHECK (confidence >= 0.00 AND confidence <= 1.00),
    insight_json JSONB NOT NULL,
    payload_hash TEXT NOT NULL,
    fallback_reason TEXT CHECK (fallback_reason IN (
        'timeout',
        'invalid_json',
        'schema_fail',
        'guardrail_reject_signals',
        'guardrail_reject_load',
        'medical_keyword',
        'provider_error',
        'none'
    )),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for fast lookup and deduplication
CREATE INDEX IF NOT EXISTS idx_workout_ai_insights_workout_id ON public.workout_ai_insights(workout_id);
CREATE INDEX IF NOT EXISTS idx_workout_ai_insights_user_id ON public.workout_ai_insights(user_id);
CREATE INDEX IF NOT EXISTS idx_workout_ai_insights_payload_hash ON public.workout_ai_insights(payload_hash);

-- Row Level Security (RLS)
ALTER TABLE public.workout_ai_insights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own workout AI insights"
    ON public.workout_ai_insights
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert workout AI insights"
    ON public.workout_ai_insights
    FOR INSERT
    WITH CHECK (auth.uid() = user_id OR auth.jwt()->>'role' = 'service_role');
