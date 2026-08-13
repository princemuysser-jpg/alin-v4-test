/* modules/core/design.js */
// === core/design.js ===
/* ===== core/design/design-system.js ===== */
(function(){
  document.documentElement.classList.add('alin-design-v175');
  function ready(){document.body?.classList.add('alin-ui-ready')}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',ready,{once:true});else ready();
  document.addEventListener('click',e=>{const b=e.target.closest('button');if(!b||b.disabled)return;b.classList.add('alin-click');setTimeout(()=>b.classList.remove('alin-click'),180)});
})();


;
;

/* modules/library/entry.js */
// === library/dashboard.js ===
/* ALIN v2.0.9 — single library entry and dashboard runtime. */
(function(){
  'use strict';
  window.AlinLibraryModules=window.AlinLibraryModules||{};

  function openLibraryJoinPortal(){
    try{
      window.pendingRole='library';
      if(typeof window.showLogin!=='function')throw new Error('login unavailable');
      window.showLogin('library');
      document.getElementById('login')?.classList.remove('hidden');
      document.getElementById('app')?.classList.add('hidden');
      document.getElementById('loginForm')?.classList.remove('hidden');
      const user=document.getElementById('loginU');
      const pass=document.getElementById('loginPass');
      const msg=document.getElementById('loginMsg');
      if(user){user.placeholder='اسم دخول المكتبة';setTimeout(()=>user.focus(),0)}
      if(pass)pass.placeholder='الرمز السري للمكتبة';
      if(msg){msg.textContent='دخول المكتبة';msg.dataset.role='library'}
    }catch(error){
      console.error('[ALIN library entry]',error);
      alert('تعذر فتح دخول المكتبة. حدّث الصفحة وحاول مرة أخرى.');
    }
  }

  function showLibraryPage(){
    if(window.current?.role!=='library')return false;
    const login=document.getElementById('login');
    const app=document.getElementById('app');
    const page=document.getElementById('libraryPage');
    if(!app||!page)return false;
    login?.classList.add('hidden');
    app.classList.remove('hidden','store-mode');
    document.querySelectorAll('.page').forEach(node=>node.classList.add('hidden'));
    page.classList.remove('hidden');
    const nav=document.getElementById('activeNav');
    if(nav)nav.innerHTML='<button type="button">المكتبة</button>';
    requestAnimationFrame(()=>window.AlinLibraryModules.renderLibrary?.());
    return true;
  }

  window.openLibraryJoinPortal=openLibraryJoinPortal;
  window.AlinLibraryModules.openLibraryJoinPortal=openLibraryJoinPortal;
  window.AlinLibraryModules.showLibraryPage=showLibraryPage;
  window.addEventListener('alin:auth-restored',event=>{
    if(event.detail?.account?.role==='library')showLibraryPage();
  });
  window.addEventListener('alin:data-refreshed',()=>{
    if(window.current?.role==='library')window.AlinLibraryModules.renderLibrary?.();
  });
})();
;

