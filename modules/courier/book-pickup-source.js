// === courier/book-pickup-source.js ===
// Shows the physical pickup source for book deliveries without changing the
// existing courier state machine or finance calculations.
(function(){
  'use strict';
  const esc=v=>String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const orders=()=>Array.isArray(window.db?.orders)?window.db.orders:[];
  const byId=id=>orders().find(o=>String(o.id)===String(id));

  function decorate(){
    document.querySelectorAll('.v174-order[data-courier-order]').forEach(card=>{
      if(card.querySelector('.alin-book-pickup-source'))return;
      const order=byId(card.dataset.courierOrder);
      if(!order||String(order.kind||'').toLowerCase()!=='book')return;
      const label=String(order.pickup_source_label||'منصة آلين').trim()||'منصة آلين';
      const data=card.querySelector('.v174-order-data');if(!data)return;
      const node=document.createElement('div');node.className='wide alin-book-pickup-source';
      node.innerHTML=`<small>استلم الطلب من</small><b>${esc(label)}</b>`;
      data.insertBefore(node,data.firstChild);
    });
  }

  function wrapDashboard(){
    const original=window.renderCourierDashboard;
    if(typeof original!=='function'||original.__alinBookPickupWrapped)return;
    const wrapped=async function(...args){
      const result=await original.apply(this,args);
      decorate();
      return result;
    };
    Object.defineProperty(wrapped,'__alinBookPickupWrapped',{value:true});
    window.renderCourierDashboard=wrapped;
  }

  wrapDashboard();
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',decorate,{once:true});else decorate();
  window.addEventListener('alin:data-refreshed',()=>setTimeout(decorate,0));
  window.addEventListener('alin:page-open',event=>{if(event.detail?.page==='courier')setTimeout(decorate,0)});
})();
