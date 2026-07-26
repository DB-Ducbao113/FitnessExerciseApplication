import {
  corsHeaders,
  createServiceClient,
  getAuthedUser,
  jsonResponse,
  normalizeGmail,
  sha256,
} from "../_shared/recovery_email.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user } = await getAuthedUser(req);
    if (!user) return jsonResponse({ error: "Unauthorized" }, 401);

    const payload = await req.json().catch(() => ({}));
    const recoveryEmail = normalizeGmail(payload.recovery_email);
    const code = typeof payload.code === "string" ? payload.code.trim() : "";
    if (!recoveryEmail || !/^\d{6}$/.test(code)) {
      return jsonResponse(
        { error: "Enter the 6-digit verification code." },
        400,
      );
    }

    const service = createServiceClient();
    const { data: verification, error: fetchError } = await service
      .from("recovery_email_verifications")
      .select("id, code_hash, expires_at, consumed_at, attempt_count")
      .eq("user_id", user.id)
      .eq("recovery_email", recoveryEmail)
      .is("consumed_at", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (fetchError) throw fetchError;
    if (!verification) {
      return jsonResponse({ error: "Verification code was not found." }, 400);
    }
    if (verification.attempt_count >= 5) {
      return jsonResponse(
        { error: "Too many attempts. Request a new code." },
        429,
      );
    }
    if (new Date(verification.expires_at).getTime() < Date.now()) {
      return jsonResponse({ error: "Verification code expired." }, 400);
    }

    const codeHash = await sha256(`${user.id}:${recoveryEmail}:${code}`);
    if (codeHash !== verification.code_hash) {
      await service
        .from("recovery_email_verifications")
        .update({ attempt_count: verification.attempt_count + 1 })
        .eq("id", verification.id);
      return jsonResponse({ error: "Verification code is incorrect." }, 400);
    }

    const now = new Date().toISOString();
    const { error: updateEmailError } = await service
      .from("user_recovery_emails")
      .update({ verified_at: now })
      .eq("user_id", user.id)
      .eq("recovery_email", recoveryEmail);
    if (updateEmailError) throw updateEmailError;

    await service
      .from("recovery_email_verifications")
      .update({ consumed_at: now })
      .eq("id", verification.id);

    return jsonResponse({
      message: "Recovery Gmail verified.",
      recovery_email: recoveryEmail,
      verified_at: now,
    });
  } catch (error) {
    console.error("[recovery-email-verify]", error);
    return jsonResponse({ error: "Could not verify recovery Gmail." }, 500);
  }
});
