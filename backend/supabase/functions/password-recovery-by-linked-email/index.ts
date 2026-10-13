import {
  createServiceClient,
  jsonResponse,
  normalizeGmail,
  resetRedirectTo,
  sendEmail,
} from "../_shared/recovery_email.ts";
import {
  clientIp,
  consumeRateLimit,
  corsPreflightResponse,
  isAllowedResetRedirect,
  isLocalEnvironment,
  logSecurityEvent,
  readJsonBody,
  requestIdFor,
} from "../_shared/security.ts";

const genericMessage =
  "If this Gmail is linked to an Aetron account, a reset email has been sent.";

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
    const payload = await readJsonBody(req, 16 * 1024).catch(
      () => ({}),
    ) as Record<string, unknown>;
    const recoveryEmail = normalizeGmail(payload.recovery_email);
    const requestedRedirect = typeof payload.redirect_to === "string"
      ? payload.redirect_to.trim()
      : "";
    const redirectTo = isAllowedResetRedirect(
        requestedRedirect,
        isLocalEnvironment(),
      )
      ? requestedRedirect
      : resetRedirectTo;

    if (!recoveryEmail) return jsonResponse(req, { message: genericMessage });

    const service = createServiceClient();
    const [ipLimit, emailLimit] = await Promise.all([
      consumeRateLimit(
        service,
        "password_recovery_ip",
        clientIp(req),
        20,
        60 * 60,
      ),
      consumeRateLimit(
        service,
        "password_recovery_email",
        recoveryEmail,
        5,
        60 * 60,
      ),
    ]);
    if (!ipLimit.allowed || !emailLimit.allowed) {
      const retryAfter = Math.max(
        ipLimit.retryAfterSeconds,
        emailLimit.retryAfterSeconds,
      );
      return jsonResponse(req, { message: genericMessage }, 429, {
        "Retry-After": retryAfter.toString(),
      });
    }

    const { data: linkedEmail, error: linkedError } = await service
      .from("user_recovery_emails")
      .select("user_id, recovery_email, verified_at")
      .eq("recovery_email", recoveryEmail)
      .not("verified_at", "is", null)
      .maybeSingle();
    if (linkedError) throw linkedError;
    if (!linkedEmail) return jsonResponse(req, { message: genericMessage });

    const { data: userData, error: userError } = await service.auth.admin
      .getUserById(linkedEmail.user_id);
    if (userError || !userData.user?.email) {
      logSecurityEvent(
        "error",
        "password_recovery_user_lookup_failed",
        requestId,
      );
      return jsonResponse(req, { message: genericMessage });
    }

    const { data: linkData, error: linkError } = await service.auth.admin
      .generateLink({
        type: "recovery",
        email: userData.user.email,
        options: { redirectTo },
      });
    if (linkError) throw linkError;

    const actionLink = linkData.properties?.action_link;
    if (!actionLink) throw new Error("Missing recovery action link");

    await sendEmail({
      to: recoveryEmail,
      subject: "Reset your Aetron password",
      html: `<p>Use this secure link to reset your Aetron password:</p>` +
        `<p><a href="${actionLink}">Reset password</a></p>` +
        `<p>If you did not request this, you can ignore this email.</p>`,
    });

    return jsonResponse(req, { message: genericMessage });
  } catch {
    logSecurityEvent("error", "password_recovery_failed", requestId);
    return jsonResponse(req, { message: genericMessage });
  }
});
