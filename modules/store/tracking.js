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

  // Local student order acknowledgements. Persist on the same browser even
  // after a guest closes the storefront; this is NOT a payment receipt.
  const studentReceiptStorageKey='alin_student_order_receipts_v1';
  const receiptOwner=()=>String(window.AlinStudentAuth?.current?.()?.id||'guest');
  const receiptMoney=value=>Math.round(Number(value)||0).toLocaleString('ar-IQ')+' د.ع';
  function readStudentReceipts(){
    try{
      const parsed=JSON.parse(localStorage.getItem(studentReceiptStorageKey)||'[]');
      return Array.isArray(parsed)?parsed.filter(row=>row&&typeof row==='object'):[];
    }catch(_){return []}
  }
  function writeStudentReceipt(receipt){
    const code=String(receipt?.order_number||'').trim();
    if(!code)return;
    try{
      const all=readStudentReceipts().filter(row=>String(row.order_number)!==code);
      all.unshift({...receipt,student_owner:receiptOwner()});
      localStorage.setItem(studentReceiptStorageKey,JSON.stringify(all.slice(0,80)));
      renderStudentReceiptLinks();
    }catch(error){console.warn('[ALIN student receipts] local save',error)}
  }
  function receiptItemsHtml(receipt){
    return (Array.isArray(receipt.items)?receipt.items:[]).map((item,index)=>
      '<tr><td style="padding:8px;border-bottom:1px solid #e8edf4">'+(index+1)+
      '</td><td style="padding:8px;border-bottom:1px solid #e8edf4">'+clean(item.title||'مادة')+
      '</td><td style="padding:8px;border-bottom:1px solid #e8edf4">'+Math.max(1,Number(item.qty)||1)+
      '</td><td style="padding:8px;border-bottom:1px solid #e8edf4">'+receiptMoney(item.total)+'</td></tr>'
    ).join('');
  }
  function studentReceiptHtml(receipt){
    const total=Number(receipt.total);
    const totalText=Number.isFinite(total)?receiptMoney(total):'راجع المبلغ في الطلب';
    const fulfilled=String(receipt.fulfillment_type||'')==='home_delivery'?'توصيل مندوب':'استلام من مكتبة';
    return '<article dir="rtl" style="padding:22px;color:#143b68;font-family:Tahoma,Arial,sans-serif">'+
      '<h2 style="margin:0">منصة آلين — وصل تأكيد الطلب</h2>'+
      '<p>رقم الطلب: <b dir="ltr">'+clean(receipt.order_number)+'</b></p>'+
      '<p>التاريخ: '+clean(String(receipt.created_at||'').replace('T',' ').slice(0,19))+'</p>'+
      '<p>الطالب: '+clean(receipt.student_name||'—')+'</p>'+
      '<p>الحالة عند الإصدار: تم تسجيل الطلب</p>'+
      '<p>طريقة الاستلام: '+clean(fulfilled)+'</p>'+
      '<table style="width:100%;border-collapse:collapse;text-align:right"><thead><tr><th>ت</th><th>المادة</th><th>الكمية</th><th>القيمة</th></tr></thead><tbody>'+
      receiptItemsHtml(receipt)+'</tbody></table>'+
      '<p style="font-size:20px;font-weight:bold">'+(receipt.total_is_cart_estimate?'قيمة مواد السلة قبل أجرة التوصيل (تقديرية): ':'الإجمالي: ')+totalText+'</p>'+
      '<p style="color:#a65b1c;font-weight:bold">وصل تأكيد طلب، وليس إثبات دفع أو تسليم. قد تتغير الحالة لاحقاً.</p>'+
      '</article>';
  }
  function openStudentReceipt(code,print=false){
    const receipt=readStudentReceipts().find(row=>
      String(row.student_owner)===receiptOwner()&&String(row.order_number)===String(code));
    if(!receipt)return false;
    const html=studentReceiptHtml(receipt);
    if(print){
      const popup=window.open('','_blank','width=860,height=800');
      if(!popup){window.alert('اسمح بفتح نافذة الطباعة وحاول مرة أخرى');return false}
      try{popup.opener=null}catch(_){}
      popup.document.write('<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>وصل طلب - منصة آلين</title></head><body>'+html+'</body></html>');
      popup.document.close();popup.focus();popup.print();
      return true;
    }
    document.getElementById('alinStudentReceiptDialog')?.remove();
    const dialog=document.createElement('dialog');
    dialog.id='alinStudentReceiptDialog';
    dialog.style.cssText='width:min(94vw,700px);max-height:85vh;overflow:auto;border:1px solid #dce5ef;border-radius:18px;box-shadow:0 20px 80px #143b6840';
    dialog.innerHTML=html+'<div style="display:flex;gap:8px;justify-content:flex-end;padding:0 20px 20px">'+
      '<button type="button" data-alin-receipt-print>طباعة / حفظ PDF</button>'+
      '<button type="button" data-alin-receipt-close>إغلاق</button></div>';
    document.body.appendChild(dialog);
    dialog.querySelector('[data-alin-receipt-close]')?.addEventListener('click',()=>dialog.close());
    dialog.querySelector('[data-alin-receipt-print]')?.addEventListener('click',()=>openStudentReceipt(code,true));
    dialog.addEventListener('close',()=>dialog.remove(),{once:true});
    if(typeof dialog.showModal==='function')dialog.showModal();else dialog.setAttribute('open','');
    return true;
  }
  function renderStudentReceiptLinks(){
    const input=document.getElementById('trackOrderInput');
    if(!input)return;
    let root=document.getElementById('alinStudentSavedReceipts');
    if(!root){
      root=document.createElement('section');
      root.id='alinStudentSavedReceipts';
      root.style.cssText='margin:18px 0;padding:14px;border:1px solid #dbe5f1;border-radius:14px;background:#fff';
      const target=document.getElementById('trackOrderResult')||input;
      target.insertAdjacentElement('afterend',root);
    }
    const receipts=readStudentReceipts().filter(row=>String(row.student_owner)===receiptOwner());
    root.hidden=!receipts.length;
    if(!receipts.length)return;
    root.innerHTML='<h3 style="margin:0 0 10px;font-size:17px">وصولاتي المحفوظة</h3>'+
      receipts.slice(0,30).map(row=>'<div style="display:flex;align-items:center;gap:10px;justify-content:space-between;padding:8px 0;border-bottom:1px solid #edf1f6">'+
        '<span dir="ltr">'+clean(row.order_number)+'</span>'+
        '<button type="button" data-student-receipt="'+clean(row.order_number)+'">عرض الوصل</button></div>').join('');
    root.querySelectorAll('[data-student-receipt]').forEach(button=>
      button.addEventListener('click',()=>openStudentReceipt(button.dataset.studentReceipt)));
  }
  document.addEventListener('alin:order-created',event=>{
    const detail=event.detail||{};
    if(!Array.isArray(detail.numbers)||!Array.isArray(detail.items))return;
    const items=detail.items.map(row=>{
      const qty=Math.max(1,Number(row.qty)||1),price=Number(row.price)||0;
      return {title:String(row.title||'مادة'),qty,unit_price:price,total:qty*price};
    });
    const rawSubtotal=items.reduce((sum,row)=>sum+row.total,0);
    // Totals are confirmed by Supabase, not by the browser; keep this visibly
    // labelled as cart value if server totals were not returned.
    writeStudentReceipt({
      order_number:String(detail.numbers[0]||''),
      created_at:new Date().toISOString(),
      student_name:window.AlinStudentAuth?.current?.()?.name||'',
      fulfillment_type:detail.fulfillment,
      items,
      total:rawSubtotal,
      total_is_cart_estimate:true
    });
  });
  window.AlinStudentReceipts=Object.freeze({read:readStudentReceipts,save:writeStudentReceipt,open:openStudentReceipt});
  window.addEventListener('alin:student-session',renderStudentReceiptLinks);

  function bindTrackingInput(){
    const input=document.getElementById('trackOrderInput');
    if(!input||input.dataset.alinTrackingBound==='1')return;
    input.dataset.alinTrackingBound='1';
    input.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();window.trackOrder()}});
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>{bindTrackingInput();renderStudentReceiptLinks()},{once:true});
  else {bindTrackingInput();renderStudentReceiptLinks()}
})();
