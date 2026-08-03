import { createClient } from 'npm:@supabase/supabase-js@2.110.7';
import { corsHeaders, jsonResponse, publicError } from '../_shared/cors.ts';
import { assertStrongPassword, cleanText, emailForUsername, normalizeUsername } from '../_shared/admin.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req) });
  if (req.method !== 'POST') return jsonResponse(req, { ok: false, error: 'الطريقة غير مسموحة' }, 405);

  let createdUserId = '';
  try {
    const url = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const expectedKey = Deno.env.get('ALIN_BOOTSTRAP_KEY') || '';
    if (!url || !serviceKey || !expectedKey) throw new Error('إعدادات التأسيس غير مكتملة');

    const body = await req.json();
    const suppliedKey = String(body.bootstrap_key || '');
    if (!suppliedKey || suppliedKey !== expectedKey) throw new Error('مفتاح التأسيس غير صحيح');

    const username = normalizeUsername(body.username);
    const password = String(body.password || '');
    const name = cleanText(body.name || 'مدير منصة آلين', 120);
    if (!username || !password || !name) throw new Error('أكمل اسم المدير واسم الدخول وكلمة المرور');
    assertStrongPassword(password);

    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { count, error: countError } = await admin.from('accounts').select('id', { head: true, count: 'exact' }).eq('role', 'admin');
    if (countError) throw countError;
    if ((count || 0) > 0) throw new Error('تم إنشاء المدير الأول مسبقاً');

    const email = emailForUsername(username);
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name, username, role: 'admin' },
    });
    if (createError || !created.user) throw createError || new Error('تعذر إنشاء مستخدم المدير');
    createdUserId = created.user.id;

    const accountId = `A${crypto.randomUUID().replaceAll('-', '').slice(0, 22)}`;
    const { data: account, error: accountError } = await admin.from('accounts').insert({
      id: accountId,
      auth_user_id: created.user.id,
      role: 'admin',
      name,
      username,
      status: 'active',
      admin_level: 'super_admin',
    }).select('id,role,name,username,status,admin_level').single();
    if (accountError) throw accountError;

    return jsonResponse(req, { ok: true, account });
  } catch (error) {
    if (createdUserId) {
      try {
        const url = Deno.env.get('SUPABASE_URL')!;
        const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
        const cleanup = createClient(url, serviceKey, { auth: { persistSession: false } });
        await cleanup.auth.admin.deleteUser(createdUserId);
      } catch (_) { /* best effort */ }
    }
    return jsonResponse(req, { ok: false, error: publicError(error, 'تعذر إنشاء المدير الأول') }, 400);
  }
});
