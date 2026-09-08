/* ALIN — Library book-supplier profit panel.
 * Keeps book-supplier earnings separate from legacy library pickup debt/profit.
 */
(function(){
  'use strict';
  if(window.__ALIN_LIBRARY_BOOK_SUPPLIER_PROFIT__)return;
  window.__ALIN_LIBRARY_BOOK_SUPPLIER_PROFIT__=true;

  const num=v=>Math.max(0,Number(v)||0);
  const money=v=>num(v).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const esc=v=>String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const eq=(a,b)=>String(a??'')===String(b??'');
  const current=()=>window.current||null;
  const client=()=>window.ALINAuthRuntime?.client?.()||window.sb||window.AlinCloud?.client?.()||null;

  let cache={id:'',at:0,rows:[]};
  let running=false;

  function libraryId(){
    const c=current();
    if(!c||c.role!=='library')return '';
    const libs=Array.isArray(window.db?.accounts?.libraries)?window.db.accounts.libraries:[];
    const ids=[c.id,c.library_id,c.account_id,c.user_id].filter(Boolean);
    const lib=libs.find(x=>ids.some(id=>eq(x.id,id)||eq(x.account_id,id)||eq(x.user_id,id)))
      ||libs.find(x=>c.username&&eq(x.username,c.username))
      ||libs.find(x=>c.name&&eq(x.name,c.name));
    return String(lib?.id||c.library_id||c.account_id||c.id||'');
  }

  async function rows(force=false){
    const id=libraryId();
    if(!id)return [];
    const now=Date.now();
    if(!force&&cache.id===id&&now-cache.at<10000)return cache.rows;
    const c=client();
    if(!c?.from)return [];
    const {data,error}=await c.from('ledger')
      .select('id,order_id,order_number,title,supplier,supplier_type,supplier_id,supplier_name,supplier_settlement_status,supplier_settled_at,supplier_settlement_id,status,created_at')
      .eq('supplier_type','library')
      .eq('supplier_id',id)
      .gt('supplier',0)
      .order('created_at',{ascending:false});
    if(error){console.error('[ALIN] library book supplier profit',error);return cache.id===id?cache.rows:[]}
    cache={id,at:now,rows:Array.isArray(data)?data:[]};
    return cache.rows;
  }

  function summary(list){
    const valid=list.filter(x=>!['cancelled','reversed'].includes(String(x.status||'')));
    const total=valid.reduce((s,x)=>s+num(x.supplier),0);
    const pending=valid.filter(x=>String(x.supplier_settlement_status||'pending')==='pending').reduce((s,x)=>s+num(x.supplier),0);
    const settled=valid.filter(x=>String(x.supplier_settlement_status||'')==='settled').reduce((s,x)=>s+num(x.supplier),0);
    return {valid,total,pending,settled};
  }

  function panelHtml(s){
    const movements=s.valid.slice(0,30).map(x=>{
      const settled=String(x.supplier_settlement_status||'pending')==='settled';
      return `<div class="library-v120-movement alin-book-supplier-row"><div><b>${esc(x.order_number||x.order_id||'طلب كتاب')}</b><small>${esc(x.title||'كتاب')} — حصة توريد الكتاب</small></div><div class="library-v120-split"><span class="profit">+${money(x.supplier)} د.ع</span><span class="${settled?'settled':'debt'}">${settled?'مسدد':'مستحق'}</span></div></div>`;
    }).join('')||'<div class="library-v116-empty">لا توجد أرباح توريد كتب بعد</div>';

    return `<section id="alinLibraryBookSupplierProfit" class="alin-library-book-supplier-profit" style="margin-top:16px">
      <div class="library-v120-finance-cards">
        <article class="profit"><small>أرباح توريد الكتب</small><strong>${money(s.total)} د.ع</strong></article>
        <article class="debt"><small>المستحق من توريد الكتب</small><strong>${money(s.pending)} د.ع</strong></article>
        <article class="settled"><small>المسدد من توريد الكتب</small><strong>${money(s.settled)} د.ع</strong></article>
      </div>
      <section class="library-v116-panel" style="margin-top:12px">
        <h3>أرباح الكتب الموردة من المكتبة</h3>
        <p class="library-v120-help">هذه الأرباح مستقلة عن ذمة المكتبة الخاصة بطلبات الاستلام والطباعة، ولا تُخصم منها.</p>
        <div class="library-v120-movements">${movements}</div>
      </section>
    </section>`;
  }

  async function decorate(force=false){
    if(running)return;
    if(current()?.role!=='library')return;
    const content=document.getElementById('libraryV116Content');
    if(!content||!content.querySelector('.library-v120-finance-cards'))return;
    running=true;
    try{
      const list=await rows(force);
      const old=document.getElementById('alinLibraryBookSupplierProfit');
      if(old)old.remove();
      content.insertAdjacentHTML('beforeend',panelHtml(summary(list)));
    }finally{running=false}
  }

  function installRenderHook(){
    const base=window.renderLibrary;
    if(typeof base!=='function'||base.__alinBookSupplierProfit)return false;
    const wrapped=function(){
      const result=base.apply(this,arguments);
      setTimeout(()=>decorate(false),0);
      return result;
    };
    wrapped.__alinBookSupplierProfit=true;
    window.renderLibrary=wrapped;
    if(window.AlinLibraryModules?.renderLibrary===base)window.AlinLibraryModules.renderLibrary=wrapped;
    return true;
  }

  document.addEventListener('click',e=>{
    if(e.target.closest('[data-library-tab="finance"]'))setTimeout(()=>decorate(true),30);
  });
  window.addEventListener('alin:data-refreshed',()=>{cache.at=0;setTimeout(()=>decorate(true),30)});
  window.addEventListener('alin:page-open',()=>setTimeout(()=>{installRenderHook();decorate(false)},30));
  window.addEventListener('alin:role-runtime-ready',()=>setTimeout(()=>{installRenderHook();decorate(false)},30));

  installRenderHook();
  setTimeout(()=>{installRenderHook();decorate(false)},300);
})();
