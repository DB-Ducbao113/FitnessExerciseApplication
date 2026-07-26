import {
  corsHeaders,
  createServiceClient,
  jsonResponse,
  normalizeGmail,
  resetRedirectTo,
  sendEmail,
} from "../_shared/recovery_email.ts";

const genericMessage =
  "If this Gmail is linked to an Aetron account, a reset email has been sent.";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json().catch(() => ({}));
    const recoveryEmail = normalizeGmail(payload.recovery_email);
    const redirectTo = typeof payload.redirect_to === "string" &&
        payload.redirect_to.trim().length > 0
      ? payload.redirect_to.trim()
      : resetRedirectTo;

    if (!recoveryEmail) return jsonResponse({ message: genericMessage });

    const service = createServiceClient();
    const { data: linkedEmail, error: linkedError } = await service
      .from("user_recovery_emails")
      .select("user_id, recovery_email, verified_at")
      .eq("recovery_email", recoveryEmail)
      .not("verified_at", "is", null)
      .maybeSingle();
    if (linkedError) throw linkedError;
    if (!linkedEmail) return jsonResponse({ message: genericMessage });

    const { data: userData, error: userError } = await service.auth.admin
      .getUserById(linkedEmail.user_id);
    if (userError || !userData.user?.email) {
      console.error(
        "[password-recovery-by-linked-email] user lookup failed",
        userError,
      );
      return jsonResponse({ message: genericMessage });
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

    return jsonResponse({ message: genericMessage });
  } catch (error) {
    console.error("[password-recovery-by-linked-email]", error);
    return jsonResponse({ message: genericMessage });
  }
});
