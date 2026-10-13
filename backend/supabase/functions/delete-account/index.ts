import {
  createServiceClient,
  getAuthedUser,
  jsonResponse,
} from "../_shared/recovery_email.ts";
import {
  corsPreflightResponse,
  logSecurityEvent,
  requestIdFor,
} from "../_shared/security.ts";

Deno.serve(async (req: Request) => {
  const requestId = requestIdFor(req);
  if (req.method === "OPTIONS") {
    return corsPreflightResponse(req);
  }

  if (req.method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed" }, 405);
  }

  try {
    const { user } = await getAuthedUser(req);
    if (!user) return jsonResponse(req, { error: "Unauthorized" }, 401);

    const service = createServiceClient();

    await removeAvatarFolder(service, user.id, requestId);

    const { error } = await service.auth.admin.deleteUser(user.id);
    if (error) throw error;

    return jsonResponse(req, { status: "deleted" });
  } catch {
    logSecurityEvent("error", "delete_account_failed", requestId);
    return jsonResponse(req, { error: "Could not delete account." }, 500);
  }
});

async function removeAvatarFolder(
  service: ReturnType<typeof createServiceClient>,
  userId: string,
  requestId: string,
) {
  try {
    const bucket = service.storage.from("avatars");
    for (let page = 0; page < 100; page++) {
      const { data, error } = await bucket.list(userId, {
        limit: 100,
        offset: 0,
      });
      if (error || !data?.length) return;
      const paths = data.map((item) => `${userId}/${item.name}`);
      const { error: removeError } = await bucket.remove(paths);
      if (removeError) throw removeError;
      if (data.length < 100) return;
    }
  } catch {
    logSecurityEvent("warn", "avatar_cleanup_skipped", requestId);
  }
}
