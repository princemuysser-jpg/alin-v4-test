import { corsHeaders, jsonResponse, publicError } from '../_shared/cors.ts';
import { cleanText, requireAdmin } from '../_shared/admin.ts';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req) });
  if (req.method !== 'POST') return jsonResponse(req, { ok: false, error: 'الطريقة غير مسموحة' }, 405);
  try {
    const { admin } = await requireAdmin(req, 'orders');
    const body = await req.json();
    const orderId = cleanText(body.order_id, 100);
    const courierId = cleanText(body.courier_id, 100) || null;
    const libraryId = cleanText(body.library_id, 100) || null;
    if (!orderId) throw new Error('معرّف الطلب غير موجود');
    const { data, error } = await admin.rpc('alin_admin_assign_order', {
      p_order_id: orderId,
      p_courier_id: courierId,
      p_library_id: libraryId,
    });
    if (error) throw error;
    if (!data?.ok) throw new Error(data?.error || 'لم يؤكد الخادم تحديث التعيين');
    return jsonResponse(req, data);
  } catch (error) {
    return jsonResponse(req, { ok: false, error: publicError(error, 'تعذر تحديث تعيين الطلب') }, 400);
  }
});
