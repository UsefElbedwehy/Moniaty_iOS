// delete-account: in-app account deletion (App Store guideline 5.1.1(v)).
// 1. `delete_my_account()` (run as the user) anonymises the profile and removes personal data,
//    keeping only records the law requires (see the SQL function).
// 2. The auth user is then deleted with the service role.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json, requireEnv } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method not allowed" });

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json(401, { error: "missing bearer token" });

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const userClient = createClient(supabaseUrl, requireEnv("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return json(401, { error: "invalid token" });

  try {
    const { error: rpcError } = await userClient.rpc("delete_my_account");
    if (rpcError) throw rpcError;
    const admin = createClient(supabaseUrl, requireEnv("SUPABASE_SERVICE_ROLE_KEY"));
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;
    return json(200, { ok: true });
  } catch (error) {
    console.error(`delete-account failed for ${user.id}:`, error instanceof Error ? error.message : error);
    return json(500, { error: "delete failed" });
  }
});
