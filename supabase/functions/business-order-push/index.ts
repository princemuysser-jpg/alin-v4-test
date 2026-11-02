import { createClient } from 'npm:@supabase/supabase-js@2.110.7';
import { importPKCS8, SignJWT } from 'npm:jose@6.1.0';
import webpush from 'npm:web-push@3.6.7';

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

function clean(value: unknown, max = 700) {
  return String(value ?? '').trim().slice(0, max);
}

async function googleAccessToken(service: any) {
  const now = Math.floor(Date.now() / 1000);
  const key = await importPKCS8(String(service.private_key || ''), 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(String(service.client_email || ''))
    .setSubject(String(service.client_email || ''))
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  if (!r.ok) throw new Error('firebase_auth_failed');
  const body = await r.json();
  if (!body?.access_token) throw new Error('firebase_token_missing');
  return String(body.access_token);
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return response({ ok: false, error: 'method_not_allowed' }, 405);
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !serviceKey) throw new Error('server_config_missing');
    const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

    const suppliedSecret = clean(req.headers.get('x-alin-internal'), 300);
    const { data: expectedSecret, error: secretError } = await admin.rpc('alin_internal_order_push_secret');
    if (secretError || !expectedSecret || suppliedSecret !== String(expectedSecret)) {
      return response({ ok: false, error: 'unauthorized' }, 401);
    }

    const body = await req.json();
    const targetRole = clean(body.target_role, 30).toLowerCase();
    const targetAccountId = clean(body.target_account_id, 120) || null;
    const orderId = clean(body.order_id, 140);
    const orderNumber = clean(body.order_number, 140);
    const checkoutGroupId = clean(body.checkout_group_id, 140);
    const eventType = clean(body.event_type, 60).toLowerCase() || 'order_update';
    const title = clean(body.title, 160) || 'آلين للأعمال';
    const message = clean(body.message, 700);
    const link = clean(body.url, 500) || `alinbusiness://orders?order=${encodeURIComponent(orderId || orderNumber)}`;

    if (!['admin', 'courier', 'library', 'printer', 'teacher', 'accountant'].includes(targetRole)) {
      return response({ ok: false, error: 'invalid_target_role' }, 400);
    }
    if (!message) return response({ ok: false, error: 'invalid_payload' }, 400);
    if (targetRole !== 'admin' && !targetAccountId) return response({ ok: false, error: 'target_account_required' }, 400);

    const notificationId = `NBO-${crypto.randomUUID()}`;
    await admin.from('notifications').insert({
      id: notificationId,
      title,
      message,
      role: targetRole,
      account_id: targetAccountId,
      type: eventType,
      link,
      status: 'active',
      is_read: false,
      created_by: 'system',
      created_at: new Date().toISOString(),
    });

    const { data: serviceRaw, error: serviceError } = await admin.rpc('alin_firebase_service_account_json');
    if (serviceError) throw serviceError;
    const raw = typeof serviceRaw === 'string' ? serviceRaw : '';
    if (!raw) throw new Error('firebase_service_missing');
    const service = JSON.parse(raw);
    if (!service?.private_key || !service?.client_email || !service?.project_id) throw new Error('firebase_service_invalid');

    const access = await googleAccessToken(service);
    const { data: targets, error: targetError } = await admin.rpc('alin_business_fcm_push_targets', {
      p_role: targetRole,
      p_account_id: targetAccountId,
    });
    if (targetError) throw targetError;

    let sent = 0;
    let failed = 0;
    let stale = 0;
    for (const target of targets || []) {
      const token = String(target.token || '');
      if (!token) continue;
      const dataPayload: Record<string, string> = {
        notification_id: notificationId,
        type: eventType,
        title,
        message,
        url: link,
        link,
        target_role: targetRole,
        order_id: orderId,
        order_number: orderNumber,
        checkout_group_id: checkoutGroupId,
      };
      const fcmBody = {
        message: {
          token,
          notification: { title, body: message },
          data: dataPayload,
          android: {
            priority: 'high',
            notification: {
              channel_id: 'alin_business_orders',
              sound: 'default',
              default_vibrate_timings: true,
              notification_priority: 'PRIORITY_MAX',
            },
          },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: { aps: { sound: 'default', badge: 1, 'content-available': 1 } },
          },
        },
      };
      try {
        const r = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(String(service.project_id))}/messages:send`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${access}`, 'Content-Type': 'application/json' },
          body: JSON.stringify(fcmBody),
        });
        if (r.ok) {
          sent++;
          continue;
        }
        failed++;
        const text = await r.text();
        if (r.status === 404 || /UNREGISTERED|registration-token-not-registered/i.test(text)) {
          await admin.rpc('alin_disable_fcm_token', { p_token: token });
          stale++;
        }
      } catch (_) {
        failed++;
      }
    }

    // Browser Push is separate from native FCM, isolated by authenticated business account.
    let webSent = 0, webFailed = 0;
    const { data: webTargets, error: webError } = await admin.rpc('alin_business_web_push_targets', {
      p_role: targetRole, p_account_id: targetAccountId,
    });
    if (!webError && (webTargets || []).length) {
      let vapidPublic = Deno.env.get('VAPID_PUBLIC_KEY') || '';
      let vapidPrivate = Deno.env.get('VAPID_PRIVATE_KEY') || '';
      let subject = Deno.env.get('VAPID_SUBJECT') || 'mailto:admin@alinplatform.com';
      if (!vapidPublic || !vapidPrivate) {
        const { data: cfg } = await admin.from('push_config')
          .select('vapid_public_key,vapid_private_key,subject').eq('id','main').maybeSingle();
        vapidPublic ||= String(cfg?.vapid_public_key || '');
        vapidPrivate ||= String(cfg?.vapid_private_key || '');
        subject = String(cfg?.subject || subject);
      }
      if (vapidPublic && vapidPrivate) {
        webpush.setVapidDetails(subject, vapidPublic, vapidPrivate);
        const payload = JSON.stringify({
          title,body:message,notification_id:notificationId,
          tag:notificationId,url:link,order_id:orderId,
        });
        for (const item of webTargets || []) {
          try {
            await webpush.sendNotification({
              endpoint: item.endpoint,keys:{p256dh:item.p256dh,auth:item.auth},
            },payload,{TTL:86400,urgency:'high'});
            webSent++;
          } catch(e:any) {
            webFailed++;
            if ([404,410].includes(Number(e?.statusCode || 0))) {
              await admin.rpc('alin_disable_business_web_push_endpoint',{p_endpoint:item.endpoint});
            }
          }
        }
      }
    }

    return response({
      ok: true,
      notification_id: notificationId,
      sent,
      failed,
      stale_disabled: stale,
      web_sent: webSent,
      web_failed: webFailed,
      active_devices: (targets || []).length,
    });
  } catch (error: any) {
    return response({ ok: false, error: clean(error?.message || 'business_push_failed', 220) }, 400);
  }
});