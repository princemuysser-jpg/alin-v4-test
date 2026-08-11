(function(){
  'use strict';
  const $=id=>document.getElementById(id);
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const first=(obj,keys,fallback='—')=>{for(const k of keys){const v=obj?.[k];if(v!==undefined&&v!==null&&String(v).trim()!=='')return v}return fallback};
  const money=v=>{const n=Number(v);return Number.isFinite(n)?n.toLocaleString('ar-IQ',{maximumFractionDigits:0})+' د.ع':'—'};
  const date=v=>{if(!v)return '—';const d=new Date(v);return Number.isNaN(d.getTime())?String(v):d.toLocaleString('ar-IQ',{dateStyle:'medium',timeStyle:'short'})};
  const normalizeStatus=value=>String(value||'new').trim().toLowerCase();
  const isCourierOrder=row=>{
    const fulfillment=String(first(row,['fulfillment_type','delivery_type','shipping_type','order_delivery_type'],'')).toLowerCase();
    return ['home_delivery','delivery','courier','door_delivery'].includes(fulfillment)
      || Boolean(first(row,['courier_id','assigned_courier_id','courier_name','delivery_area'],''));
  };
  const isPrintableOrder=row=>{
    const kind=String(first(row,['item_type','product_type','category','order_type'],'')).toLowerCase();
    const title=String(first(row,['title','item_name','product_name','order_title'],'')).toLowerCase();
    return ['booklet','booklets','print','printing','malzama'].some(token=>kind.includes(token))
      || /ملزمة|ملازم|طباعة/.test(title);
  };
  const flowFor=(row,status)=>{
    const courier=isCourierOrder(row);
    const printable=isPrintableOrder(row);
    const cancelled=['cancelled','canceled','rejected'].includes(status);
    if(cancelled)return {courier,printable,cancelled:true,index:-1,steps:[]};
    if(courier){
      let index=0;
      if(['assigned','accepted','picked_up','processing','printing','ready'].includes(status))index=1;
      if(['out_delivery','out_for_delivery'].includes(status))index=2;
      if(['completed','delivered'].includes(status))index=3;
      return {courier,printable,cancelled:false,index,steps:['تم الاستلام','تم تعيين المندوب','في الطريق','تم التسليم']};
    }
    let index=0;
    if(['assigned','accepted','processing','printing'].includes(status))index=1;
    if(['ready','picked_up','out_delivery','out_for_delivery'].includes(status))index=2;
    if(['completed','delivered'].includes(status))index=3;
    return {courier,printable,cancelled:false,index,steps:['تم الاستلام',printable?'قيد الطباعة':'قيد التجهيز','جاهز','تم التسليم']};
  };
  const statusLabel=(row,status)=>{
    const flow=flowFor(row,status);
    if(flow.cancelled)return 'ملغي';
    if(['completed','delivered'].includes(status))return 'تم التسليم';
    if(flow.courier){
      if(['out_delivery','out_for_delivery'].includes(status))return 'في الطريق';
      if(['accepted','picked_up'].includes(status))return 'استلم المندوب الطلب';
      if(['assigned','processing','printing','ready'].includes(status))return 'تم تعيين المندوب';
      return 'تم الاستلام';
    }
    if(['ready','picked_up','out_delivery','out_for_delivery'].includes(status))return 'جاهز';
    if(['assigned','accepted','processing','printing'].includes(status))return flow.printable?'قيد الطباعة':'قيد التجهيز';
    return 'تم الاستلام';
  };
  const empty=()=>'<div class="alin415-track-empty"><span class="symbol">⌖</span><b>جاهز لتتبع طلبك</b><small>أدخل رقم الطلب واضغط «تتبع الآن».</small></div>';
  const normalize=data=>{if(Array.isArray(data))return data[0]||null;if(data&&typeof data==='object'&&Array.isArray(data.data))return data.data[0]||null;if(data&&typeof data==='object'&&data.data&&typeof data.data==='object')return data.data;return data&&typeof data==='object'?data:null};
  const candidates=value=>{const raw=String(value||'').trim();return [...new Set([raw,raw.toUpperCase(),raw.toLowerCase()])].filter(Boolean)};
  const render=(row,typed)=>{
    const box=$('alinTrack415Result');if(!box)return;
    const status=normalizeStatus(first(row,['status','order_status'],'new'));
    const flow=flowFor(row,status);
    const number=first(row,['order_number','tracking_code','id'],typed);
    const title=first(row,['title','item_name','product_name','order_title'],'طلب منصة آلين');
    const notes=first(row,['notes','note','status_note','delivery_notes'],'لا توجد ملاحظات');
    const created=date(first(row,['created_at','order_date','updated_at'],''));
    box.innerHTML=`<section class="alin415-track-head"><div><small>رقم الطلب</small><h3>${esc(number)}</h3><p>${esc(title)}</p></div><span class="alin415-track-status ${flow.cancelled?'cancel':flow.index===3?'done':''}">${esc(statusLabel(row,status))}</span></section>
    <section class="alin415-track-details compact">
      <article class="alin415-track-detail"><small>التاريخ</small><b>${esc(created)}</b></article>
      <article class="alin415-track-detail"><small>الملاحظات</small><b>${esc(notes)}</b></article>
    </section>
    ${flow.cancelled?'<div class="alin415-track-alert error" style="margin-top:14px">هذا الطلب ملغي.</div>':`<section class="alin415-track-timeline">${flow.steps.map((name,i)=>`<article class="alin415-track-step ${i<flow.index?'done':i===flow.index?'current':''}"><i>${i<flow.index?'✓':i+1}</i><b>${name}</b></article>`).join('')}</section>`}`;
  };
  async function search(){
    const input=$('alinTrack415Input'),box=$('alinTrack415Result');if(!box)return false;
    const code=String(input?.value||'').trim();
    if(code.length<4){box.innerHTML='<div class="alin415-track-alert">اكتب رقم الطلب الكامل أولاً.</div>';return false}
    box.innerHTML='<div class="alin415-track-loading"><i></i><span>جارٍ التحقق من حالة الطلب...</span></div>';
    try{
      const client=window.sb||(window.AlinCloud&&window.AlinCloud.client?.());
      if(!client?.rpc)throw new Error('tracking client unavailable');
      let row=null,lastError=null;
      for(const c of candidates(code)){
        const {data,error}=await client.rpc('alin_track_order',{p_order_number:c});
        if(error){lastError=error;continue}
        const candidate=normalize(data);
        if(candidate && candidate.found!==false){row=candidate;break}
      }
      if(!row){if(lastError)console.warn('[ALIN 4.1.5 tracking]',lastError);box.innerHTML='<div class="alin415-track-alert error"><b>لم يتم العثور على الطلب</b><br><small>تأكد من رقم الطلب وأعد المحاولة.</small></div>';return false}
      render(row,code);return true;
    }catch(err){console.error('[ALIN 4.1.5 safe tracking]',err);box.innerHTML='<div class="alin415-track-alert error"><b>تعذر التحقق الآن</b><br><small>أعد المحاولة بعد قليل.</small></div>';return false}
  }
  function open(){const layer=$('alinTrack415Layer');if(!layer)return;layer.hidden=false;layer.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';$('alinTrack415Result').innerHTML=empty();setTimeout(()=>$('alinTrack415Input')?.focus(),40)}
  function close(){const layer=$('alinTrack415Layer');if(!layer)return;layer.hidden=true;layer.setAttribute('aria-hidden','true');document.body.style.overflow='';return true}
  window.AlinTrack415Safe={open,close,search};
  document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!$('alinTrack415Layer')?.hidden)close();if(e.key==='Enter'&&document.activeElement===$('alinTrack415Input')){e.preventDefault();search()}});
  document.addEventListener('click',e=>{if(e.target===$('alinTrack415Layer'))close()});
  document.addEventListener('DOMContentLoaded',()=>{const box=$('alinTrack415Result');if(box)box.innerHTML=empty()});
})();
