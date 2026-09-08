/* ALIN — Printer dashboard: collector debt + book supply account + settlements. */
(function(){
  'use strict';
  if(window.__ALIN_PRINTER_DASHBOARD__)return;
  window.__ALIN_PRINTER_DASHBOARD__=true;

  const money=v=>Math.max(0,Number(v)||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const esc=v=>String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const client=()=>window.ALINAuthRuntime?.client?.()||window.sb||window.AlinCloud?.client?.()||null;
  let cache=null,running=false;

  async function loadSummary(force=false){
    if(cache&&!force)return cache;
    const c=client();if(!c?.rpc)throw new Error('خدمة حسابات المطبعة غير متاحة');
    const {data,error}=await c.rpc('alin_printer_finance_summary');if(error)throw error;
    cache=data||{};return cache;
  }

  function settlementRows(rows,label){
    return (Array.isArray(rows)?rows:[]).map(x=>`<div class="library-v116-row"><div><b>${esc(x.receipt_number||x.id||label)}</b><small>${esc(String(x.created_at||'').slice(0,10))}${x.payment_method?' — '+esc(x.payment_method):''}</small></div><span class="library-v116-money settled">${money(x.amount)} د.ع</span></div>`).join('')||'<div class="library-v116-empty">لا توجد تسويات بعد</div>';
  }

  function bookRows(rows){
    return (Array.isArray(rows)?rows:[]).map(x=>`<div class="library-v120-movement"><div><b>${esc(x.order_number||x.order_id||'طلب كتاب')}</b><small>${esc(x.title||'كتاب')}</small></div><div class="library-v120-split"><span class="profit">+${money(x.amount)} د.ع</span><span class="${x.status==='settled'?'settled':'debt'}">${x.status==='settled'?'مسدد':'مستحق'}</span></div></div>`).join('')||'<div class="library-v116-empty">لا توجد حركات توريد كتب بعد</div>';
  }

  function html(s){
    return `<section class="library-v116-finance alin-printer-finance"><header class="library-v116-header" style="margin-bottom:16px"><div class="library-v116-identity"><div aria-hidden="true" class="library-v116-logo">ط</div><div><small>حساب المطبعة</small><h2>${esc(s.printer_name||window.current?.name||'المطبعة')}</h2><p>ذمة التشغيل وحساب توريد الكتب والتسويات</p></div></div></header>
      <section class="library-v120-finance-cards"><article class="debt"><small>ذمة المطبعة للإدارة</small><strong>${money(s.collector_remaining)} د.ع</strong></article><article class="settled"><small>المسدد من الذمة</small><strong>${money(s.collector_settled)} د.ع</strong></article><article class="profit"><small>توريد الكتب المستحق</small><strong>${money(s.book_supply_pending)} د.ع</strong></article><article><small>توريد الكتب المسدد</small><strong>${money(s.book_supply_settled)} د.ع</strong></article></section>
      <section class="library-v116-grid library-v120-grid" style="margin-top:16px"><div class="library-v116-panel"><h3>حساب توريد الكتب</h3><p class="library-v120-help">هذا الحساب مستقل عن ذمة المطبعة. تسويته من الإدارة تصفّر المستحق فقط وتبقي السجل.</p><div class="library-v120-movements">${bookRows(s.book_rows)}</div></div><aside class="library-v116-panel"><h3>تسويات توريد الكتب</h3><div class="library-v116-list">${settlementRows(s.book_settlements,'تسوية توريد')}</div></aside></section>
      <section class="library-v116-grid library-v120-grid" style="margin-top:16px"><div class="library-v116-panel"><h3>ذمة المطبعة مع الإدارة</h3><div class="library-v120-debt-box"><small>المتبقي بذمة المطبعة</small><strong>${money(s.collector_remaining)} د.ع</strong><span>إجمالي الذمة ${money(s.collector_debt_total)} د.ع — المسدد ${money(s.collector_settled)} د.ع</span></div></div><aside class="library-v116-panel"><h3>تسويات الذمة</h3><div class="library-v116-list">${settlementRows(s.collector_settlements,'تسوية ذمة')}</div></aside></section>
      <div class="row-actions" style="margin-top:16px"><button class="secondary" data-alin-click="AlinPrinterDashboard.refresh">تحديث الحسابات</button><button class="logout" data-alin-click="logout">تسجيل الخروج</button></div>
    </section>`;
  }

  async function render(force=false){
    if(String(window.current?.role||'')!=='printer')return false;
    const page=document.getElementById('libraryPage'),host=document.getElementById('libraryV116Content');if(!page||!host)return false;
    document.querySelector('.library-v116-tabs')?.setAttribute('hidden','');
    const name=document.getElementById('libraryV116Name');if(name)name.textContent=window.current?.name||'المطبعة';
    const loc=document.getElementById('libraryV116Location');if(loc)loc.textContent='الحسابات والتسويات';
    const status=document.getElementById('libraryV116Status');if(status)status.innerHTML='<div class="library-v116-status-card open"><span class="library-v116-status-dot"></span><div><b>حساب مطبعة</b><small>متصل بمنصة آلين</small></div></div>';
    if(running)return true;running=true;
    try{host.innerHTML='<div class="library-v116-empty">جارٍ تحميل حسابات المطبعة...</div>';const s=await loadSummary(force);host.innerHTML=html(s)}catch(e){console.error('[ALIN printer finance]',e);host.innerHTML=`<div class="library-v116-empty">${esc(e?.message||'تعذر تحميل حسابات المطبعة')}</div>`}finally{running=false}
    return true;
  }

  window.AlinPrinterDashboard=Object.freeze({render,refresh:()=>{cache=null;return render(true)}});
  window.renderPrinter=render;
  window.addEventListener('alin:page-open',e=>{if(e.detail?.page==='printer'||(e.detail?.page==='library'&&window.current?.role==='printer'))setTimeout(()=>render(false),0)});
  window.addEventListener('alin:data-refreshed',()=>{if(window.current?.role==='printer'){cache=null;setTimeout(()=>render(true),0)}});
  setTimeout(()=>{if(window.current?.role==='printer')render(false)},100);
})();
