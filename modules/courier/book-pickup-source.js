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

  const observer=new MutationObserver(()=>decorate());
  function boot(){
    decorate();
    const root=document.getElementById('courierV161Content');if(root)observer.observe(root,{childList:true,subtree:true});
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
  window.addEventListener('alin:data-refreshed',decorate);
})();
