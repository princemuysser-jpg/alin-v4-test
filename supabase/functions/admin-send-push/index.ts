import { createClient } from 'npm:@supabase/supabase-js@2.110.7';
import webpush from 'npm:web-push@3.6.7';

const allowedOrigins = new Set(['https://alinplatform.com','https://www.alinplatform.com','https://princemuysser-jpg.github.io']);
function cors(req: Request){
  const origin=req.headers.get('Origin')||'';
  const local=/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);
  return {...(allowedOrigins.has(origin)||local?{'Access-Control-Allow-Origin':origin}:{}),'Vary':'Origin','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Access-Control-Max-Age':'86400'};
}
function json(req:Request,body:unknown,status=200){return new Response(JSON.stringify(body),{status,headers:{...cors(req),'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'}})}
function clean(v:unknown,max=500){return String(v??'').trim().slice(0,max)}

Deno.serve(async(req:Request)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors(req)});
  if(req.method!=='POST')return json(req,{ok:false,error:'الطريقة غير مسموحة'},405);
  try{
    const url=Deno.env.get('SUPABASE_URL'); const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if(!url||!serviceKey)throw new Error('إعدادات الخادم غير متوفرة');
    const token=(req.headers.get('Authorization')||'').replace(/^Bearer\s+/i,'').trim();
    if(!token)throw new Error('يجب تسجيل الدخول أولاً');
    const admin=createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data:userData,error:userError}=await admin.auth.getUser(token);
    if(userError||!userData.user)throw new Error('جلسة الدخول غير صالحة');
    const {data:account,error:accountError}=await admin.from('accounts').select('id,role,status,admin_level,deleted_at').eq('auth_user_id',userData.user.id).maybeSingle();
    if(accountError)throw accountError;
    if(!account||account.role!=='admin'||account.status!=='active'||account.deleted_at)throw new Error('هذه العملية مسموحة للمدير فقط');
    if(account.admin_level!=='super_admin'){
      const {data:perm,error:permError}=await admin.from('account_permissions').select('permission').eq('account_id',account.id).eq('permission','notifications').eq('granted',true).maybeSingle();
      if(permError)throw permError;
      if(!perm)throw new Error('لا تملك صلاحية إرسال الإشعارات');
    }
    const body=await req.json();
    const title=clean(body.title,160)||'منصة آلين'; const message=clean(body.message,700);
    const role=clean(body.role||'student',30).toLowerCase(); const targetId=clean(body.target_id,120)||null;
    const notificationId=clean(body.notification_id,120)||null; const urlPath=clean(body.url||'./store-mobile.html',500)||'./store-mobile.html';
    if(!message)throw new Error('اكتب نص الإشعار');
    if(!['all','student'].includes(role))return json(req,{ok:true,sent:0,failed:0,skipped:true,reason:'لا توجد أجهزة Push لهذه الفئة'});

    let vapidPublic=clean(Deno.env.get('VAPID_PUBLIC_KEY'),400); let vapidPrivate=clean(Deno.env.get('VAPID_PRIVATE_KEY'),400);
    let subject=clean(Deno.env.get('VAPID_SUBJECT'),300)||'mailto:admin@alinplatform.com';
    if(!vapidPublic||!vapidPrivate){
      const {data:cfg,error:cfgError}=await admin.from('push_config').select('vapid_public_key,vapid_private_key,subject').eq('id','main').single();
      if(cfgError||!cfg)throw cfgError||new Error('إعدادات Push غير موجودة');
      vapidPublic=vapidPublic||clean(cfg.vapid_public_key,400); vapidPrivate=vapidPrivate||clean(cfg.vapid_private_key,400); subject=clean(cfg.subject,300)||subject;
    }
    if(!vapidPublic||!vapidPrivate)throw new Error('مفاتيح Push السرية غير مهيأة على الخادم');
    webpush.setVapidDetails(subject,vapidPublic,vapidPrivate);

    let query=admin.from('push_subscriptions').select('id,endpoint,p256dh,auth,student_id').eq('status','active');
    if(targetId)query=query.eq('student_id',targetId);
    const {data:subs,error:subError}=await query; if(subError)throw subError;
    const payload=JSON.stringify({title,body:message,icon:'./assets/icons/icon-192.png',badge:'./assets/icons/icon-192.png',url:urlPath,tag:notificationId||`alin-${Date.now()}`,notification_id:notificationId,renotify:true});
    let sent=0,failed=0; const stale:string[]=[];
    for(const sub of subs||[]){
      try{await webpush.sendNotification({endpoint:sub.endpoint,keys:{p256dh:sub.p256dh,auth:sub.auth}},payload,{TTL:86400,urgency:'high'});sent++}
      catch(error:any){failed++;const status=Number(error?.statusCode||error?.status||0);if(status===404||status===410)stale.push(String(sub.id))}
    }
    if(stale.length)await admin.from('push_subscriptions').update({status:'inactive',updated_at:new Date().toISOString()}).in('id',stale);
    return json(req,{ok:true,sent,failed,active_devices:(subs||[]).length,stale_disabled:stale.length});
  }catch(error:any){const message=clean(error?.message||'',220);return json(req,{ok:false,error:/[\u0600-\u06FF]/.test(message)?message:'تعذر إرسال إشعار الجهاز'},400)}
});
