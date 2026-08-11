/* ALIN v2.2.6 — teacher orders and finance views backed only by AlinFinance. */
(function(){
  'use strict';
  if(!window.TeacherApp)throw new Error('TeacherApp must load before teacher/finance.js');
  window.AlinTeacherModules=window.AlinTeacherModules||{};
  const arr=value=>Array.isArray(value)?value:[];
  const same=(a,b)=>String(a??'')===String(b??'');
  const escv=value=>typeof window.esc==='function'?window.esc(value):String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const moneyv=value=>typeof window.money==='function'?window.money(value):Math.round(Number(value)||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const dateOnly=value=>String(value||'').slice(0,10)||'-';
  const done=new Set(['delivered','completed','done','received','settled']);
  const cancelled=new Set(['cancelled','canceled','rejected']);
  const finance=()=>window.AlinFinance;

  function data(){return window.TeacherApp.data()}
  function statusText(value){const key=String(value||'new').toLowerCase();return({new:'جديد',pending:'قيد الانتظار',assigned:'تم التحويل',accepted:'مقبول',processing:'قيد التجهيز',printing:'قيد الطباعة',ready:'جاهز',picked_up:'تم الاستلام',out_for_delivery:'قيد التوصيل',delivered:'تم التسليم',completed:'مكتمل',done:'مكتمل',cancelled:'ملغي',canceled:'ملغي',rejected:'مرفوض'})[key]||key}
  function statusGroup(value){const key=String(value||'').toLowerCase();return done.has(key)?'done':cancelled.has(key)?'cancelled':'active'}

  function teacherSummary(id){
    return finance()?.teacherSummary?.(id)||{earned:0,paid:0,remaining:0,monthEarn:0,rows:[],payouts:[]};
  }

  function teacherAccountPaid(id){return teacherSummary(id).paid}
  function alinV67SumTeacherBalances(){return arr(window.db?.accounts?.teachers).reduce((sum,row)=>sum+Number(teacherSummary(row.id).remaining||0),0)}
  function addTeacherPayoutPrompt(id){return finance()?.payBalance?.('teacher',id)}

  function renderOrders(){
    const d=data();
    const totalQty=d.orders.reduce((sum,row)=>sum+(Number(row.qty)||1),0);
    const active=d.orders.filter(row=>statusGroup(row.status)==='active').length;
    const completed=d.orders.filter(row=>statusGroup(row.status)==='done').length;
    const libraries=arr(window.db?.accounts?.libraries);
    const cards=d.orders.slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||''))).map(order=>{
      const book=d.books.find(row=>same(row.id,order.item_id||order.booklet_id));
      const library=libraries.find(row=>same(row.id,order.library_id));
      const group=statusGroup(order.status);
      return `<article class="teacher-v154-order" data-search="${escv(`${order.order_number||order.id} ${order.title||book?.title||''}`.toLowerCase())}" data-status="${group}" data-library="${escv(order.library_id||'')}" data-date="${escv(dateOnly(order.created_at))}"><div><h4>${escv(order.order_number||order.id)} — ${escv(order.title||book?.title||'ملزمة')}</h4><small>النسخ: ${Number(order.qty)||1} • المكتبة: ${escv(library?.name||'-')} • ${dateOnly(order.created_at)}</small></div><div class="teacher-v154-order-side"><span class="teacher-v154-status ${group}">${escv(statusText(order.status))}</span><b>${moneyv(order.total)} د.ع</b></div></article>`;
    }).join('')||'<div class="teacher-v154-empty">لا توجد طلبات مرتبطة بملازمك.</div>';
    window.teacherContent.innerHTML=`<div class="teacher-v154-shell"><div class="teacher-v154-head"><div><h3>مبيعات وطلبات ملازمي</h3><p>عرض الطلبات من مصدر واحد بدون احتساب الطلبات الملغاة كأرباح.</p></div></div><div class="teacher-v154-summary"><div class="teacher-v154-stat"><small>إجمالي الطلبات</small><b>${d.orders.length}</b></div><div class="teacher-v154-stat"><small>قيد التنفيذ</small><b>${active}</b></div><div class="teacher-v154-stat"><small>مكتملة</small><b>${completed}</b></div><div class="teacher-v154-stat gold"><small>إجمالي النسخ</small><b>${totalQty}</b></div></div><div class="teacher-v154-tools"><input id="tv154OrderSearch" placeholder="ابحث برقم الطلب أو اسم الملزمة" data-alin-input="teacherV154FilterOrders"><select id="tv154OrderStatus" data-alin-change="teacherV154FilterOrders"><option value="">كل الحالات</option><option value="active">قيد التنفيذ</option><option value="done">مكتمل</option><option value="cancelled">ملغي</option></select></div><div id="teacherV154Orders" class="teacher-v154-list">${cards}</div></div>`;
  }

  function teacherV154FilterOrders(){
    const q=(document.getElementById('tv154OrderSearch')?.value||'').trim().toLowerCase();
    const status=document.getElementById('tv154OrderStatus')?.value||'';
    document.querySelectorAll('#teacherV154Orders .teacher-v154-order').forEach(card=>{card.hidden=Boolean((q&&!String(card.dataset.search||'').includes(q))||(status&&card.dataset.status!==status))});
  }

  function financeRows(id){
    const d=data();
    return teacherSummary(id).rows.slice().sort((a,b)=>String(b.settled_at||b.created_at||'').localeCompare(String(a.settled_at||a.created_at||''))).map(row=>{
      const order=d.orders.find(item=>same(item.id,row.order_id)||same(item.order_number,row.order_number||row.order_id));
      return `<tr><td>${escv(row.order_number||row.order_id)}</td><td>${escv(order?.title||'-')}</td><td>${dateOnly(row.settled_at||row.created_at)}</td><td>${moneyv(row.teacher||row.teacher_amount)} د.ع</td></tr>`;
    }).join('')||'<tr><td colspan="4">لا توجد أرباح من طلبات مسلّمة.</td></tr>';
  }

  function renderFinance(){
    const d=data(),summary=teacherSummary(d.id);
    const payouts=summary.payouts.slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||''))).map(row=>`<div class="teacher-v154-payout"><div><b>${moneyv(row.amount)} د.ع</b><small>${dateOnly(row.created_at)} • ${escv(row.note||'تسوية أرباح')}</small></div><span class="teacher-v154-status ${String(row.status||'').toLowerCase()==='paid'?'done':'active'}">${String(row.status||'').toLowerCase()==='paid'?'مدفوعة':'قيد الانتظار'}</span></div>`).join('')||'<div class="teacher-v154-empty">لا توجد تسويات سابقة.</div>';
    window.teacherContent.innerHTML=`<div class="teacher-v154-shell"><div class="teacher-v154-head"><div><h3>الأرباح والتسويات</h3><p>تُحتسب الأرباح من الطلبات المسلّمة فقط.</p></div><div class="teacher-v154-actions"><button data-alin-click="printTeacherStatement">طباعة كشف الحساب</button><button class="secondary" data-alin-click="teacherV154ExportFinance">تصدير CSV</button></div></div><div class="teacher-v154-summary"><div class="teacher-v154-stat gold"><small>إجمالي الأرباح</small><b>${moneyv(summary.earned)} د.ع</b></div><div class="teacher-v154-stat"><small>أرباح هذا الشهر</small><b>${moneyv(summary.monthEarn)} د.ع</b></div><div class="teacher-v154-stat"><small>المبلغ المدفوع</small><b>${moneyv(summary.paid)} د.ع</b></div><div class="teacher-v154-stat gold"><small>الرصيد الحالي</small><b>${moneyv(summary.remaining)} د.ع</b></div></div><section><h3>كشف الأرباح</h3><div class="teacher-v154-ledger"><table class="teacher-v154-table"><thead><tr><th>رقم الطلب</th><th>الملزمة</th><th>التاريخ</th><th>ربح المدرس</th></tr></thead><tbody>${financeRows(d.id)}</tbody></table></div></section><section><h3>التسويات السابقة</h3><div class="teacher-v154-payouts">${payouts}</div></section></div>`;
  }

  function printTeacherStatement(){
    const d=data(),summary=teacherSummary(d.id);
    const teacherName=escv(d.teacher?.name||window.current?.name||'المدرس');
    const generatedAt=new Date().toLocaleString('ar-IQ');
    const rows=summary.rows.slice().sort((a,b)=>String(b.settled_at||b.created_at||'').localeCompare(String(a.settled_at||a.created_at||'')));
    const orderTitle=row=>{
      const order=(d.orders||[]).find(item=>same(item.id,row.order_id)||same(item.order_number,row.order_number||row.order_id));
      return escv(order?.title||order?.item_title||order?.booklet_title||'-');
    };
    const rowsHtml=rows.map((row,index)=>`<tr><td>${index+1}</td><td dir="ltr">${escv(row.order_number||row.order_id||'-')}</td><td>${orderTitle(row)}</td><td>${dateOnly(row.settled_at||row.created_at)}</td><td>${moneyv(row.teacher||row.teacher_amount)} د.ع</td></tr>`).join('')||'<tr><td colspan="5" class="empty">لا توجد حركات مالية مسجلة.</td></tr>';
    const payoutsHtml=summary.payouts.slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||''))).map((row,index)=>`<tr><td>${index+1}</td><td>${dateOnly(row.created_at)}</td><td>${escv(row.note||'تسوية أرباح')}</td><td>${moneyv(row.amount)} د.ع</td><td>${String(row.status||'').toLowerCase()==='paid'?'مدفوعة':'قيد الانتظار'}</td></tr>`).join('')||'<tr><td colspan="5" class="empty">لا توجد تسويات سابقة.</td></tr>';
    const documentHtml=`<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>كشف حساب المدرس</title><style>
      @page{size:A4;margin:11mm}*{box-sizing:border-box}html,body{margin:0;padding:0;background:#fff;color:#102b4e;font-family:Tahoma,"Segoe UI",Arial,sans-serif}.sheet{width:100%;max-width:190mm;margin:0 auto;border:1px solid #dce5ef;background:#fff}.head{display:flex;justify-content:space-between;gap:18px;align-items:center;padding:20px 22px;border-top:9px solid #0b3f70;border-bottom:2px solid #d8b35e}.brand{display:flex;align-items:center;gap:12px}.mark{display:grid;place-items:center;width:54px;height:54px;border-radius:15px;background:#0b3f70;color:#f0c86e;font-size:25px;font-weight:900}.head h1{margin:0;font-size:24px}.head p{margin:5px 0 0;color:#69798c}.meta{text-align:left}.meta b,.meta small{display:block}.meta small{color:#9b741d}.summary{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;padding:16px 22px}.summary div{padding:13px;border:1px solid #e0e7ef;border-radius:10px;background:#f8fbfe}.summary small,.summary b{display:block}.summary small{color:#68798d}.summary b{margin-top:6px;font-size:19px}.summary .balance{background:#fff7e6;border-color:#d8b35e}.section{padding:0 22px 16px}.section h2{margin:5px 0 10px;font-size:17px}.table-wrap{overflow:visible}table{width:100%;border-collapse:collapse;font-size:12px}th,td{border:1px solid #dfe6ee;padding:8px;text-align:right;vertical-align:top}th{background:#edf3f8;color:#0b3f70}.empty{text-align:center;color:#78879a;padding:18px}.footer{display:flex;justify-content:space-between;gap:15px;padding:13px 22px;background:#0b3f70;color:#fff;font-size:11px}.footer span:last-child{text-align:left}@media(max-width:700px){.head{align-items:flex-start;flex-direction:column}.meta{text-align:right}.summary{grid-template-columns:1fr}.table-wrap{overflow:auto}.sheet{border:0}}@media print{body{-webkit-print-color-adjust:exact;print-color-adjust:exact}.sheet{border:0}.head{break-inside:avoid}.summary{break-inside:avoid}thead{display:table-header-group}tr{break-inside:avoid;page-break-inside:avoid}.footer{break-inside:avoid}}
    </style></head><body><main class="sheet"><header class="head"><div class="brand"><span class="mark">آ</span><div><h1>كشف حساب المدرس</h1><p>${teacherName}</p></div></div><div class="meta"><small>تاريخ الإصدار</small><b>${escv(generatedAt)}</b></div></header><section class="summary"><div><small>إجمالي الأرباح</small><b>${moneyv(summary.earned)} د.ع</b></div><div><small>المبلغ المدفوع</small><b>${moneyv(summary.paid)} د.ع</b></div><div class="balance"><small>الرصيد الحالي</small><b>${moneyv(summary.remaining)} د.ع</b></div></section><section class="section"><h2>تفاصيل الأرباح</h2><div class="table-wrap"><table><thead><tr><th>#</th><th>رقم الطلب</th><th>الملزمة</th><th>التاريخ</th><th>ربح المدرس</th></tr></thead><tbody>${rowsHtml}</tbody></table></div></section><section class="section"><h2>التسويات السابقة</h2><div class="table-wrap"><table><thead><tr><th>#</th><th>التاريخ</th><th>البيان</th><th>المبلغ</th><th>الحالة</th></tr></thead><tbody>${payoutsHtml}</tbody></table></div></section><footer class="footer"><span>منصة آلين</span><span>كشف مالي مُنشأ من بيانات الحساب المسجلة في المنصة</span></footer></main></body></html>`;

    const popup=window.open('','_blank','width=980,height=760');
    if(popup){
      try{popup.opener=null}catch(_){ }
      popup.document.open();popup.document.write(documentHtml);popup.document.close();
      const doPrint=()=>setTimeout(()=>{try{popup.focus();popup.print()}catch(error){console.warn('[ALIN teacher statement] print',error)}},260);
      if(popup.document.readyState==='complete')doPrint();else popup.addEventListener('load',doPrint,{once:true});
      return true;
    }

    if(window.checkoutBox&&window.checkoutModal){
      window.checkoutBox.innerHTML=`<section class="teacher-statement-fallback"><div class="teacher-statement-fallback-head"><div><h2>كشف حساب المدرس</h2><p>تعذّر فتح نافذة الطباعة الجديدة؛ استخدم الزر أدناه.</p></div></div><iframe id="teacherStatementFrame" title="معاينة كشف حساب المدرس" style="width:100%;height:min(70vh,760px);border:1px solid #dce5ef;border-radius:14px;background:#fff"></iframe><div class="row-actions no-print"><button type="button" data-alin-click="@frame-print" data-alin-click-target="teacherStatementFrame">طباعة الكشف</button><button type="button" class="secondary" data-alin-click="closeCheckout">إغلاق</button></div></section>`;
      const frame=document.getElementById('teacherStatementFrame');if(frame)frame.srcdoc=documentHtml;
      window.checkoutModal.classList.remove('hidden');
    }
    return false;
  }

  function teacherV154ExportFinance(){
    const d=data(),summary=teacherSummary(d.id);
    const rows=[['رقم الطلب','التاريخ','ربح المدرس'],...summary.rows.map(row=>[row.order_number||row.order_id,dateOnly(row.settled_at||row.created_at),row.teacher||row.teacher_amount||0]),[],['الإجمالي',summary.earned],['المدفوع',summary.paid],['المتبقي',summary.remaining]];
    const csv='\ufeff'+rows.map(row=>row.map(value=>`"${String(value??'').replace(/"/g,'""')}"`).join(',')).join('\n');
    const link=document.createElement('a');link.href=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));link.download='teacher-finance.csv';link.click();setTimeout(()=>URL.revokeObjectURL(link.href),1000);
  }

  window.teacherAccountPaid=teacherAccountPaid;
  window.alinV67SumTeacherBalances=alinV67SumTeacherBalances;
  window.addTeacherPayoutPrompt=addTeacherPayoutPrompt;
  window.printTeacherStatement=printTeacherStatement;
  window.teacherV154FilterOrders=teacherV154FilterOrders;
  window.teacherV154ExportFinance=teacherV154ExportFinance;
  window.AlinTeacherModules.teacherAccountPaid=teacherAccountPaid;
  window.AlinTeacherModules.printTeacherStatement=printTeacherStatement;
  window.TeacherApp.registerTab('orders',renderOrders);
  window.TeacherApp.registerTab('finance',renderFinance);
  window.TeacherFinanceV154={renderOrders,renderFinance,data};
})();
