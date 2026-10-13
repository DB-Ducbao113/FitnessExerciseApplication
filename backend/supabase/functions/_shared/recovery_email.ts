import { createClient } from "https://esm.sh/@supabase/supabase-js@2.105.1";
import { corsHeadersForRequest, requestIdFor } from "./security.ts";

export const resetRedirectTo = "io.supabase.flutter://callback";

export function jsonResponse(
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

export function normalizeGmail(email: unknown): string | null {
  if (typeof email !== "string") return null;
  const normalized = email.trim().toLowerCase();
  if (!/^[^@\s]+@gmail\.com$/.test(normalized)) return null;
  return normalized;
}

export function createUserClient(authHeader: string) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ??
    Deno.env.get("AETRON_SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("AETRON_SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    throw new Error("Missing Supabase URL or anon key");
  }

  return createClient(
    supabaseUrl,
    anonKey,
    { global: { headers: { Authorization: authHeader } } },
  );
}

export function createServiceClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ??
    Deno.env.get("AETRON_SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("AETRON_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing Supabase URL or service role key");
  }

  return createClient(
    supabaseUrl,
    serviceRoleKey,
  );
}

export async function getAuthedUser(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return { user: null, authHeader: null };

  const supabase = createUserClient(authHeader);
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return { user, authHeader };
}

export function generateCode(): string {
  const bytes = new Uint8Array(4);
  crypto.getRandomValues(bytes);
  const value = new DataView(bytes.buffer).getUint32(0) % 1000000;
  return value.toString().padStart(6, "0");
}

export async function sha256(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function sendEmail({
  to,
  subject,
  html,
}: {
  to: string;
  subject: string;
  html: string;
}) {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("RESEND_FROM_EMAIL") ??
    "Aetron <onboarding@resend.dev>";
  if (!apiKey) throw new Error("Missing RESEND_API_KEY");

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from, to: [to], subject, html }),
  });

  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(`Email provider failed with status ${response.status}`);
  }
}
