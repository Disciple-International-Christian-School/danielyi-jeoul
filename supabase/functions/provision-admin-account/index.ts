import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Role = "SEONDO" | "SASAENG";
type Scope = "ALL" | "ELEMENTARY" | "MIDDLE" | "HIGH";

interface ProvisionBody {
  loginId?: string;
  displayName?: string;
  role?: Role;
  disciplineScope?: Scope | null;
  isLead?: boolean;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeLoginId(value: unknown) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function generateTemporaryPassword() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
  const values = new Uint32Array(18);
  crypto.getRandomValues(values);
  let random = "";
  for (const value of values) random += alphabet[value % alphabet.length];
  // Guaranteed upper/lower/digit/symbol prefix, then cryptographically random suffix.
  return "A7!a" + random;
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

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  const caller = userData.user;

  if (userError || !caller) {
    return json({ error: "Invalid authenticated session." }, 401);
  }

  // Check lead status before creating any Auth user.
  const { data: callerAdmin, error: callerAdminError } = await adminClient
    .from("admins")
    .select("is_lead,is_active,role")
    .eq("user_id", caller.id)
    .maybeSingle();

  if (
    callerAdminError ||
    !callerAdmin ||
    !callerAdmin.is_active ||
    !callerAdmin.is_lead ||
    callerAdmin.role !== "SEONDO"
  ) {
    return json({ error: "선도부장 권한이 필요합니다." }, 403);
  }

  let body: ProvisionBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }

  const loginId = normalizeLoginId(body.loginId);
  const displayName = typeof body.displayName === "string" ? body.displayName.trim() : "";
  const role = body.role;
  let disciplineScope = body.disciplineScope ?? null;
  let isLead = Boolean(body.isLead);

  if (!/^[a-z0-9][a-z0-9._-]{2,31}$/.test(loginId)) {
    return json({ error: "로그인 ID는 영문 소문자/숫자/._- 조합 3~32자로 입력해주세요." }, 400);
  }
  if (!displayName || displayName.length > 80) {
    return json({ error: "표시 이름을 확인해주세요." }, 400);
  }
  if (role !== "SEONDO" && role !== "SASAENG") {
    return json({ error: "관리자 역할을 확인해주세요." }, 400);
  }

  if (role === "SEONDO") {
    const scopes: Scope[] = ["ALL", "ELEMENTARY", "MIDDLE", "HIGH"];
    if (!disciplineScope || !scopes.includes(disciplineScope)) {
      return json({ error: "선도부 담당 범위를 선택해주세요." }, 400);
    }
  } else {
    disciplineScope = null;
    isLead = false;
  }

  const email = `${loginId}@scale.dics.kr`;

  // Fail before Auth creation if the login ID is already used as an admin profile.
  const { data: existingProfile, error: existingProfileError } = await adminClient
    .from("admins")
    .select("id")
    .eq("login_id", loginId)
    .maybeSingle();

  if (existingProfileError) {
    return json({ error: "기존 관리자 계정 확인에 실패했습니다." }, 500);
  }
  if (existingProfile) {
    return json({ error: "이미 사용 중인 로그인 ID입니다." }, 409);
  }

  const temporaryPassword = generateTemporaryPassword();

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password: temporaryPassword,
    email_confirm: true,
    user_metadata: { display_name: displayName },
  });

  if (createError || !created.user) {
    const message = createError?.message?.toLowerCase().includes("already")
      ? "이미 존재하는 Auth 계정입니다."
      : "Auth 계정 생성에 실패했습니다.";
    return json({ error: message }, createError?.status ?? 400);
  }

  const { data: adminId, error: profileError } = await userClient.rpc("register_admin_profile", {
    p_user_id: created.user.id,
    p_login_id: loginId,
    p_display_name: displayName,
    p_role: role,
    p_scope: disciplineScope,
    p_is_lead: isLead,
  });

  if (profileError) {
    // Compensating cleanup: do not leave an orphan Auth user if profile creation fails.
    await adminClient.auth.admin.deleteUser(created.user.id);
    return json({ error: profileError.message || "관리자 프로필 생성에 실패했습니다." }, 400);
  }

  return json({
    adminId,
    loginId,
    temporaryPassword,
    mustChangePassword: true,
  }, 201);
});
