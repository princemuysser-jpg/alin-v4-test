// Group checkout rows into one admin order card and expose courier assignment directly.
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
 .alin-order-list-btn{border:0;border-radius:12px;padding:10px 15px;background:#173b67;color:#fff;font-weight:800;cursor:pointer}
 .alin-order-group-items{margin:0 16px 12px;padding:12px 14px;border:1px solid #e6edf5;border-radius:14px;background:#fbfdff}.alin-order-group-items h4{margin:0 0 8px;font-size:14px;color:#173b67}.alin-order-group-item{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:7px 0;border-bottom:1px dashed #e2e8f0}.alin-order-group-item:last-child{border-bottom:0}.alin-order-group-item b{font-size:13px}.alin-order-group-item span{font-size:12px;color:#64748b;white-space:nowrap}
 .alin-order-group-courier{margin:0 16px 16px;padding:14px;border:1px solid #b9d3ef;border-radius:14px;background:#f1f7ff}.alin-order-group-courier h3{margin:0 0 8px;font-size:15px;color:#173b67}.alin-order-group-courier-row{display:flex;gap:8px;align-items:end;flex-wrap:wrap}.alin-order-group-courier label{flex:1;min-width:220px;font-size:12px;color:#64748b}.alin-order-group-courier select{display:block;width:100%;margin-top:5px;padding:10px;border:1px solid #cbd5e1;border-radius:10px;background:white}.alin-order-group-courier button{border:0;border-radius:10px;padding:10px 14px;background:#173b67;color:white;font-weight:800;cursor:pointer}.alin-order-group-courier button:disabled{opacity:.55;cursor:not-allowed}
 .alin-order-prep-backdrop{position:fixed;inset:0;z-index:10050;background:rgba(15,23,42,.55);display:flex;align-items:center;justify-content:center;padding:18px}.alin-order-prep-modal{width:min(1040px,96vw);max-height:92vh;overflow:auto;background:#fff;border-radius:22px}.alin-order-prep-head{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;padding:18px 20px;border-bottom:1px solid #e7edf4}.alin-order-prep-close{border:0;background:#f1f5f9;border-radius:11px;width:40px;height:40px;font-size:22px;cursor:pointer}.alin-order-prep-table-wrap{padding:18px 20px;overflow:auto}.alin-order-prep-table{width:100%;border-collapse:collapse;min-width:720px}.alin-order-prep-table th,.alin-order-prep-table td{padding:10px;border-bottom:1px solid #edf1f5;text-align:right}.alin-order-prep-summary{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;padding:0 20px 18px}.alin-order-prep-summary span{background:#f8fafc;border-radius:12px;padding:10px;color:#667085;font-size:12px}.alin-order-prep-summary b{display:block;color:#172b4d}
 @media(max-width:760px){.alin-order-group-head{align-items:flex-start;flex-direction:column}.alin-order-group-actions{width:100%;justify-content:space-between}.alin-order-group-item{align-items:flex-start}.alin-order-group-courier-row{display:block}.alin-order-group-courier button{width:100%;margin-top:8px}.alin-order-prep-summary{grid-template-columns:1fr 1fr}}
 `;document.head.appendChild(s)
}
function isHomeDelivery(o){return ['home_delivery','delivery','courier'].includes(String(o?.fulfillment_type||o?.delivery_type||''))}
function groupStatus(list){const st=[...new Set(list.map(statusOf))];return st.length===1?statusLabel(list[0]):'حالات متعددة'}
function groupCourierId(list){return String(list.map(o=>o.courier_id||o.delegate_id).find(Boolean)||'')}
function allCouriers(){
 const core=window.AlinCourierCore;if(core?.allCouriers)return core.allCouriers();
 const all=[...arr(window.db?.accounts?.couriers),...arr(window.db?.accounts?.delegates),...arr(window.db?.couriers),...arr(window.db?.delegates)];
 const map=new Map();for(const c of all){const id=String(c?.account_id||c?.id||'');if(id)map.set(id,{...(map.get(id)||{}),...c,id})}return [...map.values()]
}
function matchingCouriers(area){
 const core=window.AlinCourierCore;if(core?.matchingCouriers){const x=core.matchingCouriers(area);if(x?.length)return x}
 const normalize=v=>window.alinNormalizeDeliveryArea?.(v)||String(v||'').trim();const target=normalize(area);const active=allCouriers().filter(c=>String(c?.status||'active')!=='inactive');
 const matches=active.filter(c=>{let raw=c.areas||c.area_ids||c.area||[];if(typeof raw==='string'){try{const p=JSON.parse(raw);raw=Array.isArray(p)?p:raw.split(/[,،|]/)}catch(_){raw=raw.split(/[,،|]/)}}return arr(raw).some(a=>normalize(typeof a==='object'?(a.name||a.area||a.id):a)===target)});
 return matches.length?matches:(target==='كركوك'?active:matches)
}
function materialsHtml(g){return `<section class="alin-order-group-items"><h4>مواد الطلب</h4>${g.rows.map((o,i)=>`<div class="alin-order-group-item"><b>${i+1}. ${esc(o.title||'مادة')}</b><span>× ${Math.max(1,num(o.qty||o.quantity))} • ${money(o.total||0)} د.ع</span></div>`).join('')}</section>`}
function courierAssignmentHtml(g){
 const first=g.rows[0];if(!isHomeDelivery(first))return'';
 const core=window.AlinCourierCore,all=allCouriers(),options=matchingCouriers(first.delivery_area),current=groupCourierId(g.rows);
 const currentCourier=all.find(c=>[c.id,c.account_id,c.courier_row_id].filter(Boolean).map(String).includes(current));if(currentCourier&&!options.some(c=>String(c.id)===String(currentCourier.id)))options.unshift(currentCourier);
 const opts=options.length?options.map(c=>`<option value="${esc(c.id)}" ${current&&[c.id,c.account_id,c.courier_row_id].filter(Boolean).map(String).includes(current)?'selected':''}>${esc(c.name||c.username||'مندوب')} • ${esc(c.phone||'')}</option>`).join(''):'<option value="" disabled>لا يوجد مندوب مطابق للمنطقة</option>';
 return `<section class="alin-order-group-courier"><h3>تعيين مندوب للطلب كامل</h3><div class="alin-order-group-courier-row"><label>المندوب<select class="alin-order-group-courier-select"><option value="">بدون مندوب</option>${opts}</select></label><button type="button" class="alin-order-group-assign-btn" data-group-key="${esc(g.key)}" ${!core?.assignOrder?'disabled':''}>${current?'حفظ المندوب':'تعيين المندوب'}</button></div><small>${core?.assignOrder?'يتم تطبيق المندوب على كل مواد هذا الطلب دفعة واحدة.':'حدّث الصفحة لتفعيل خدمة التعيين.'}</small></section>`
}
function prepModal(groupKey){
 const g=groupsByKey.get(String(groupKey));if(!g?.rows?.length)return;document.querySelector('.alin-order-prep-backdrop')?.remove();
 const list=g.rows,first=list[0],total=list.reduce((s,o)=>s+num(o.total),0),delivery=list.reduce((s,o)=>s+num(o.delivery_fee),0),discount=list.reduce((s,o)=>s+num(o.discount),0);
 const el=document.createElement('div');el.className='alin-order-prep-backdrop';el.innerHTML=`<section class="alin-order-prep-modal"><header class="alin-order-prep-head"><div><h2>قائمة تجهيز الطلب</h2><p>${esc(first.student_name||'بدون اسم')} • ${esc(first.student_phone||'بدون هاتف')}</p></div><button class="alin-order-prep-close">×</button></header><div class="alin-order-prep-table-wrap"><table class="alin-order-prep-table"><thead><tr><th>#</th><th>المادة</th><th>الكمية</th><th>الإجمالي</th><th>الحالة</th></tr></thead><tbody>${list.map((o,i)=>`<tr><td>${i+1}</td><td>${esc(o.title||'مادة')}</td><td>× ${Math.max(1,num(o.qty||o.quantity))}</td><td>${money(o.total||0)} د.ع</td><td>${esc(statusLabel(o))}</td></tr>`).join('')}</tbody></table></div><section class="alin-order-prep-summary"><span>المواد<b>${money(total-delivery)} د.ع</b></span><span>التوصيل<b>${money(delivery)} د.ع</b></span><span>الخصم<b>${money(discount)} د.ع</b></span><span>الإجمالي<b>${money(total)} د.ع</b></span></section>${courierAssignmentHtml(g)}</section>`;
 const close=()=>el.remove();el.querySelector('.alin-order-prep-close')?.addEventListener('click',close);el.addEventListener('click',e=>{if(e.target===el)close()});document.body.appendChild(el)
}
function enhance(){
 css();const host=document.querySelector('#adminContent .admin-orders-v126-list');if(!host||host.dataset.grouped==='1')return;const cards=[...host.children].filter(x=>x.classList?.contains('admin-order-v126'));if(!cards.length)return;
 groupsByKey.clear();const groups=new Map(),order=[];cards.forEach(card=>{const r=rowFor(card),k=r?key(r):`card:${order.length}`;if(!groups.has(k)){groups.set(k,{key:k,rows:[],cards:[]});order.push(k)};groups.get(k).cards.push(card);if(r)groups.get(k).rows.push(r)});host.replaceChildren();
 order.forEach(k=>{const g=groups.get(k);groupsByKey.set(k,g);if(!g.rows.length||g.rows.length!==g.cards.length){g.cards.forEach(c=>host.appendChild(c));return}
  if(g.rows.length===1){const card=g.cards[0];host.appendChild(card);if(isHomeDelivery(g.rows[0]))card.insertAdjacentHTML('beforeend',courierAssignmentHtml(g));return}
  const first=g.rows[0],total=g.rows.reduce((s,o)=>s+num(o.total),0),qty=g.rows.reduce((s,o)=>s+Math.max(1,num(o.qty||o.quantity)),0),delivery=g.rows.reduce((s,o)=>s+num(o.delivery_fee),0),a=document.createElement('article');a.className='alin-order-group';
  a.innerHTML=`<div class="alin-order-group-head"><div><h3>${esc(first.order_number||first.id)}</h3><p>${esc(first.student_name||'بدون اسم')} • ${esc(first.student_phone||'بدون هاتف')}</p><div class="alin-order-group-main"><span class="alin-order-pill">${g.rows.length} مواد</span><span class="alin-order-pill">${qty} قطعة/نسخة</span><span class="alin-order-pill">${esc(groupStatus(g.rows))}</span></div></div><div class="alin-order-group-actions"><div><small>الإجمالي</small><div class="alin-order-group-total">${money(total)} د.ع</div>${delivery?`<small>منها توصيل ${money(delivery)} د.ع</small>`:''}</div><button type="button" class="alin-order-list-btn" data-group-key="${esc(k)}">عرض القائمة</button></div></div>${materialsHtml(g)}${courierAssignmentHtml(g)}`;host.appendChild(a)
 });
 host.dataset.grouped='1';const count=document.querySelector('#adminContent .admin-orders-v126-head-actions span');if(count)count.textContent=String(order.length)
}
function render(...args){const r=old(...args);Promise.resolve(r).finally(()=>requestAnimationFrame(()=>setTimeout(enhance,0)));return r}
window.renderOrdersAdmin=render;if(window.AlinAdminModules?.register)window.AlinAdminModules.register('orders',render);
document.addEventListener('click',async e=>{
 const listBtn=e.target.closest?.('.alin-order-list-btn');if(listBtn){prepModal(listBtn.dataset.groupKey);return}
 const btn=e.target.closest?.('.alin-order-group-assign-btn');if(!btn)return;const g=groupsByKey.get(String(btn.dataset.groupKey));if(!g?.rows?.length)return;const select=btn.closest('.alin-order-group-courier')?.querySelector('.alin-order-group-courier-select'),courierId=String(select?.value||'').trim()||null,core=window.AlinCourierCore;if(!core?.assignOrder){window.toast?.('خدمة تعيين المندوب غير جاهزة');return}
 btn.disabled=true;try{await core.assignOrder(String(g.rows[0].id),courierId,null);await Promise.resolve(window.renderOrdersAdmin?.());window.toast?.(courierId?'تم تعيين المندوب للطلب كامل':'تم إلغاء تعيين المندوب عن الطلب كامل')}catch(error){console.error(error);window.toast?.(core.friendlyOrderError?.(error)||error?.message||'تعذر تعيين المندوب')}finally{btn.disabled=false}
});
window.addEventListener('alin:data-refreshed',()=>setTimeout(enhance,0));window.addEventListener('alin:admin-tab',e=>{if(e.detail?.tab==='orders')setTimeout(enhance,0)});
})();