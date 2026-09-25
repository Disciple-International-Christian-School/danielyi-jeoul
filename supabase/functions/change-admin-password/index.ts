import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function strongPassword(value: unknown): value is string {
  return typeof value === "string"
    && value.length >= 12
    && /[A-Z]/.test(value)
    && /[a-z]/.test(value)
    && /[0-9]/.test(value)
    && /[^A-Za-z0-9]/.test(value);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authorization = req.headers.get("Authorization");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "Server configuration is incomplete." }, 500);
  }
  if (!authorization) {
    return json({ error: "Authentication required." }, 401);
  }

  let body: { password?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }

  if (!strongPassword(body.password)) {
    return json({ error: "비밀번호는 12자 이상이며 영문 대·소문자, 숫자, 특수문자를 모두 포함해야 합니다." }, 400);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData.user;
  if (userError || !user) {
    return json({ error: "Invalid authenticated session." }, 401);
  }

  const { data: profile, error: profileError } = await adminClient
    .from("admins")
    .select("id,is_active,login_id")
    .eq("user_id", user.id)
    .maybeSingle();

  if (profileError || !profile || !profile.is_active) {
    return json({ error: "활성 관리자 계정을 찾을 수 없습니다." }, 403);
  }

  // Do the real Auth password change first. The profile flag is cleared only after this succeeds.
  const { error: updateError } = await userClient.auth.updateUser({
    password: body.password,
  });

  if (updateError) {
    return json({ error: updateError.message || "비밀번호 변경에 실패했습니다." }, 400);
  }

  const now = new Date().toISOString();
  const { error: stateError } = await adminClient
    .from("admins")
    .update({
      must_change_password: false,
      last_password_changed_at: now,
      updated_at: now,
    })
    .eq("id", profile.id);

  if (stateError) {
    // Password already changed successfully. Keep the flag conservative; retrying this
    // function with the new password is safe and will complete state reconciliation.
    return json({
      error: "비밀번호는 변경됐지만 관리자 상태 갱신에 실패했습니다. 새 비밀번호로 다시 로그인한 뒤 재시도해주세요.",
      passwordChanged: true,
    }, 500);
  }

  return json({ ok: true, passwordChanged: true });
});
