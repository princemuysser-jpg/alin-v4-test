// Group rows created by the same checkout into one compact admin card.
// A dedicated "عرض القائمة" modal shows the full preparation list while
// keeping each underlying order row intact for stock, finance and actions.
(function(){
'use strict';
const old=window.renderOrdersAdmin;if(typeof old!=='function')return;
const arr=v=>Array.isArray(v)?v:[];
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const num=v=>Number(v||0)||0;
const money=v=>typeof window.money==='function'?window.money(v):Math.round(num(v)).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
const rows=()=>arr(window.db?.orders);
const key=o=>String(o?.checkout_group_id||o?.checkout_request_key||`single:${o?.id||o?.order_number}`);
const codeOf=card=>String(card.querySelector('.admin-order-v126-title > span')?.textContent||'').trim();
const rowFor=card=>{const c=codeOf(card);return rows().find(o=>String(o.order_number||o.id)===c)||null};
const groupsByKey=new Map();
const statusLabels={pending:'قيد الانتظار',new:'جديد',pending_admin:'بانتظار الإدارة',payment_pending:'بانتظار الدفع',paid:'مدفوع',assigned:'محول للمندوب',accepted:'مقبول من المندوب',picked_up:'استلمه المندوب',out_for_delivery:'قيد التوصيل',out_delivery:'قيد التوصيل',processing:'قيد التجهيز',printing:'قيد الطباعة',ready:'جاهز',completed:'مكتمل',delivered:'تم التسليم',cancelled:'ملغي',rejected:'مرفوض',receipt_rejected:'وصل مرفوض'};
const statusOf=o=>String(o?.status||o?.payment_status||'new');
const statusLabel=o=>statusLabels[statusOf(o)]||statusOf(o);
function css(){
 if(document.getElementById('alinGroupedOrdersCss'))return;
 const s=document.createElement('style');s.id='alinGroupedOrdersCss';s.textContent=`
 .alin-order-group{border:1px solid #dce5ef;border-radius:18px;background:#fff;margin-bottom:14px;overflow:hidden;box-shadow:0 6px 18px rgba(17,40,70,.05)}
 .alin-order-group-head{display:flex;align-items:center;justify-content:space-between;gap:14px;padding:16px}
 .alin-order-group-head h3{margin:0 0 4px;font-size:17px}.alin-order-group-head p{margin:0;color:#667085;font-size:13px}
 .alin-order-group-main{display:flex;align-items:center;gap:9px;flex-wrap:wrap}.alin-order-pill{display:inline-flex;align-items:center;border-radius:999px;background:#f1f5f9;color:#334155;padding:6px 10px;font-size:12px;font-weight:700}
 .alin-order-group-total{font-weight:800;color:#172b4d;white-space:nowrap}.alin-order-group-actions{display:flex;align-items:center;gap:8px}
 .alin-order-list-btn{border:0;border-radius:12px;padding:10px 15px;background:#173b67;color:#fff;font-weight:800;cursor:pointer}.alin-order-list-btn:hover{filter:brightness(.96)}
 .alin-order-prep-backdrop{position:fixed;inset:0;z-index:10050;background:rgba(15,23,42,.55);display:flex;align-items:center;justify-content:center;padding:18px}
 .alin-order-prep-modal{width:min(1040px,96vw);max-height:92vh;overflow:auto;background:#fff;border-radius:22px;box-shadow:0 30px 70px rgba(15,23,42,.25)}
 .alin-order-prep-head{position:sticky;top:0;z-index:2;display:flex;align-items:flex-start;justify-content:space-between;gap:16px;padding:18px 20px;background:#fff;border-bottom:1px solid #e7edf4}
 .alin-order-prep-head h2{margin:0 0 5px}.alin-order-prep-head p{margin:0;color:#667085}.alin-order-prep-close{border:0;background:#f1f5f9;border-radius:11px;width:40px;height:40px;font-size:22px;cursor:pointer}
 .alin-order-prep-info{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;padding:16px 20px}.alin-order-prep-info span{background:#f8fafc;border-radius:12px;padding:10px;color:#667085;font-size:12px}.alin-order-prep-info b{display:block;margin-top:4px;color:#172b4d;font-size:14px}
 .alin-order-prep-table-wrap{padding:0 20px 18px;overflow:auto}.alin-order-prep-table{width:100%;border-collapse:separate;border-spacing:0;min-width:760px}.alin-order-prep-table th{background:#eef3f8;text-align:right;padding:10px;font-size:12px;color:#475569}.alin-order-prep-table td{padding:11px 10px;border-bottom:1px solid #edf1f5;vertical-align:top}.alin-order-prep-table td b{display:block}.alin-order-prep-table td small{display:block;color:#667085;margin-top:3px}
 .alin-order-prep-summary{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;padding:0 20px 18px}.alin-order-prep-summary span{background:#f8fafc;border-radius:12px;padding:10px;color:#667085;font-size:12px}.alin-order-prep-summary b{display:block;margin-top:3px;color:#172b4d}
 .alin-order-prep-notes{margin:0 20px 18px;padding:13px 14px;background:#fff7ed;border-radius:12px;color:#7c2d12}.alin-order-prep-notes b{display:block;margin-bottom:5px}
 .alin-order-prep-actions{padding:0 20px 20px}.alin-order-prep-actions details{border:1px solid #e3e9f0;border-radius:14px}.alin-order-prep-actions summary{cursor:pointer;padding:12px 14px;font-weight:800}.alin-order-group-manage{padding:0 10px 10px}.alin-order-group-manage .admin-order-v126{margin-top:10px}
 @media(max-width:760px){.alin-order-group-head{align-items:flex-start;flex-direction:column}.alin-order-group-actions{width:100%;justify-content:space-between}.alin-order-prep-info,.alin-order-prep-summary{grid-template-columns:1fr 1fr}.alin-order-prep-backdrop{padding:6px}.alin-order-prep-modal{width:100%;max-height:96vh;border-radius:16px}}
 `;document.head.appendChild(s)
}
function grouped(data){const m=new Map();data.forEach(o=>{const k=key(o);if(!m.has(k))m.set(k,[]);m.get(k).push(o)});return m}
function kindLabel(o){const k=String(o?.kind||'').toLowerCase();if(k==='booklet')return 'ملزمة';if(k==='book')return 'كتاب';if(k==='stationery')return 'قرطاسية';if(k==='gift')return 'هدية';return 'منتج'}
function detailText(o){const bits=[];if(o.product_variant_code)bits.push(`كود: ${o.product_variant_code}`);if(o.product_variant_name)bits.push(`التصميم: ${o.product_variant_name}`);if(String(o.purchase_type||'unit')==='pack')bits.push(`باكيت${num(o.pack_size)>=2?` (${num(o.pack_size)} قطع)`:''}`);if(o.subject)bits.push(String(o.subject));if(o.term||o.chapter)bits.push(String(o.term||o.chapter));return bits.join(' • ')}
function groupStatus(list){const st=[...new Set(list.map(statusOf))];return st.length===1?statusLabel(list[0]):'حالات متعددة'}
function libraryName(id){const r=arr(window.db?.accounts?.libraries).find(x=>String(x.id)===String(id));return r?.name||r?.library_name||'—'}
function courierName(id){const all=[...arr(window.db?.accounts?.couriers),...arr(window.db?.couriers)];const r=all.find(x=>String(x.id)===String(id));return r?.name||'غير معيّن'}
function fulfillmentText(first){const home=['home_delivery','delivery','courier'].includes(String(first?.fulfillment_type||first?.delivery_type||''));return home?(first.delivery_area||'توصيل للمنزل'):libraryName(first.library_id||first.pickup_library_id)}
function prepModal(groupKey){
 const g=groupsByKey.get(String(groupKey));if(!g?.rows?.length)return;
 document.querySelector('.alin-order-prep-backdrop')?.remove();
 const list=g.rows,first=list[0],total=list.reduce((s,o)=>s+num(o.total),0),delivery=list.reduce((s,o)=>s+num(o.delivery_fee),0),discount=list.reduce((s,o)=>s+num(o.discount),0),qty=list.reduce((s,o)=>s+Math.max(1,num(o.qty||o.quantity)),0);
 const backdrop=document.createElement('div');backdrop.className='alin-order-prep-backdrop';
 backdrop.innerHTML=`<section class="alin-order-prep-modal" role="dialog" aria-modal="true" aria-label="قائمة تجهيز الطلب">
   <header class="alin-order-prep-head"><div><h2>قائمة تجهيز الطلب</h2><p>${esc(first.student_name||'بدون اسم')} • ${esc(first.student_phone||'بدون هاتف')} • ${esc(first.order_number||first.id)}</p></div><button type="button" class="alin-order-prep-close" aria-label="إغلاق">×</button></header>
   <section class="alin-order-prep-info">
    <span>عدد المواد<b>${list.length}</b></span><span>إجمالي القطع/النسخ<b>${qty}</b></span><span>الحالة<b>${esc(groupStatus(list))}</b></span><span>الاستلام<b>${esc(fulfillmentText(first))}</b></span>
   </section>
   <div class="alin-order-prep-table-wrap"><table class="alin-order-prep-table"><thead><tr><th>#</th><th>المادة</th><th>النوع والتفاصيل</th><th>الكمية</th><th>سعر الوحدة</th><th>الخصم</th><th>الإجمالي</th><th>الحالة</th></tr></thead><tbody>${list.map((o,i)=>`<tr><td>${i+1}</td><td><b>${esc(o.title||'مادة')}</b><small>${esc(o.order_number||o.id||'')}</small></td><td><b>${esc(kindLabel(o))}</b>${detailText(o)?`<small>${esc(detailText(o))}</small>`:''}</td><td><b>× ${Math.max(1,num(o.qty||o.quantity))}</b></td><td>${money(o.unit_price||0)} د.ع</td><td>${money(o.discount||0)} د.ع</td><td><b>${money(o.total||0)} د.ع</b></td><td>${esc(statusLabel(o))}</td></tr>`).join('')}</tbody></table></div>
   <section class="alin-order-prep-summary"><span>مجموع المواد<b>${money(total-delivery)} د.ع</b></span><span>أجرة التوصيل<b>${money(delivery)} د.ع</b></span><span>مجموع الخصم<b>${money(discount)} د.ع</b></span><span>الإجمالي الكلي<b>${money(total)} د.ع</b></span></section>
   <section class="alin-order-prep-info"><span>المنطقة / المكتبة<b>${esc(fulfillmentText(first))}</b></span><span>المندوب<b>${esc(courierName(first.courier_id||first.delegate_id))}</b></span><span>أقرب نقطة دالة<b>${esc(first.delivery_landmark||'—')}</b></span><span>تاريخ الطلب<b>${first.created_at?esc(new Date(first.created_at).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')):'—'}</b></span></section>
   ${first.notes?`<div class="alin-order-prep-notes"><b>ملاحظات الطالب</b>${esc(first.notes)}</div>`:''}
   <section class="alin-order-prep-actions"><details><summary>إجراءات وتفاصيل كل مادة</summary><div class="alin-order-group-manage"></div></details></section>
 </section>`;
 const manage=backdrop.querySelector('.alin-order-group-manage');g.cards.forEach(card=>manage.appendChild(card));
 const close=()=>{g.cards.forEach(card=>g.cardParking?.appendChild(card));backdrop.remove()};
 backdrop.querySelector('.alin-order-prep-close')?.addEventListener('click',close);
 backdrop.addEventListener('click',e=>{if(e.target===backdrop)close()});
 document.addEventListener('keydown',function onKey(e){if(e.key==='Escape'){document.removeEventListener('keydown',onKey);close()}},{once:true});
 document.body.appendChild(backdrop);
}
function enhance(){
 css();const host=document.querySelector('#adminContent .admin-orders-v126-list');if(!host||host.dataset.grouped==='1')return;
 const cards=[...host.children].filter(x=>x.classList?.contains('admin-order-v126'));if(!cards.length)return;
 groupsByKey.clear();const groups=new Map(),order=[];
 cards.forEach(card=>{const r=rowFor(card),k=r?key(r):`card:${order.length}`;if(!groups.has(k)){groups.set(k,{key:k,rows:[],cards:[]});order.push(k)};groups.get(k).cards.push(card);if(r)groups.get(k).rows.push(r)});
 host.replaceChildren();
 order.forEach(k=>{const g=groups.get(k);if(g.rows.length<2||g.rows.length!==g.cards.length){g.cards.forEach(c=>host.appendChild(c));return}
  const first=g.rows[0],total=g.rows.reduce((s,o)=>s+num(o.total),0),qty=g.rows.reduce((s,o)=>s+Math.max(1,num(o.qty||o.quantity)),0),delivery=g.rows.reduce((s,o)=>s+num(o.delivery_fee),0);
  const a=document.createElement('article');a.className='alin-order-group';
  const parking=document.createElement('div');parking.hidden=true;parking.className='alin-order-card-parking';g.cards.forEach(c=>parking.appendChild(c));g.cardParking=parking;groupsByKey.set(k,g);
  a.innerHTML=`<div class="alin-order-group-head"><div><h3>${esc(first.order_number||first.id)}</h3><p>${esc(first.student_name||'بدون اسم')} • ${esc(first.student_phone||'بدون هاتف')}</p><div class="alin-order-group-main"><span class="alin-order-pill">${g.rows.length} مواد</span><span class="alin-order-pill">${qty} قطعة/نسخة</span><span class="alin-order-pill">${esc(groupStatus(g.rows))}</span></div></div><div class="alin-order-group-actions"><div><small>الإجمالي</small><div class="alin-order-group-total">${money(total)} د.ع</div>${delivery?`<small>منها توصيل ${money(delivery)} د.ع</small>`:''}</div><button type="button" class="alin-order-list-btn" data-group-key="${esc(k)}">عرض القائمة</button></div></div>`;
  a.appendChild(parking);host.appendChild(a)
 });
 host.dataset.grouped='1';const count=document.querySelector('#adminContent .admin-orders-v126-head-actions span');if(count)count.textContent=String(order.length)
}
function render(...args){const r=old(...args);Promise.resolve(r).finally(()=>requestAnimationFrame(()=>setTimeout(enhance,0)));return r}
window.renderOrdersAdmin=render;if(window.AlinAdminModules?.register)window.AlinAdminModules.register('orders',render);
document.addEventListener('click',e=>{const b=e.target.closest?.('.alin-order-list-btn');if(b)prepModal(b.dataset.groupKey)});
window.addEventListener('alin:data-refreshed',()=>setTimeout(enhance,0));window.addEventListener('alin:admin-tab',e=>{if(e.detail?.tab==='orders')setTimeout(enhance,0)});
})();