/* store/banners.js */
/* ALIN 2.0.1 — single authoritative banner module (admin + storefront). */
(function(){
  'use strict';

  const state={rows:[],index:0,timer:null,installed:false,saving:false};
  const q=(selector,root=document)=>root.querySelector(selector);
  const esc=value=>String(value??'').replace(/[&<>"']/g,char=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[char]));
  const today=()=>new Date().toISOString().slice(0,10);
  const truthy=value=>value===true||value===1||value==='1'||String(value).toLowerCase()==='true';
  const rows=()=>Array.isArray(window.db?.banners)?window.db.banners:state.rows;
  const client=()=>window.AlinCloud?.client?.()||window.sb||window.supabaseClient||null;

  function enabled(banner){return truthy(banner?.active) && banner?.status!=='hidden'}

  function active(banner){
    const date=today();
    return enabled(banner) &&
      (!(banner?.starts_at||banner?.start_date)||String(banner.starts_at||banner.start_date).slice(0,10)<=date) &&
      (!(banner?.ends_at||banner?.end_date)||String(banner.ends_at||banner.end_date).slice(0,10)>=date);
  }

  function safeLink(value){
    if(!value)return '';
    try{
      const url=new URL(String(value),location.href);
      return ['http:','https:'].includes(url.protocol)?url.href:'';
    }catch(_){return ''}
  }

  function imageUrl(banner){
    const ref=banner?.image_path||banner?.image_url||banner?.cover_path||'';
    if(!ref)return '';
    try{
      if(typeof window.mediaUrl==='function')return window.mediaUrl(ref);
    }catch(error){console.warn('[ALIN banners] media URL',error)}
    if(/^https?:\/\//i.test(String(ref)))return String(ref);
    try{return client()?.storage?.from('alin-files').getPublicUrl(String(ref).replace(/^\/+|^alin-files\//g,'')).data?.publicUrl||''}
    catch(_){return ''}
  }

  function host(){
    return document.getElementById('alinStoreBanners');
  }

  function sortedActiveRows(){
    return rows().filter(active).sort((a,b)=>
      (Number(a.sort_order)||0)-(Number(b.sort_order)||0) ||
      String(b.created_at||'').localeCompare(String(a.created_at||''))
    );
  }

  function renderStorefront(){
    const box=host();
    if(!box)return;
    const visible=sortedActiveRows();
    if(!visible.length){
      box.replaceChildren();
      box.hidden=true;
      clearInterval(state.timer);
      state.timer=null;
      return;
    }

    state.index=Math.min(state.index,visible.length-1);
    const banner=visible[state.index];
    const image=imageUrl(banner);
    const link=safeLink(banner.link_url);
    box.hidden=false;
    const copy=String(banner.subtitle||banner.text||'').trim();
    const hasText=Boolean(String(banner.title||'').trim()||copy);
    box.innerHTML=`
      <article class="alin-store-banner${link?' is-clickable':''}${hasText?' has-copy':' no-copy'}" ${link?'role="link" tabindex="0"':''}>
        <div class="alin-store-banner__media"${image?` style='--alin-banner-image:url("${esc(image)}")'`:''}>
          ${image?`<img class="alin-store-banner__image" src="${esc(image)}" alt="${esc(banner.title||'إعلان منصة آلين')}" loading="eager" decoding="async" style="width:100%!important;height:100%!important;object-fit:fill!important;object-position:center!important;padding:0!important;margin:0!important;">`:`<span class="alin-store-banner__placeholder" aria-hidden="true">آ</span>`}
        </div>
        ${hasText?`<div class="alin-store-banner__content">
          <div class="alin-store-banner__copy">
            <span class="alin-store-banner__label">إعلان منصة آلين</span>
            ${banner.title?`<h2>${esc(banner.title)}</h2>`:''}
            ${copy?`<p>${esc(copy)}</p>`:''}
          </div>
          ${link?`<span class="alin-store-banner__cta" aria-hidden="true">عرض الإعلان <b>←</b></span>`:''}
        </div>`:''}
      </article>`;

    const article=q('.alin-store-banner',box);
    if(article&&link){
      const open=()=>window.open(link,'_blank','noopener,noreferrer');
      article.addEventListener('click',open);
      article.addEventListener('keydown',event=>{
        if(event.key==='Enter'||event.key===' '){event.preventDefault();open()}
      });
    }
    q('.alin-store-banner__image',box)?.addEventListener('error',event=>{
      console.warn('[ALIN banners] image failed',event.currentTarget.src);
      const media=event.currentTarget.closest('.alin-store-banner__media');
      event.currentTarget.remove();
      if(media)media.innerHTML='<span class="alin-store-banner__placeholder" aria-hidden="true">آ</span>';
      article?.classList.add('without-image');
    },{once:true});
  }

  function restartRotation(){
    clearInterval(state.timer);
    state.timer=null;
    if(sortedActiveRows().length>1){
      state.timer=setInterval(()=>{
        const count=sortedActiveRows().length;
        if(!count)return;
        state.index=(state.index+1)%count;
        renderStorefront();
      },6500);
    }
  }

  async function refresh(){
    try{
      if(typeof window.query==='function'){
        const data=await window.query('banners');
        if(Array.isArray(data)){
          state.rows=data;
          if(window.db)window.db.banners=data;
        }
      }else state.rows=rows();
    }catch(error){
      console.warn('[ALIN banners] refresh failed; using loaded rows',error);
      state.rows=rows();
    }
    renderStorefront();
    restartRotation();
  }

  function bannerById(id){return rows().find(item=>String(item.id)===String(id))}
  function value(id){return document.getElementById(id)?.value?.trim()||''}
  function setValue(id,next){const element=document.getElementById(id);if(element)element.value=next??''}
  function notify(message){if(typeof window.toast==='function')window.toast(message);else alert(message)}

  function clearForm(){
    ['alinBannerId','alinBannerTitle','alinBannerText','alinBannerLink','alinBannerStart','alinBannerEnd','alinBannerSort']
      .forEach(id=>setValue(id,''));
    const file=document.getElementById('alinBannerFile');if(file)file.value='';
    const save=document.getElementById('alinBannerSave');if(save)save.textContent='إضافة البنر';
  }

  async function uploadImage(file){
    if(!file)return '';
    if(typeof window.uploadFile!=='function')throw new Error('خدمة رفع الصور غير جاهزة');
    const result=await window.uploadFile('banners',file,{type:'image',required:true});
    if(!result)throw new Error('لم يتم استلام مسار الصورة بعد الرفع');
    return typeof result==='string'?result:(result.path||result.url||'');
  }

  async function removeStoredImage(path){
    const clean=String(path||'').replace(/^\/+|^alin-files\//g,'');
    if(!clean.startsWith('banners/'))return;
    try{
      const c=client();
      if(c?.storage){const {error}=await c.storage.from('alin-files').remove([clean]);if(error)console.warn('[ALIN banners] storage cleanup',error)}
    }catch(error){console.warn('[ALIN banners] storage cleanup',error)}
  }

  async function save(){
    if(state.saving)return;
    const id=value('alinBannerId');
    const title=value('alinBannerTitle');
    const text=value('alinBannerText');
    const link=value('alinBannerLink');
    const start=value('alinBannerStart')||null;
    const end=value('alinBannerEnd')||null;
    const sort=Number(value('alinBannerSort')||0);
    const file=document.getElementById('alinBannerFile')?.files?.[0];
    if(!title)return alert('اكتب عنوان البنر');
    if(start&&end&&start>end)return alert('تاريخ النهاية يجب أن يكون بعد تاريخ البداية');
    if(link&&!safeLink(link))return alert('رابط البنر يجب أن يبدأ بـ http أو https');

    state.saving=true;
    const button=document.getElementById('alinBannerSave');
    if(button){button.disabled=true;button.textContent='جارٍ الحفظ...'}
    let newlyUploaded='';
    try{
      const old=bannerById(id);
      newlyUploaded=file?await uploadImage(file):'';
      const payload={
        title,subtitle:text,link_url:link||null,
        image_path:newlyUploaded||(old?.image_path||null),
        starts_at:start,ends_at:end,sort_order:sort,
        active:old?enabled(old):true,updated_at:new Date().toISOString()
      };
      if(id){
        if(typeof window.update!=='function')throw new Error('خدمة تعديل البنر غير جاهزة');
        await window.update('banners',payload,{id});
        if(newlyUploaded&&old?.image_path&&old.image_path!==newlyUploaded)await removeStoredImage(old.image_path);
      }else{
        if(typeof window.insert!=='function')throw new Error('خدمة إضافة البنر غير جاهزة');
        await window.insert('banners',{
          id:typeof window.uid==='function'?window.uid('BN'):`BN-${Date.now()}`,
          ...payload,created_at:new Date().toISOString()
        });
      }
      if(typeof window.audit==='function')await window.audit('banner',`${id?'تعديل':'إضافة'} البنر ${title}`);
      await refresh();
      renderAdmin();
      clearForm();
      notify(id?'تم تعديل البنر والصورة':'تمت إضافة البنر والصورة');
    }catch(error){
      if(newlyUploaded)await removeStoredImage(newlyUploaded);
      console.error('[ALIN banners] save',error);
      alert(error?.message||'تعذر حفظ البنر');
    }finally{
      state.saving=false;
      if(button){button.disabled=false;button.textContent=id?'حفظ التعديل':'إضافة البنر'}
    }
  }

  function edit(id){
    const banner=bannerById(id);if(!banner)return;
    setValue('alinBannerId',banner.id);
    setValue('alinBannerTitle',banner.title);
    setValue('alinBannerText',banner.subtitle||banner.text);
    setValue('alinBannerLink',banner.link_url);
    setValue('alinBannerStart',String(banner.starts_at||banner.start_date||'').slice(0,10));
    setValue('alinBannerEnd',String(banner.ends_at||banner.end_date||'').slice(0,10));
    setValue('alinBannerSort',banner.sort_order||0);
    const save=document.getElementById('alinBannerSave');if(save)save.textContent='حفظ التعديل';
    document.getElementById('alinBannerTitle')?.scrollIntoView({behavior:'smooth',block:'center'});
  }

  async function toggle(id){
    const banner=bannerById(id);if(!banner)return;
    const next=!enabled(banner);
    try{
      await window.update('banners',{active:next,updated_at:new Date().toISOString()},{id});
      await refresh();renderAdmin();notify(next?'تم إظهار البنر':'تم إخفاء البنر');
    }catch(error){alert(error?.message||'تعذر تغيير حالة البنر')}
  }

  async function remove(id){
    const banner=bannerById(id);if(!banner)return;
    if(!confirm(`حذف البنر ${banner.title||''}؟`))return;
    try{
      await window.removeRow('banners',{id});
      await removeStoredImage(banner.image_path);
      if(typeof window.audit==='function')await window.audit('banner',`حذف البنر ${banner.title||''}`);
      await refresh();renderAdmin();notify('تم حذف البنر وصورته');
    }catch(error){alert(error?.message||'تعذر حذف البنر')}
  }

  function renderAdmin(){
    const container=document.getElementById('adminContent');
    if(!container)return;
    const list=rows().slice().sort((a,b)=>(Number(a.sort_order)||0)-(Number(b.sort_order)||0));
    container.innerHTML=`
      <section class="alin-banner-admin">
        <header class="alin-banner-admin__heading"><div><h2>الإعلانات والبنرات</h2><p>البنر المنشور يظهر مباشرة أعلى واجهة المتجر.</p></div><strong>${list.length} بنر</strong></header>
        <input id="alinBannerId" type="hidden">
        <div class="alin-banner-form">
          <label><span>عنوان البنر</span><input id="alinBannerTitle" maxlength="120" placeholder="مثال: عروض العودة إلى المدارس"></label>
          <label><span>نص الإعلان</span><textarea id="alinBannerText" maxlength="500" placeholder="وصف مختصر وواضح"></textarea></label>
          <label><span>رابط عند الضغط — اختياري</span><input id="alinBannerLink" inputmode="url" placeholder="https://..."></label>
          <label class="alin-banner-file"><span>صورة البنر</span><input id="alinBannerFile" type="file" accept="image/png,image/jpeg,image/webp"><small>المقاس المقترح للكمبيوتر 1600 × 500. النص يظهر تلقائيًا أسفل الصورة، وعلى الموبايل تتكيف القطعة دون تشويه الصورة.</small></label>
          <label><span>تاريخ البداية</span><input id="alinBannerStart" type="date"></label>
          <label><span>تاريخ النهاية</span><input id="alinBannerEnd" type="date"></label>
          <label><span>ترتيب الظهور</span><input id="alinBannerSort" type="number" min="0" value="0"></label>
          <div class="alin-banner-form__actions"><button id="alinBannerSave" type="button">إضافة البنر</button><button id="alinBannerClear" class="secondary" type="button">تفريغ الحقول</button></div>
        </div>
        <div class="alin-banner-list">${list.map(banner=>{
          const image=imageUrl(banner);
          return `<article class="alin-banner-row">
            <div class="alin-banner-preview">${image?`<img src="${esc(image)}" alt="${esc(banner.title||'بنر')}">`:'<span>لا توجد صورة</span>'}</div>
            <div class="alin-banner-info"><div><h3>${esc(banner.title||'بدون عنوان')}</h3><em class="${enabled(banner)?'active':'hidden'}">${enabled(banner)?'ظاهر':'مخفي'}</em></div><p>${esc(banner.text||'')}</p><small>${banner.start_date||'بدون بداية'} — ${banner.end_date||'بدون نهاية'} • ترتيب ${Number(banner.sort_order)||0}</small></div>
            <div class="alin-banner-actions"><button type="button" data-banner-action="edit" data-id="${esc(banner.id)}">تعديل</button><button type="button" class="secondary" data-banner-action="toggle" data-id="${esc(banner.id)}">${enabled(banner)?'إخفاء':'إظهار'}</button><button type="button" class="danger" data-banner-action="delete" data-id="${esc(banner.id)}">حذف</button></div>
          </article>`;
        }).join('')||'<div class="alin-banner-empty">لا توجد بنرات مضافة حالياً.</div>'}</div>
      </section>`;
    document.getElementById('alinBannerSave')?.addEventListener('click',save);
    document.getElementById('alinBannerClear')?.addEventListener('click',clearForm);
    container.querySelectorAll('[data-banner-action]').forEach(button=>button.addEventListener('click',()=>{
      const {bannerAction,id}=button.dataset;
      if(bannerAction==='edit')edit(id);
      else if(bannerAction==='toggle')toggle(id);
      else if(bannerAction==='delete')remove(id);
    }));
  }

  function registerAdmin(){
    window.renderAdsAdmin=renderAdmin;
    if(window.AlinAdminModules?.register)window.AlinAdminModules.register('ads',renderAdmin);
  }

  function install(){
    if(state.installed)return;state.installed=true;
    registerAdmin();
    document.addEventListener('alin:store-rendered',()=>setTimeout(renderStorefront,0));
    window.addEventListener('alin:data-mutated',event=>{if(event.detail?.table==='banners')refresh()});
    document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh()});
    refresh();
  }

  window.AlinBanners=Object.freeze({refresh,renderStorefront,renderAdmin});
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
})();
;

/* modules/store/delivery.js */
// === store/delivery.js ===
/* ===== store/js/delivery-gps-v162.js ===== */
/* ALIN v2.1.8: delivery area dropdown + landmark + GPS, without free-text address. */
(function(){
  'use strict';
  const $=(s,r=document)=>r.querySelector(s);
  const $$=(s,r=document)=>Array.from(r.querySelectorAll(s));
  const esc=v=>String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const areas=()=>{const cloud=window.db?.deliveryAreas||window.db?.delivery_areas||[];const source=cloud.length?cloud.map(row=>row?.name):(Array.isArray(window.ALIN_KIRKUK_AREAS)?window.ALIN_KIRKUK_AREAS:[]);return [...new Set(source.map(name=>String(name||'').trim()).filter(Boolean))]};
  const mapUrl=(lat,lng)=>lat&&lng?`https://www.google.com/maps?q=${encodeURIComponent(lat)},${encodeURIComponent(lng)}`:'';

  function areaOptions(selected=''){
    return `<option value="">اختر منطقة التوصيل في كركوك</option>`+areas().map(a=>`<option value="${esc(a)}" ${String(a)===String(selected)?'selected':''}>${esc(a)}</option>`).join('');
  }
  function gpsMarkup(){
    return `<section class="v162-gps-box" id="v162GpsBox">
      <div class="v162-gps-head"><div><b>نقطة موقع التوصيل GPS</b><small>تساعد الإدارة والمندوب على الوصول لنقطة التسليم بدقة.</small></div><span id="v162GpsStatus" class="v162-gps-status">غير محدد</span></div>
      <div class="v162-gps-actions">
        <button type="button" class="v162-gps-primary" data-alin-click="alinV162UseCurrentLocation"><span aria-hidden="true">⌖</span> استخدام موقعي الحالي</button>
        <button type="button" id="v162OpenMapBtn" class="secondary" data-alin-click="alinV162OpenSelectedMap" disabled>فتح الموقع على الخريطة</button>
        <button type="button" id="v162ClearGpsBtn" class="secondary" data-alin-click="alinV162ClearGps" hidden>مسح الموقع</button>
      </div>
      <div id="v162GpsDetails" class="v162-gps-details" hidden></div>
      <input type="hidden" id="deliveryLatitude"><input type="hidden" id="deliveryLongitude"><input type="hidden" id="deliveryLocationUrl"><input type="hidden" id="deliveryLocationAccuracy">
      <p class="v162-gps-note">حدد موقع التوصيل أو اكتب أقرب نقطة دالة، وبعد تأكيد الطلب تتولى الإدارة تعيين المندوب.</p>
    </section>`;
  }
  function enhanceDeliveryFields(){
    const root=$('#checkoutBox'); if(!root)return;
    const fields=$('#deliveryFields',root); if(!fields)return;
    const oldArea=$('#deliveryArea',root);
    if(oldArea && oldArea.tagName!=='SELECT'){
      const select=document.createElement('select');select.id='deliveryArea';select.required=true;select.innerHTML=areaOptions(oldArea.value);
      oldArea.replaceWith(select);
    } else if(oldArea && oldArea.tagName==='SELECT' && oldArea.options.length<2){ oldArea.innerHTML=areaOptions(oldArea.value); }
    const oldAddress=$('#deliveryAddress',root);if(oldAddress)oldAddress.remove();
    const courier=$('#courierSelect',root); if(courier) courier.closest('label')?.remove(),courier.remove();
    if(!$('#v162GpsBox',root)){
      const grid=$('.form-grid',fields);
      if(grid) grid.insertAdjacentHTML('afterend',gpsMarkup()); else fields.insertAdjacentHTML('beforeend',gpsMarkup());
    }
    restoreGpsState();
  }
  const stateKey='alin_v162_checkout_gps';
  function saveGpsState(data){try{sessionStorage.setItem(stateKey,JSON.stringify(data))}catch(_){}}
  function readGpsState(){try{return JSON.parse(sessionStorage.getItem(stateKey)||'null')}catch(_){return null}}
  function restoreGpsState(){const s=readGpsState();if(s?.lat&&s?.lng)setGps(s.lat,s.lng,s.accuracy,false)}
  function setGps(lat,lng,accuracy,store=true){
    const la=$('#deliveryLatitude'),lo=$('#deliveryLongitude'),url=$('#deliveryLocationUrl'),acc=$('#deliveryLocationAccuracy');if(!la||!lo)return;
    la.value=Number(lat).toFixed(7);lo.value=Number(lng).toFixed(7);url.value=mapUrl(la.value,lo.value);if(acc)acc.value=Math.round(Number(accuracy||0));
    const status=$('#v162GpsStatus'),details=$('#v162GpsDetails'),open=$('#v162OpenMapBtn'),clear=$('#v162ClearGpsBtn');
    if(status){status.textContent='تم تحديد الموقع';status.classList.add('is-set')}
    if(details){details.hidden=false;details.innerHTML=`<span>خط العرض: <b>${esc(la.value)}</b></span><span>خط الطول: <b>${esc(lo.value)}</b></span>${accuracy?`<span>الدقة التقريبية: <b>${Math.round(accuracy)} متر</b></span>`:''}`}
    if(open)open.disabled=false;if(clear)clear.hidden=false;if(store)saveGpsState({lat:la.value,lng:lo.value,accuracy:Number(accuracy||0)});
  }
  window.alinV162UseCurrentLocation=function(){
    const status=$('#v162GpsStatus');
    if(!navigator.geolocation){if(status)status.textContent='المتصفح لا يدعم GPS';return}
    if(status){status.textContent='جاري تحديد الموقع...';status.classList.remove('is-set')}
    navigator.geolocation.getCurrentPosition(p=>setGps(p.coords.latitude,p.coords.longitude,p.coords.accuracy),e=>{
      if(status)status.textContent=e.code===1?'لم يتم السماح بالموقع':'تعذر تحديد الموقع';
      if(typeof toast==='function')toast('تعذر تحديد GPS. اكتب أقرب نقطة دالة أو حاول مرة أخرى.');
    },{enableHighAccuracy:true,timeout:15000,maximumAge:30000});
  };
  window.alinV162OpenSelectedMap=function(){const u=$('#deliveryLocationUrl')?.value;if(u)window.open(u,'_blank','noopener')};
  window.alinV162ClearGps=function(){['deliveryLatitude','deliveryLongitude','deliveryLocationUrl','deliveryLocationAccuracy'].forEach(id=>{const e=document.getElementById(id);if(e)e.value=''});try{sessionStorage.removeItem(stateKey)}catch(_){};const st=$('#v162GpsStatus'),dt=$('#v162GpsDetails'),op=$('#v162OpenMapBtn'),cl=$('#v162ClearGpsBtn');if(st){st.textContent='غير محدد';st.classList.remove('is-set')}if(dt)dt.hidden=true;if(op)op.disabled=true;if(cl)cl.hidden=true};

  function installCartHook(){
    document.addEventListener('alin:cart-rendered',()=>setTimeout(enhanceDeliveryFields,0));
    document.addEventListener('alin:fulfillment-changed',()=>setTimeout(enhanceDeliveryFields,0));
    document.addEventListener('change',e=>{if(e.target?.name==='fulfillment')setTimeout(enhanceDeliveryFields,0)});
  }

  function orderMapLink(o){
    const lat=o.delivery_latitude||o.latitude||o.delivery_lat,lng=o.delivery_longitude||o.longitude||o.delivery_lng;
    return o.delivery_location_url||o.location_url||mapUrl(lat,lng);
  }
  function decorateAdminDelivery(){
    const rows=(window.db?.orders||[]).filter(o=>o.fulfillment_type==='home_delivery'||o.delivery_area);
    $$('.v161-delivery-card').forEach((card,i)=>{const o=rows[i];if(!o)return;const url=orderMapLink(o);if(!url||$('.v162-map-link',card))return;const actions=$('.v161-delivery-actions',card)||card;actions.insertAdjacentHTML('afterbegin',`<a class="v162-map-link" href="${esc(url)}" target="_blank" rel="noopener">فتح موقع الطالب GPS</a>`)});
  }
  function decorateCourierOrders(){
    const currentId=window.current?.id;
    const rows=(window.db?.orders||[]).filter(o=>String(o.courier_id||o.delegate_id||'')===String(currentId));
    $$('.v161-courier-orders>article').forEach(card=>{
      const numText=$('small',card)?.textContent||'';const o=rows.find(x=>String(x.order_number||x.id)===numText.trim());if(!o)return;const url=orderMapLink(o);if(!url||$('.v162-map-link',card))return;const target=$('.v161-courier-order-actions',card)||card;target.insertAdjacentHTML('afterbegin',`<a class="v162-map-link" href="${esc(url)}" target="_blank" rel="noopener">فتح موقع الطالب</a>`)});
  }
  function installDashboardHooks(){
    if(typeof window.renderDeliveryOrdersAdmin==='function'){const old=window.renderDeliveryOrdersAdmin;window.renderDeliveryOrdersAdmin=function(){const r=old.apply(this,arguments);setTimeout(decorateAdminDelivery,0);return r}}
    if(typeof window.renderCourierDashboard==='function'){const old=window.renderCourierDashboard;window.renderCourierDashboard=function(){const r=old.apply(this,arguments);setTimeout(decorateCourierOrders,0);return r}}
  }
  function install(){installCartHook();installDashboardHooks();setTimeout(enhanceDeliveryFields,100)}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install);else install();
})();


;
;

/* modules/admin/branding.js */
// === admin/branding.js ===
/* ALIN v2.4.2 — visual identity editor with calm presets and appearance-safe theming. */
(function(){
  'use strict';

  const STORAGE_KEY='alin_visual_identity_v235';
  const LEGACY_STORAGE_KEY='alin_visual_identity_v227';
  const defaults={
    theme:'alin-original',
    primary:'#0b3158',secondary:'#c9a24a',background:'#f6f8fb',card:'#ffffff',
    success:'#2f7d62',warning:'#b98532',danger:'#b44b4b',
    font:'Cairo',radius:18,shadow:'soft',logo:'',logoDark:'',icon:''
  };

  const templates={
    'alin-original':{
      label:'آلين الأصلي',description:'أزرق هادئ مع لمسة ذهبية',
      theme:'alin-original',primary:'#0b3158',secondary:'#c9a24a',background:'#f6f8fb',card:'#ffffff',success:'#2f7d62',warning:'#b98532',danger:'#b44b4b',font:'Cairo',radius:18,shadow:'soft'
    },
    'sky-calm':{
      label:'سماء هادئة',description:'أزرق ضبابي ومريح للعين',
      theme:'sky-calm',primary:'#315d7a',secondary:'#9eb9c9',background:'#f3f7f9',card:'#ffffff',success:'#4e806d',warning:'#b38a4e',danger:'#a95b5b',font:'Tajawal',radius:20,shadow:'soft'
    },
    'sage-calm':{
      label:'مريمي هادئ',description:'أخضر طبيعي بطابع دراسي',
      theme:'sage-calm',primary:'#456b5f',secondary:'#b9a878',background:'#f4f7f3',card:'#ffffff',success:'#3f7b5d',warning:'#a98045',danger:'#a95555',font:'Cairo',radius:20,shadow:'soft'
    },
    'sand-calm':{
      label:'رملي دافئ',description:'ألوان دافئة وخفيفة',
      theme:'sand-calm',primary:'#6f5948',secondary:'#c2a278',background:'#faf7f1',card:'#fffdfa',success:'#5f8067',warning:'#ad7b3c',danger:'#aa5952',font:'Tajawal',radius:18,shadow:'soft'
    },
    'lavender-calm':{
      label:'لافندر هادئ',description:'بنفسجي ناعم بدون إزعاج',
      theme:'lavender-calm',primary:'#5d5d7d',secondary:'#b8afca',background:'#f7f6fa',card:'#ffffff',success:'#5e806e',warning:'#a98652',danger:'#a95b67',font:'Cairo',radius:22,shadow:'soft'
    },
    'rose-calm':{
      label:'وردي ترابي',description:'لون راقٍ ومناسب للهدايا',
      theme:'rose-calm',primary:'#765861',secondary:'#d0aeb5',background:'#faf6f7',card:'#ffffff',success:'#5b7d6b',warning:'#aa8050',danger:'#a64f5a',font:'Tajawal',radius:22,shadow:'soft'
    },
    'graphite-calm':{
      label:'رمادي احترافي',description:'محايد وهادئ للوحات الإدارة',
      theme:'graphite-calm',primary:'#3f4b59',secondary:'#aeb7c0',background:'#f4f6f8',card:'#ffffff',success:'#4d7b69',warning:'#9e7d4e',danger:'#a65353',font:'Cairo',radius:16,shadow:'soft'
    }
  };

  const escv=value=>typeof window.esc==='function'?window.esc(value):String(value??'');
  const t=value=>window.AlinI18n?.t?.(value)||value;
  const settings=()=>window.db?.settings||{};
  const clamp=(value,min,max)=>Math.min(max,Math.max(min,Number(value)||min));
  const normalizeTheme=value=>value==='dark'?'graphite-calm':(templates[value]?value:'custom');
  const readJson=key=>{try{return JSON.parse(localStorage.getItem(key)||'{}')}catch(_){return{}}};
  const stored=()=>({...readJson(LEGACY_STORAGE_KEY),...readJson(STORAGE_KEY)});
  const urlOf=value=>{if(!value)return '';if(/^https?:|^blob:|^data:/i.test(String(value)))return String(value);try{return window.mediaUrl?.(value)||String(value)}catch(_){return String(value)}};
  const validHex=(value,fallback)=>/^#[0-9a-f]{6}$/i.test(String(value||''))?String(value):fallback;
  const hexToRgb=hex=>{const value=validHex(hex,'#000000').slice(1);return [0,2,4].map(index=>parseInt(value.slice(index,index+2),16))};
  const rgbToHex=rgb=>'#'+rgb.map(value=>Math.round(clamp(value,0,255)).toString(16).padStart(2,'0')).join('');
  const mix=(a,b,weight=.5)=>{const first=hexToRgb(a),second=hexToRgb(b);return rgbToHex(first.map((value,index)=>value+(second[index]-value)*weight))};
  const shadowValue=name=>name==='none'?'none':name==='medium'?'0 14px 34px rgba(7,26,55,.12)':'0 8px 24px rgba(7,26,55,.075)';

  function normalizeIdentity(identity={}){
    return {
      ...defaults,...identity,
      theme:normalizeTheme(identity.theme||defaults.theme),
      primary:validHex(identity.primary,defaults.primary),secondary:validHex(identity.secondary,defaults.secondary),
      background:validHex(identity.background,defaults.background),card:validHex(identity.card,defaults.card),
      success:validHex(identity.success,defaults.success),warning:validHex(identity.warning,defaults.warning),danger:validHex(identity.danger,defaults.danger),
      font:['Cairo','Tajawal','Arial'].includes(identity.font)?identity.font:defaults.font,
      radius:clamp(identity.radius,8,28),shadow:['none','soft','medium'].includes(identity.shadow)?identity.shadow:defaults.shadow,
      logo:String(identity.logo||''),logoDark:String(identity.logoDark||''),icon:String(identity.icon||'')
    };
  }

  function current(){
    const s=settings(),local=stored();
    return normalizeIdentity({
      ...local,
      theme:s.visual_theme||local.theme||defaults.theme,
      primary:s.visual_primary||local.primary||defaults.primary,
      secondary:s.visual_secondary||local.secondary||defaults.secondary,
      background:s.visual_background||local.background||defaults.background,
      card:s.visual_card||local.card||defaults.card,
      success:s.visual_success||local.success||defaults.success,
      warning:s.visual_warning||local.warning||defaults.warning,
      danger:s.visual_danger||local.danger||defaults.danger,
      font:s.visual_font||local.font||defaults.font,
      radius:s.visual_radius||local.radius||defaults.radius,
      shadow:s.visual_shadow||local.shadow||defaults.shadow,
      logo:s.platform_logo_path||s.platform_logo_url||local.logo||'',
      logoDark:s.platform_logo_dark_path||local.logoDark||'',
      icon:s.platform_icon_path||s.platform_icon_url||local.icon||''
    });
  }

  function setLogo(node,url,fallback='آ'){
    if(!node)return;
    if(url)node.innerHTML=`<img class="logo-img" src="${escv(url)}" alt="${escv(t('شعار منصة آلين'))}">`;
    else node.textContent=fallback;
  }

  function applyPalette(identity){
    const root=document.documentElement,style=root.style;
    const dark=root.dataset.alinTheme==='dark';
    const darkBg=mix(identity.primary,'#000000',.72);
    const darkSurface=mix(identity.primary,'#000000',.58);
    const darkSoft=mix(identity.primary,'#000000',.45);
    const border=dark?mix(identity.primary,'#ffffff',.22):mix(identity.primary,'#ffffff',.82);
    style.setProperty('--alin-primary',identity.primary);
    style.setProperty('--alin-primary-2',mix(identity.primary,'#ffffff',.12));
    style.setProperty('--alin-primary-3',mix(identity.primary,'#000000',.12));
    style.setProperty('--alin-gold',identity.secondary);
    style.setProperty('--alin-gold-2',mix(identity.secondary,'#ffffff',.14));
    style.setProperty('--alin-bg',dark?darkBg:identity.background);
    style.setProperty('--alin-surface',dark?darkSurface:identity.card);
    style.setProperty('--alin-surface-2',dark?darkSoft:mix(identity.card,identity.background,.45));
    style.setProperty('--alin-success',identity.success);
    style.setProperty('--alin-warning',identity.warning);
    style.setProperty('--alin-danger',identity.danger);
    style.setProperty('--alin-radius-lg',`${identity.radius}px`);
    style.setProperty('--alin-radius-md',`${Math.max(10,identity.radius-4)}px`);
    style.setProperty('--alin-shadow-md',shadowValue(identity.shadow));
    style.setProperty('--ao-ink',dark?'#f3f6f8':identity.primary);
    style.setProperty('--ao-gold',identity.secondary);
    style.setProperty('--ao-bg',dark?darkBg:identity.background);
    style.setProperty('--ao-surface',dark?darkSurface:identity.card);
    style.setProperty('--ao-soft',dark?darkSoft:mix(identity.background,identity.card,.5));
    style.setProperty('--ao-border',border);
    style.setProperty('--ao-muted',dark?'#b8c3cc':mix(identity.primary,'#ffffff',.42));
    style.setProperty('--ao-shadow',dark?'0 28px 80px rgba(0,0,0,.48)':shadowValue(identity.shadow));
  }

  function applyTheme(identity=current()){
    identity=normalizeIdentity(identity);
    applyPalette(identity);
    if(document.body)document.body.style.fontFamily=`"${identity.font}",Tahoma,"Segoe UI",sans-serif`;
    // Brand preset and light/dark appearance are separate. Never overwrite data-alin-theme here.
    document.documentElement.dataset.alinBrandTheme=identity.theme||'custom';
    const name=settings().platform_name||'منصة آلين';
    const useDarkLogo=document.documentElement.dataset.alinTheme==='dark'&&identity.logoDark;
    const logo=urlOf(useDarkLogo||identity.logo),icon=urlOf(identity.icon);
    document.title=name;
    document.querySelectorAll('.brand b').forEach(node=>node.textContent=name.replace('منصة ',''));
    document.querySelectorAll('.login-card .logo').forEach(node=>setLogo(node,logo,'آ'));
    document.querySelectorAll('.topbar .logo.small').forEach(node=>setLogo(node,icon||logo,'آ'));
    document.querySelectorAll('.alin98-logo').forEach(node=>setLogo(node,logo||icon,'آ'));
    if(icon)document.querySelectorAll('link[rel="icon"],link[rel="apple-touch-icon"]').forEach(link=>link.href=icon);
    const theme=document.querySelector('meta[name="theme-color"]');if(theme)theme.content=identity.primary;
    window.dispatchEvent(new CustomEvent('alin:brand-applied',{detail:{identity}}));
    return identity;
  }
  function applyBrand(){return applyTheme(current())}

  async function uploadBrandFile(file,kind){
    if(!file)return '';
    const allowed=kind==='icon'?['image/png','image/jpeg','image/webp']:['image/png','image/jpeg','image/webp','image/svg+xml'];
    if(!allowed.includes(file.type))throw new Error('صيغة الصورة غير مدعومة');
    if(file.size>3*1024*1024)throw new Error('حجم الصورة يجب أن يكون أقل من 3MB');
    if(typeof window.uploadFile!=='function')throw new Error('خدمة رفع الصور غير متاحة');
    return window.uploadFile(`brand/${kind}`,file,{required:true,type:'image',maxBytes:3*1024*1024});
  }

  async function saveIdentity(identity){
    identity=normalizeIdentity(identity);
    if(typeof window.settingsSet!=='function')throw new Error('خدمة الإعدادات غير جاهزة');
    const map={
      visual_theme:identity.theme,visual_primary:identity.primary,visual_secondary:identity.secondary,
      visual_background:identity.background,visual_card:identity.card,visual_success:identity.success,
      visual_warning:identity.warning,visual_danger:identity.danger,visual_font:identity.font,
      visual_radius:identity.radius,visual_shadow:identity.shadow,platform_logo_path:identity.logo||'',
      platform_logo_dark_path:identity.logoDark||'',platform_icon_path:identity.icon||''
    };
    for(const [key,value] of Object.entries(map))await window.settingsSet(key,value);
    localStorage.setItem(STORAGE_KEY,JSON.stringify(identity));
    localStorage.removeItem(LEGACY_STORAGE_KEY);
    applyTheme(identity);
    window.dispatchEvent(new CustomEvent('alin:settings-updated',{detail:{keys:Object.keys(map)}}));
    if(typeof window.audit==='function')await window.audit('brand','تحديث الهوية البصرية للمنصة');
    return identity;
  }

  function imageMarkup(value,label){return value?`<img src="${escv(urlOf(value))}" alt="${escv(label)}">`:'<span aria-hidden="true">آ</span>'}
  function previewFile(box,file){
    if(!box||!file)return '';
    if(box.dataset.previewUrl)URL.revokeObjectURL(box.dataset.previewUrl);
    const url=URL.createObjectURL(file);box.dataset.previewUrl=url;box.innerHTML=`<img src="${url}" alt="${escv(t('معاينة'))}">`;return url;
  }

  function render(root=document.getElementById('adminContent')){
    if(!root)return;
    const base=current();let draft={...base};let busy=false;
    root.className='panel admin-brand-v235';
    const templateMarkup=Object.entries(templates).map(([key,preset])=>`
      <button type="button" class="ab235-template ${draft.theme===key?'active':''}" data-theme="${key}" aria-pressed="${draft.theme===key}">
        <span class="ab235-template-preview" style="--p:${preset.primary};--s:${preset.secondary};--b:${preset.background};--c:${preset.card}">
          <i></i><i></i><i></i><i></i>
        </span>
        <span><b>${escv(preset.label)}</b><small>${escv(preset.description)}</small></span>
        <em>${draft.theme===key?'مختار':'اختيار'}</em>
      </button>`).join('');

    root.innerHTML=`
      <header class="ab235-head">
        <div><span class="ab235-eyebrow">إعدادات المظهر</span><h2>الهوية البصرية</h2><p>غيّر هوية المنصة بأمان. القالب لا يغيّر الوضع النهاري أو الليلي.</p></div>
        <span class="ab235-version">v${esc(window.ALIN_CONFIG?.version||'4.2.0')}</span>
      </header>
      <div class="ab235-layout">
        <main class="ab235-main">
          <section class="ab235-card">
            <div class="ab235-section-head"><div><h3>قوالب جاهزة هادئة</h3><p>اختر قالبًا ثم شاهد المعاينة قبل الحفظ.</p></div><span>${Object.keys(templates).length} قوالب</span></div>
            <div class="ab235-templates">${templateMarkup}</div>
          </section>

          <section class="ab235-card">
            <div class="ab235-section-head"><div><h3>الشعار والأيقونة</h3><p>PNG أو WebP أو JPG، والشعار يقبل SVG أيضًا. الحد الأعلى 3MB.</p></div></div>
            <div class="ab235-uploads">
              <article class="ab235-upload"><div id="ab235LogoPreview" class="ab235-upload-preview">${imageMarkup(draft.logo,'الشعار الأساسي')}</div><div><b>الشعار الأساسي</b><small>يظهر في الوضع النهاري وتسجيل الدخول.</small><label class="ab235-file">اختيار صورة<input id="ab235Logo" type="file" accept="image/png,image/jpeg,image/webp,image/svg+xml"></label><button type="button" class="ab235-clear" data-clear="logo">إزالة</button></div></article>
              <article class="ab235-upload"><div id="ab235DarkLogoPreview" class="ab235-upload-preview">${imageMarkup(draft.logoDark,'شعار الوضع الليلي')}</div><div><b>شعار الوضع الليلي</b><small>اختياري، ويُستخدم فقط عند تفعيل الوضع الليلي.</small><label class="ab235-file">اختيار صورة<input id="ab235DarkLogo" type="file" accept="image/png,image/jpeg,image/webp,image/svg+xml"></label><button type="button" class="ab235-clear" data-clear="logoDark">إزالة</button></div></article>
              <article class="ab235-upload"><div id="ab235IconPreview" class="ab235-upload-preview icon">${imageMarkup(draft.icon,'أيقونة التطبيق')}</div><div><b>أيقونة التطبيق</b><small>يفضل ملف مربع بدقة 512×512.</small><label class="ab235-file">اختيار صورة<input id="ab235Icon" type="file" accept="image/png,image/jpeg,image/webp"></label><button type="button" class="ab235-clear" data-clear="icon">إزالة</button></div></article>
            </div>
          </section>

          <section class="ab235-card">
            <div class="ab235-section-head"><div><h3>تخصيص الألوان</h3><p>يمكن تعديل أي قالب يدويًا قبل الحفظ.</p></div></div>
            <div class="ab235-colors">${[
              ['primary','اللون الأساسي'],['secondary','اللون الثانوي'],['background','الخلفية'],['card','البطاقات'],['success','النجاح'],['warning','التنبيه'],['danger','الخطر']
            ].map(([key,label])=>`<label><span>${label}</span><span class="ab235-color"><input type="color" data-color="${key}" value="${escv(draft[key])}"><output data-output="${key}">${escv(draft[key].toUpperCase())}</output></span></label>`).join('')}</div>
            <div class="ab235-controls">
              <label><span>الخط</span><select id="ab235Font"><option value="Cairo" ${draft.font==='Cairo'?'selected':''}>Cairo</option><option value="Tajawal" ${draft.font==='Tajawal'?'selected':''}>Tajawal</option><option value="Arial" ${draft.font==='Arial'?'selected':''}>Arial</option></select></label>
              <label><span>استدارة البطاقات</span><div class="ab235-range"><input id="ab235Radius" type="range" min="8" max="28" value="${draft.radius}"><output>${draft.radius}px</output></div></label>
              <label><span>الظل</span><select id="ab235Shadow"><option value="none" ${draft.shadow==='none'?'selected':''}>بدون</option><option value="soft" ${draft.shadow==='soft'?'selected':''}>خفيف</option><option value="medium" ${draft.shadow==='medium'?'selected':''}>متوسط</option></select></label>
            </div>
          </section>

          <div class="ab235-actions">
            <button type="button" id="ab235Reset" class="secondary">استعادة هوية آلين</button>
            <button type="button" id="ab235Save" class="primary">حفظ وتطبيق الهوية</button>
          </div>
          <div id="ab235Status" class="ab235-status" role="status" aria-live="polite"></div>
        </main>

        <aside class="ab235-preview-wrap">
          <section class="ab235-card ab235-sticky"><div class="ab235-section-head"><div><h3>معاينة مباشرة</h3><p>هذه المعاينة لا تغيّر المنصة إلا بعد الحفظ.</p></div></div>
            <div id="ab235Preview" class="ab235-preview">
              <div class="ab235-preview-top"><div class="ab235-preview-brand"><span id="ab235PreviewLogo" class="ab235-preview-logo">${imageMarkup(draft.logo,'شعار منصة آلين')}</span><div><b>منصة آلين</b><small>للملازم والقرطاسية والهدايا</small></div></div><span class="ab235-preview-bell">◌</span></div>
              <div class="ab235-preview-body"><div class="ab235-preview-hero"><small>كل ما يحتاجه الطالب</small><h4>دراسة أسهل بتصميم هادئ</h4><p>ملازم وقرطاسية وهدايا في مكان واحد.</p><button type="button">تصفح المتجر</button></div><div class="ab235-preview-cards"><article><span>الملازم</span><b>24</b></article><article><span>الطلبات</span><b>12</b></article><article><span>المكتبات</span><b>6</b></article></div></div>
            </div>
            <div class="ab235-note">الوضع النهاري والليلي يبقيان مستقلين عن القالب المختار.</div>
          </section>
        </aside>
      </div>`;

    const preview=root.querySelector('#ab235Preview');
    const status=root.querySelector('#ab235Status');
    const saveButton=root.querySelector('#ab235Save');
    const logoInput=root.querySelector('#ab235Logo');
    const darkLogoInput=root.querySelector('#ab235DarkLogo');
    const iconInput=root.querySelector('#ab235Icon');

    const sync=()=>{
      if(!preview)return;
      preview.style.setProperty('--ab-primary',draft.primary);preview.style.setProperty('--ab-secondary',draft.secondary);
      preview.style.setProperty('--ab-bg',draft.background);preview.style.setProperty('--ab-card',draft.card);
      preview.style.setProperty('--ab-font',`"${draft.font}",Tahoma,sans-serif`);preview.style.setProperty('--ab-radius',`${draft.radius}px`);
      preview.style.setProperty('--ab-shadow',shadowValue(draft.shadow));
      root.querySelector('#ab235PreviewLogo').innerHTML=imageMarkup(draft.logo,'شعار منصة آلين');
      root.querySelectorAll('.ab235-template').forEach(button=>{
        const active=button.dataset.theme===draft.theme;button.classList.toggle('active',active);button.setAttribute('aria-pressed',String(active));
        const label=button.querySelector('em');if(label)label.textContent=active?'مختار':'اختيار';
      });
      root.querySelectorAll('[data-color]').forEach(input=>{if(input.value.toLowerCase()!==draft[input.dataset.color].toLowerCase())input.value=draft[input.dataset.color]});
      root.querySelectorAll('[data-output]').forEach(output=>output.textContent=String(draft[output.dataset.output]).toUpperCase());
      root.querySelector('#ab235Font').value=draft.font;root.querySelector('#ab235Shadow').value=draft.shadow;
      const radius=root.querySelector('#ab235Radius');radius.value=draft.radius;radius.nextElementSibling.textContent=`${draft.radius}px`;
    };

    root.querySelectorAll('.ab235-template').forEach(button=>button.addEventListener('click',()=>{
      const preset=templates[button.dataset.theme];if(!preset)return;draft=normalizeIdentity({...draft,...preset});sync();
    }));
    root.querySelectorAll('[data-color]').forEach(input=>input.addEventListener('input',()=>{draft[input.dataset.color]=input.value;draft.theme='custom';sync()}));
    root.querySelector('#ab235Font').addEventListener('change',event=>{draft.font=event.target.value;draft.theme='custom';sync()});
    root.querySelector('#ab235Shadow').addEventListener('change',event=>{draft.shadow=event.target.value;draft.theme='custom';sync()});
    root.querySelector('#ab235Radius').addEventListener('input',event=>{draft.radius=Number(event.target.value);draft.theme='custom';sync()});

    logoInput.addEventListener('change',()=>{if(logoInput.files[0]){draft.logo=previewFile(root.querySelector('#ab235LogoPreview'),logoInput.files[0]);sync()}});
    darkLogoInput.addEventListener('change',()=>{if(darkLogoInput.files[0]){draft.logoDark=previewFile(root.querySelector('#ab235DarkLogoPreview'),darkLogoInput.files[0])}});
    iconInput.addEventListener('change',()=>{if(iconInput.files[0]){draft.icon=previewFile(root.querySelector('#ab235IconPreview'),iconInput.files[0])}});
    root.querySelectorAll('[data-clear]').forEach(button=>button.addEventListener('click',()=>{
      const key=button.dataset.clear;draft[key]='';const map={logo:['#ab235LogoPreview',logoInput],logoDark:['#ab235DarkLogoPreview',darkLogoInput],icon:['#ab235IconPreview',iconInput]};
      const [selector,input]=map[key];input.value='';root.querySelector(selector).innerHTML='<span aria-hidden="true">آ</span>';sync();
    }));

    root.querySelector('#ab235Reset').addEventListener('click',async()=>{
      if(busy||!confirm('استعادة هوية آلين الافتراضية؟'))return;busy=true;saveButton.disabled=true;status.className='ab235-status';status.textContent='جارٍ استعادة الهوية...';
      try{await saveIdentity({...defaults});status.className='ab235-status ok';status.textContent='تمت استعادة هوية آلين الافتراضية';window.toast?.('تمت استعادة الهوية');render(root)}
      catch(error){status.className='ab235-status err';status.textContent=error.message||'تعذر الاستعادة'}finally{busy=false;saveButton.disabled=false}
    });

    saveButton.addEventListener('click',async()=>{
      if(busy)return;busy=true;saveButton.disabled=true;status.className='ab235-status';status.textContent='جارٍ رفع الصور وحفظ الهوية...';
      try{
        if(logoInput.files[0])draft.logo=await uploadBrandFile(logoInput.files[0],'logo');
        if(darkLogoInput.files[0])draft.logoDark=await uploadBrandFile(darkLogoInput.files[0],'logo-dark');
        if(iconInput.files[0])draft.icon=await uploadBrandFile(iconInput.files[0],'icon');
        draft=await saveIdentity(draft);status.className='ab235-status ok';status.textContent='تم حفظ وتطبيق الهوية على جميع صفحات المنصة';window.toast?.('تم تطبيق الهوية البصرية');sync();
      }catch(error){status.className='ab235-status err';status.textContent=error.message||'تعذر حفظ الهوية'}finally{busy=false;saveButton.disabled=false}
    });
    sync();
  }

  Object.assign(window,{applyBrand,applyBrandV28:applyBrand,uploadBrandFile,saveBrandIdentity:saveIdentity,resetBrandIdentity:()=>saveIdentity({...defaults})});
  function install(){applyBrand();window.AlinAdminModules?.register?.('brandIdentity',render)}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
  window.addEventListener('alin:data-refreshed',applyBrand);
  window.addEventListener('alin:settings-updated',applyBrand);
  window.addEventListener('alin:theme-changed',applyBrand);
  window.AlinBrand=Object.freeze({current,apply:applyBrand,render,save:saveIdentity,upload:uploadBrandFile,templates:Object.freeze({...templates})});
})();

;
;

/* modules/core/supabase-ui.js */
// === core/supabase-ui.js ===
/* ALIN v2.4.2 — read-only UI binding for the authoritative Supabase service.
   Data access is owned only by modules/core/supabase.js.
   File storage is owned only by modules/core/storage.js.
*/
(function(){
  'use strict';

  const VERSION='2.4.2';
  let lastRefresh=null;
  let lastMutation=null;

  function setRootState(state){
    const root=document.documentElement;
    if(!root?.dataset)return;
    root.dataset.alinDataState=state;
    root.dataset.alinDataVersion=VERSION;
  }
  function onRefresh(event){
    lastRefresh={...(event?.detail||{}),received_at:new Date().toISOString()};
    setRootState(lastRefresh.errors?.length?'partial':'ready');
  }
  function onMutation(event){
    lastMutation={...(event?.detail||{}),received_at:new Date().toISOString()};
    setRootState('updating');
  }
  async function refresh(options={}){
    if(!window.AlinRepository?.refresh)throw new Error('خدمة البيانات غير جاهزة');
    return window.AlinRepository.refresh(options);
  }
  function status(){
    return Object.freeze({version:VERSION,lastRefresh,lastMutation,connected:!!window.AlinRepository?.online?.()});
  }

  window.addEventListener('alin:data-refreshed',onRefresh);
  window.addEventListener('alin:cloud-mutation',onMutation);
  window.AlinRepositoryUI=Object.freeze({version:VERSION,refresh,status});
  setRootState(window.AlinRepository?.online?.()?'loading':'offline');
})();

;
;

/* modules/core/cloud-status.js */
// === core/cloud-status.js ===
/* ===== core/js/cloud-status-ui-rc5-3.js ===== */
(function(){
  function mount(){
    if(document.getElementById('alinCloudRc53'))return;
    const el=document.createElement('div');el.id='alinCloudRc53';el.className='alin-cloud-rc53';el.dataset.status=navigator.onLine?'loading':'offline';el.textContent=navigator.onLine?'جاري ربط البيانات':'غير متصل';document.body.appendChild(el);
    const set=(s,t)=>{el.dataset.status=s;el.textContent=t};
    window.addEventListener('alin:cloud-status',e=>{const s=e.detail?.status||'loading';const map={online:'متصل ومزامن',realtime:'تحديث مباشر',loading:'جاري تحميل البيانات',syncing:'جاري المزامنة',offline:'غير متصل',error:'خطأ في الربط','offline-queued':'محفوظ للمزامنة'};set(s,map[s]||'حالة الاتصال: '+s)});
    window.addEventListener('alin:data-refreshed',e=>set(e.detail?.errors?.length?'error':'online',e.detail?.errors?.length?'اتصال جزئي':'متصل ومزامن'));
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount,{once:true});else mount();
})();
;

/* modules/core/auth-service.js */
/* ALIN v4.2.0 RC3 — secure Edge login with authoritative server-side attempt protection. */
(function(){
  'use strict';
  const cfg=()=>window.ALIN_CONFIG||{};
  const enabled=()=>cfg().authEnabled===true;
  const client=()=>window.sb||(window.AlinCloud&&window.AlinCloud.client?.())||null;
  const emailFor=value=>{
    const raw=String(value||'').trim().toLocaleLowerCase('en-US').replace(/\s+/g,'-');
    if(raw.includes('@'))return raw;
    const ascii=raw.replace(/[^a-z0-9._-]/g,'-').replace(/-+/g,'-').replace(/^-|-$/g,'')||'user';
    let hash=2166136261;for(const byte of new TextEncoder().encode(raw))hash=Math.imul(hash^byte,16777619);
    const key=`${ascii.slice(0,38)}-${(hash>>>0).toString(36)}`;
    return `${key}@${cfg().authEmailDomain||'users.alin.local'}`;
  };
  const msg=text=>{const el=window.loginMsg||document.getElementById('loginMsg');if(el)el.textContent=text};
  const DEVICE_KEY='alin_device_id_v3';
  function deviceId(){
    try{let value=localStorage.getItem(DEVICE_KEY);if(!value){value=crypto.randomUUID?.()||`${Date.now()}-${Math.random()}`;localStorage.setItem(DEVICE_KEY,value)}return value}
    catch(_){return 'browser-session'}
  }
  async function edgeErrorInfo(error){
    let message=String(error?.message||'');
    let status=Number(error?.context?.status||0);
    try{
      const payload=await error?.context?.clone?.().json?.();
      if(payload?.error)message=String(payload.error);
    }catch(_){}
    return {message,status};
  }
  async function secureSignIn(username,password){
    const c=client();
    if(!c?.functions||!c?.auth)throw new Error('خدمة تسجيل الدخول الآمنة غير متاحة');
    const {data,error}=await c.functions.invoke('secure-login',{
      body:{username:String(username||'').trim(),password:String(password||'')}
    });
    if(error){
      const info=await edgeErrorInfo(error);
      throw new Error(info.message||'تعذر تسجيل الدخول حالياً');
    }
    if(!data?.ok||!data?.session?.access_token||!data?.session?.refresh_token||!data?.user?.id){
      throw new Error(data?.error||'تعذر تسجيل الدخول حالياً');
    }
    const sessionResult=await c.auth.setSession({
      access_token:String(data.session.access_token),
      refresh_token:String(data.session.refresh_token)
    });
    if(sessionResult?.error||!sessionResult?.data?.session||!sessionResult?.data?.user){
      try{await c.auth.signOut()}catch(_){}
      throw new Error('تعذر تثبيت جلسة الدخول الآمنة');
    }
    if(String(sessionResult.data.user.id)!==String(data.user.id)){
      try{await c.auth.signOut()}catch(_){}
      throw new Error('تعذر التحقق من جلسة الدخول');
    }
    return sessionResult.data;
  }
  const invokeError=async(error,fallback)=>{let message=error?.message||fallback;try{message=(await error?.context?.json())?.error||message}catch(_){}return new Error(message||fallback)};
  const friendlyAdminMessage=value=>{const text=String(value||'');if(/already (?:been )?registered|already exists|email.*registered/i.test(text))return 'الحساب موجود مسبقاً وسيتم ربطه بدلاً من إنشائه من جديد';if(/duplicate key.*username|اسم الدخول مستخدم/i.test(text))return 'اسم الدخول مستخدم مسبقاً';return text};
  const invalidSessionMessage=value=>/جلسة الدخول غير صالحة|انتهت جلسة|invalid(?:\s+)?jwt|jwt(?:\s+)?expired|session|user from sub claim/i.test(String(value||''));
  async function adminSession(forceRefresh=false){
    const c=client();if(!c?.auth)throw new Error('خدمة تسجيل الدخول غير متاحة');
    let response=forceRefresh?await c.auth.refreshSession():await c.auth.getSession();
    let session=response?.data?.session||null;
    if(!session&&!forceRefresh){response=await c.auth.refreshSession();session=response?.data?.session||null}
    if(!session?.access_token)throw new Error('انتهت جلسة المدير. سجل الخروج ثم ادخل مرة ثانية');
    const check=await c.auth.getUser(session.access_token);
    if(check?.error||!check?.data?.user){
      if(!forceRefresh)return adminSession(true);
      throw new Error('انتهت جلسة المدير. سجل الخروج ثم ادخل مرة ثانية');
    }
    return session;
  }
  async function invokeAdmin(name,body){
    const c=client();if(!c?.functions)throw new Error('خدمة الإدارة الآمنة غير متاحة');
    let lastError=null;
    for(let attempt=0;attempt<2;attempt++){
      const session=await adminSession(attempt===1);
      const {data,error}=await c.functions.invoke(name,{body,headers:{Authorization:`Bearer ${session.access_token}`}});
      if(error){lastError=await invokeError(error,'تعذر تنفيذ العملية');lastError=new Error(friendlyAdminMessage(lastError.message));if(attempt===0&&invalidSessionMessage(lastError.message))continue;throw lastError}
      if(!data?.ok){lastError=new Error(friendlyAdminMessage(data?.error||'تعذر تنفيذ العملية'));if(attempt===0&&invalidSessionMessage(lastError.message))continue;throw lastError}
      return data;
    }
    throw lastError||new Error('تعذر تنفيذ العملية');
  }

  async function accountForUser(user){
    const c=client();if(!c||!user)return null;
    const {data,error}=await c.from('accounts').select('id,role,name,username,status,auth_user_id,area,phone,landmark,admin_level,deleted_at').eq('auth_user_id',user.id).maybeSingle();
    if(error)throw error;
    return data||null;
  }

  async function login(){
    const c=client();if(!c)throw new Error('خدمة تسجيل الدخول غير متاحة');
    const username=(window.loginU||document.getElementById('loginU'))?.value||'';
    const password=(window.loginPass||document.getElementById('loginPass'))?.value||'';
    const requested=String(window.pendingRole||'');
    if(!username.trim()||!password)throw new Error('اكتب اسم الدخول وكلمة المرور');
    let data;
    try{data=await secureSignIn(username,password)}catch(error){throw new Error(error?.message||'تعذر تسجيل الدخول')}
    const account=await accountForUser(data.user);
    if(!account||account.status!=='active'){
      await c.auth.signOut();throw new Error('الحساب غير مربوط أو غير فعال');
    }
    const accountRole=String(account.role||'').toLowerCase()==='delegate'?'courier':String(account.role||'').toLowerCase();
    if(requested&&requested!=='store'&&accountRole!==requested&&accountRole!=='admin'){
      await c.auth.signOut();throw new Error('نوع الحساب لا يطابق البوابة المختارة');
    }
    window.current={role:accountRole,id:account.id,name:account.name,username:account.username,auth_user_id:data.user.id,area:account.area||'',phone:account.phone||'',landmark:account.landmark||'',admin_level:account.admin_level||'operator'};
    try{await ensureRoleRuntime(accountRole)}catch(error){
      window.current=null;try{await c.auth.signOut()}catch(_){ }
      throw error;
    }
    if(typeof window.load==='function')await window.load();
    const targetPage=accountRole==='accountant'?'admin':accountRole;
    if(typeof window.openPage==='function')window.openPage(targetPage,{render:false});
    const passEl=window.loginPass||document.getElementById('loginPass');if(passEl)passEl.value='';
    window.dispatchEvent(new CustomEvent('alin:auth-login',{detail:{account}}));
    return account;
  }


  let restorePromise=null,logoutPromise=null,explicitSignOut=false;
  function finishAuthBoot(){
    try{document.documentElement?.removeAttribute?.('data-alin-auth-boot')}catch(_){}
  }
  function showSignedOut(){
    if(window.current)return;
    if(window.ALINNavigation?.showSignedOut)return window.ALINNavigation.showSignedOut();
    document.getElementById('app')?.classList.add('hidden');
    document.getElementById('login')?.classList.remove('hidden');
  }
  function accountState(account,user){
    return {role:String(account.role||'').toLowerCase()==='delegate'?'courier':String(account.role||'').toLowerCase(),id:account.id,name:account.name,username:account.username,auth_user_id:user.id,area:account.area||'',phone:account.phone||'',landmark:account.landmark||'',admin_level:account.admin_level||'operator'};
  }
  async function ensureRoleRuntime(role){
    const normalized=String(role||'').toLowerCase();
    if(!normalized||normalized==='store'||normalized==='student')return false;
    if(!window.AlinRoleRuntime?.ensure)throw new Error('محمل لوحة الحساب غير متوفر');
    return window.AlinRoleRuntime.ensure(normalized);
  }
  async function openPublicStore(){
    try{window.AlinCloud?.loadCachedSnapshot?.()}catch(_){}
    if(typeof window.openPage==='function')window.openPage('store',{render:true});
    finishAuthBoot();
    try{if(typeof window.load==='function')await window.load({reason:'public-boot'})}catch(error){console.warn('[ALIN public data refresh]',error)}
    return false;
  }
  async function restoreSession(){
    if(!enabled()){if(typeof window.openPage==='function')window.openPage('store');finishAuthBoot();return false}
    if(restorePromise)return restorePromise;
    restorePromise=(async()=>{
      const c=client();
      if(!c?.auth)return openPublicStore();
      const response=await c.auth.getSession();
      const session=response?.data?.session||null;
      if(response?.error||!session?.user)return openPublicStore();
      const account=await accountForUser(session.user);
      if(!account||account.status!=='active'){
        explicitSignOut=true;
        try{await c.auth.signOut()}catch(_){}
        explicitSignOut=false;
        window.current=null;showSignedOut();finishAuthBoot();return false;
      }
      window.current=accountState(account,session.user);
      try{window.AlinCloud?.loadCachedSnapshot?.()}catch(_){}
      try{await ensureRoleRuntime(window.current.role)}catch(error){
        console.warn('[ALIN role runtime]',error);window.current=null;return openPublicStore();
      }
      const target=account.role==='accountant'?'admin':account.role;
      if(typeof window.openPage==='function')window.openPage(target,{render:true});
      finishAuthBoot();
      try{if(typeof window.load==='function')await window.load({reason:'session-boot'})}catch(error){console.warn('[ALIN session data refresh]',error)}
      if(typeof window.openPage==='function')window.openPage(target,{render:false});
      if(account.role==='library')window.AlinLibraryModules?.showLibraryPage?.();
      window.dispatchEvent(new CustomEvent('alin:auth-restored',{detail:{account}}));
      return true;
    })().catch(error=>{
      console.error('[ALIN auth restore]',error);
      window.current=null;showSignedOut();finishAuthBoot();return false;
    }).finally(()=>{restorePromise=null});
    return restorePromise;
  }

  async function loginFromUI(){
    try{msg('جارٍ التحقق...');const account=await login();msg('');return account}
    catch(error){msg(error?.message||'تعذر تسجيل الدخول');throw error}
    finally{finishAuthBoot()}
  }
  async function signOut(){
    if(logoutPromise)return logoutPromise;
    logoutPromise=(async()=>{
      explicitSignOut=true;
      try{await client()?.auth?.signOut()}finally{explicitSignOut=false}
      try{window.AlinCloud?.clearPrivateCache?.()}catch(_){}
      finishAuthBoot();
      return true;
    })().finally(()=>{logoutPromise=null});
    return logoutPromise;
  }
  function install(){
    if(!enabled()){window.ALIN_AUTH_MODE='disabled';finishAuthBoot();return}
    window.ALIN_AUTH_MODE='supabase';
    if(typeof window.ALINAuth?.createAccountFromAdmin==='function')window.addAccount=window.ALINAuth.createAccountFromAdmin;
    client()?.auth?.onAuthStateChange?.((event)=>{
      if(event==='SIGNED_OUT'&&!explicitSignOut){window.current=null;showSignedOut();finishAuthBoot();window.dispatchEvent(new CustomEvent('alin:logout',{detail:{source:'external'}}))}
    });
    restoreSession();
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();

  window.ALINAuthRuntime=Object.freeze({client,invokeAdmin,adminSession,finishAuthBoot,showSignedOut,deviceId,secureSignIn});
  window.ALINAuth=Object.assign(window.ALINAuth||{},{
    enabled,emailFor,login,loginFromUI,signOut,restoreSession,accountForUser,
    ensureAdminSession:()=>adminSession(false)
  });
})();
;

/* modules/core/checkout-service.js */
// === core/checkout-service.js ===
/* ALIN v2.7.0 Stage 4 — guarded checkout, idempotency and device rate limits. */
(function(){
  'use strict';
  const client=()=>window.ALINAuthRuntime?.client?.()||window.sb||window.AlinCloud?.client?.()||null;
  function normalizeCheckoutItems(lines){
    const booklets=Array.isArray(window.db?.booklets)?window.db.booklets:[];
    const products=Array.isArray(window.db?.products)?window.db.products:[];
    const same=(a,b)=>String(a??'')===String(b??'');
    const findBooklet=id=>booklets.find(x=>same(x.id,id))||null;
    const findProduct=id=>products.find(x=>same(x.id,id))||null;
    const aliases={booklet:'booklet',booklets:'booklet','ملزمة':'booklet','ملازم':'booklet',product:'product',products:'product',stationery:'product',stationary:'product',gift:'product',gifts:'product',deal:'product',booklet_product:'product'};
    return lines.map((line,index)=>{
      let id=String(line?.id??'').trim();
      let kind=String(line?.kind??'').trim().toLowerCase();
      let booklet=findBooklet(id),product=findProduct(id);
      // بعض الأكواد القديمة كانت تستدعي addToCart(id, kind) بالعكس.
      if(!booklet&&!product&&kind){
        const swappedBooklet=findBooklet(kind),swappedProduct=findProduct(kind);
        if(swappedBooklet||swappedProduct){id=kind;kind=String(line?.id??'').trim().toLowerCase();booklet=swappedBooklet;product=swappedProduct}
      }
      const canonical=booklet?'booklet':product?'product':aliases[kind]||'';
      if(!id||!canonical||(!booklet&&!product&&booklets.length+products.length>0)){
        const title=String(line?.title||`العنصر ${index+1}`).trim();
        throw new Error(`العنصر «${title}» لم يعد موجوداً في المتجر. احذفه من السلة وأضفه من جديد`);
      }
      // إصلاح السلة القديمة محلياً حتى لا يتكرر الخطأ في الطلب التالي.
      line.id=id;line.kind=canonical;
      const purchaseType=canonical==='product'&&String(line?.purchase_type||line?.purchaseType||'unit')==='pack'?'pack':'unit';
      return {kind:canonical,id,qty:Math.max(1,Math.min(100,Number(line?.qty)||1)),purchase_type:purchaseType};
    });
  }


  function normalizeFulfillment(raw={}){
    const type=String(raw?.fulfillment_type||raw?.delivery_type||'').trim().toLowerCase();
    if(['pickup','library'].includes(type)){
      const libraryId=String(raw?.library_id||raw?.pickup_library_id||'').trim();
      if(!libraryId)throw new Error('اختر مكتبة الاستلام');
      const libraryName=String(raw?.library_name||raw?.pickup_library_name||'').trim();
      return {fulfillment_type:'pickup',library_id:libraryId,pickup_library_id:libraryId,library_name:libraryName,pickup_library_name:libraryName};
    }
    if(['home_delivery','courier','delivery'].includes(type)){
      const area=String(raw?.delivery_area||'').trim();
      const landmark=String(raw?.delivery_landmark||'').trim().slice(0,300);
      const latitude=raw?.delivery_latitude==null||raw.delivery_latitude===''?null:Number(raw.delivery_latitude);
      const longitude=raw?.delivery_longitude==null||raw.delivery_longitude===''?null:Number(raw.delivery_longitude);
      const accuracy=raw?.delivery_location_accuracy==null||raw.delivery_location_accuracy===''?null:Math.round(Number(raw.delivery_location_accuracy));
      if(!area)throw new Error('اختر منطقة التوصيل');
      if(!landmark&&!Number.isFinite(latitude))throw new Error('حدد الموقع أو اكتب أقرب نقطة دالة');
      return {
        fulfillment_type:'home_delivery',delivery_area:area,delivery_landmark:landmark,
        delivery_latitude:Number.isFinite(latitude)?latitude:null,
        delivery_longitude:Number.isFinite(longitude)?longitude:null,
        delivery_location_accuracy:Number.isFinite(accuracy)?accuracy:null
      };
    }
    throw new Error('اختر طريقة استلام صحيحة');
  }


  function randomId(){
    if(globalThis.crypto?.randomUUID)return globalThis.crypto.randomUUID();
    const bytes=new Uint8Array(16);globalThis.crypto?.getRandomValues?.(bytes);
    if(!bytes.some(Boolean)){for(let i=0;i<bytes.length;i++)bytes[i]=Math.floor(Math.random()*256)}
    bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128;
    return [...bytes].map((b,i)=>([4,6,8,10].includes(i)?'-':'')+b.toString(16).padStart(2,'0')).join('');
  }
  function deviceId(){
    const key='alin_device_id_v1';
    try{
      let value=localStorage.getItem(key);
      if(!value||value.length<16){value=randomId();localStorage.setItem(key,value)}
      return value;
    }catch(_){return randomId()}
  }
  function checkoutAttempt(fingerprint){
    const key='alin_checkout_attempt_v1';
    const now=Date.now();
    try{
      const saved=JSON.parse(sessionStorage.getItem(key)||'null');
      if(saved?.fingerprint===fingerprint&&saved?.requestKey&&now-Number(saved.createdAt||0)<15*60*1000)return saved;
      const next={fingerprint,requestKey:randomId(),createdAt:now};
      sessionStorage.setItem(key,JSON.stringify(next));return next;
    }catch(_){return {fingerprint,requestKey:randomId(),createdAt:now}}
  }
  function clearCheckoutAttempt(){try{sessionStorage.removeItem('alin_checkout_attempt_v1')}catch(_){}}

  let checkoutPending=false;
  async function secureCheckout(){
    if(checkoutPending)return;
    const button=document.querySelector('[data-alin-click="confirmCartCheckout"],#confirmCheckoutButton,[data-confirm-checkout]');
    try{
      checkoutPending=true;
      if(button){button.disabled=true;button.setAttribute('aria-busy','true');button.dataset.originalText=button.textContent;button.textContent='جارٍ إرسال الطلب...'}
      const c=client();if(!c?.rpc)throw new Error('تعذر الاتصال بالخدمة. تحقق من الإنترنت وحاول مجدداً');
      if(typeof cart==='undefined'||!Array.isArray(cart)||!cart.length)throw new Error('السلة فارغة');
      const signedStudent=window.AlinStudentAuth?.current?.()||null;
      const name=(signedStudent?.name||document.getElementById('studentName')?.value||'').trim();
      const phone=(signedStudent?.phone||document.getElementById('studentPhone')?.value||'').trim().replace(/\s+/g,'');
      const notes=(document.getElementById('orderNotes')?.value||'').trim().slice(0,1000);
      if(name.length<2)throw new Error('اكتب اسم الطالب بصورة صحيحة');
      if(!/^\+?[0-9٠-٩]{7,15}$/.test(phone))throw new Error('اكتب رقم هاتف صحيح');
      const fulfillment=normalizeFulfillment(typeof alinOrderExtra==='function'?alinOrderExtra():{});
      const coupon=(window.AlinCoupons?.getAppliedCode?.()||document.getElementById('couponInput')?.value||'').trim();
      const cartSnapshot=cart.map(item=>({...item}));
      const items=normalizeCheckoutItems(cart);
      const fingerprint=JSON.stringify({items,customer:{name,phone,notes},student:signedStudent?.id||null,fulfillment,coupon:coupon.toLowerCase()});
      const attempt=checkoutAttempt(fingerprint);
      if(typeof cartSave==='function')cartSave();
      const guestArgs={
        p_items:items,p_customer:{name,phone,notes},p_fulfillment:fulfillment,p_coupon_code:coupon||null,
        p_request_key:attempt.requestKey,p_device_id:deviceId()
      };
      const studentArgs={
        ...guestArgs,
        p_student_token:signedStudent?window.AlinStudentAuth?.token?.()||null:null,
        p_student_device:signedStudent?window.AlinStudentAuth?.deviceId?.()||null:null
      };
      const signatureMissing=error=>/PGRST202|Could not find the function|schema cache|function .* does not exist/i.test(`${error?.message||''} ${error?.code||''}`);
      let response=await c.rpc('alin_create_store_orders_guarded',signedStudent?studentArgs:guestArgs);
      // توافق آمن مع قاعدة البيانات الحالية والنسخة المحدثة:
      // الزائر يستخدم التوقيع القديم، والطالب يستخدم التوقيع المعزول عند توفره.
      if(response?.error&&signatureMissing(response.error)){
        response=await c.rpc('alin_create_store_orders_guarded',signedStudent?guestArgs:studentArgs);
        if(!response?.error&&signedStudent){
          document.dispatchEvent(new CustomEvent('alin:student-order-link-deferred',{detail:{studentId:signedStudent.id||null}}));
        }
      }
      const {data,error}=response||{};
      if(error){
        if(signatureMissing(error))throw new Error('خدمة تأكيد الطلب غير جاهزة على الخادم. أعد تحميل الصفحة، وإن استمرت المشكلة راجع إعدادات قاعدة البيانات.');
        throw error;
      }
      const numbers=Array.isArray(data)?data.map(x=>String(x.order_number||'')).filter(Boolean):[];
      if(!numbers.length)throw new Error('لم يرجع الخادم رقم تتبع للطلب');
      clearCheckoutAttempt();
      document.dispatchEvent(new CustomEvent('alin:order-created',{detail:{orderNumbers:numbers,studentId:signedStudent?.id||null}}));
      cart=[];if(typeof cartSave==='function')cartSave();
      if(typeof load==='function')await load();
      const box=window.checkoutBox||document.getElementById('checkoutBox');
      if(box){
        const copyTrackingCode=async(code,button)=>{
          let copied=false;
          try{
            if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(code);copied=true}
          }catch(_){}
          if(!copied){
            const field=document.createElement('textarea');
            field.value=code;field.setAttribute('readonly','');field.style.position='fixed';field.style.opacity='0';
            document.body.appendChild(field);field.select();
            try{copied=document.execCommand('copy')}catch(_){}
            field.remove();
          }
          if(!copied){window.prompt('انسخ رقم التتبع',code);return}
          const label=button.querySelector('span');
          button.classList.add('is-copied');
          if(label)label.textContent='تم النسخ';
          if(typeof window.toast==='function')window.toast('تم نسخ رقم التتبع');
          setTimeout(()=>{button.classList.remove('is-copied');if(label)label.textContent='نسخ'},1800);
        };
        box.replaceChildren();
        const success=document.createElement('section');success.className='alin-order-success';
        const icon=document.createElement('div');icon.className='alin-order-success__icon';icon.setAttribute('aria-hidden','true');icon.textContent='✓';
        const h=document.createElement('h2');h.textContent='تم استلام طلبك';
        const note=document.createElement('p');note.textContent='احتفظ برقم التتبع لمتابعة حالة طلبك.';
        const pickup=document.createElement('p');pickup.className='alin-order-success__pickup';
        if(fulfillment.fulfillment_type==='pickup'&&fulfillment.library_name){pickup.textContent=`مكتبة الاستلام: ${fulfillment.library_name}`}
        const codes=document.createElement('div');codes.className='alin-order-success__codes';
        numbers.forEach(number=>{
          const row=document.createElement('div');row.className='alin-tracking-code';
          const code=document.createElement('b');code.dir='ltr';code.textContent=number;code.title='رقم التتبع';
          const copy=document.createElement('button');copy.type='button';copy.className='alin-copy-tracking';copy.setAttribute('aria-label',`نسخ رقم التتبع ${number}`);copy.title='نسخ رقم التتبع';
          copy.innerHTML='<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="8" y="8" width="11" height="11" rx="2"></rect><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"></path></svg><span>نسخ</span>';
          copy.addEventListener('click',()=>copyTrackingCode(number,copy));
          code.addEventListener('click',()=>copyTrackingCode(number,copy));code.tabIndex=0;code.setAttribute('role','button');code.setAttribute('aria-label',`نسخ رقم التتبع ${number}`);
          code.addEventListener('keydown',event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();copyTrackingCode(number,copy)}});
          row.append(code,copy);codes.append(row);
        });
        const close=document.createElement('button');close.type='button';close.className='alin-order-success__close';close.textContent='إغلاق';close.addEventListener('click',()=>window.closeCheckout?.());
        success.append(icon,h,note);if(pickup.textContent)success.append(pickup);success.append(codes,close);box.append(success);
        document.dispatchEvent(new CustomEvent('alin:order-created',{detail:{numbers,fulfillment:fulfillment.fulfillment_type||fulfillment.delivery_type||'',items:cartSnapshot}}));
      }
    }catch(e){throw e}
    finally{checkoutPending=false;if(button){button.disabled=false;button.removeAttribute('aria-busy');button.textContent=button.dataset.originalText||'تأكيد الطلب'}}
  }
  window.ALINAuth=Object.assign(window.ALINAuth||{},{secureCheckout});
  window.ALINCheckout=Object.freeze({normalizeCheckoutItems,normalizeFulfillment,secureCheckout});
})();
;

/* modules/store/tracking.js */
// === store/tracking.js ===
/* ALIN v4.1.5 — tracking accepts mixed-case order numbers and legacy RPC responses. */
(function(){
  'use strict';

  const statusLabels=Object.freeze({
    pending:'تم استلام الطلب',new:'تم استلام الطلب',payment_pending:'بانتظار التأكيد',pending_admin:'بانتظار التعيين',
    assigned:'تم تعيين المندوب',accepted:'قبل المندوب الطلب',processing:'قيد التجهيز',printing:'قيد الطباعة',
    ready:'جاهز',picked_up:'استلم المندوب الطلب',out_delivery:'الطلب في الطريق',out_for_delivery:'الطلب في الطريق',
    completed:'تم التسليم',delivered:'تم التسليم',cancelled:'ملغي',rejected:'مرفوض'
  });
  const clean=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const normalizeCode=value=>String(value??'')
    .replace(/[٠-٩]/g,d=>'0123456789'['٠١٢٣٤٥٦٧٨٩'.indexOf(d)])
    .replace(/\s+/g,'').trim();
  function trackingCandidates(value){
    const raw=normalizeCode(value),items=[];
    const add=candidate=>{candidate=String(candidate||'').trim();if(candidate&&!items.includes(candidate))items.push(candidate)};
    add(raw);
    const parts=raw.split('-');
    if(parts.length>=2){
      const suffix=parts.pop();
      add(parts.map((part,index)=>index===0?part.toUpperCase():part).concat(String(suffix).toLowerCase()).join('-'));
    }
    add(raw.toUpperCase());
    add(raw.toLowerCase());
    return items;
  }
  const normalizeStatus=value=>{
    const status=String(value||'new').trim().toLowerCase();
    if(status==='delivered')return'completed';
    if(status==='out_delivery')return'out_for_delivery';
    if(status==='pending')return'new';
    return status;
  };
  function rowFromRpc(data){
    if(Array.isArray(data))return data[0]||null;
    if(data&&Array.isArray(data.rows))return data.rows[0]||null;
    if(data&&data.found===false)return null;
    if(data&&data.order&&typeof data.order==='object')return data.order;
    return data&&typeof data==='object'?data:null;
  }
  function isHomeDelivery(row){
    const fulfillment=String(row?.fulfillment_type||row?.delivery_type||'').toLowerCase();
    return ['home_delivery','delivery','courier'].includes(fulfillment)||Boolean(row?.delivery_area);
  }
  function stageIndex(status){
    const map={
      new:0,payment_pending:0,pending_admin:0,
      assigned:1,accepted:1,processing:1,printing:1,
      ready:2,picked_up:2,
      out_for_delivery:3,
      completed:4
    };
    return Object.prototype.hasOwnProperty.call(map,status)?map[status]:0;
  }
  function timelineLabels(home){
    return home
      ? ['تم استلام الطلب','تم تعيين المندوب','استلم المندوب الطلب','الطلب في الطريق','تم التسليم']
      : ['تم استلام الطلب','قيد التجهيز','جاهز بالمكتبة','بانتظار الاستلام','تم التسليم'];
  }
  function renderTracking(box,row,code){
    const status=normalizeStatus(row.status);
    const cancelled=['cancelled','rejected'].includes(status);
    const current=statusLabels[status]||String(row.status||'قيد المتابعة');
    const title=row.title||row.item_name||'طلب منصة آلين';
    const number=row.order_number||row.tracking_code||code;
    if(cancelled){
      box.innerHTML=`<b>${clean(number)} — ${clean(title)}</b><div class="track-current is-cancelled">الحالة الحالية: ${clean(current)}</div>`;
    }else{
      const reached=stageIndex(status),labels=timelineLabels(isHomeDelivery(row));
      box.innerHTML=`<b>${clean(number)} — ${clean(title)}</b><div class="track-current">الحالة الحالية: <strong>${clean(current)}</strong></div>${row.ready_eta?`<small>الجاهزية المتوقعة: ${clean(row.ready_eta)}</small>`:''}<div class="timeline v31">${labels.map((label,index)=>`<span class="${index<=reached?'done':''}" aria-current="${index===reached?'step':'false'}">${clean(label)}</span>`).join('')}</div>`;
    }
    document.dispatchEvent(new CustomEvent('alin:tracking-rendered',{detail:{code,data:row,status}}));
  }
  window.trackOrder=async function(){
    const input=document.getElementById('trackOrderInput');
    const box=document.getElementById('trackOrderResult');
    if(!box)return false;
    const code=normalizeCode(input?.value||'');
    if(input)input.value=code;
    box.className='track-result show';
    if(code.length<4){box.textContent='اكتب رقم الطلب الكامل أولاً';return false}
    box.textContent='جارٍ التحقق من حالة الطلب...';
    try{
      const client=window.sb||(window.AlinCloud&&window.AlinCloud.client?.());
      if(!client?.rpc)throw new Error('خدمة التتبع غير متاحة');
      let row=null,lastError=null,matchedCode=code;
      for(const candidate of trackingCandidates(code)){
        const {data,error}=await client.rpc('alin_track_order',{p_order_number:candidate});
        if(error){lastError=error;break}
        row=rowFromRpc(data);
        if(row){matchedCode=candidate;break}
      }
      if(lastError)throw lastError;
      if(!row){box.textContent='لم يتم العثور على الطلب. تأكد من رقم التتبع.';return false}
      if(input)input.value=row.order_number||matchedCode;
      renderTracking(box,row,matchedCode);
      return true;
    }catch(error){
      console.error('[ALIN tracking v4.1.5]',error);
      const message=String(error?.message||'');
      box.textContent=/PGRST202|Could not find the function|schema cache/i.test(message)
        ?'خدمة تتبع الطلب غير مهيأة في قاعدة البيانات.'
        :'تعذر التحقق الآن. أعد المحاولة بعد قليل.';
      return false;
    }
  };
  function bindTrackingInput(){
    const input=document.getElementById('trackOrderInput');
    if(!input||input.dataset.alinTrackingBound==='1')return;
    input.dataset.alinTrackingBound='1';
    input.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();window.trackOrder()}});
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',bindTrackingInput,{once:true});
  else bindTrackingInput();
})();
;

