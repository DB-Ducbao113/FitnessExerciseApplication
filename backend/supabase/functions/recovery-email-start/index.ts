import {
  corsHeaders,
  createServiceClient,
  generateCode,
  getAuthedUser,
  jsonResponse,
  normalizeGmail,
  sendEmail,
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
    if (!recoveryEmail) {
      return jsonResponse(
        { error: "Recovery email must be a Gmail address." },
        400,
      );
    }
    if (user.email?.trim().toLowerCase() === recoveryEmail) {
      return jsonResponse(
        { error: "Use a different Gmail as your recovery email." },
        400,
      );
    }

    const service = createServiceClient();
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

    return jsonResponse({
      message: "Verification code sent.",
      recovery_email: recoveryEmail,
    });
  } catch (error) {
    console.error("[recovery-email-start]", error);
    return jsonResponse({
      error: "Could not start recovery email verification.",
    }, 500);
  }
});
