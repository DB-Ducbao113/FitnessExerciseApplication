import {
  createServiceClient,
  getAuthedUser,
  jsonResponse,
  normalizeGmail,
  sha256,
} from "../_shared/recovery_email.ts";
import {
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
    const code = typeof payload.code === "string" ? payload.code.trim() : "";
    if (!recoveryEmail || !/^\d{6}$/.test(code)) {
      return jsonResponse(
        req,
        { error: "Enter the 6-digit verification code." },
        400,
      );
    }

    const service = createServiceClient();
    const codeHash = await sha256(`${user.id}:${recoveryEmail}:${code}`);
    const { data, error } = await service.rpc("verify_recovery_email_code", {
      p_user_id: user.id,
      p_recovery_email: recoveryEmail,
      p_code_hash: codeHash,
    });
    if (error) throw error;
    const result = Array.isArray(data) ? data[0] : data;
    if (!result || result.status === "not_found") {
      return jsonResponse(
        req,
        { error: "Verification code was not found." },
        400,
      );
    }
    if (result.status === "locked") {
      return jsonResponse(
        req,
        { error: "Too many attempts. Request a new code." },
        429,
      );
    }
    if (result.status === "expired") {
      return jsonResponse(req, { error: "Verification code expired." }, 400);
    }
    if (result.status === "incorrect") {
      return jsonResponse(
        req,
        { error: "Verification code is incorrect." },
        400,
      );
    }
    if (result.status !== "verified" || !result.verified_at) {
      throw new Error("Unexpected verification result");
    }

    return jsonResponse(req, {
      message: "Recovery Gmail verified.",
      recovery_email: recoveryEmail,
      verified_at: result.verified_at,
    });
  } catch {
    logSecurityEvent("error", "recovery_email_verify_failed", requestId);
    return jsonResponse(
      req,
      { error: "Could not verify recovery Gmail." },
      500,
    );
  }
});
