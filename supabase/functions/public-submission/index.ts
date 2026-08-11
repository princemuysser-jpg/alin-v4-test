import { createClient } from 'npm:@supabase/supabase-js@2.110.7';

const ALLOWED_ORIGINS = new Set([
  'https://alinplatform.com',
  'https://www.alinplatform.com',
  'https://princemuysser-jpg.github.io',
]);

function cors(req: Request) {
  const origin = req.headers.get('Origin') || '';
  const local = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);
  const allowed = ALLOWED_ORIGINS.has(origin) || local;
  return {
    ...(allowed ? { 'Access-Control-Allow-Origin': origin } : {}),
    'Vary': 'Origin',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  };
}

function json(req: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: cors(req) });
}

function requestIp(req: Request) {
  return String(
    req.headers.get('cf-connecting-ip') ||
    req.headers.get('x-real-ip') ||
    (req.headers.get('x-forwarded-for') || '').split(',')[0] ||
    'unknown'
  ).trim().slice(0, 120);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors(req) });
  if (req.method !== 'POST') return json(req, { ok: false, message: 'الطريقة غير مسموحة' }, 405);

  const origin = req.headers.get('Origin') || '';
  const local = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);
  if (origin && !ALLOWED_ORIGINS.has(origin) && !local) {
    return json(req, { ok: false, message: 'المصدر غير مسموح' }, 403);
  }

  try {
    const url = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !serviceKey) throw new Error('server_not_configured');
    const body = await req.json();
    const action = String(body.action || '').trim();
    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const ip = requestIp(req);

    if (action === 'review') {
      const { data, error } = await admin.rpc('alin_public_submit_review', {
        p_kind: body.kind, p_item_id: body.item_id, p_contact: body.contact,
        p_rating: body.rating, p_comment: body.comment, p_ip: ip,
      });
      if (error) throw error;
      const status = data?.ok === false && data?.code === 'rate_limited' ? 429 : (data?.ok === false ? 400 : 200);
      return json(req, data, status);
    }

    if (action === 'stock_alert') {
      const { data, error } = await admin.rpc('alin_public_submit_stock_alert', {
        p_kind: body.kind, p_item_id: body.item_id, p_contact: body.contact, p_ip: ip,
      });
      if (error) throw error;
      const status = data?.ok === false && data?.code === 'rate_limited' ? 429 : (data?.ok === false ? 400 : 200);
      return json(req, data, status);
    }
    return json(req, { ok: false, message: 'الطلب غير معروف' }, 400);
  } catch (error) {
    console.error(error);
    return json(req, { ok: false, message: 'تعذر إرسال الطلب حالياً' }, 500);
  }
});
