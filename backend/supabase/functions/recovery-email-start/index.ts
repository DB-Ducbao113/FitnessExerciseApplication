import {
  createServiceClient,
  generateCode,
  getAuthedUser,
  jsonResponse,
  normalizeGmail,
  sendEmail,
  sha256,
} from "../_shared/recovery_email.ts";
import {
  consumeRateLimit,
  corsPreflightResponse,
  logSecurityEvent,
  readJsonBody,
  requestIdFor,
} from "../_shared/security.ts";

Deno.serve(async (req: Request) => {
  const requestId = requestIdFor(req);
  if (req.method === "OPTIONS") {
    return corsPreflightResponse(req);
  }
  if (req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed" }, 405, {
      Allow: "POST, OPTIONS",
    });
  }

  try {
    const { user } = await getAuthedUser(req);
    if (!user) return jsonResponse(req, { error: "Unauthorized" }, 401);

    const payload = await readJsonBody(req, 16 * 1024).catch(
      () => ({}),
    ) as Record<string, unknown>;
    const recoveryEmail = normalizeGmail(payload.recovery_email);
    if (!recoveryEmail) {
      return jsonResponse(
        req,
        { error: "Recovery email must be a Gmail address." },
        400,
      );
    }
    if (user.email?.trim().toLowerCase() === recoveryEmail) {
      return jsonResponse(
        req,
        { error: "Use a different Gmail as your recovery email." },
        400,
      );
    }

    const service = createServiceClient();
    const rateLimit = await consumeRateLimit(
      service,
      "recovery_email_start_user",
      user.id,
      3,
      15 * 60,
    );
    if (!rateLimit.allowed) {
      return jsonResponse(
        req,
        { error: "Too many requests. Try again later." },
        429,
        { "Retry-After": rateLimit.retryAfterSeconds.toString() },
      );
    }

    const code = generateCode();
    const codeHash = await sha256(`${user.id}:${recoveryEmail}:${code}`);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { error: upsertError } = await service
      .from("user_recovery_emails")
      .upsert(
        {
          user_id: user.id,
          recovery_email: recoveryEmail,
          verified_at: null,
        },
        { onConflict: "user_id" },
      );
    if (upsertError) throw upsertError;

    const { error: invalidateError } = await service
      .from("recovery_email_verifications")
      .update({ consumed_at: new Date().toISOString() })
      .eq("user_id", user.id)
      .is("consumed_at", null);
    if (invalidateError) throw invalidateError;

    const { error: insertError } = await service
      .from("recovery_email_verifications")
      .insert({
        user_id: user.id,
        recovery_email: recoveryEmail,
        code_hash: codeHash,
        expires_at: expiresAt,
      });
    if (insertError) throw insertError;

    await sendEmail({
      to: recoveryEmail,
      subject: "Verify your Aetron recovery Gmail",
      html: `<p>Your Aetron recovery Gmail verification code is:</p>` +
        `<p style="font-size:28px;font-weight:700;letter-spacing:4px">${code}</p>` +
        `<p>This code expires in 10 minutes.</p>`,
    });

    return jsonResponse(req, {
      message: "Verification code sent.",
      recovery_email: recoveryEmail,
    });
  } catch {
    logSecurityEvent("error", "recovery_email_start_failed", requestId);
    return jsonResponse(req, {
      error: "Could not start recovery email verification.",
    }, 500);
  }
});