/* modules/core/cloud-status-ui.js */
// === core/cloud-status-ui.js ===
/* ALIN v2.4.2 — final boot verification for modular cloud services. */
(function(){
  'use strict';
  const required=['enabled','loginFromUI','signOut','restoreSession','secureCheckout'];
  const auth=window.ALINAuth||{};
  const missing=required.filter(name=>typeof auth[name]!=='function');
  if(missing.length)console.error('[ALIN cloud modules missing]',missing);
  else window.dispatchEvent(new CustomEvent('alin:cloud-services-ready',{detail:{services:required.slice()}}));
})();
;

/* store/mobile-navigation.js */
/* ALIN 2.0.1 - mobile navigation controller */

(function(){
  const byId=id=>document.getElementById(id);
  function showSheet(id){
    const backdrop=byId('alinSheetBackdrop');
    ['alinAccountSheet','alinTrackingSheet'].forEach(x=>{const el=byId(x); if(el) el.hidden=x!==id;});
    if(backdrop) backdrop.hidden=false;
    document.body.style.overflow='hidden';
  }
  window.alinOpenAccountSheet=()=>showSheet('alinAccountSheet');
  window.alinOpenTrackingSheet=()=>showSheet('alinTrackingSheet');
  window.alinCloseMobileSheets=function(){
    ['alinAccountSheet','alinTrackingSheet'].forEach(x=>{const el=byId(x);if(el)el.hidden=true;});
    const backdrop=byId('alinSheetBackdrop'); if(backdrop)backdrop.hidden=true;
    document.body.style.overflow='';
  };
  window.alinAccountAction=function(action){
    if(action==='login'||action==='signup'){
      alinCloseMobileSheets();
      if(typeof openStudentAuth==='function') openStudentAuth(action);
      else document.getElementById('studentAuthBtn')?.click();
      return;
    }
    if(action==='about'){
      alinCloseMobileSheets();
      document.getElementById('storeAbout')?.scrollIntoView({behavior:'smooth',block:'start'});
    }
  };
  window.alinSubmitMobileTracking=function(){
    const source=byId('alinMobileTrackingInput');
    const target=byId('trackOrderInput');
    const result=byId('alinMobileTrackingResult');
    if(!source?.value.trim()){if(result)result.innerHTML='<div class="notice">اكتب رقم الطلب أولاً.</div>';return;}
    if(target)target.value=source.value.trim();
    try{ if(typeof trackOrder==='function') trackOrder(); }catch(e){}
    setTimeout(()=>{
      const original=byId('trackOrderResult');
      if(result&&original) result.innerHTML=original.innerHTML||'<div class="notice">جاري البحث عن الطلب...</div>';
    },300);
  };
  document.addEventListener('keydown',e=>{if(e.key==='Escape')alinCloseMobileSheets();});
})();
;

