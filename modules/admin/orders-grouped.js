// Group rows created by the same checkout into one visible admin card.
(function(){
'use strict';
const old=window.renderOrdersAdmin;if(typeof old!=='function')return;
const arr=v=>Array.isArray(v)?v:[];
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const num=v=>Number(v||0)||0;
const money=v=>typeof window.money==='function'?window.money(v):Math.round(num(v)).toLocaleString('ar-IQ');
const key=o=>String(o?.checkout_group_id||o?.checkout_request_key||`single:${o?.id||o?.order_number}`);
const rows=()=>arr(window.db?.orders);
const codeOf=card=>String(card.querySelector('.admin-order-v126-title > span')?.textContent||'').trim();
const rowFor=card=>{const c=codeOf(card);return rows().find(o=>String(o.order_number||o.id)===c)||null};
function css(){if(document.getElementById('alinGroupedOrdersCss'))return;const s=document.createElement('style');s.id='alinGroupedOrdersCss';s.textContent='.alin-order-group{border:1px solid #dce5ef;border-radius:18px;background:#fff;margin-bottom:14px;overflow:hidden}.alin-order-group-head{display:flex;justify-content:space-between;gap:12px;padding:16px;border-bottom:1px solid #edf1f5}.alin-order-group-head h3{margin:0 0 4px}.alin-order-group-head p{margin:0;color:#667085}.alin-order-group-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;padding:12px 16px}.alin-order-group-grid span{background:#f8fafc;border-radius:10px;padding:8px;font-size:12px;color:#667085}.alin-order-group-grid b{display:block;color:#172b4d;margin-top:3px}.alin-order-group-items{padding:0 16px 10px}.alin-order-group-item{display:grid;grid-template-columns:1fr auto auto;gap:10px;padding:9px 0;border-top:1px dashed #e5eaf0}.alin-order-group details{border-top:1px solid #edf1f5}.alin-order-group summary{cursor:pointer;padding:12px 16px;font-weight:700}.alin-order-group-manage{padding:0 12px 12px}@media(max-width:760px){.alin-order-group-grid{grid-template-columns:1fr 1fr}.alin-order-group-item{grid-template-columns:1fr auto}.alin-order-group-item .amt{grid-column:2}}';document.head.appendChild(s)}
function grouped(data){const m=new Map();data.forEach(o=>{const k=key(o);if(!m.has(k))m.set(k,[]);m.get(k).push(o)});return m}
function enhance(){
 css();const host=document.querySelector('#adminContent .admin-orders-v126-list');if(!host||host.dataset.grouped==='1')return;
 const cards=[...host.children].filter(x=>x.classList?.contains('admin-order-v126'));if(!cards.length)return;
 const groups=new Map(),order=[];
 cards.forEach(card=>{const r=rowFor(card),k=r?key(r):`card:${order.length}`;if(!groups.has(k)){groups.set(k,{rows:[],cards:[]});order.push(k)};groups.get(k).cards.push(card);if(r)groups.get(k).rows.push(r)});
 host.replaceChildren();
 order.forEach(k=>{const g=groups.get(k);if(g.rows.length<2||g.rows.length!==g.cards.length){g.cards.forEach(c=>host.appendChild(c));return}
  const first=g.rows[0],total=g.rows.reduce((s,o)=>s+num(o.total),0),qty=g.rows.reduce((s,o)=>s+Math.max(1,num(o.qty||o.quantity)),0),delivery=g.rows.reduce((s,o)=>s+num(o.delivery_fee),0);
  const a=document.createElement('article');a.className='alin-order-group';a.innerHTML=`<div class="alin-order-group-head"><div><h3>${esc(first.order_number||first.id)}</h3><p>${esc(first.student_name||'بدون اسم')} • ${esc(first.student_phone||'بدون هاتف')}</p></div><b>${g.rows.length} مواد</b></div><div class="alin-order-group-grid"><span>عدد المواد<b>${g.rows.length}</b></span><span>إجمالي الكمية<b>${qty}</b></span><span>التوصيل<b>${money(delivery)} د.ع</b></span><span>الإجمالي<b>${money(total)} د.ع</b></span></div><div class="alin-order-group-items">${g.rows.map(o=>`<div class="alin-order-group-item"><b>${esc(o.title||'مادة')}</b><span>× ${Math.max(1,num(o.qty||o.quantity))}</span><span class="amt">${money(o.total)} د.ع</span></div>`).join('')}</div><details><summary>إدارة مواد الطلب</summary><div class="alin-order-group-manage"></div></details>`;
  const manage=a.querySelector('.alin-order-group-manage');g.cards.forEach(c=>manage.appendChild(c));host.appendChild(a)
 });
 host.dataset.grouped='1';const count=document.querySelector('#adminContent .admin-orders-v126-head-actions span');if(count)count.textContent=String(order.length)
}
function render(...args){const r=old(...args);Promise.resolve(r).finally(()=>requestAnimationFrame(()=>setTimeout(enhance,0)));return r}
window.renderOrdersAdmin=render;if(window.AlinAdminModules?.register)window.AlinAdminModules.register('orders',render);
window.addEventListener('alin:data-refreshed',()=>setTimeout(enhance,0));window.addEventListener('alin:admin-tab',e=>{if(e.detail?.tab==='orders')setTimeout(enhance,0)});
})();
