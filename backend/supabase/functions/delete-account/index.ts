import {
  corsHeaders,
  createServiceClient,
  getAuthedUser,
  jsonResponse,
} from "../_shared/recovery_email.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const { user } = await getAuthedUser(req);
    if (!user) return jsonResponse({ error: "Unauthorized" }, 401);

    const service = createServiceClient();

    await removeAvatarFolder(service, user.id);

    const { error } = await service.auth.admin.deleteUser(user.id);
    if (error) throw error;

    return jsonResponse({ status: "deleted" });
  } catch (error) {
    console.error("[delete-account]", error);
    return jsonResponse({ error: "Could not delete account." }, 500);
  }
});

async function removeAvatarFolder(
  service: ReturnType<typeof createServiceClient>,
  userId: string,
) {
  try {
    const bucket = service.storage.from("avatars");
    const { data, error } = await bucket.list(userId);
    if (error || !data?.length) return;

    const paths = data.map((item) => `${userId}/${item.name}`);
    await bucket.remove(paths);
  } catch (error) {
    console.warn("[delete-account] avatar cleanup skipped", error);
  }
}
