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
