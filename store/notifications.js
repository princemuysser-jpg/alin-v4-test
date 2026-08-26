/* ALIN v4.2 Stable Lock — storefront notifications with secure per-student delivery. */
(function(){
  'use strict';

  const escapeHtml=value=>String(value??'').replace(/[&<>"']/g,char=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[char]));
  const arr=value=>Array.isArray(value)?value:[];
  const service=()=>window.AlinNotifications;
  const auth=()=>window.AlinStudentAuth;
  const student=()=>auth()?.current?.()||null;
  const context=()=>({role:'student',id:String(student()?.id||'')});
  const client=()=>window.sb||window.AlinCloud?.client?.()||null;
  let secureRows=[];
  let secureLoaded=false;

  function sessionArgs(){
    const token=auth()?.token?.()||'';
    const device=auth()?.deviceId?.()||'';
    return token&&device?{p_token:token,p_device:device}:null;
  }

  async function studentRpc(name,args={}){
    const c=client();
    if(!c?.rpc)throw new Error('خدمة إشعارات الطالب غير متاحة');
    const {data,error}=await c.rpc(name,args);
    if(error)throw error;
    return data;
  }

  function publicRows(){return service()?.visible?.(context())||[]}
  function rows(){return student()&&secureLoaded?secureRows:publicRows()}
  function isRead(row){
    if(student()&&secureLoaded)return row?.is_read===true;
    return service()?.isRead?.(row,context())??true;
  }
  function unread(){return rows().filter(row=>!isRead(row)).length}

  function badges(){
    const count=unread();
    document.querySelectorAll('.alin98-notify-count,.alin-v94-notify-count').forEach(badge=>{
      badge.textContent=count>99?'99+':String(count);
      badge.hidden=count===0;
    });
    document.querySelectorAll('[data-desktop-control="notifications"],.mobile-header-icon-btn[aria-label^="الإشعارات"]').forEach(button=>{
      button.classList.toggle('has-unread',count>0);
    });
  }

  function close(){
    document.getElementById('alinNotificationsV120')?.remove();
    document.body.classList.remove('alin-notifications-open');
  }

  function itemHtml(row){
    const read=isRead(row);
    const orderCode=String(row?.link||'').startsWith('order:')?String(row.link).slice(6):'';
    return `<article class="${read?'read':'unread'}" data-notification-id="${escapeHtml(row.id)}"${orderCode?` data-order-code="${escapeHtml(orderCode)}"`:''}><span class="alin-notifications-v120__dot"></span><div><div class="alin-notifications-v120__title"><h3>${escapeHtml(row.title||'إشعار')}</h3>${read?'':'<b>جديد</b>'}</div><p>${escapeHtml(row.message||row.text||'')}</p>${orderCode?'<small class="alin-notification-order-hint">اضغط لفتح تتبع الطلب</small>':''}<time>${escapeHtml(new Date(row.created_at||Date.now()).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ'))}</time></div></article>`;
  }

  async function markRead(id){
    const args=sessionArgs();
    if(args&&student()){
      await studentRpc('alin_student_notification_mark_read',{...args,p_notification_id:String(id)});
      const row=secureRows.find(item=>String(item.id)===String(id));
      if(row)row.is_read=true;
      badges();
      return true;
    }
    return service()?.markRead?.(id,context());
  }

  async function markAll(){
    const args=sessionArgs();
    if(args&&student()){
      await studentRpc('alin_student_notifications_mark_all',args);
      secureRows.forEach(row=>{row.is_read=true});
      badges();
      return true;
    }
    return service()?.markAll?.(context());
  }

  function openOrderTracking(code){
    const value=String(code||'').trim();
    if(!value)return false;
    close();
    const tracker=auth()?.track;
    if(typeof tracker==='function'){
      tracker(encodeURIComponent(value));
      return true;
    }
    const input=document.getElementById('trackOrderInput');
    if(input){input.value=value;window.trackOrder?.();return true}
    return false;
  }

  function open(){
    close();
    const box=document.createElement('div');
    box.id='alinNotificationsV120';
    box.className='alin-notifications-v120';
    const list=rows();
    box.innerHTML=`<button class="alin-notifications-v120__backdrop" type="button" aria-label="إغلاق"></button><section class="alin-notifications-v120__panel" role="dialog" aria-modal="true"><header><div><h2>الإشعارات</h2><p>${unread()?unread()+' إشعار جديد':'لا توجد إشعارات جديدة'}</p></div><div><button type="button" data-read-all>قراءة الكل</button><button type="button" data-close aria-label="إغلاق">×</button></div></header><div class="alin-notifications-v120__list">${list.map(itemHtml).join('')||'<div class="alin-notifications-v120__empty"><span>🔕</span><b>لا توجد إشعارات حالياً</b><p>تحديثات طلباتك وإشعارات المنصة ستظهر هنا.</p></div>'}</div></section>`;
    document.body.appendChild(box);
    document.body.classList.add('alin-notifications-open');
    box.querySelector('[data-close]')?.addEventListener('click',close);
    box.querySelector('.alin-notifications-v120__backdrop')?.addEventListener('click',close);
    box.querySelector('[data-read-all]')?.addEventListener('click',async()=>{try{await markAll()}catch(error){console.warn('[ALIN student notifications] mark all',error)}open()});
    box.querySelectorAll('[data-notification-id]').forEach(item=>item.addEventListener('click',async()=>{
      try{await markRead(item.dataset.notificationId)}catch(error){console.warn('[ALIN student notifications] mark read',error)}
      const code=item.dataset.orderCode||'';
      if(code){openOrderTracking(code);return}
      open();
    }));
  }

  let refreshPromise=null;
  let lastRefreshAt=0;
  async function refresh(options={}){
    const force=options?.force===true;
    const now=Date.now();
    if(!force&&now-lastRefreshAt<2500){badges();return rows()}
    if(refreshPromise)return refreshPromise;
    refreshPromise=(async()=>{
      try{
        await service()?.refresh?.();
        const args=sessionArgs();
        if(args&&student()){
          const data=await studentRpc('alin_student_notifications',args);
          secureRows=arr(data).map(row=>({...row,__studentSecure:true}));
          secureLoaded=true;
        }else{
          secureRows=[];
          secureLoaded=false;
        }
        lastRefreshAt=Date.now();
      }catch(error){
        console.warn('[ALIN store notifications] secure refresh',error);
        if(!student()){secureRows=[];secureLoaded=false}
      }finally{
        badges();
        refreshPromise=null;
      }
      return rows();
    })();
    return refreshPromise;
  }

  function refreshOnResume(){
    if(document.visibilityState&&document.visibilityState!=='visible')return;
    refresh({force:true}).catch(error=>console.warn('[ALIN store notifications] resume refresh',error));
  }

  function consumeTrackingQuery(){
    try{
      const url=new URL(location.href),code=url.searchParams.get('track');
      if(!code)return;
      url.searchParams.delete('track');
      history.replaceState(history.state,'',url.href);
      setTimeout(()=>openOrderTracking(code),350);
    }catch(_){}
  }

  function install(){
    document.querySelectorAll('[data-desktop-control="notifications"],.mobile-header-icon-btn[aria-label^="الإشعارات"]').forEach(button=>{
      button.removeAttribute('onclick');
      if(button.dataset.alinNotificationsBound==='1')return;
      button.dataset.alinNotificationsBound='1';
      button.addEventListener('click',event=>{event.preventDefault();open()});
    });
    document.addEventListener('keydown',event=>{if(event.key==='Escape')close()});
    window.addEventListener('alin:notifications-updated',()=>{badges();if(document.getElementById('alinNotificationsV120'))open()});
    window.addEventListener('alin:store-rendered',badges);
    window.addEventListener('alin:student-session',()=>{
      secureRows=[];secureLoaded=false;
      refresh({force:true}).catch(()=>{});
    });
    window.addEventListener('focus',refreshOnResume,{passive:true});
    window.addEventListener('pageshow',refreshOnResume,{passive:true});
    window.addEventListener('online',refreshOnResume,{passive:true});
    document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')refreshOnResume()});
    window.addEventListener('alin:push-received',refreshOnResume);
    setInterval(()=>{if(document.visibilityState==='visible')refresh().catch(()=>{})},45000);
    refresh({force:true});
    consumeTrackingQuery();
  }

  const api=Object.freeze({open,close,refresh,badges,rows,markRead,markAll,openOrderTracking});
  window.AlinStoreNotifications=api;
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
})();
