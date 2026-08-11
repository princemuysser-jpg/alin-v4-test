/* ALIN v4.1.5 — isolated receipts center (orders + settlements). */
(function(){
  'use strict';
  if(window.Alin415Receipts)return;

  const arr=value=>Array.isArray(value)?value:[];
  const same=(a,b)=>String(a??'')===String(b??'');
  const num=value=>Number(value||0)||0;
  const esc=value=>String(value??'').replace(/[&<>"']/g,char=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[char]));
  const locale=()=>window.AlinI18n?.locale?.()||'ar-IQ';
  const money=value=>num(value).toLocaleString(locale(),{maximumFractionDigits:0});
  const dateTime=value=>{
    const date=value?new Date(value):null;
    if(!date||Number.isNaN(date.getTime()))return '—';
    return date.toLocaleString(locale(),{dateStyle:'medium',timeStyle:'short'});
  };
  const db=()=>window.db||{};
  const current=()=>window.current||{};
  const statusKey=row=>String(row?.status||row?.order_status||'').trim().toLowerCase();
  const delivered=row=>['completed','delivered','done'].includes(statusKey(row));
  const cancelled=row=>['cancelled','canceled','rejected','reversed'].includes(statusKey(row));
  const statusLabel=row=>cancelled(row)?'ملغي':delivered(row)?'مكتمل':'مثبت';

  function unique(rows,keyFn){
    const seen=new Set();
    return rows.filter(row=>{
      const key=String(keyFn(row)||'');
      if(!key||seen.has(key))return false;
      seen.add(key);
      return true;
    });
  }

  function roleAccounts(role){
    const accounts=db().accounts||{};
    return arr(role==='teacher'?accounts.teachers:role==='library'?accounts.libraries:role==='courier'?accounts.couriers:[]);
  }

  function roleAccount(role){
    const active=current();
    const ids=[active.id,active.account_id,active.user_id,active[role+'_id']].filter(Boolean);
    return roleAccounts(role).find(row=>ids.some(id=>[row.id,row.account_id,row.user_id].some(value=>same(value,id))))
      ||roleAccounts(role).find(row=>active.username&&same(row.username,active.username))
      ||active;
  }

  function roleId(role){
    const account=roleAccount(role),active=current();
    return String(account?.id||active?.[role+'_id']||active?.id||'');
  }

  function teacherBookIds(id){
    return new Set(arr(db().booklets).filter(row=>same(row.teacher_id,id)).map(row=>String(row.id)));
  }

  function scopedOrders(role){
    const rows=arr(db().orders).filter(delivered);
    if(role==='admin'||role==='accountant')return rows;
    const id=roleId(role);
    if(role==='teacher'){
      const bookIds=teacherBookIds(id);
      return rows.filter(row=>same(row.teacher_id,id)||bookIds.has(String(row.item_id||row.booklet_id||'')));
    }
    if(role==='library')return rows.filter(row=>[row.library_id,row.pickup_library_id,row.assigned_library_id].some(value=>same(value,id)));
    if(role==='courier')return rows.filter(row=>[row.courier_id,row.delegate_id,row.assigned_courier_id].some(value=>same(value,id)));
    return [];
  }

  function settlementIdentity(row){
    const direct=row?.id||row?.settlement_id||row?.transaction_id||row?.payout_id||row?.receipt_number||row?.voucher_number;
    if(direct!==undefined&&direct!==null&&String(direct).trim()!=='')return String(direct);
    return [
      settlementRole(row),
      settlementPartyId(row),
      row?.created_at||row?.updated_at||row?.date||row?.settled_at||'',
      num(row?.amount||row?.paid_amount||row?.settled_amount||row?.value||row?.total),
      row?.payment_method||row?.method||''
    ].map(value=>String(value??'').trim()).join('|');
  }

  function allSettlements(){
    return unique(arr(db().settlements),settlementIdentity);
  }

  function settlementRole(row){
    const explicit=String(row.role||row.party_role||row.account_role||'').toLowerCase();
    if(['teacher','library','courier','delegate','admin'].includes(explicit))return explicit==='delegate'?'courier':explicit;
    if(row.teacher_id)return'teacher';
    if(row.library_id)return'library';
    if(row.courier_id||row.delegate_id)return'courier';
    return'admin';
  }

  function settlementPartyId(row){
    return String(row.party_id||row.account_id||row.teacher_id||row.library_id||row.courier_id||row.delegate_id||'');
  }

  function scopedSettlements(role){
    const rows=allSettlements();
    if(role==='admin'||role==='accountant')return rows;
    const id=roleId(role);
    return rows.filter(row=>settlementRole(row)===role&&same(settlementPartyId(row),id));
  }

  function orderNumber(row){return String(row.order_number||row.tracking_code||row.order_id||row.id||'—')}
  function receiptNumber(row){
    if(row.receipt_number||row.voucher_number)return String(row.receipt_number||row.voucher_number);
    const base=orderNumber(row).replace(/^AL-/i,'');
    return `RC-${base}`;
  }
  function settlementNumber(row){return String(row.receipt_number||row.voucher_number||row.settlement_number||row.id||row.settlement_id||`ST-${settlementIdentity(row).split('|').slice(1,4).join('-')}`||'تسوية')}
  function orderKey(row){return encodeURIComponent(String(row.id||row.order_id||row.order_number||row.tracking_code||''))}
  function settlementKey(row){return encodeURIComponent(settlementIdentity(row))}
  function findOrder(key,role){
    const value=decodeURIComponent(String(key||''));
    return scopedOrders(role).find(row=>[row.id,row.order_id,row.order_number,row.tracking_code].some(item=>same(item,value)))||null;
  }
  function findSettlement(key,role){
    const value=decodeURIComponent(String(key||''));
    if(!value)return null;
    return scopedSettlements(role).find(row=>settlementIdentity(row)===value||[
      row.id,row.settlement_id,row.transaction_id,row.payout_id,row.receipt_number,row.voucher_number
    ].some(item=>item!==undefined&&item!==null&&same(item,value)))||null;
  }

  function roleName(role){return({teacher:'مدرس',library:'مكتبة',courier:'مندوب',admin:'الإدارة',accountant:'الحسابات'})[role]||'حساب'}
  function accountNameById(role,id){
    return roleAccounts(role).find(row=>same(row.id,id))?.name||'';
  }
  function settlementPartyName(row,role){
    const actual=settlementRole(row),id=settlementPartyId(row);
    return String(row.party_name||row.account_name||row.teacher_name||row.library_name||row.courier_name||accountNameById(actual,id)||roleAccount(role)?.name||'منصة آلين');
  }
  function studentName(row){return String(row.student_name||row.customer_name||row.student?.name||'—')}
  function studentPhone(row){return String(row.student_phone||row.customer_phone||row.phone||'—')}
  function title(row){return String(row.title||row.item_name||row.product_name||row.order_title||'طلب منصة آلين')}
  function fulfillment(row){
    const kind=String(row.fulfillment_type||row.delivery_type||row.shipping_type||'').toLowerCase();
    if(['delivery','courier','home_delivery','door_delivery'].includes(kind)||row.courier_id||row.delegate_id){
      return row.courier_name?`توصيل بواسطة ${row.courier_name}`:'توصيل بواسطة المندوب';
    }
    return row.library_name||row.pickup_library_name?'استلام من المكتبة':'استلام من المكتبة';
  }
  function orderAmounts(row){
    const quantity=Math.max(1,num(row.qty||row.quantity||1));
    const delivery=Math.max(0,num(row.delivery_fee||row.shipping_fee));
    const discount=Math.max(0,num(row.discount||row.discount_amount));
    const total=Math.max(0,num(row.total||row.total_amount||row.amount));
    const subtotal=Math.max(0,num(row.subtotal||row.items_total)||(total+discount-delivery));
    const unit=Math.max(0,num(row.unit_price||row.price)||(subtotal/quantity));
    return {quantity,delivery,discount,total,subtotal,unit};
  }

  function receiptStatus(row,type){
    if(type==='settlement')return cancelled(row)?'ملغي':'مثبت';
    return delivered(row)?'مكتمل':'ملغي';
  }

  function orderRow(row,role){
    const key=orderKey(row);
    const search=[receiptNumber(row),orderNumber(row),title(row),studentName(row),money(orderAmounts(row).total)].join(' ').toLowerCase();
    return `<article class="alin415r-row" data-alin415r-kind="order" data-alin415r-status="${esc(receiptStatus(row,'order'))}" data-alin415r-search="${esc(search)}">
      <div class="alin415r-code"><b dir="ltr">${esc(receiptNumber(row))}</b><small dir="ltr">${esc(orderNumber(row))}</small></div>
      <span class="alin415r-type">وصل طلب</span>
      <time>${esc(dateTime(row.completed_at||row.delivered_at||row.updated_at||row.created_at))}</time>
      <strong>${money(orderAmounts(row).total)} د.ع</strong>
      <span class="alin415r-status is-complete">مكتمل</span>
      <div class="alin415r-actions"><button class="secondary" type="button" data-alin415r-preview="order" data-alin415r-key="${esc(key)}">معاينة</button><button type="button" data-alin415r-print="order" data-alin415r-key="${esc(key)}">طباعة / حفظ PDF</button></div>
    </article>`;
  }

  function settlementRow(row,role){
    const key=settlementKey(row),number=settlementNumber(row),status=receiptStatus(row,'settlement');
    const search=[number,settlementPartyName(row,role),roleName(settlementRole(row)),row.payment_method,row.note,row.notes].join(' ').toLowerCase();
    return `<article class="alin415r-row" data-alin415r-kind="settlement" data-alin415r-status="${esc(status)}" data-alin415r-search="${esc(search)}">
      <div class="alin415r-code"><b dir="ltr">${esc(number)}</b><small>${esc(settlementPartyName(row,role))}</small></div>
      <span class="alin415r-type is-settlement">تسوية مالية</span>
      <time>${esc(dateTime(row.created_at||row.updated_at||row.date||row.settled_at))}</time>
      <strong>${money(row.amount||row.paid_amount||row.settled_amount||row.value||row.total)} د.ع</strong>
      <span class="alin415r-status ${status==='ملغي'?'is-cancelled':'is-settled'}">${esc(status)}</span>
      <div class="alin415r-actions"><button class="secondary" type="button" data-alin415r-preview="settlement" data-alin415r-key="${esc(key)}">معاينة</button><button type="button" data-alin415r-print="settlement" data-alin415r-key="${esc(key)}">طباعة / حفظ PDF</button></div>
    </article>`;
  }

  function orderReceipt(row){
    const amount=orderAmounts(row),number=receiptNumber(row);
    return `<article class="alin415r-paper" dir="rtl" data-alin415r-printable>
      <header class="alin415r-paper-head"><div class="alin415r-paper-brand"><span>آ</span><div><h2>منصة آلين</h2><p>ملازم • قرطاسية • هدايا</p></div></div><div class="alin415r-paper-title"><small>وصل طلب</small><b dir="ltr">${esc(number)}</b></div></header>
      <div class="alin415r-paper-meta"><div><small>رقم الطلب</small><b dir="ltr">${esc(orderNumber(row))}</b></div><div><small>التاريخ</small><b>${esc(dateTime(row.completed_at||row.delivered_at||row.updated_at||row.created_at))}</b></div><div><small>الحالة</small><b>مكتمل</b></div></div>
      <section class="alin415r-paper-section"><h3>بيانات الطالب</h3><div class="alin415r-student"><div><small>اسم الطالب</small><b>${esc(studentName(row))}</b></div><div><small>رقم الهاتف</small><b dir="ltr">${esc(studentPhone(row))}</b></div><div><small>طريقة الاستلام</small><b>${esc(fulfillment(row))}</b></div></div></section>
      <section class="alin415r-paper-section"><h3>تفاصيل الطلب</h3><table><thead><tr><th>#</th><th>الصنف</th><th>الكمية</th><th>سعر الوحدة</th><th>الإجمالي</th></tr></thead><tbody><tr><td>1</td><td>${esc(title(row))}</td><td>${amount.quantity}</td><td>${money(amount.unit)} د.ع</td><td>${money(amount.subtotal)} د.ع</td></tr>${amount.delivery?`<tr><td>2</td><td>أجرة التوصيل</td><td>1</td><td>${money(amount.delivery)} د.ع</td><td>${money(amount.delivery)} د.ع</td></tr>`:''}</tbody></table>
      <div class="alin415r-totals"><div><span>المجموع الفرعي</span><b>${money(amount.subtotal)} د.ع</b></div><div><span>الخصم</span><b>${money(amount.discount)} د.ع</b></div><div class="final"><span>الإجمالي</span><strong>${money(amount.total)} د.ع</strong></div></div></section>
      <section class="alin415r-paper-note"><small>ملاحظات</small><p>${esc(row.notes||row.note||row.delivery_note||'لا توجد ملاحظات')}</p></section>
      <footer><b>منصة آلين</b><small>شكراً لاستخدام منصة آلين</small></footer>
    </article>`;
  }

  function settlementReceipt(row,role){
    const number=settlementNumber(row),actual=settlementRole(row);
    return `<article class="alin415r-paper" dir="rtl" data-alin415r-printable>
      <header class="alin415r-paper-head"><div class="alin415r-paper-brand"><span>آ</span><div><h2>منصة آلين</h2><p>ملازم • قرطاسية • هدايا</p></div></div><div class="alin415r-paper-title"><small>وصل تسوية</small><b dir="ltr">${esc(number)}</b></div></header>
      <div class="alin415r-paper-meta"><div><small>التاريخ</small><b>${esc(dateTime(row.created_at||row.updated_at||row.date||row.settled_at))}</b></div><div><small>نوع الحساب</small><b>${esc(roleName(actual))}</b></div><div><small>الحالة</small><b>${esc(receiptStatus(row,'settlement'))}</b></div></div>
      <section class="alin415r-paper-section"><h3>معلومات التسوية</h3><div class="alin415r-student"><div><small>اسم الحساب</small><b>${esc(settlementPartyName(row,role))}</b></div><div><small>طريقة التسوية</small><b>${esc(row.payment_method||row.method||'نقداً')}</b></div><div><small>رقم الوصل</small><b dir="ltr">${esc(number)}</b></div></div></section>
      <section class="alin415r-settlement-amount"><small>المبلغ المسدد</small><strong>${money(row.amount||row.paid_amount||row.settled_amount||row.value||row.total)} د.ع</strong></section>
      <section class="alin415r-paper-note"><small>ملاحظات</small><p>${esc(row.note||row.notes||'تسوية مالية مثبتة في منصة آلين')}</p></section>
      <footer><b>منصة آلين</b><small>شكراً لاستخدام منصة آلين</small></footer>
    </article>`;
  }

  function centerHtml(role){
    const orders=[...scopedOrders(role)].sort((a,b)=>String(b.completed_at||b.updated_at||b.created_at||'').localeCompare(String(a.completed_at||a.updated_at||a.created_at||'')));
    const settlements=[...scopedSettlements(role)].sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||'')));
    const all=[...orders.map(row=>orderRow(row,role)),...settlements.map(row=>settlementRow(row,role))].join('');
    const orderTotal=orders.reduce((sum,row)=>sum+orderAmounts(row).total,0);
    const settlementTotal=settlements.filter(row=>!cancelled(row)).reduce((sum,row)=>sum+Math.max(0,num(row.amount)),0);
    return `<section class="alin415r-center" data-alin415r-role="${esc(role)}">
      <header class="alin415r-heading"><div><small>منصة آلين</small><h2>الوصولات</h2><p>وصولات الطلبات المكتملة والتسويات المثبتة بصورة مرتبة.</p></div><span>${orders.length+settlements.length}</span></header>
      <section class="alin415r-metrics"><article><i>1</i><div><small>جميع الوصولات</small><strong>${orders.length+settlements.length}</strong></div></article><article><i>2</i><div><small>وصولات الطلبات</small><strong>${orders.length}</strong></div></article><article><i>3</i><div><small>وصولات التسويات</small><strong>${settlements.length}</strong></div></article><article><i>د.ع</i><div><small>إجمالي المبالغ</small><strong>${money(orderTotal+settlementTotal)} د.ع</strong></div></article></section>
      <section class="alin415r-workspace">
        <div class="alin415r-browser">
          <div class="alin415r-filters"><div class="alin415r-tabs"><button class="active" type="button" data-alin415r-filter="all">الكل</button><button type="button" data-alin415r-filter="order">وصولات الطلبات</button><button type="button" data-alin415r-filter="settlement">وصولات التسويات</button></div><label><span>بحث</span><input type="search" placeholder="ابحث برقم الوصول أو الطلب أو اسم الطالب..." data-alin415r-search></label><select data-alin415r-status><option value="all">كل الحالات</option><option value="مكتمل">مكتمل</option><option value="مثبت">مثبت</option><option value="ملغي">ملغي</option></select></div>
          <div class="alin415r-table-head"><span>رقم الوصول / الطلب</span><span>النوع</span><span>التاريخ</span><span>المبلغ</span><span>الحالة</span><span>الإجراءات</span></div>
          <div class="alin415r-list">${all||'<div class="alin415r-empty">لا توجد وصولات لهذا الحساب.</div>'}</div><div class="alin415r-no-results" hidden>لا توجد نتائج مطابقة.</div>
        </div>
      </section>
    </section>`;
  }

  function hostFor(role){return document.getElementById(role==='admin'||role==='accountant'?'adminContent':role==='teacher'?'teacherContent':role==='library'?'libraryV116Content':'courierV161Content')}
  function renderCenter(role,host){
    const target=host||hostFor(role);
    if(!target)return false;
    target.innerHTML=centerHtml(role);
    const root=target.querySelector('.alin415r-center');
    bind(root);
    document.body.dataset.alin415ReceiptsRole=role;
    closePreview();
    return true;
  }

  function bind(root){
    if(!root)return;
    let kind='all';
    const role=root.dataset.alin415rRole||'admin';
    const search=root.querySelector('[data-alin415r-search]');
    const status=root.querySelector('[data-alin415r-status]');
    const rows=()=>[...root.querySelectorAll('.alin415r-row')];
    const apply=()=>{
      const query=String(search?.value||'').trim().toLowerCase(),state=String(status?.value||'all');
      let shown=0;
      rows().forEach(row=>{
        const visible=(kind==='all'||row.dataset.alin415rKind===kind)&&(state==='all'||row.dataset.alin415rStatus===state)&&(!query||String(row.dataset.alin415rSearch||'').includes(query));
        row.hidden=!visible;if(visible)shown++;
      });
      const empty=root.querySelector('.alin415r-no-results');if(empty)empty.hidden=shown!==0||rows().length===0;
    };
    root.querySelectorAll('[data-alin415r-filter]').forEach(button=>button.addEventListener('click',()=>{kind=button.dataset.alin415rFilter||'all';root.querySelectorAll('[data-alin415r-filter]').forEach(item=>item.classList.toggle('active',item===button));apply()}));
    search?.addEventListener('input',apply);status?.addEventListener('change',apply);
    root.addEventListener('click',event=>{
      const previewButton=event.target.closest('[data-alin415r-preview]');
      if(previewButton){
        event.preventDefault();event.stopPropagation();
        const key=previewButton.dataset.alin415rKey||'',receiptKind=previewButton.dataset.alin415rPreview;
        return receiptKind==='order'?previewOrder(key,role):previewSettlement(key,role);
      }
      const printButton=event.target.closest('[data-alin415r-print]');
      if(printButton){
        event.preventDefault();event.stopPropagation();
        const key=printButton.dataset.alin415rKey||'',receiptKind=printButton.dataset.alin415rPrint;
        return receiptKind==='order'?printOrder(key,role):printSettlement(key,role);
      }
    });
  }

  function ensurePreviewModal(){
    let modal=document.getElementById('alin415rPreviewModal');
    if(modal)return modal;
    modal=document.createElement('div');
    modal.id='alin415rPreviewModal';
    modal.className='alin415r-modal';
    modal.hidden=true;
    modal.innerHTML=`<button class="alin415r-modal-backdrop" type="button" data-alin415r-modal-close aria-label="إغلاق المعاينة"></button><section class="alin415r-modal-dialog" role="dialog" aria-modal="true" aria-labelledby="alin415rModalTitle"><header><div><small>منصة آلين</small><h3 id="alin415rModalTitle">معاينة الوصل</h3></div><button class="alin415r-modal-close" type="button" data-alin415r-modal-close aria-label="إغلاق">×</button></header><div class="alin415r-modal-body"></div></section>`;
    modal.addEventListener('click',event=>{if(event.target.closest('[data-alin415r-modal-close]'))closePreview()});
    document.body.appendChild(modal);
    return modal;
  }

  function closePreview(){
    const modal=document.getElementById('alin415rPreviewModal');
    if(modal){modal.hidden=true;const body=modal.querySelector('.alin415r-modal-body');if(body)body.innerHTML=''}
    document.body.classList.remove('alin415r-modal-open');
    return true;
  }

  function renderPreview(role,titleText,content,kind,key){
    const modal=ensurePreviewModal(),target=modal.querySelector('.alin415r-modal-body');
    if(!target)return false;
    target.innerHTML=`<div class="alin415r-preview-toolbar"><div><small>المعاينة الحالية</small><b>${esc(titleText)}</b></div><button type="button" data-alin415r-modal-print>طباعة / حفظ PDF</button></div><div class="alin415r-modal-paper-wrap">${content}</div>`;
    const printButton=target.querySelector('[data-alin415r-modal-print]');
    printButton?.addEventListener('click',()=>kind==='order'?printOrder(key,role):printSettlement(key,role));
    modal.hidden=false;
    document.body.classList.add('alin415r-modal-open');
    requestAnimationFrame(()=>modal.querySelector('.alin415r-modal-close')?.focus());
    return true;
  }
  function previewOrder(key,role=String(current().role||'admin')){const row=findOrder(key,role);if(!row){window.toast?.('هذا الوصل غير متاح');return false}return renderPreview(role,'وصل طلب',orderReceipt(row),'order',key)}
  function previewSettlement(key,role=String(current().role||'admin')){const row=findSettlement(key,role);if(!row){window.toast?.('هذا الوصل غير متاح');return false}return renderPreview(role,'وصل تسوية',settlementReceipt(row,role),'settlement',key)}

  function printDocument(content,titleText){
    const popup=window.open('','_blank','width=980,height=820');
    if(!popup){window.toast?.('اسمح بفتح نافذة الطباعة من المتصفح');return false}
    popup.document.open();
    popup.document.write(`<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><title>${esc(titleText)}</title><style>@page{size:A4;margin:10mm}*{box-sizing:border-box}html,body{margin:0;padding:0;background:#fff;font-family:Tahoma,Arial,sans-serif;color:#102b4e}.alin415r-paper{width:100%;max-width:190mm;margin:0 auto;border:1px solid #dce5ef;border-radius:14px;overflow:hidden;background:#fff}.alin415r-paper-head{display:flex;justify-content:space-between;gap:20px;align-items:center;padding:22px 24px;border-top:9px solid #0b3f70;border-bottom:2px solid #d8b35e}.alin415r-paper-brand{display:flex;align-items:center;gap:12px}.alin415r-paper-brand>span{display:grid;place-items:center;width:54px;height:54px;border-radius:16px;background:#0b3f70;color:#f0c86e;font-size:28px;font-weight:900}.alin415r-paper h2{margin:0;font-size:25px}.alin415r-paper p{margin:4px 0 0}.alin415r-paper-title{text-align:left}.alin415r-paper-title small,.alin415r-paper-title b{display:block}.alin415r-paper-title small{color:#b58419;font-weight:800}.alin415r-paper-title b{margin-top:7px;font-size:18px}.alin415r-paper-meta,.alin415r-student{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;padding:16px 24px}.alin415r-paper-meta>div,.alin415r-student>div{padding:11px;border:1px solid #e0e7ef;border-radius:9px}.alin415r-paper small{color:#66768b}.alin415r-paper small,.alin415r-paper b{display:block}.alin415r-paper-section{padding:0 24px 15px}.alin415r-paper-section h3{margin:4px 0 10px;font-size:17px}.alin415r-paper table{width:100%;border-collapse:collapse}.alin415r-paper th,.alin415r-paper td{border:1px solid #dfe6ee;padding:9px;text-align:right}.alin415r-paper th{background:#edf3f8}.alin415r-totals{margin-top:10px;border:1px solid #e0e7ef;border-radius:9px;overflow:hidden}.alin415r-totals>div{display:flex;justify-content:space-between;padding:8px 12px}.alin415r-totals .final{background:#fff7e6;border-top:1px solid #d8b35e}.alin415r-paper-note{margin:0 24px 16px;padding:12px;border:1px solid #e0e7ef;border-radius:9px}.alin415r-paper-note p{margin-top:6px}.alin415r-settlement-amount{margin:0 24px 16px;padding:24px;border:1px solid #d8b35e;background:#fff7e6;border-radius:12px;text-align:center}.alin415r-settlement-amount strong{display:block;margin-top:8px;font-size:30px;color:#0b3f70}.alin415r-paper footer{display:flex;justify-content:space-between;padding:15px 24px;background:#0b3f70;color:#fff}.alin415r-paper footer small{color:#e8edf3}@media print{body{-webkit-print-color-adjust:exact;print-color-adjust:exact}.alin415r-paper{border-radius:0;break-inside:avoid-page;page-break-inside:avoid}}</style></head><body>${content}</body></html>`);
    popup.document.close();
    popup.focus();
    setTimeout(()=>popup.print(),180);
    return true;
  }
  function printOrder(key,role=String(current().role||'admin')){const row=findOrder(key,role);return row?printDocument(orderReceipt(row),'وصل طلب'):false}
  function printSettlement(key,role=String(current().role||'admin')){const row=findSettlement(key,role);return row?printDocument(settlementReceipt(row,role),'وصل تسوية'):false}

  function markPartnerTab(role,button){
    const selector=role==='library'?'.library-v116-tabs button':role==='courier'?'.courier-v161-tabs button':'';
    if(selector)document.querySelectorAll(selector).forEach(node=>node.classList.toggle('active',node===button));
  }
  function openCenter(role,button){markPartnerTab(role,button||null);return renderCenter(role)}

  function install(){
    window.AlinAdminModules?.register?.('receipts',host=>renderCenter('admin',host));
    document.addEventListener('keydown',event=>{if(event.key==='Escape'&&document.body.classList.contains('alin415r-modal-open'))closePreview()});
    window.TeacherApp?.registerTab?.('receipts',()=>renderCenter('teacher'));
    document.addEventListener('click',event=>{
      const button=event.target.closest('[data-alin415-receipts-role]');
      if(!button)return;
      event.preventDefault();openCenter(button.dataset.alin415ReceiptsRole,button);
    });
    window.addEventListener('alin:data-refreshed',()=>{
      const role=document.body.dataset.alin415ReceiptsRole,host=role?hostFor(role):null;
      if(role&&host&&!host.closest('.hidden')&&host.querySelector(`.alin415r-center[data-alin415r-role="${role}"]`))renderCenter(role);
    });
  }

  const api=Object.freeze({renderCenter,openCenter,previewOrder,previewSettlement,closePreview,printOrder,printSettlement,orders:scopedOrders,settlements:scopedSettlements});
  window.Alin415Receipts=api;
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
})();
