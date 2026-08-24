import { corsHeaders, jsonResponse, publicError } from '../_shared/cors.ts';
import {
  cleanText,
  emailForUsername,
  ensureAuthUserForAccount,
  insertCompat,
  normalizeUsername,
  publicAccount,
  removeLegacyPassword,
  requireAdmin,
  updateCompat,
  assertStrongPassword,
  requireSuperAdmin,
} from '../_shared/admin.ts';

const ALLOWED_ROLES = new Set(['admin', 'teacher', 'library', 'courier', 'accountant']);

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req) });
  if (req.method !== 'POST') return jsonResponse(req, { ok: false, error: 'الطريقة غير مسموحة' }, 405);

  let stage = 'start';
  try {
    stage = 'require-admin';
    const context = await requireAdmin(req, 'accounts');
    const { admin } = context;
    const body = await req.json();
    const accountId = cleanText(body.account_id, 80);
    if (!accountId) throw new Error('معرّف الحساب مطلوب');

    stage = 'load-account';
    let { data: account, error: accountError } = await admin
      .from('accounts')
      .select('id,role,name,username,status,auth_user_id,deleted_at')
      .eq('id', accountId)
      .maybeSingle();
    if (accountError) throw accountError;

    const requestedRole = cleanText(body.role || account?.role || 'courier', 30).toLowerCase();
    if (requestedRole === 'admin' || account?.role === 'admin') requireSuperAdmin(context);
    if (!ALLOWED_ROLES.has(requestedRole)) throw new Error('نوع الحساب غير مدعوم');
    const hasRequestedAreas = Array.isArray(body.areas);
    const requestedAreas = hasRequestedAreas
      ? [...new Set(body.areas.map((x: unknown) => cleanText(x, 100)).filter(Boolean))]
      : undefined;
    if (requestedRole === 'courier' && hasRequestedAreas && !requestedAreas?.length) {
      throw new Error('اختر منطقة عمل واحدة على الأقل للمندوب');
    }
    const requestedPrimaryArea = requestedRole === 'courier'
      ? (hasRequestedAreas ? (requestedAreas?.[0] || '') : (body.area === undefined ? undefined : cleanText(body.area, 120)))
      : (body.area === undefined ? undefined : cleanText(body.area, 120));
    const username = body.username === undefined ? normalizeUsername(account?.username) : normalizeUsername(body.username);
    const name = body.name === undefined ? cleanText(account?.name, 120) : cleanText(body.name, 120);
    const password = String(body.password || '');
    if (password) assertStrongPassword(password);
    if (account?.deleted_at && body.status === 'active' && !password) {
      throw new Error('لتفعيل حساب مؤرشف عيّن كلمة مرور جديدة أولاً');
    }

    let authWarning = '';

    // Seamless migration for a legacy courier row that has no accounts/Auth user yet.
    if (!account) {
      if (requestedRole !== 'courier') throw new Error('الحساب غير موجود');
      if (!username || !name || password.length < 12) {
        throw new Error('هذا مندوب قديم غير مربوط. اكتب اسمه واسم الدخول وكلمة مرور جديدة من 12 حرفاً تتضمن حروفاً وأرقاماً لترحيله');
      }
      stage = 'legacy-courier-auth';
      const resolved = await ensureAuthUserForAccount(admin, {
        accountId, authUserId: null, username, password, name, role: 'courier',
      });
      try {
        stage = 'legacy-courier-account-insert';
        account = await insertCompat(admin, 'accounts', {
          id: accountId,
          role: 'courier',
          name,
          username,
          status: body.status || 'active',
          auth_user_id: resolved.id,
          area: requestedPrimaryArea || '',
          landmark: cleanText(body.landmark, 180),
          phone: cleanText(body.phone, 40),
          notes: cleanText(body.notes, 500),
          updated_at: new Date().toISOString(),
        }) as typeof account;
      } catch (error) {
        if (resolved.created) await admin.auth.admin.deleteUser(resolved.id);
        throw error;
      }
    } else {
      const oldUsername = normalizeUsername(account.username);
      const oldName = cleanText(account.name, 120);
      const oldRole = cleanText(account.role, 30);
      const nextUsername = username || oldUsername;
      const nextName = name || oldName;
      if (!nextUsername || !nextName) throw new Error('الاسم واسم الدخول مطلوبان');

      let nextAuthUserId = account.auth_user_id ? String(account.auth_user_id) : '';

      // Password changes always require an authoritative Auth update.
      if (password) {
        stage = 'auth-password-sync';
        const resolved = await ensureAuthUserForAccount(admin, {
          accountId,
          authUserId: nextAuthUserId || null,
          username: nextUsername,
          password,
          name: nextName,
          role: requestedRole,
        });
        nextAuthUserId = resolved.id;
      } else if (nextAuthUserId && nextUsername !== oldUsername) {
        // Username is part of the login identity, so this sync is required.
        stage = 'auth-username-sync';
        const { error: authUpdateError } = await admin.auth.admin.updateUserById(nextAuthUserId, {
          email: emailForUsername(nextUsername),
          user_metadata: { name: nextName, username: nextUsername, role: requestedRole },
        });
        if (authUpdateError) throw authUpdateError;
      } else if (nextAuthUserId && (nextName !== oldName || requestedRole !== oldRole)) {
        // Name/role metadata is helpful but must never block ordinary account edits.
        stage = 'auth-metadata-sync';
        const { error: authMetaError } = await admin.auth.admin.updateUserById(nextAuthUserId, {
          user_metadata: { name: nextName, username: nextUsername, role: requestedRole },
        });
        if (authMetaError) {
          console.warn('[admin-update-account] metadata sync skipped', authMetaError.message);
          authWarning = 'تم حفظ بيانات الحساب، لكن تعذر تحديث بيانات الدخول الثانوية';
        }
      }
      account.auth_user_id = nextAuthUserId || null;

      stage = 'update-account-row';
      account = await updateCompat(admin, 'accounts', {
        role: requestedRole,
        name: nextName,
        username: nextUsername,
        status: ['active', 'inactive', 'pending'].includes(body.status) ? body.status : account.status,
        deleted_at: body.status === 'active' ? null : account.deleted_at,
        auth_user_id: account.auth_user_id,
        area: requestedPrimaryArea,
        landmark: body.landmark === undefined ? undefined : cleanText(body.landmark, 180),
        phone: body.phone === undefined ? undefined : cleanText(body.phone, 40),
        notes: body.notes === undefined ? undefined : cleanText(body.notes, 500),
        updated_at: new Date().toISOString(),
      }, accountId) as typeof account;
    }

    const finalRole = cleanText(account?.role || requestedRole, 30);
    if (finalRole === 'courier' || requestedRole === 'courier') {
      stage = 'update-courier-row';
      const areas = requestedAreas;
      const courierPayload: Record<string, unknown> = {
        name: cleanText(body.name ?? account?.name, 120),
        username: normalizeUsername(body.username ?? account?.username),
        phone: body.phone === undefined ? undefined : cleanText(body.phone, 40),
        area: requestedPrimaryArea === undefined ? (areas?.[0] || undefined) : requestedPrimaryArea,
        areas,
        availability: ['available', 'busy', 'offline'].includes(body.availability) ? body.availability : undefined,
        status: body.status === 'active' ? 'active' : (body.status === undefined ? undefined : 'inactive'),
        updated_at: new Date().toISOString(),
      };
      Object.keys(courierPayload).forEach((key) => courierPayload[key] === undefined && delete courierPayload[key]);
      const updatedCourier = await updateCompat(admin, 'couriers', courierPayload, accountId);
      if (!updatedCourier) {
        stage = 'insert-courier-row';
        await insertCompat(admin, 'couriers', { id: accountId, ...courierPayload, created_at: new Date().toISOString() });
      }
      await removeLegacyPassword(admin, 'couriers', accountId);
    }
    await removeLegacyPassword(admin, 'accounts', accountId);

    return jsonResponse(req, {
      ok: true,
      account: publicAccount(account as Record<string, unknown>),
      warning: authWarning || undefined,
    });
  } catch (error) {
    console.error(`[admin-update-account:${stage}]`, error);
    return jsonResponse(req, { ok: false, error: publicError(error, 'تعذر تحديث الحساب') }, 400);
  }
});