/* store/notifications.js */
/* ALIN v2.2.6 — storefront notification center backed by AlinNotifications. */
(function(){
  'use strict';

  const escapeHtml=value=>String(value??'').replace(/[&<>"']/g,char=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[char]));
  const context=()=>({role:'student',id:''});
  const service=()=>window.AlinNotifications;
  const rows=()=>service()?.visible?.(context())||[];
  const unread=()=>service()?.unreadCount?.(context())||0;

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
    const read=service()?.isRead?.(row,context())??true;
    return `<article class="${read?'read':'unread'}" data-notification-id="${escapeHtml(row.id)}"><span class="alin-notifications-v120__dot"></span><div><div class="alin-notifications-v120__title"><h3>${escapeHtml(row.title||'إشعار')}</h3>${read?'':'<b>جديد</b>'}</div><p>${escapeHtml(row.message||row.text||'')}</p><time>${escapeHtml(new Date(row.created_at||Date.now()).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ'))}</time></div></article>`;
  }

  function open(){
    close();
    const box=document.createElement('div');
    box.id='alinNotificationsV120';
    box.className='alin-notifications-v120';
    const list=rows();
    box.innerHTML=`<button class="alin-notifications-v120__backdrop" type="button" aria-label="إغلاق"></button><section class="alin-notifications-v120__panel" role="dialog" aria-modal="true"><header><div><h2>الإشعارات</h2><p>${unread()?unread()+' إشعار جديد':'لا توجد إشعارات جديدة'}</p></div><div><button type="button" data-read-all>قراءة الكل</button><button type="button" data-close aria-label="إغلاق">×</button></div></header><div class="alin-notifications-v120__list">${list.map(itemHtml).join('')||'<div class="alin-notifications-v120__empty"><span>🔕</span><b>لا توجد إشعارات حالياً</b><p>إشعارات الإدارة الجديدة ستظهر هنا.</p></div>'}</div></section>`;
    document.body.appendChild(box);
    document.body.classList.add('alin-notifications-open');
    box.querySelector('[data-close]')?.addEventListener('click',close);
    box.querySelector('.alin-notifications-v120__backdrop')?.addEventListener('click',close);
    box.querySelector('[data-read-all]')?.addEventListener('click',async()=>{await service()?.markAll?.(context());open()});
    box.querySelectorAll('[data-notification-id]').forEach(item=>item.addEventListener('click',async()=>{
      await service()?.markRead?.(item.dataset.notificationId,context());
      open();
    }));
  }

  async function refresh(){
    await service()?.refresh?.();
    badges();
  }

  function install(){
    document.querySelectorAll('[data-desktop-control="notifications"],.mobile-header-icon-btn[aria-label^="الإشعارات"]').forEach(button=>{
      button.removeAttribute('onclick');
      if(button.dataset.alinNotificationsBound==='1')return;
      button.dataset.alinNotificationsBound='1';
      button.addEventListener('click',event=>{event.preventDefault();open()});
    });
    document.addEventListener('keydown',event=>{if(event.key==='Escape')close()});
    window.addEventListener('alin:notifications-updated',badges);
    window.addEventListener('alin:store-rendered',badges);
    refresh();
  }

  const api=Object.freeze({open,close,refresh,badges,rows});
  window.AlinStoreNotifications=api;
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
})();
;
