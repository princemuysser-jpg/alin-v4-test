import { createClient } from 'npm:@supabase/supabase-js@2.110.7';
import { corsHeaders, jsonResponse, publicError } from '../_shared/cors.ts';
import { cleanText, normalizeUsername } from '../_shared/admin.ts';

function requestIp(req: Request): string {
  const forwarded = (req.headers.get('x-forwarded-for') || '').split(',')[0]?.trim() || '';
  return cleanText(
    req.headers.get('cf-connecting-ip') ||
    req.headers.get('x-real-ip') ||
    forwarded ||
    'unknown',
    80,
  );
}

function invalidCredentials(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String((error as { message?: unknown })?.message || '');
  return /invalid login credentials|invalid credentials|email not confirmed/i.test(message);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req) });
  if (req.method !== 'POST') return jsonResponse(req, { ok: false, error: 'الطريقة غير مسموحة' }, 405);

  try {
    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anonKey || !serviceKey) throw new Error('إعدادات تسجيل الدخول غير مكتملة');

    const body = await req.json();
    const username = normalizeUsername(body.username);
    const password = String(body.password || '');
    if (!username || !password) throw new Error('اكتب اسم الدخول وكلمة المرور');
    if (password.length > 256) return jsonResponse(req, { ok: false, error: 'بيانات الدخول غير صحيحة' }, 401);

    // The guard scope is derived on the server from the login identifier + request IP.
    // Client-provided device IDs are deliberately not trusted for rate-limit identity.
    const guardDevice = requestIp(req);
    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: guard, error: guardError } = await admin.rpc('alin_login_guard_check', {
      p_identifier: username,
      p_device: guardDevice,
    });
    if (guardError) throw guardError;
    if (guard?.allowed === false) {
      const minutes = Math.max(1, Math.ceil(Number(guard.retry_after_seconds || 60) / 60));
      return jsonResponse(req, { ok: false, error: `تم إيقاف المحاولات مؤقتاً. حاول بعد ${minutes} دقيقة` }, 429);
    }

    // Resolve the Auth email from the authoritative account/auth_user_id link instead of
    // guessing legacy email aliases in the browser. This preserves old usernames safely.
    const { data: account, error: accountError } = await admin
      .from('accounts')
      .select('id,role,status,auth_user_id,deleted_at')
      .eq('username', username)
      .maybeSingle();
    if (accountError) throw accountError;

    let authEmail = '';
    if (account?.auth_user_id) {
      const { data: authUserData, error: authUserError } = await admin.auth.admin.getUserById(String(account.auth_user_id));
      if (!authUserError && authUserData?.user?.email) authEmail = String(authUserData.user.email);
    }

    if (!account || !authEmail) {
      // Keep the response generic so the endpoint does not disclose whether a username exists.
      const { data: failed } = await admin.rpc('alin_login_guard_fail', {
        p_identifier: username,
        p_device: guardDevice,
      });
      const locked = failed?.allowed === false;
      const remaining = Math.max(0, Number(failed?.remaining ?? guard?.remaining ?? 0));
      return jsonResponse(req, {
        ok: false,
        error: locked ? 'تم إيقاف المحاولات لمدة 15 دقيقة بسبب تكرار الخطأ' : `بيانات الدخول غير صحيحة. المحاولات المتبقية: ${remaining}`,
      }, locked ? 429 : 401);
    }

    const authClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data, error } = await authClient.auth.signInWithPassword({ email: authEmail, password });
    if (error || !data.session || !data.user) {
      if (error && !invalidCredentials(error)) {
        // The reservation remains counted: repeated retries during a backend outage are still bounded.
        throw error;
      }
      const { data: failed } = await admin.rpc('alin_login_guard_fail', {
        p_identifier: username,
        p_device: guardDevice,
      });
      const locked = failed?.allowed === false;
      const remaining = Math.max(0, Number(failed?.remaining ?? guard?.remaining ?? 0));
      return jsonResponse(req, {
        ok: false,
        error: locked ? 'تم إيقاف المحاولات لمدة 15 دقيقة بسبب تكرار الخطأ' : `بيانات الدخول غير صحيحة. المحاولات المتبقية: ${remaining}`,
      }, locked ? 429 : 401);
    }

    await admin.rpc('alin_login_guard_success', { p_identifier: username, p_device: guardDevice });

    // Correct credentials are not enough: never return a session for an inactive, deleted,
    // or orphaned ALIN account.
    if (account.status !== 'active' || account.deleted_at || String(account.auth_user_id) !== data.user.id) {
      try { await authClient.auth.signOut(); } catch (_) { /* no-op */ }
      return jsonResponse(req, { ok: false, error: 'الحساب غير فعال أو غير مربوط بشكل صحيح' }, 403);
    }

    return jsonResponse(req, {
      ok: true,
      session: {
        access_token: data.session.access_token,
        refresh_token: data.session.refresh_token,
        expires_at: data.session.expires_at,
        expires_in: data.session.expires_in,
      },
      user: { id: data.user.id },
    });
  } catch (error) {
    return jsonResponse(req, { ok: false, error: publicError(error, 'تعذر تسجيل الدخول حالياً') }, 400);
  }
});
