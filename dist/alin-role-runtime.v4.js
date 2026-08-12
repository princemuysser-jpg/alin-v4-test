/* core/lazy-libs.js */
/* ALIN 2.0.1 - Load optional libraries only when a feature needs them. */
(function(){
  const MAMMOTH_URL='https://cdn.jsdelivr.net/npm/mammoth@1.8.0/mammoth.browser.min.js';
  let mammothPromise=null;

  window.AlinLoadMammoth=function(){
    if(window.mammoth) return Promise.resolve(window.mammoth);
    if(mammothPromise) return mammothPromise;

    mammothPromise=new Promise((resolve,reject)=>{
      const script=document.createElement('script');
      script.src=MAMMOTH_URL;
      script.async=true;
      script.crossOrigin='anonymous';
      script.onload=()=>window.mammoth
        ? resolve(window.mammoth)
        : reject(new Error('تعذر تشغيل مكتبة معاينة Word'));
      script.onerror=()=>reject(new Error('تعذر تحميل مكتبة معاينة Word. تحقق من الإنترنت ثم حاول مجدداً.'));
      document.head.appendChild(script);
    }).catch(error=>{
      mammothPromise=null;
      throw error;
    });

    return mammothPromise;
  };
})();
;

/* core/finance-runtime.js */
/* ALIN v2.8.0 Stage 5 — server-authoritative atomic finance runtime. */
(function(){
  'use strict';

  const arr=value=>Array.isArray(value)?value:[];
  const num=value=>Number.isFinite(Number(value))?Number(value):0;
  const same=(a,b)=>String(a??'')===String(b??'');
  const now=()=>new Date().toISOString();
  const db=()=>window.db||{};
  const api=name=>typeof window[name]==='function'?window[name]:null;
  const client=()=>window.ALINAuthRuntime?.client?.()||window.sb||window.AlinCloud?.client?.()||null;
  const money=value=>typeof window.money==='function'?window.money(value):Math.round(num(value)).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const delivered=value=>['completed','delivered','done','received','settled','تم التسليم'].includes(String(value||'').toLowerCase());
  const cancelled=value=>['cancelled','canceled','rejected','ملغي','إلغاء'].some(token=>String(value||'').toLowerCase().includes(token));

  function ratios(){
    const settings=db().settings||{};
    const clamp=value=>Math.max(0,Math.min(100,num(value)));
    return {
      admin:clamp(settings.admin_profit_percent??20),
      teacher:clamp(settings.teacher_profit_percent??50),
      library:clamp(settings.library_profit_percent??30),
      delegate:clamp(settings.delegate_profit_percent??30)
    };
  }

  function deliveryType(order){
    const raw=String(order?.fulfillment_type||order?.delivery_type||order?.delivery_method||'').toLowerCase();
    if(/home_delivery|delivery|delegate|courier|مندوب/.test(raw)||order?.delegate_id||order?.courier_id)return 'delegate';
    return 'library';
  }

  function booklet(order){return arr(db().booklets).find(row=>same(row.id,order?.item_id||order?.booklet_id))||null}

  function shares(order){
    const total=Math.max(0,Math.round(num(order?.total)));
    const deliveryFee=Math.min(total,Math.max(0,Math.round(num(order?.delivery_fee))));
    const merchandise=Math.max(0,total-deliveryFee);
    const rate=ratios(),book=booklet(order),isBooklet=/booklet|ملزمة|ملازم/.test(String(order?.kind||order?.item_kind||'').toLowerCase());
    const teacherPct=Math.max(0,Math.min(100,num(book?.teacher_share_percent??rate.teacher)));
    const libraryPct=Math.max(0,Math.min(100,num(book?.library_share_percent??rate.library)));
    const delivery=deliveryType(order);
    const teacher=isBooklet?Math.min(merchandise,Math.max(0,Math.round(merchandise*teacherPct/100))):0;
    const library=delivery==='library'?Math.min(Math.max(0,merchandise-teacher),Math.max(0,Math.round(merchandise*libraryPct/100))):0;
    const delegate=delivery==='delegate'?Math.min(deliveryFee,Math.max(0,Math.round(deliveryFee*rate.delegate/100))):0;
    const admin=Math.max(0,total-teacher-library-delegate);
    const collectorId=delivery==='library'?(order?.library_id||order?.pickup_library_id||order?.assigned_library_id||''):(order?.delegate_id||order?.courier_id||'');
    const collectorProfit=delivery==='library'?library:delegate;
    return {total,merchandise,deliveryFee,admin,teacher,library,delegate,delivery,collectorId,debt:Math.max(0,total-collectorProfit)};
  }

  function orderFor(row){return arr(db().orders).find(order=>same(order.id,row?.order_id)||same(order.order_number,row?.order_number||row?.order_id))||null}

  function delegateAliases(id){
    const set=new Set([String(id??'')].filter(Boolean));
    const sources=[...arr(db().delegates),...arr(db().accounts?.delegates),...arr(db().accounts?.couriers),...arr(db().accounts?.all).filter(row=>['courier','delegate'].includes(String(row?.role||'').toLowerCase())),...arr(db().couriers)];
    let changed=true;
    while(changed){
      changed=false;
      for(const row of sources){
        const values=[row?.id,row?.account_id,row?.accountId,row?.user_id,row?.courier_row_id,row?.auth_user_id].filter(Boolean).map(String);
        if(values.some(value=>set.has(value))){for(const value of values)if(!set.has(value)){set.add(value);changed=true}}
      }
    }
    return set;
  }
  const matchesDelegate=(value,id)=>delegateAliases(id).has(String(value??''));

  function syntheticLedgerRow(order){
    const split=shares(order),book=booklet(order),delivery=split.delivery;
    const delegateId=order?.delegate_id||order?.courier_id||order?.courier_account_id||'';
    const libraryId=order?.library_id||order?.pickup_library_id||order?.assigned_library_id||'';
    const teacherId=book?.teacher_id||order?.teacher_id||'';
    const delegateProfit=Math.max(0,num(order?.delegate_profit||order?.courier_profit||split.delegate));
    const libraryProfit=Math.max(0,num(order?.library_profit||split.library));
    const teacherProfit=Math.max(0,num(order?.teacher_profit||split.teacher));
    const adminProfit=Math.max(0,num(order?.platform_profit||order?.admin_profit||split.admin));
    const total=Math.max(0,num(order?.total));
    const collectorProfit=delivery==='delegate'?delegateProfit:libraryProfit;
    return {
      id:`virtual-${order?.id||order?.order_number||Date.now()}`,order_id:order?.id,order_number:order?.order_number,title:order?.title,
      total,merchandise_total:split.merchandise,delivery_fee:split.deliveryFee,
      alin:adminProfit,admin:adminProfit,teacher:teacherProfit,teacher_id:teacherId,
      library:libraryProfit,library_id:libraryId,delegate:delegateProfit,courier:delegateProfit,
      delegate_id:delegateId,courier_id:delegateId,collector_role:delivery,collector_id:delivery==='delegate'?delegateId:libraryId,
      collector_debt:Math.max(0,total-collectorProfit),delivery_type:delivery,status:'pending',settlement_status:'pending',
      settled_at:order?.settlement_at||order?.completed_at||order?.delivered_at||order?.updated_at||order?.created_at||'',
      created_at:order?.completed_at||order?.delivered_at||order?.created_at||'',is_current:true,is_virtual:true,finance_version:'4.1.6-fallback'
    };
  }

  function canonicalLedger(){
    const rows=new Map(),coveredOrders=new Set();
    for(const row of arr(db().ledger)){
      if(row?.is_current===false)continue;
      const order=orderFor(row);
      if(cancelled(row?.settlement_status)||cancelled(order?.status)||order?.settlement_cancelled)continue;
      if(order&&!delivered(order.status)&&!order.settlement_done)continue;
      const key=String(row?.order_id||row?.order_number||row?.id||'');if(!key)continue;
      const previous=rows.get(key),currentAt=String(row?.settled_at||row?.updated_at||row?.created_at||''),previousAt=String(previous?.settled_at||previous?.updated_at||previous?.created_at||'');
      if(!previous||currentAt>=previousAt)rows.set(key,row);
      if(row?.order_id)coveredOrders.add(String(row.order_id));
      if(row?.order_number)coveredOrders.add(String(row.order_number));
    }
    for(const order of arr(db().orders)){
      if(!order||cancelled(order.status)||order.settlement_cancelled||!delivered(order.status))continue;
      const id=String(order.id||''),number=String(order.order_number||'');
      if((id&&coveredOrders.has(id))||(number&&coveredOrders.has(number)))continue;
      const virtual=syntheticLedgerRow(order),key=String(virtual.order_id||virtual.order_number||virtual.id);
      rows.set(key,virtual);if(id)coveredOrders.add(id);if(number)coveredOrders.add(number);
    }
    return [...rows.values()];
  }

  function payoutRows(){
    const rows=[
      ...arr(db().settlements).filter(row=>['admin','teacher'].includes(String(row.party_role||'').toLowerCase())),
      ...arr(db().withdrawals).filter(row=>String(row.status||'').toLowerCase()==='paid')
    ];
    const seen=new Set();
    return rows.filter(row=>{const key=String(row.id||row.receipt_number||`${row.party_role||row.role}-${row.party_id||row.account_id}-${row.created_at}-${row.amount}`);if(!key||seen.has(key))return false;seen.add(key);return true});
  }
  const payoutRole=row=>String(row.party_role||row.role||(row.teacher_id?'teacher':'')||'').toLowerCase().replace('courier','delegate');
  const payoutParty=row=>row.party_id||row.account_id||row.user_id||row.teacher_id||row.library_id||row.delegate_id||row.courier_id||'';
  function payoutValue(row){const status=String(row.status||'paid').toLowerCase();if(['cancelled','canceled','rejected','reversed','pending'].includes(status))return 0;return status==='reversal'?-Math.abs(num(row.amount)):Math.max(0,num(row.amount))}

  function librarySettlementRows(id){
    return arr(db().settlements).filter(row=>String(row.party_role||'').toLowerCase()==='library'&&same(row.party_id,id));
  }
  function isConfirmedDelegateSettlement(row){
    if(!row)return false;
    const role=String(row.party_role||'').toLowerCase().replace('courier','delegate');
    const status=String(row.status||'').toLowerCase();
    return role==='delegate'&&['received','paid'].includes(status);
  }
  function delegateSettlementRows(id){
    const aliases=delegateAliases(id),seen=new Set();
    return arr(db().settlements).filter(row=>{
      if(!isConfirmedDelegateSettlement(row)||!aliases.has(String(row.party_id||'')))return false;
      const key=String(row.id||row.receipt_number||`${row.party_id}-${row.created_at}-${row.amount}`);if(!key||seen.has(key))return false;seen.add(key);return true;
    });
  }
  function settlementValue(row){const status=String(row.status||'').toLowerCase();if(!['received','paid'].includes(status))return 0;return Math.max(0,num(row.amount))}

  function earned(role,id){
    const key=String(role||'').toLowerCase().replace('courier','delegate');
    return canonicalLedger().reduce((sum,row)=>{
      if(key==='admin')return sum+Math.max(0,num(row.admin||row.alin));
      if(key==='teacher'&&same(row.teacher_id,id))return sum+Math.max(0,num(row.teacher||row.teacher_amount));
      if(key==='library'&&same(row.library_id,id))return sum+Math.max(0,num(row.library||row.library_amount));
      if(key==='delegate'&&matchesDelegate(row.delegate_id||row.courier_id||row.collector_id,id))return sum+Math.max(0,num(row.delegate||row.courier||row.courier_amount));
      return sum;
    },0);
  }
  function paid(role,id){const key=String(role||'').toLowerCase().replace('courier','delegate');return Math.max(0,payoutRows().filter(row=>payoutRole(row)===key&&(key==='admin'||same(payoutParty(row),id))).reduce((sum,row)=>sum+payoutValue(row),0))}
  function balance(role,id){const totalEarned=earned(role,id),totalPaid=paid(role,id);return {earned:totalEarned,paid:totalPaid,remaining:Math.max(0,totalEarned-totalPaid)}}

  function librarySummary(libraryId){
    const rows=canonicalLedger().filter(row=>same(row.library_id,libraryId)&&String(row.collector_role||row.delivery_type||'library')==='library').map(row=>{const order=orderFor(row)||{},gross=Math.max(0,num(row.total)||num(order.total)),profit=Math.max(0,num(row.library||row.library_amount)),debt=Math.max(0,num(row.collector_debt)||gross-profit);return {...row,order,gross,profit,libraryProfit:profit,debt,at:row.settled_at||row.created_at||order.delivered_at||order.updated_at||order.created_at||''}});
    const settlements=librarySettlementRows(libraryId),gross=rows.reduce((sum,row)=>sum+row.gross,0),profit=rows.reduce((sum,row)=>sum+row.profit,0),debtTotal=rows.reduce((sum,row)=>sum+row.debt,0),settled=Math.max(0,settlements.reduce((sum,row)=>sum+settlementValue(row),0)),month=new Date().toISOString().slice(0,7),monthProfit=rows.filter(row=>String(row.at).slice(0,7)===month).reduce((sum,row)=>sum+row.profit,0);
    return {rows,settlements,gross,profit,libraryProfit:profit,debtTotal,settled,remaining:Math.max(0,debtTotal-settled),debtRemaining:Math.max(0,debtTotal-settled),monthProfit};
  }
  function teacherSummary(teacherId){const rows=canonicalLedger().filter(row=>same(row.teacher_id,teacherId)),summary=balance('teacher',teacherId),month=new Date().toISOString().slice(0,7),monthEarn=rows.filter(row=>String(row.settled_at||row.created_at||'').slice(0,7)===month).reduce((sum,row)=>sum+Math.max(0,num(row.teacher||row.teacher_amount)),0);return {...summary,rows,payouts:payoutRows().filter(row=>payoutRole(row)==='teacher'&&same(payoutParty(row),teacherId)),monthEarn}}
  function delegateSummary(delegateId){
    const aliases=delegateAliases(delegateId);
    // Use delivered orders as the primary source for courier cash debt. Ledger rows can be stale/partial on older installs.
    const deliveredOrders=arr(db().orders).filter(order=>delivered(order?.status)&&!cancelled(order?.status)&&deliveryType(order)==='delegate'&&[
      order?.delegate_id,order?.courier_id,order?.courier_account_id,order?.assigned_courier_id,order?.assigned_delegate_id
    ].filter(Boolean).some(value=>aliases.has(String(value))));
    const rows=deliveredOrders.map(order=>{
      const split=shares(order);
      const gross=Math.max(0,num(order?.delegate_cash_collected)||num(order?.courier_cash_collected)||num(order?.cash_collected)||num(order?.amount_collected)||num(order?.total)||num(order?.grand_total)||num(order?.final_total));
      const persistedProfit=Math.max(0,num(order?.delegate_profit)||num(order?.courier_profit));
      const profit=persistedProfit>0?persistedProfit:Math.max(0,num(split.delegate));
      return {...syntheticLedgerRow(order),order,total:gross,delegate:profit,courier:profit,collector_debt:Math.max(0,gross-profit)};
    });
    const covered=new Set(rows.map(row=>String(row.order_id||row.order_number||'')));
    // Preserve legacy completed finance entries only when their order is no longer present in the local order cache.
    for(const row of canonicalLedger()){
      if(!aliases.has(String(row.delegate_id||row.courier_id||row.collector_id||''))||String(row.collector_role||row.delivery_type||'delegate')!=='delegate')continue;
      const key=String(row.order_id||row.order_number||'');if(key&&covered.has(key))continue;
      const order=orderFor(row)||{};
      const gross=Math.max(0,num(row.total)||num(order.total));
      const persistedProfit=Math.max(0,num(row.delegate||row.courier||row.courier_amount)||num(order.delegate_profit)||num(order.courier_profit));
      const profit=persistedProfit>0?persistedProfit:Math.max(0,num(shares(order).delegate));
      rows.push({...row,order,total:gross,delegate:profit,courier:profit,collector_debt:Math.max(0,gross-profit)});if(key)covered.add(key);
    }
    const collected=rows.reduce((sum,row)=>sum+Math.max(0,num(row.total)),0),earnings=rows.reduce((sum,row)=>sum+Math.max(0,num(row.delegate||row.courier||row.courier_amount)),0),debtTotal=rows.reduce((sum,row)=>sum+Math.max(0,num(row.collector_debt)),0),settlements=delegateSettlementRows(delegateId),settled=Math.max(0,settlements.reduce((sum,row)=>sum+settlementValue(row),0));
    return {earned:earnings,earnings,collected,debtTotal,paid:settled,settled,remaining:Math.max(0,debtTotal-settled),debt:Math.max(0,debtTotal-settled),rows,settlements,payouts:payoutRows().filter(row=>payoutRole(row)==='delegate'&&aliases.has(String(payoutParty(row))))};
  }
  function partySummary(role,id){if(String(role).toLowerCase()==='library'){const profit=balance('library',id);return {...profit,debt:librarySummary(id)}}if(['courier','delegate'].includes(String(role).toLowerCase()))return delegateSummary(id);return balance(role,id)}

  function financeError(error){
    const message=String(error?.message||error||'').trim();
    if(/alin_order_transition_atomic|schema cache|function .* does not exist/i.test(message))return new Error('خدمة الحسابات غير مهيأة في مشروع Supabase الجديد. نفّذ ملف ALIN_V4_CLEAN_PROJECT_MASTER.sql مرة واحدة ثم حدّث الصفحة.');
    return error instanceof Error?error:new Error(message||'تعذر تنفيذ العملية المالية');
  }
  async function rpc(name,args){const c=client();if(!c?.rpc)throw new Error('خدمة Supabase غير متاحة');const {data,error}=await c.rpc(name,args);if(error)throw financeError(error);return data}

  async function transitionOrder(id,status,reason=''){
    const data=await rpc('alin_order_transition_atomic',{p_order_id:String(id),p_status:String(status),p_reason:reason||null});
    if(!data?.ok)throw new Error('لم يؤكد الخادم تحديث الطلب');
    const order=arr(db().orders).find(row=>same(row.id,id));if(order&&data.order)Object.assign(order,data.order);
    if(api('load'))await window.load({force:true,reason:'atomic-order-finance'});
    return data;
  }
  async function persistLedger(order){if(!order?.id)throw new Error('الطلب غير موجود');const data=await transitionOrder(order.id,'completed');return {row:data.finance,split:data.finance}}
  async function finalizeDelivered(order,status='completed'){if(!order?.id)throw new Error('الطلب غير موجود');const data=await transitionOrder(order.id,status);return {order:data.order,row:data.finance,split:data.finance}}
  async function cancelOrder(order,reason=''){if(!order?.id)throw new Error('الطلب غير موجود');return transitionOrder(order.id,'cancelled',reason)}
  async function setOrderStatus(id,status,source='admin',reason=''){
    const data=await transitionOrder(id,status,reason);
    const order=data.order||arr(db().orders).find(row=>same(row.id,id));
    if(api('audit'))await window.audit('order',`${source==='library'?'المكتبة':source==='courier'?'المندوب':'الإدارة'} حدثت الطلب ${order?.order_number||id} إلى ${status}`);
    if(source==='library'&&api('renderLibrary'))window.renderLibrary();if(source==='admin'&&api('renderOrdersAdmin'))window.renderOrdersAdmin();if(api('toast'))window.toast('تم تحديث الطلب والحسابات');
    return true;
  }

  function partyName(role,id){const accounts=db().accounts||{};if(role==='admin')return 'منصة آلين';const list=role==='teacher'?arr(accounts.teachers):role==='library'?arr(accounts.libraries):arr(db().delegates||accounts.couriers||db().couriers);return list.find(row=>same(row.id,id))?.name||id||role}
  async function recordSettlement(role,id,amount,method,note){return rpc('alin_finance_record_settlement',{p_role:role,p_party_id:String(id||role),p_amount:Number(amount),p_method:method||'نقدي',p_note:note||null})}
  async function payBalance(role,id){
    const normalized=String(role||'').toLowerCase().replace('courier','delegate'),currentRole=String(window.current?.role||'').toLowerCase();if(!['admin','accountant'].includes(currentRole))return alert('هذا الإجراء متاح للإدارة فقط');
    const summary=balance(normalized,id);if(summary.remaining<=0)return alert('لا يوجد رصيد متبقٍ');
    const raw=window.prompt(`الرصيد المتبقي لـ ${partyName(normalized,id)} هو ${money(summary.remaining)} د.ع\nاكتب مبلغ التسديد`,String(summary.remaining));if(raw===null)return false;
    const amount=num(String(raw).replace(/[,،]/g,''));if(amount<=0||amount>summary.remaining)return alert('مبلغ التسديد غير صحيح');
    const method=window.prompt('طريقة الدفع','نقدي')||'نقدي',data=await recordSettlement(normalized,id,amount,method,normalized==='admin'?'استلام ربح المنصة':'تسديد أرباح');
    if(api('load'))await window.load({force:true,reason:'finance-payout'});if(api('renderFinanceAdmin'))window.renderFinanceAdmin();if(api('toast'))window.toast('تم تسجيل السند');return data;
  }
  async function settleLibrary(libraryId){
    const currentRole=String(window.current?.role||'').toLowerCase();if(!['admin','accountant'].includes(currentRole))return alert('هذا الإجراء متاح للإدارة فقط');
    const summary=librarySummary(libraryId);if(summary.remaining<=0)return alert('حساب المكتبة مصفّى ولا توجد ذمة متبقية');
    const raw=window.prompt(`المتبقي بذمة ${partyName('library',libraryId)} هو ${money(summary.remaining)} د.ع\nاكتب المبلغ المستلم`,String(summary.remaining));if(raw===null)return false;
    const amount=num(String(raw).replace(/[,،]/g,''));if(amount<=0||amount>summary.remaining)return alert('مبلغ التسوية غير صحيح');
    const data=await recordSettlement('library',libraryId,amount,window.prompt('طريقة الاستلام','نقدي')||'نقدي','تسوية ذمة مكتبة من لوحة الإدارة');
    if(api('load'))await window.load({force:true,reason:'library-settlement'});if(api('renderFinanceAdmin'))window.renderFinanceAdmin();if(api('toast'))window.toast('تم تسجيل تسوية المكتبة');return data;
  }
  async function settleDelegate(delegateId){
    const currentRole=String(window.current?.role||'').toLowerCase();if(!['admin','accountant'].includes(currentRole))return alert('هذا الإجراء متاح للإدارة فقط');
    const summary=delegateSummary(delegateId);if(summary.remaining<=0)return alert('ذمة المندوب مصفّاة');
    const raw=window.prompt(`المتبقي بذمة ${partyName('delegate',delegateId)} هو ${money(summary.remaining)} د.ع\nاكتب المبلغ المستلم`,String(summary.remaining));if(raw===null)return false;
    const amount=num(String(raw).replace(/[,،]/g,''));if(amount<=0||amount>summary.remaining)return alert('مبلغ التسوية غير صحيح');
    const data=await recordSettlement('delegate',delegateId,amount,window.prompt('طريقة الاستلام','نقدي')||'نقدي','تسوية ذمة مندوب من لوحة الإدارة');
    if(api('load'))await window.load({force:true,reason:'delegate-settlement'});if(api('renderFinanceAdmin'))window.renderFinanceAdmin();if(api('toast'))window.toast('تم تسجيل تسوية المندوب');return data;
  }

  async function reverseSettlement(role,id,reason){
    const text=String(reason||'').trim();if(!text)throw new Error('اكتب سبب عكس السند');
    const data=await rpc('alin_finance_reverse_settlement',{p_role:role,p_settlement_id:String(id),p_reason:text});
    if(api('load'))await window.load({force:true,reason:'finance-reversal'});return data;
  }

  async function requestWithdraw(role){const id=window.current?.id;if(!id)return alert('سجل الدخول أولاً');const field=role==='teacher'?document.getElementById('teacherWithdrawAmount'):document.getElementById('libraryWithdrawAmount'),amount=num(field?.value);if(amount<=0)return alert('المبلغ غير صحيح');const row={id:api('uid')?window.uid('W'):`W-${Date.now()}`,role,account_id:id,amount,status:'pending',created_at:now()},insert=api('insert');if(!insert)throw new Error('خدمة طلبات السحب غير جاهزة');await insert('withdrawals',row);if(api('toast'))window.toast('تم إرسال طلب السحب');return row}
  async function updateWithdrawal(id,status){const update=api('update');if(!update)throw new Error('خدمة تحديث طلب السحب غير جاهزة');await update('withdrawals',{status,updated_at:now()},{id});if(api('load'))await window.load();if(api('renderFinanceAdmin'))window.renderFinanceAdmin()}

  const service=Object.freeze({ratios,deliveryType,shares,canonicalLedger,payoutRows,librarySummary,teacherSummary,delegateSummary,partySummary,balance,earned,paid,transitionOrder,persistLedger,finalizeDelivered,cancelOrder,setOrderStatus,recordSettlement,payBalance,settleLibrary,settleDelegate,reverseSettlement,requestWithdraw,updateWithdrawal,partyName});
  window.AlinFinance=service;window.AlinFinanceV207=service;
  window.ensureOrderFinancials=async order=>delivered(order?.status)?transitionOrder(order.id,'completed'):null;
  window.alinV57SettleOrder=async order=>transitionOrder(order.id,'completed');
  window.maybeCreateFinancialEntry=async id=>transitionOrder(id,'completed');
  window.requestWithdraw=requestWithdraw;window.withdrawStatus=updateWithdrawal;window.alinV68Balance=balance;window.alinV65Balance=balance;window.alinV65Paid=paid;window.alinV65AllPayouts=payoutRows;window.alinV64LibraryDebt=librarySummary;window.alinV64AllSettlements=()=>arr(db().settlements);window.alinV68PayBalance=payBalance;window.alinV65PayBalance=payBalance;window.alinV64AdminSettleLibrary=settleLibrary;window.addTeacherPayoutPrompt=id=>payBalance('teacher',id);window.AlinV120Finance={summary:librarySummary,settle:settleLibrary};
})();
;

/* modules/admin/accounts.js */
// === admin/accounts.js ===
/* ALIN v2.2.6 — authoritative accounts administration. */

/* ===== admin/js/admin-accounts-v133.js ===== */
(function(){
  'use strict';
  const state={query:'',role:'all',status:'all',area:'all'};
  const DEFAULT_COURIER_AREAS=['القادسية','الحرية','الإسكان','عرفة','رحيم آوه','شوراو','طريق بغداد','الواسطي','دوميز','بنجا علي','تسعين','حي النصر','حي النداء','الخضراء','المصلى','القورية','الشورجة','واحد حزيران','الحي العسكري','حي المعلمين','حي الجامعة','حي عدن','حي الزوراء','حي الحسين','حي العمل الشعبي','غرناطة','المنصور','البلديات','الشرطة'];
  const escx=v=>typeof esc==='function'?esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const arr=v=>Array.isArray(v)?v:[];
  const roleLabel={teacher:'مدرس',library:'مكتبة',courier:'مندوب',accountant:'محاسب',admin:'مدير'};

  function unique(values){return [...new Set(values.map(x=>String(x||'').trim()).filter(Boolean))]}
  function parseAreas(value){
    if(Array.isArray(value))return unique(value);
    if(value&&typeof value==='object')return unique(Object.values(value));
    const text=String(value||'').trim();
    if(!text)return[];
    try{const parsed=JSON.parse(text);if(Array.isArray(parsed))return unique(parsed)}catch(_){ }
    return unique(text.split(/[,،|]/));
  }
  function deliveryAreaNames(){
    const rows=arr(window.db?.deliveryAreas||window.db?.delivery_areas||window.deliveryAreas);
    const cloud=rows.filter(x=>x&&x.active!==false&&String(x.status||'active')!=='inactive').map(x=>x.name||x.title||x.area);
    const names=unique(cloud.length?cloud:(window.ALIN_KIRKUK_AREAS||DEFAULT_COURIER_AREAS));
    return names.sort((a,b)=>a.localeCompare(b,'ar'));
  }
  function accountAreas(x){return unique([...parseAreas(x?.areas||x?.area_ids),...parseAreas(x?.area)])}
  window.AlinCourierAreas=Object.freeze({list:deliveryAreaNames,parse:parseAreas,forAccount:accountAreas});

  function initials(name){return String(name||'؟').trim().split(/\s+/).slice(0,2).map(x=>x[0]||'').join('')||'؟'}
  function allAccounts(){
    const teachers=arr(window.db?.accounts?.teachers).map(x=>({...x,role:'teacher'}));
    const libraries=arr(window.db?.accounts?.libraries).map(x=>({...x,role:'library'}));
    const couriers=arr(window.db?.accounts?.couriers||window.db?.couriers).map(x=>({...x,role:'courier'}));
    const accountants=arr(window.db?.accounts?.accountants).map(x=>({...x,role:'accountant'}));
    return [...teachers,...libraries,...couriers,...accountants];
  }
  function normalizedStatus(x){const s=String(x.status||'active').toLowerCase();return ['active','open','enabled','approved'].includes(s)?'active':['pending','review'].includes(s)?'pending':'inactive'}
  function filtered(){return allAccounts().filter(x=>{
    const xAreas=accountAreas(x);
    const text=[x.name,x.username,x.phone,x.mobile,x.landmark,roleLabel[x.role],...xAreas].join(' ').toLowerCase();
    return (!state.query||text.includes(state.query.toLowerCase()))&&(state.role==='all'||x.role===state.role)&&(state.status==='all'||normalizedStatus(x)===state.status)&&(state.area==='all'||xAreas.includes(state.area));
  })}
  function areas(){return unique(allAccounts().flatMap(accountAreas)).sort((a,b)=>a.localeCompare(b,'ar'))}
  function stats(){const a=allAccounts();return {all:a.length,active:a.filter(x=>normalizedStatus(x)==='active').length,inactive:a.filter(x=>normalizedStatus(x)==='inactive').length,teachers:a.filter(x=>x.role==='teacher').length,libraries:a.filter(x=>x.role==='library').length,couriers:a.filter(x=>x.role==='courier').length}}
  function card(x){
    const st=normalizedStatus(x),locked=['admin','accountant'].includes(x.role),phone=x.phone||x.mobile||'',xAreas=accountAreas(x);
    const meta=[x.username?`الدخول: ${escx(x.username)}`:'',phone?escx(phone):'',...xAreas.slice(0,4).map(escx)].filter(Boolean);
    if(xAreas.length>4)meta.push(`+${xAreas.length-4} مناطق`);
    return `<article class="v131-account-card"><div class="v131-avatar ${escx(x.role)}">${escx(initials(x.name))}</div><div class="v131-account-info"><h3>${escx(x.name||roleLabel[x.role])}</h3><div class="v131-account-meta"><span class="v131-chip">${roleLabel[x.role]||escx(x.role)}</span>${meta.map(m=>`<span class="v131-chip">${m}</span>`).join('')}<span class="v131-status ${st}">${st==='active'?'فعال':st==='pending'?'قيد المراجعة':'موقوف'}</span></div></div><div class="v131-card-actions">${locked?`<button class="secondary" data-alin-click="v131AccountInfo" data-alin-click-arg0="${escx(x.id)}">تفاصيل الصلاحية</button>`:`<button class="secondary" data-alin-click="v132OpenAccountEditor" data-alin-click-arg0="${escx(x.id)}">تعديل كامل</button><button class="warning" data-alin-click="v132ToggleAccount" data-alin-click-arg0="${escx(x.id)}" data-alin-click-arg1="${st==='active'?'inactive':'active'}">${st==='active'?'إيقاف':'تفعيل'}</button><button class="secondary" data-alin-click="v132OpenActivity" data-alin-click-arg0="${escx(x.id)}">النشاط</button><button class="danger" data-alin-click="v132SafeDeleteAccount" data-alin-click-arg0="${escx(x.id)}">أرشفة</button>`}</div></article>`;
  }
  function courierAreaPicker(){
    return `<section id="v163CourierAccountFields" class="v163-courier-account-fields" hidden>
      <div class="v163-courier-fields-title"><div><b>بيانات حساب المندوب</b><small>حدد كل المناطق التي يعمل بها المندوب. الطلبات تُطابق حسب منطقة الزبون.</small></div><span>مناطق متعددة</span></div>
      <div class="form-grid v163-courier-fields-grid"><select id="v163CourierAvailability"><option value="available">متاح</option><option value="busy">مشغول</option><option value="offline">غير متصل</option></select></div>
      <div class="v163-area-toolbar"><h4>مناطق عمل المندوب</h4><div><button type="button" class="secondary" data-alin-click="v131CourierAreasSelectAll">تحديد الكل</button><button type="button" class="secondary" data-alin-click="v131CourierAreasClear">إلغاء التحديد</button></div></div>
      <div id="v163CourierAreaPicker" class="v163-area-picker">${deliveryAreaNames().map(name=>`<label><input type="checkbox" value="${escx(name)}" data-alin-change="v131CourierAreaCount"><span>${escx(name)}</span></label>`).join('')}</div>
      <p class="v163-account-note"><b id="v163CourierAreaCount">0</b> منطقة محددة. بعد الحفظ يظهر المندوب فقط ضمن الطلبات المطابقة لمناطقه.</p>
    </section>`;
  }
  function render(){
    if(!window.adminContent)return;
    const s=stats(),rows=filtered();
    adminContent.innerHTML=`<section class="v131-accounts"><header class="v131-accounts-head"><div><h2>إدارة الحسابات</h2><p>إدارة المدرسين والمكتبات والمندوبين والصلاحيات من مكان واحد.</p></div><button type="button" class="v131-add-account" data-alin-click="v131ToggleAccountForm">+ إضافة حساب جديد</button></header><section class="v131-account-stats"><article class="v131-account-stat"><small>إجمالي الحسابات</small><b>${s.all}</b></article><article class="v131-account-stat"><small>الحسابات الفعالة</small><b>${s.active}</b></article><article class="v131-account-stat danger"><small>الحسابات الموقوفة</small><b>${s.inactive}</b></article><article class="v131-account-stat"><small>المدرسون</small><b>${s.teachers}</b></article><article class="v131-account-stat"><small>المكتبات</small><b>${s.libraries}</b></article><article class="v131-account-stat"><small>المندوبون</small><b>${s.couriers}</b></article></section><section id="v131AccountForm" class="v131-account-form"><h3>إضافة حساب</h3><div class="form-grid"><select id="aRole" data-alin-change="v131SyncAccountRole"><option value="teacher">مدرس</option><option value="library">مكتبة</option><option value="courier">مندوب</option><option value="accountant">محاسب</option></select><input id="aName" placeholder="الاسم الكامل"><input id="aUser" placeholder="اسم الدخول"><input id="aPass" type="password" placeholder="كلمة مرور من 12 حرفاً وحروف وأرقام"><input id="aPhone" inputmode="tel" placeholder="رقم الهاتف"><input id="aArea" placeholder="المنطقة"><input id="aLandmark" placeholder="أقرب نقطة دالة"></div>${courierAreaPicker()}<div class="form-actions"><button type="button" class="secondary" data-alin-click="v131ToggleAccountForm" data-alin-click-arg0="false" data-alin-click-arg0-type="boolean">إلغاء</button><button type="button" id="v131SaveAccountButton" data-alin-click="addAccount">حفظ الحساب</button></div></section><section class="v131-account-tools"><input id="v131AccountSearch" value="${escx(state.query)}" placeholder="ابحث بالاسم أو اسم الدخول أو المنطقة" data-alin-input="v131AccountFilter" data-alin-input-arg0="query" data-alin-input-arg1-source="value"><select data-alin-change="v131AccountFilter" data-alin-change-arg0="role" data-alin-change-arg1-source="value"><option value="all">كل أنواع الحسابات</option>${Object.entries(roleLabel).map(([k,v])=>`<option value="${k}" ${state.role===k?'selected':''}>${v}</option>`).join('')}</select><select data-alin-change="v131AccountFilter" data-alin-change-arg0="status" data-alin-change-arg1-source="value"><option value="all">كل الحالات</option><option value="active" ${state.status==='active'?'selected':''}>فعال</option><option value="inactive" ${state.status==='inactive'?'selected':''}>موقوف</option><option value="pending" ${state.status==='pending'?'selected':''}>قيد المراجعة</option></select><select data-alin-change="v131AccountFilter" data-alin-change-arg0="area" data-alin-change-arg1-source="value"><option value="all">كل المناطق</option>${areas().map(a=>`<option value="${escx(a)}" ${state.area===a?'selected':''}>${escx(a)}</option>`).join('')}</select></section><nav class="v131-role-tabs">${[['all','الكل'],...Object.entries(roleLabel)].map(([k,v])=>`<button class="${state.role===k?'active':''}" data-alin-click="v131AccountFilter" data-alin-click-arg0="role" data-alin-click-arg1="${k}">${v}</button>`).join('')}</nav><section class="v131-account-grid">${rows.map(card).join('')||'<div class="v131-empty">لا توجد حسابات مطابقة للبحث والفلترة.</div>'}</section><section id="v132AccountEditorHost"></section></section>`;
    adminContent.dataset.adminModule='accounts';
    adminContent.classList.add('admin-accounts-module');
    window.v131SyncAccountRole();
  }

  window.v131SyncAccountRole=()=>{
    const role=document.getElementById('aRole')?.value||'teacher';
    const courier=role==='courier';
    const box=document.getElementById('v163CourierAccountFields');if(box)box.hidden=!courier;
    const area=document.getElementById('aArea'),landmark=document.getElementById('aLandmark');
    if(area){area.hidden=courier;area.disabled=courier;}
    if(landmark){landmark.hidden=courier;landmark.disabled=courier;}
    const title=document.querySelector('#v131AccountForm h3');if(title)title.textContent=courier?'إضافة حساب مندوب':'إضافة حساب';
    const save=document.getElementById('v131SaveAccountButton');if(save)save.textContent=courier?'حفظ حساب المندوب':'حفظ الحساب';
    window.v131CourierAreaCount();
  };
  window.v131CourierAreaCount=()=>{const count=document.querySelectorAll('#v163CourierAreaPicker input:checked').length;const out=document.getElementById('v163CourierAreaCount');if(out)out.textContent=String(count);return count};
  window.v131CourierAreasSelectAll=()=>{document.querySelectorAll('#v163CourierAreaPicker input').forEach(x=>x.checked=true);window.v131CourierAreaCount()};
  window.v131CourierAreasClear=()=>{document.querySelectorAll('#v163CourierAreaPicker input').forEach(x=>x.checked=false);window.v131CourierAreaCount()};
  window.v131AccountFilter=(k,v)=>{state[k]=v;render()};
  window.v131ToggleAccountForm=(force)=>{const el=document.getElementById('v131AccountForm');if(!el)return;el.classList.toggle('open',typeof force==='boolean'?force:!el.classList.contains('open'));if(el.classList.contains('open')){window.v131SyncAccountRole();el.scrollIntoView({behavior:'smooth',block:'center'})}};
  window.v131AccountInfo=id=>{const x=allAccounts().find(a=>String(a.id)===String(id));if(!x)return;alert(`${x.name}\nنوع الحساب: ${roleLabel[x.role]}\nالصلاحية: ${x.role==='admin'?'إدارة كاملة':'المالية والتقارير فقط'}`)};
  window.renderAccountsAdmin=render;
  if(window.AlinAdminModules?.register)AlinAdminModules.register('accounts',()=>render());
})();

;
;

/* modules/teacher/booklets.js */
// === teacher/booklets.js ===
/* ===== teacher/js/booklets.js ===== */
/* V111: actual teacher code moved from core/js/platform-legacy.js */
window.AlinTeacherModules=window.AlinTeacherModules||{};
function bestTeacherBook(books,orders){
  let counts={}; orders.forEach(o=>counts[o.item_id]=(counts[o.item_id]||0)+(+o.qty||0));
  const best=books.slice().sort((a,b)=>(counts[b.id]||0)-(counts[a.id]||0))[0];
  return best?`${esc(best.title)} (${counts[best.id]||0} نسخة)`:'-';
}

async function sendTeacherBookRequest(){
  try{
    const f=new FormData(teacherRequestForm);
    if(!String(f.get('title')||'').trim()) throw Error('اكتب اسم الملزمة');
    const sourceFile=f.get('source');
    if(!sourceFile || !sourceFile.name) throw Error('اختر ملف Word بصيغة DOCX');
    const ext=(sourceFile.name.split('.').pop()||'').toLowerCase();
    if(ext!=='docx') throw Error('صيغة الملف يجب أن تكون DOCX حتى يمكن عرضها داخل المنصة بدون تنزيل');
    const validMime=['application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/octet-stream',''];
    if(sourceFile.type && !validMime.includes(sourceFile.type)) throw Error('اختر ملف Word DOCX صحيح');
    const requestId=uid('TR');
    const path=await uploadFile('teacher-requests',sourceFile,{type:'docx',required:true,ownerId:current.id,entityId:requestId,maxBytes:20*1024*1024});
    const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)throw new Error('خدمة طلبات المدرسين غير متاحة');
    const {data,error}=await client.rpc('alin_teacher_create_request',{
      p_id:requestId,p_title:String(f.get('title')).trim(),p_subject:String(f.get('subject')||''),p_grade:String(f.get('grade')||''),p_note:String(f.get('note')||''),
      p_source_file_path:path||'',p_source_file_name:sourceFile.name||'',p_source_mime_type:sourceFile.type||'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    });
    if(error)throw error;if(!data?.ok)throw new Error(data?.error||'لم يؤكد الخادم إرسال الطلب');
    await audit('teacher_request','رفع ملف Word لطلب ملزمة من '+current.name);
    await load(); teacherTab('requests'); toast('تم إرسال ملف Word للإدارة للمراجعة');
  }catch(e){
    console.warn('teacher request error', e);
    if(isMissingTableError(e,'teacher_requests')){
      alert('تعذر إرسال طلب الملزمة حالياً. تأكد من تنفيذ ملف القاعدة النظيفة في مشروع Supabase الجديد.');
      return;
    }
    alert(e.message||'تعذر إرسال الطلب حالياً.');
  }
}

async function openTeacherPdf(bookletId){
  const b=db.booklets.find(x=>x.id===bookletId); if(!b?.file_path)return alert('لا يوجد ملف PDF لهذه الملزمة');
  let cleanUrl='';
  try{cleanUrl=await secureFileUrl(b.file_path,300,'booklets');}catch(e){return alert(e.message||'تعذر فتح ملف الملزمة');}
  checkoutBox.innerHTML=`<h2>مشاهدة الملزمة</h2><div class="pdf-viewer"><div class="pdf-loading">جاري فتح الملزمة...</div></div><div class="row-actions no-print"><button class="secondary" data-alin-click="closeCheckout">إغلاق</button></div>`;
  checkoutModal.classList.remove('hidden');
  const ok=await checkPublicFile(cleanUrl);
  if(!ok){
    checkoutBox.innerHTML=`<h2>مشاهدة الملزمة</h2><div class="empty-state"><b>تعذر فتح ملف الملزمة</b><p>الملف القديم غير مرتبط بالتخزين الحالي. احذف الملزمة من لوحة المدير وارفع ملف PDF من جديد.</p></div><div class="row-actions no-print"><button class="secondary" data-alin-click="closeCheckout">إغلاق</button></div>`;
    return;
  }
  const url=cleanUrl+'#toolbar=0&navpanes=0&scrollbar=1';
  checkoutBox.innerHTML=`<h2>مشاهدة الملزمة</h2><div class="pdf-guard"><div class="watermark">${esc(current?.name||'منصة آلين')} — مشاهدة فقط</div><iframe src="${url}" data-alin-contextmenu="@prevent"></iframe></div><div class="row-actions no-print"><button class="secondary" data-alin-click="closeCheckout">إغلاق</button></div>`;
}

function teacherPhoneForBooklet(b){ return b.teacher_phone || teacherObj(b.teacher_id).phone || ''; }

function teacherImageForBooklet(b){ return b.teacher_image_path || teacherObj(b.teacher_id).avatar_path || b.cover_path || ''; }

function alinBookletTeacher(b){ return teacherName(b.teacher_id); }

function alinV72TeacherName(item){
  return (db.accounts?.teachers||[]).find(t=>t.id===item.teacher_id)?.name||'';
}

async function teacherRequestStatus(id,status){ await update('teacher_requests',{status},{id}); await audit('teacher_request','تحديث طلب مدرس '+id+' إلى '+status); await load(); renderTeacherRequestsAdmin(); }

async function openTeacherRequestSource(id){
  const r=(db.teacherRequests||[]).find(x=>String(x.id)===String(id));
  if(!r?.source_file_path)return alert('لا يوجد ملف مرفوع لهذا الطلب');
  const fileName=String(r.source_file_name||r.source_file_path||'').toLowerCase();
  if(!fileName.endsWith('.docx') && String(r.source_file_type||'').toLowerCase()!=='docx'){
    return alert('هذا ملف قديم غير قابل للمعاينة الداخلية. اطلب من المدرس إعادة رفعه بصيغة DOCX.');
  }
  checkoutBox.innerHTML=`<section class="teacher-word-viewer"><div class="teacher-word-head"><div><h2>معاينة ملف Word</h2><p>${esc(r.title||'ملزمة')} — مشاهدة داخلية فقط</p></div><span>DOCX</span></div><div class="teacher-word-security">لا يوجد زر تنزيل داخل المعاينة. استخدم ملاحظات الإدارة لطلب أي تعديل من المدرس.</div><div id="teacherWordPreview" class="teacher-word-pages"><div class="teacher-word-loading">جاري تجهيز المعاينة...</div></div><div class="row-actions no-print"><button class="secondary" data-alin-click="closeCheckout">إغلاق</button></div></section>`;
  checkoutModal.classList.remove('hidden');
  try{
    if(typeof window.AlinLoadMammoth!=='function') throw new Error('محمل مكتبة معاينة Word غير متاح');
    await window.AlinLoadMammoth();
    const resolved=typeof alinResolveStoredFile==='function'?await alinResolveStoredFile(r.source_file_path,'teacher-requests'):null;
    const url=resolved?.url;
    if(!url)throw new Error('ملف Word غير محمي أو غير متاح');
    const response=await fetch(url,{cache:'no-store'});
    if(!response.ok) throw new Error('تعذر قراءة ملف Word');
    const arrayBuffer=await response.arrayBuffer();
    const result=await window.mammoth.convertToHtml({arrayBuffer},{includeDefaultStyleMap:true});
    const target=document.getElementById('teacherWordPreview');
    if(!target)return;
    target.innerHTML=`<article class="teacher-word-document" data-alin-contextmenu="@prevent">${result.value||'<p>الملف لا يحتوي نصاً قابلاً للعرض.</p>'}</article>`;
    target.querySelectorAll('a').forEach(a=>{a.removeAttribute('href');a.removeAttribute('download');});
    target.querySelectorAll('img').forEach(img=>img.setAttribute('draggable','false'));
  }catch(e){
    const target=document.getElementById('teacherWordPreview');
    if(target)target.innerHTML=`<div class="teacher-word-error"><b>تعذرت معاينة الملف</b><p>${esc(e.message||'تأكد أن الملف DOCX صحيح وأن التخزين متاح.')}</p></div>`;
  }
}

window.AlinTeacherModules['bestTeacherBook']=typeof bestTeacherBook==='function'?bestTeacherBook:window['bestTeacherBook'];window['bestTeacherBook']=window.AlinTeacherModules['bestTeacherBook'];
window.AlinTeacherModules['sendTeacherBookRequest']=typeof sendTeacherBookRequest==='function'?sendTeacherBookRequest:window['sendTeacherBookRequest'];window['sendTeacherBookRequest']=window.AlinTeacherModules['sendTeacherBookRequest'];
window.AlinTeacherModules['openTeacherPdf']=typeof openTeacherPdf==='function'?openTeacherPdf:window['openTeacherPdf'];window['openTeacherPdf']=window.AlinTeacherModules['openTeacherPdf'];
window.AlinTeacherModules['teacherPhoneForBooklet']=typeof teacherPhoneForBooklet==='function'?teacherPhoneForBooklet:window['teacherPhoneForBooklet'];window['teacherPhoneForBooklet']=window.AlinTeacherModules['teacherPhoneForBooklet'];
window.AlinTeacherModules['teacherImageForBooklet']=typeof teacherImageForBooklet==='function'?teacherImageForBooklet:window['teacherImageForBooklet'];window['teacherImageForBooklet']=window.AlinTeacherModules['teacherImageForBooklet'];
window.AlinTeacherModules['alinBookletTeacher']=typeof alinBookletTeacher==='function'?alinBookletTeacher:window['alinBookletTeacher'];window['alinBookletTeacher']=window.AlinTeacherModules['alinBookletTeacher'];
window.AlinTeacherModules['alinV72TeacherName']=typeof alinV72TeacherName==='function'?alinV72TeacherName:window['alinV72TeacherName'];window['alinV72TeacherName']=window.AlinTeacherModules['alinV72TeacherName'];
window.AlinTeacherModules['teacherRequestStatus']=typeof teacherRequestStatus==='function'?teacherRequestStatus:window['teacherRequestStatus'];window['teacherRequestStatus']=window.AlinTeacherModules['teacherRequestStatus'];
window.AlinTeacherModules['openTeacherRequestSource']=typeof openTeacherRequestSource==='function'?openTeacherRequestSource:window['openTeacherRequestSource'];window['openTeacherRequestSource']=window.AlinTeacherModules['openTeacherRequestSource'];

async function approveTeacherBooklet(id){
  const booklet=(db.booklets||[]).find(row=>String(row.id)===String(id));
  if(!booklet)throw new Error('الملزمة غير موجودة');
  if(!window.sb?.rpc)throw new Error('خدمة الموافقة الآمنة غير متاحة');
  const {data,error}=await window.sb.rpc('alin_teacher_approve_booklet',{p_booklet_id:String(booklet.id)});
  if(error)throw error;
  const payload={teacher_approved:true,teacher_approved_at:new Date().toISOString()};
  Object.assign(booklet,payload);
  if(typeof audit==='function')await audit('booklet','موافقة المدرس على نشر '+(booklet.title||booklet.id));
  if(typeof load==='function')await load();
  teacherTab('booklets');
  if(typeof toast==='function')toast('تم إرسال الموافقة إلى الإدارة');
}

async function publishTeacherBooklet(id){
  const booklet=(db.booklets||[]).find(row=>String(row.id)===String(id));
  if(!booklet)throw new Error('الملزمة غير موجودة');
  if(!booklet.teacher_approved&&!confirm('المدرس لم يوافق بعد. هل تريد النشر رغم ذلك؟'))return;
  const payload={status:'published',publish_status:'published',published_at:new Date().toISOString(),updated_at:new Date().toISOString()};
  await update('booklets',payload,{id:booklet.id});
  Object.assign(booklet,payload);
  if(typeof audit==='function')await audit('booklet','نشر ملزمة '+(booklet.title||booklet.id));
  if(typeof load==='function')await load();
  if(typeof renderTeacherRequestsAdmin==='function')renderTeacherRequestsAdmin();
}

async function unpublishTeacherBooklet(id){
  const booklet=(db.booklets||[]).find(row=>String(row.id)===String(id));
  if(!booklet)throw new Error('الملزمة غير موجودة');
  const payload={status:'hidden',publish_status:'hidden',updated_at:new Date().toISOString()};
  await update('booklets',payload,{id:booklet.id});
  Object.assign(booklet,payload);
  if(typeof audit==='function')await audit('booklet','إخفاء ملزمة '+(booklet.title||booklet.id));
  if(typeof load==='function')await load();
}

window.approveTeacherBooklet=approveTeacherBooklet;
window.alinTeacherApproveBookletV56=approveTeacherBooklet;
window.publishTeacherBooklet=publishTeacherBooklet;
window.alinAdminPublishBookletV56=publishTeacherBooklet;
window.unpublishTeacherBooklet=unpublishTeacherBooklet;
window.alinUnpublishBookletV56=unpublishTeacherBooklet;
window.AlinTeacherModules.approveTeacherBooklet=approveTeacherBooklet;
window.AlinTeacherModules.publishTeacherBooklet=publishTeacherBooklet;
window.AlinTeacherModules.unpublishTeacherBooklet=unpublishTeacherBooklet;


;
;

/* modules/teacher/finance.js */
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
;

/* modules/teacher/dashboard.js */
// === teacher/dashboard.js ===
/* ALIN v2.2.6 — teacher dashboard and booklets tabs. */
(function(){
  'use strict';
  const app=window.TeacherApp;
  if(!app)throw new Error('TeacherApp must load before teacher/dashboard.js');

  const escSafe=value=>typeof esc==='function'?esc(value):String(value??'').replace(/[&<>'"]/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char]));
  const moneySafe=value=>typeof money==='function'?money(value):Number(value||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const dateOnly=value=>String(value||'').slice(0,10);
  const monthOnly=value=>String(value||'').slice(0,7);
  const statusName=status=>({published:'منشورة',active:'منشورة',hidden:'مخفية',draft:'مسودة',pending:'قيد المراجعة',review:'قيد المراجعة',rejected:'مرفوضة',approved:'منشورة'}[String(status||'').toLowerCase()]||status||'غير محددة');
  const statusClass=status=>{
    const value=String(status||'').toLowerCase();
    if(['published','active','approved'].includes(value))return'published';
    if(['pending','review','new'].includes(value))return'pending';
    if(value==='rejected')return'rejected';
    return'hidden';
  };

  function paidAmount(context){
    return context.payouts.filter(row=>String(row.status||'').toLowerCase()==='paid').reduce((sum,row)=>sum+(+row.amount||0),0);
  }

  function renderChrome(context){
    const page=document.getElementById('teacherPage');
    const statsBox=document.getElementById('teacherStats');
    if(!page||!statsBox)return;
    let header=page.querySelector('.teacher-v148-head');
    if(!header){
      header=document.createElement('div');
      header.className='teacher-v148-head';
      page.insertBefore(header,statsBox);
    }
    const avatar=context.teacher.avatar_path||context.teacher.image_path||'';
    header.innerHTML=`<div><h1>أهلاً ${escSafe(context.teacher.name||window.current?.name||'أستاذنا')}</h1><p>تابع ملازمك ومبيعاتك وأرباحك من مكان واحد.</p></div><div class="teacher-v148-avatar">${avatar?`<img src="${escSafe(typeof mediaUrl==='function'?mediaUrl(avatar):avatar)}" alt="">`:'م'}</div>`;

    const today=new Date().toISOString().slice(0,10);
    const month=today.slice(0,7);
    const published=context.books.filter(book=>['published','active','approved'].includes(String(book.status||'').toLowerCase())).length;
    const pending=context.books.filter(book=>['pending','review','new','draft'].includes(String(book.status||'').toLowerCase())).length;
    const completed=context.orders.filter(order=>['delivered','completed','done','received'].includes(String(order.status||'').toLowerCase()));
    const daySales=completed.filter(order=>dateOnly(order.delivered_at||order.updated_at||order.created_at)===today).reduce((sum,order)=>sum+(+order.total||0),0);
    const monthSales=completed.filter(order=>monthOnly(order.delivered_at||order.updated_at||order.created_at)===month).reduce((sum,order)=>sum+(+order.total||0),0);
    const earned=context.ledger.reduce((sum,row)=>sum+(+row.teacher||0),0);
    const paid=paidAmount(context);
    statsBox.innerHTML=`<div><b>الملازم المنشورة</b><span>${published}</span></div><div><b>قيد المراجعة</b><span>${pending}</span></div><div><b>مبيعات اليوم</b><span>${moneySafe(daySales)} د.ع</span></div><div><b>مبيعات الشهر</b><span>${moneySafe(monthSales)} د.ع</span></div><div><b>الرصيد الحالي</b><span>${moneySafe(Math.max(0,earned-paid))} د.ع</span></div><div><b>المستلم سابقاً</b><span>${moneySafe(paid)} د.ع</span></div>`;
  }

  function renderDashboard(context){
    const host=document.getElementById('teacherContent');
    if(!host)return;
    const recent=context.orders.slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||''))).slice(0,6);
    const notices=context.notifications.slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||''))).slice(0,5);
    const orderHtml=recent.map(order=>`<div class="teacher-v148-order"><div><b>${escSafe(order.order_number||order.id)} — ${escSafe(order.title||'طلب ملزمة')}</b><small>${escSafe(statusName(order.status))} • ${+order.qty||1} نسخة • ${dateOnly(order.created_at)||'-'}</small></div><strong>${moneySafe(order.total)} د.ع</strong></div>`).join('')||'<div class="teacher-v148-empty">لا توجد طلبات حديثة.</div>';
    const noticeHtml=notices.map(row=>`<div class="teacher-v148-notice"><b>${escSafe(row.title||'إشعار')}</b><p>${escSafe(row.message||row.text||'')}</p></div>`).join('')||'<div class="teacher-v148-empty">لا توجد إشعارات جديدة.</div>';
    host.innerHTML=`<div class="teacher-v148-grid"><section class="teacher-v148-card"><div class="teacher-v148-card-head"><h3>آخر الطلبات</h3><button class="teacher-v148-link" data-alin-click="teacherTab" data-alin-click-arg0="orders">عرض الكل</button></div><div class="teacher-v148-orders">${orderHtml}</div></section><aside class="teacher-v148-card"><div class="teacher-v148-card-head"><h3>آخر الإشعارات</h3><button class="teacher-v148-link" data-alin-click="teacherTab" data-alin-click-arg0="notifications">عرض الكل</button></div><div class="teacher-v148-notices">${noticeHtml}</div></aside></div>`;
  }

  function renderBooklets(context){
    const host=document.getElementById('teacherContent');
    if(!host)return;
    const subjects=[...new Set(context.books.map(book=>book.subject).filter(Boolean))];
    const cards=context.books.map(book=>{
      const orders=context.orders.filter(order=>String(order.item_id)===String(book.id));
      const qty=orders.reduce((sum,order)=>sum+(+order.qty||0),0);
      const profit=context.ledger.filter(row=>String(row.item_id||row.booklet_id||'')===String(book.id)).reduce((sum,row)=>sum+(+row.teacher||0),0);
      const cover=book.cover_path||book.image_path||book.cover_url||'';
      return `<article class="teacher-v148-book" data-title="${escSafe((book.title||'').toLowerCase())}" data-status="${escSafe(statusClass(book.status))}" data-subject="${escSafe(book.subject||'')}"><div class="teacher-v148-cover">${cover?`<img src="${escSafe(typeof mediaUrl==='function'?mediaUrl(cover):cover)}" alt="${escSafe(book.title)}">`:'آلين'}</div><div class="teacher-v148-book-body"><span class="teacher-v148-status ${statusClass(book.status)}">${escSafe(statusName(book.status))}</span><h3>${escSafe(book.title)}</h3><div class="teacher-v148-meta"><span class="teacher-v148-chip">${escSafe(book.subject||'بدون مادة')}</span><span class="teacher-v148-chip">${escSafe(book.grade||'بدون صف')}</span></div><div class="teacher-v148-book-stats"><div><small>السعر</small><b>${moneySafe(book.price)} د.ع</b></div><div><small>المبيعات</small><b>${qty} نسخة</b></div><div><small>الأرباح</small><b>${moneySafe(profit)} د.ع</b></div></div><div class="teacher-v148-actions">${book.file_path?`<button data-alin-click="openTeacherPdf" data-alin-click-arg0="${escSafe(book.id)}">عرض</button>`:''}${!book.teacher_approved&&!['published','active'].includes(String(book.status||'').toLowerCase())?`<button class="success" data-alin-click="approveTeacherBooklet" data-alin-click-arg0="${escSafe(book.id)}">موافقة للنشر</button>`:''}<button class="secondary" data-alin-click="teacherTab" data-alin-click-arg0="requests">طلب تحديث</button></div></div></article>`;
    }).join('')||'<div class="teacher-v148-empty">لا توجد ملازم مرتبطة بحسابك.</div>';
    host.innerHTML=`<section class="teacher-v148-card"><div class="teacher-v148-card-head"><h3>ملازمي</h3><button data-alin-click="teacherTab" data-alin-click-arg0="requests">رفع طلب ملزمة</button></div><div class="teacher-v148-book-toolbar"><input id="teacherBookSearch" placeholder="ابحث باسم الملزمة" data-alin-input="filterTeacherBooks"><select id="teacherBookStatus" data-alin-change="filterTeacherBooks"><option value="">كل الحالات</option><option value="published">منشورة</option><option value="pending">قيد المراجعة</option><option value="hidden">مخفية/مسودة</option><option value="rejected">مرفوضة</option></select><select id="teacherBookSubject" data-alin-change="filterTeacherBooks"><option value="">كل المواد</option>${subjects.map(subject=>`<option>${escSafe(subject)}</option>`).join('')}</select></div><div id="teacherV148BookGrid" class="teacher-v148-book-grid">${cards}</div></section>`;
  }

  window.filterTeacherBooks=function(){
    const query=(document.getElementById('teacherBookSearch')?.value||'').trim().toLowerCase();
    const status=document.getElementById('teacherBookStatus')?.value||'';
    const subject=document.getElementById('teacherBookSubject')?.value||'';
    document.querySelectorAll('#teacherV148BookGrid .teacher-v148-book').forEach(card=>{
      card.hidden=Boolean((query&&!card.dataset.title.includes(query))||(status&&card.dataset.status!==status)||(subject&&card.dataset.subject!==subject));
    });
  };

  app.registerChrome(renderChrome);
  app.registerTab('dashboard',renderDashboard);
  app.registerTab('booklets',renderBooklets);
  window.TeacherDashboardV148={renderChrome,renderDashboard,renderBooklets};
})();
;

/* modules/teacher/publishing.js */
// === teacher/publishing.js ===
/* ===== teacher/js/teacher-publishing-v150.js ===== */
/* V150 — رفع الملزمة وطلبات النشر */
(function(){
  const escSafe=v=>typeof esc==='function'?esc(v):String(v??'');
  const currentSafe=()=>typeof current!=='undefined'?current:(window.current||{});
  const dbSafe=()=>typeof db!=='undefined'?db:(window.db||{});
  const statusMap={new:'قيد الاستلام',pending:'قيد المراجعة',designing:'قيد التصميم',review:'قيد المراجعة',ready:'جاهزة للموافقة',approved:'تمت الموافقة',published:'منشورة',rejected:'مرفوضة'};
  const statusName=s=>statusMap[String(s||'new').toLowerCase()]||s||'قيد المراجعة';
  const statusStep=s=>{s=String(s||'new').toLowerCase();if(['rejected'].includes(s))return 1;if(['new','pending'].includes(s))return 1;if(['designing'].includes(s))return 2;if(['review','ready'].includes(s))return 3;if(['approved','published'].includes(s))return 4;return 1};
  function teacherRequests(){
    const cur=currentSafe(), database=dbSafe();
    return (database.teacherRequests||database.teacher_requests||[]).filter(r=>String(r.teacher_id)===String(cur.id)).sort((a,b)=>String(b.created_at||b.id||'').localeCompare(String(a.created_at||a.id||'')));
  }
  function requestCards(){
    const rows=teacherRequests();
    if(!rows.length)return '<div class="teacher-v150-empty">لا توجد طلبات رفع أو تحديث حتى الآن.</div>';
    return rows.map(r=>{
      const status=String(r.status||'new').toLowerCase(),step=statusStep(status);
      const adminNote=r.admin_note||r.review_note||r.rejection_reason||'';
      return `<article class="teacher-v150-request"><div class="teacher-v150-request-top"><div><h4>${escSafe(r.title||'طلب ملزمة')}</h4><small>${escSafe(r.subject||'بدون مادة')} • ${escSafe(r.grade||'بدون صف')}</small></div><span class="teacher-v150-status ${escSafe(status)}">${escSafe(statusName(status))}</span></div><div class="teacher-v150-progress">${[1,2,3,4].map(i=>`<span class="${i<=step?'done':''}"></span>`).join('')}</div>${r.note?`<small>${escSafe(r.note)}</small>`:''}${adminNote?`<div class="teacher-v150-note" style="margin-top:10px">ملاحظة الإدارة: ${escSafe(adminNote)}</div>`:''}<div class="teacher-v150-request-actions">${r.source_file_path?`<button type="button" data-alin-click="openTeacherRequestSource" data-alin-click-arg0="${escSafe(r.id)}">عرض الملف المرسل</button>`:''}<button type="button" class="secondary" data-alin-click="alinV150ReuseRequest" data-alin-click-arg0="${escSafe(r.id)}">إعادة استخدام البيانات</button></div></article>`;
    }).join('');
  }
  function renderPublishing(){
    const box=document.getElementById('teacherContent');if(!box)return;
    box.innerHTML=`<div class="teacher-v150-layout"><section class="teacher-v150-panel"><div class="teacher-v150-panel-head"><div><h3>رفع ملزمة جديدة</h3><p>ارفع ملف Word بصيغة DOCX حتى تراجعه الإدارة داخل المنصة. النسخة النهائية PDF يرفعها المدير عند النشر.</p></div><span class="teacher-v150-badge">مراجعة قبل النشر</span></div><form id="teacherRequestForm" class="teacher-v150-form"><div class="teacher-v150-field"><label>اسم الملزمة *</label><input name="title" id="v150Title" required placeholder="مثال: ملزمة الرياضيات"></div><div class="teacher-v150-field"><label>المادة</label><input name="subject" id="v150Subject" placeholder="الرياضيات، الفيزياء..."></div><div class="teacher-v150-field"><label>الصف أو المرحلة</label><input name="grade" id="v150Grade" placeholder="السادس الإعدادي"></div><div class="teacher-v150-field"><label>الفصل</label><input id="v150Chapter" placeholder="الفصل الأول"></div><div class="teacher-v150-field"><label>سنة الإصدار</label><input id="v150Year" type="number" min="2024" max="2100" value="${new Date().getFullYear()}"></div><div class="teacher-v150-field"><label>السعر المقترح</label><input id="v150Price" type="number" min="0" step="250" placeholder="بالدينار العراقي"></div><div class="teacher-v150-field full"><label>ملاحظات للإدارة</label><textarea name="note" id="v150Note" placeholder="اكتب تفاصيل التنضيد أو الغلاف أو أي ملاحظة مهمة"></textarea></div><div class="teacher-v150-field full"><label class="teacher-v150-upload"><input name="source" id="v150Word" type="file" accept="application/vnd.openxmlformats-officedocument.wordprocessingml.document,.docx" data-alin-change="alinV150FileChanged" data-alin-change-arg0-source="self"><span class="teacher-v150-upload-icon">W</span><b>اختر ملف الملزمة بصيغة Word</b><small>ملف DOCX قابل للمراجعة، ولا يُنشر للطالب مباشرة</small></label><div id="v150FileInfo" class="teacher-v150-file-info"></div></div><div id="v150Preview" class="teacher-v150-preview"></div><div class="teacher-v150-note">بعد الإرسال يستطيع المدير مشاهدة محتوى Word داخل المنصة فقط وإرسال ملاحظاته. لا يظهر زر تنزيل في واجهة المعاينة.</div><div class="teacher-v150-actions"><button type="button" class="secondary" data-alin-click="alinV150PreviewRequest">معاينة البيانات</button><button type="button" id="v150SubmitBtn" data-alin-click="alinV150SubmitRequest">إرسال للإدارة</button></div></form></section><aside class="teacher-v150-panel"><div class="teacher-v150-panel-head"><div><h3>طلبات النشر والتحديث</h3><p>تابع حالة كل طلب وملاحظات الإدارة.</p></div><span class="teacher-v150-badge">${teacherRequests().length} طلب</span></div><div class="teacher-v150-requests">${requestCards()}</div></aside></div>`;
  }
  window.alinV150FileChanged=function(input){
    const file=input.files?.[0],info=document.getElementById('v150FileInfo');if(!info)return;
    if(!file){info.classList.remove('show');info.innerHTML='';return}
    const mb=(file.size/1024/1024).toFixed(1);info.innerHTML=`<span>${escSafe(file.name)}</span><b>${mb} MB</b>`;info.classList.add('show');
  };
  window.alinV150PreviewRequest=function(){
    const title=document.getElementById('v150Title')?.value.trim()||'غير محدد',subject=document.getElementById('v150Subject')?.value.trim()||'-',grade=document.getElementById('v150Grade')?.value.trim()||'-',chapter=document.getElementById('v150Chapter')?.value.trim()||'-',year=document.getElementById('v150Year')?.value||'-',price=document.getElementById('v150Price')?.value||'0',preview=document.getElementById('v150Preview');if(!preview)return;
    preview.innerHTML=`<h4>معاينة الطلب</h4><div class="teacher-v150-preview-grid"><div><small>الملزمة</small><b>${escSafe(title)}</b></div><div><small>المادة</small><b>${escSafe(subject)}</b></div><div><small>الصف</small><b>${escSafe(grade)}</b></div><div><small>الفصل</small><b>${escSafe(chapter)}</b></div><div><small>الإصدار</small><b>${escSafe(year)}</b></div><div><small>السعر المقترح</small><b>${Number(price||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')} د.ع</b></div></div>`;preview.classList.add('show');
  };
  window.alinV150SubmitRequest=async function(){
    const title=document.getElementById('v150Title')?.value.trim();if(!title)return alert('اكتب اسم الملزمة');
    const word=document.getElementById('v150Word')?.files?.[0];if(!word)return alert('اختر ملف Word بصيغة DOCX');const ext=(word.name.split('.').pop()||'').toLowerCase();if(ext!=='docx')return alert('احفظ الملف بصيغة DOCX ثم ارفعه. صيغة DOC القديمة لا يمكن معاينتها بأمان داخل المتصفح.');
    const noteParts=[];const chapter=document.getElementById('v150Chapter')?.value.trim(),year=document.getElementById('v150Year')?.value,price=document.getElementById('v150Price')?.value,note=document.getElementById('v150Note')?.value.trim();
    if(chapter)noteParts.push(`الفصل: ${chapter}`);if(year)noteParts.push(`الإصدار: ${year}`);if(price)noteParts.push(`السعر المقترح: ${price} د.ع`);if(note)noteParts.push(note);
    const noteField=document.getElementById('v150Note');if(noteField)noteField.value=noteParts.join(' | ');
    const btn=document.getElementById('v150SubmitBtn');if(btn){btn.disabled=true;btn.textContent='جاري الإرسال...'}
    try{if(typeof sendTeacherBookRequest!=='function')throw new Error('خدمة إرسال الطلب غير متاحة');await sendTeacherBookRequest();}
    finally{if(btn&&document.body.contains(btn)){btn.disabled=false;btn.textContent='إرسال للإدارة'}}
  };
  window.alinV150ReuseRequest=function(id){
    const r=teacherRequests().find(x=>String(x.id)===String(id));if(!r)return;
    renderPublishing();
    const set=(id,v)=>{const el=document.getElementById(id);if(el)el.value=v||''};set('v150Title',r.title);set('v150Subject',r.subject);set('v150Grade',r.grade);set('v150Note',r.note);document.getElementById('v150Title')?.focus();
  };
  if(!window.TeacherApp)throw new Error('TeacherApp must load before teacher/publishing.js');
  window.TeacherApp.registerTab('requests',()=>renderPublishing());
  window.AlinTeacherModules=window.AlinTeacherModules||{};
  window.AlinTeacherModules.renderPublishingV150=renderPublishing;
})();

/* ===== teacher/js/teacher-review-v152.js ===== */
/* V152 — مسار مراجعة ونشر ملزمة المدرس */
(function(){
  const safeEsc=v=>typeof esc==='function'?esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const cur=()=>typeof current!=='undefined'?current:(window.current||{});
  const data=()=>typeof db!=='undefined'?db:(window.db||{});
  const statusLabels={new:'تم الإرسال',pending:'بانتظار المراجعة',review:'قيد المراجعة',changes_requested:'مطلوب تعديل',resubmitted:'أعيد الإرسال',approved:'تمت الموافقة',ready:'جاهزة للنشر',published:'منشورة',rejected:'مرفوضة',designing:'قيد التجهيز'};
  const label=s=>statusLabels[String(s||'new').toLowerCase()]||String(s||'قيد المراجعة');
  const step=s=>{s=String(s||'new').toLowerCase();if(s==='rejected')return 2;if(['new','pending'].includes(s))return 1;if(['review','designing'].includes(s))return 2;if(['changes_requested'].includes(s))return 3;if(['resubmitted','approved','ready'].includes(s))return 4;if(s==='published')return 5;return 1};
  const teacherRows=()=>((data().teacherRequests||data().teacher_requests||[]).filter(r=>String(r.teacher_id)===String(cur().id))).sort((a,b)=>String(b.updated_at||b.created_at||b.id||'').localeCompare(String(a.updated_at||a.created_at||a.id||'')));
  const allRows=()=>((data().teacherRequests||data().teacher_requests||[])).slice().sort((a,b)=>String(b.updated_at||b.created_at||b.id||'').localeCompare(String(a.updated_at||a.created_at||a.id||'')));
  function parseHistory(r){
    if(Array.isArray(r.version_history))return r.version_history;
    if(typeof r.version_history==='string'){try{return JSON.parse(r.version_history)||[]}catch(_){}}
    if(Array.isArray(r.history))return r.history;
    return [];
  }
  function statusClass(s){return String(s||'new').toLowerCase().replace(/[^a-z_]/g,'')}
  function canReupload(s){return ['changes_requested','rejected'].includes(String(s||'').toLowerCase())}
  function requestCard(r){
    const s=String(r.status||'new').toLowerCase(),n=step(s),hist=parseHistory(r),note=r.admin_note||r.review_note||r.rejection_reason||'',created=r.created_at?new Date(r.created_at).toLocaleDateString(window.AlinI18n?.locale?.()||'ar-IQ'):'-';
    return `<article class="teacher-v152-card" data-title="${safeEsc((r.title||'')+' '+(r.subject||'')+' '+(r.grade||''))}" data-status="${safeEsc(s)}"><div class="teacher-v152-top"><div><h3>${safeEsc(r.title||'طلب ملزمة')}</h3><small>${safeEsc(r.subject||'بدون مادة')} • ${safeEsc(r.grade||'بدون صف')}</small></div><span class="teacher-v152-status ${statusClass(s)}">${safeEsc(label(s))}</span></div><div class="teacher-v152-meta"><span class="teacher-v152-chip">تاريخ الإرسال: ${safeEsc(created)}</span><span class="teacher-v152-chip">الإصدار: ${Math.max(1,hist.length+1)}</span>${r.source_file_name?`<span class="teacher-v152-chip">${safeEsc(r.source_file_name)}</span>`:''}</div><div class="teacher-v152-steps">${['الإرسال','المراجعة','التعديل','الموافقة','النشر'].map((x,i)=>`<span class="teacher-v152-step ${i+1<=n?'done':''}">${x}</span>`).join('')}</div>${note?`<div class="teacher-v152-note"><strong>ملاحظة الإدارة:</strong> ${safeEsc(note)}</div>`:''}${r.note?`<div class="teacher-v152-note"><strong>ملاحظتك:</strong> ${safeEsc(r.note)}</div>`:''}<div class="teacher-v152-actions">${r.source_file_path?`<button type="button" class="secondary" data-alin-click="openTeacherRequestSource" data-alin-click-arg0="${safeEsc(r.id)}">مشاهدة النسخة الحالية</button>`:''}${canReupload(s)?`<button type="button" class="warning" data-alin-click="alinV152ToggleReupload" data-alin-click-arg0="${safeEsc(r.id)}">رفع نسخة معدلة</button>`:''}${s==='approved'||s==='ready'?`<button type="button" class="success" disabled>بانتظار نشر الإدارة</button>`:''}</div>${canReupload(s)?`<div id="v152Reupload-${safeEsc(r.id)}" class="teacher-v152-upload-box hidden"><b>رفع نسخة Word معدلة</b><input id="v152File-${safeEsc(r.id)}" type="file" accept=".docx,application/vnd.openxmlformats-officedocument.wordprocessingml.document"><textarea id="v152Note-${safeEsc(r.id)}" placeholder="اكتب ما تم تعديله"></textarea><button type="button" data-alin-click="alinV152Resubmit" data-alin-click-arg0="${safeEsc(r.id)}">إعادة الإرسال للإدارة</button></div>`:''}<details class="teacher-v152-history"><summary>سجل النسخ والمراجعات (${hist.length})</summary><div class="teacher-v152-history-list">${hist.length?hist.slice().reverse().map((h,i)=>`<div class="teacher-v152-history-item"><span>${safeEsc(h.file_name||h.status||'نسخة سابقة')}</span><span>${safeEsc(h.at?new Date(h.at).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ'):'')}</span></div>`).join(''):'<div class="teacher-v152-history-item"><span>لا يوجد سجل سابق</span></div>'}</div></details></article>`;
  }
  function renderTeacherReview(){
    const box=document.getElementById('teacherContent');if(!box)return;const rows=teacherRows();
    box.innerHTML=`<section class="teacher-v152-wrap"><div class="teacher-v152-head"><div><h2>طلبات النشر والمراجعة</h2><p>تابع مراجعة الإدارة، اطلع على الملاحظات، وارفع نسخة Word معدلة عند الحاجة.</p></div><span class="teacher-v152-count">${rows.length}</span></div><div class="teacher-v152-filters"><input id="v152Search" placeholder="ابحث باسم الملزمة أو المادة" data-alin-input="alinV152Filter"><select id="v152Status" data-alin-change="alinV152Filter"><option value="">كل الحالات</option><option value="new">تم الإرسال</option><option value="review">قيد المراجعة</option><option value="changes_requested">مطلوب تعديل</option><option value="approved">تمت الموافقة</option><option value="published">منشورة</option><option value="rejected">مرفوضة</option></select><select id="v152Sort" data-alin-change="alinV152Filter"><option value="newest">الأحدث أولاً</option><option value="oldest">الأقدم أولاً</option></select></div><div id="v152List" class="teacher-v152-list">${rows.length?rows.map(requestCard).join(''):'<div class="teacher-v152-empty">لا توجد طلبات نشر أو مراجعة حتى الآن.</div>'}</div></section>`;
  }
  window.alinV152Filter=function(){
    const q=(document.getElementById('v152Search')?.value||'').trim().toLowerCase(),s=document.getElementById('v152Status')?.value||'';document.querySelectorAll('#v152List .teacher-v152-card').forEach(c=>{c.hidden=!!((q&&!String(c.dataset.title||'').toLowerCase().includes(q))||(s&&c.dataset.status!==s))});
  };
  window.alinV152ToggleReupload=id=>document.getElementById('v152Reupload-'+id)?.classList.toggle('hidden');
  window.alinV152Resubmit=async function(id){
    const file=document.getElementById('v152File-'+id)?.files?.[0],note=document.getElementById('v152Note-'+id)?.value.trim()||'';if(!file)return alert('اختر ملف DOCX المعدل');if((file.name.split('.').pop()||'').toLowerCase()!=='docx')return alert('الملف يجب أن يكون DOCX');
    const r=teacherRows().find(x=>String(x.id)===String(id));if(!r)return alert('الطلب غير موجود');
    const button=event?.currentTarget;if(button){button.disabled=true;button.textContent='جاري الرفع...'}
    try{
      const path=await uploadFile('teacher-requests',file,{type:'docx',required:true,ownerId:cur().id,entityId:id,maxBytes:20*1024*1024});
      const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)throw new Error('خدمة إعادة إرسال الطلب غير متاحة');
      const {data,error}=await client.rpc('alin_teacher_resubmit_request',{p_id:String(id),p_source_file_path:path,p_source_file_name:file.name,p_note:note||r.note||''});
      if(error)throw error;if(!data?.ok)throw new Error(data?.error||'لم يؤكد الخادم إعادة إرسال الطلب');
      if(typeof audit==='function')await audit('teacher_request','إعادة رفع نسخة Word معدلة للطلب '+id);if(typeof load==='function')await load();renderTeacherReview();if(typeof toast==='function')toast('تم إرسال النسخة المعدلة للإدارة');
    }catch(e){console.warn(e);alert(e.message||'تعذر رفع النسخة المعدلة');}finally{if(button&&document.body.contains(button)){button.disabled=false;button.textContent='إعادة الإرسال للإدارة'}}
  };
  function adminCard(r){
    const s=String(r.status||'new').toLowerCase(),note=r.admin_note||r.review_note||r.rejection_reason||'';return `<article class="teacher-admin-v152-card"><div class="teacher-v152-top"><div><h3>${safeEsc(r.title||'طلب ملزمة')}</h3><small>${safeEsc(r.teacher_name||'مدرس')} • ${safeEsc(r.subject||'')} • ${safeEsc(r.grade||'')}</small></div><span class="teacher-v152-status ${statusClass(s)}">${safeEsc(label(s))}</span></div>${note?`<div class="teacher-v152-note"><strong>آخر ملاحظة:</strong> ${safeEsc(note)}</div>`:''}<div class="teacher-admin-v152-actions">${r.source_file_path?`<button data-alin-click="openTeacherRequestSource" data-alin-click-arg0="${safeEsc(r.id)}">معاينة Word</button>`:''}<textarea id="v152AdminNote-${safeEsc(r.id)}" placeholder="ملاحظة للمدرس أو سبب طلب التعديل"></textarea><button class="secondary" data-alin-click="alinV152AdminDecision" data-alin-click-arg0="${safeEsc(r.id)}" data-alin-click-arg1="review">قيد المراجعة</button><button class="warning" data-alin-click="alinV152AdminDecision" data-alin-click-arg0="${safeEsc(r.id)}" data-alin-click-arg1="changes_requested">طلب تعديل</button><button class="success" data-alin-click="alinV152AdminDecision" data-alin-click-arg0="${safeEsc(r.id)}" data-alin-click-arg1="approved">موافقة</button><button class="danger" data-alin-click="alinV152AdminDecision" data-alin-click-arg0="${safeEsc(r.id)}" data-alin-click-arg1="rejected">رفض</button></div></article>`;
  }
  function renderAdminReview(){
    const rows=allRows();adminContent.innerHTML=`<section class="teacher-admin-v152"><div class="teacher-v152-head"><div><h2>طلبات المدرسين للمراجعة والنشر</h2><p>شاهد ملف Word داخل المنصة، أرسل ملاحظاتك، ثم اطلب تعديلاً أو وافق على الطلب.</p></div><span class="teacher-v152-count">${rows.length}</span></div><div class="teacher-admin-v152-toolbar"><input id="v152AdminSearch" placeholder="بحث بالمدرس أو الملزمة" data-alin-input="alinV152AdminFilter"><select id="v152AdminStatus" data-alin-change="alinV152AdminFilter"><option value="">كل الحالات</option><option value="new">جديد</option><option value="review">قيد المراجعة</option><option value="changes_requested">مطلوب تعديل</option><option value="resubmitted">أعيد الإرسال</option><option value="approved">موافق عليه</option><option value="rejected">مرفوض</option></select><select id="v152AdminTeacher" data-alin-change="alinV152AdminFilter"><option value="">كل المدرسين</option>${[...new Set(rows.map(x=>x.teacher_name||x.teacher_id).filter(Boolean))].map(x=>`<option>${safeEsc(x)}</option>`).join('')}</select></div><div id="v152AdminList">${rows.length?rows.map(r=>`<div data-q="${safeEsc(((r.teacher_name||'')+' '+(r.title||'')+' '+(r.subject||'')).toLowerCase())}" data-status="${safeEsc(String(r.status||'new').toLowerCase())}" data-teacher="${safeEsc(r.teacher_name||r.teacher_id||'')}">${adminCard(r)}</div>`).join(''):'<div class="teacher-v152-empty">لا توجد طلبات مدرسين.</div>'}</div></section>`;
  }
  window.alinV152AdminFilter=function(){const q=(document.getElementById('v152AdminSearch')?.value||'').toLowerCase(),s=document.getElementById('v152AdminStatus')?.value||'',t=document.getElementById('v152AdminTeacher')?.value||'';document.querySelectorAll('#v152AdminList>div').forEach(x=>x.hidden=!!((q&&!x.dataset.q.includes(q))||(s&&x.dataset.status!==s)||(t&&x.dataset.teacher!==t)))};
  window.alinV152AdminDecision=async function(id,status){const note=document.getElementById('v152AdminNote-'+id)?.value.trim()||'';if(['changes_requested','rejected'].includes(status)&&!note)return alert('اكتب ملاحظة أو سبب واضح للمدرس');try{await update('teacher_requests',{status,admin_note:note,reviewed_at:new Date().toISOString(),reviewed_by:cur().name||cur().username||'admin',updated_at:new Date().toISOString()},{id});if(typeof audit==='function')await audit('teacher_request',`تحديث طلب ${id} إلى ${status}`);if(typeof load==='function')await load();renderAdminReview();if(typeof toast==='function')toast('تم تحديث حالة الطلب')}catch(e){console.warn(e);alert(e.message||'تعذر تحديث الطلب')}};
  if(!window.TeacherApp)throw new Error('TeacherApp must load before teacher/publishing.js');
  window.TeacherApp.registerTab('review',()=>renderTeacherReview());
  window.TeacherApp.registerTab('publishing',()=>renderTeacherReview());
  window.TeacherApp.registerTab('publication',()=>renderTeacherReview());
  window.renderTeacherRequestsAdmin=renderAdminReview;
  window.AlinTeacherModules=window.AlinTeacherModules||{};
  window.AlinTeacherModules.renderTeacherRequestsAdmin=renderAdminReview;
  window.AlinTeacherModules.renderReviewV152=renderTeacherReview;
  window.AlinTeacherModules.renderAdminReviewV152=renderAdminReview;
})();


;
;

/* modules/teacher/notifications.js */
// === teacher/notifications.js ===
/* ALIN v2.0.2 — مركز إشعارات المدرس الموحد */
(function(){
  'use strict';

  const BUTTON_ID='teacherNotificationsTabV160';
  const BADGE_ID='teacherNotificationsBadgeV160';

  const array=value=>Array.isArray(value)?value:[];
  const escapeHtml=value=>String(value??'').replace(/[&<>"']/g,char=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[char]));

  function teacher(){
    try{
      if(typeof current!=='undefined'&&current?.role==='teacher')return current;
    }catch(_){ }
    return window.current?.role==='teacher'?window.current:null;
  }

  function host(){return document.getElementById('teacherContent')}
  function teacherId(){return String(teacher()?.id||'')}
  function storageKey(){return `alin_teacher_seen_notifications_${teacherId()||'guest'}`}

  function localSeen(){
    try{return new Set(JSON.parse(localStorage.getItem(storageKey())||'[]').map(String))}
    catch(_){return new Set()}
  }

  function saveLocalSeen(values){
    try{localStorage.setItem(storageKey(),JSON.stringify([...values]))}
    catch(error){console.warn('[ALIN teacher notifications] local state',error)}
  }

  function matchesTeacher(notification){
    const id=teacherId();
    if(!id||!notification)return false;
    if(['deleted','inactive','hidden'].includes(String(notification.status||'').toLowerCase()))return false;

    const role=String(notification.target_role||notification.audience||notification.role||'all').toLowerCase();
    const target=String(notification.target_id||notification.account_id||notification.teacher_id||'').trim();

    // إذا كان الإشعار موجهاً إلى حساب محدد فلا يظهر لبقية المدرسين.
    if(target)return target===id;
    return ['all','teacher','teachers'].includes(role);
  }

  function rows(){
    const serviceRows=window.AlinNotifications?.visible?.({role:'teacher',id:teacherId()});
    if(Array.isArray(serviceRows))return serviceRows;
    const unique=new Map();
    array(window.db?.notifications).forEach((notification,index)=>{
      if(!notification)return;
      const id=String(notification.id??`local-${index}`);
      if(!unique.has(id))unique.set(id,notification);
    });
    return [...unique.values()].filter(matchesTeacher).sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||'')));
  }

  function isRead(notification,seen=localSeen()){
    if(window.AlinNotifications?.isRead)return window.AlinNotifications.isRead(notification,{role:'teacher',id:teacherId()});
    return Boolean(notification?.read_at)||seen.has(String(notification?.id));
  }

  function unreadCount(){
    const seen=localSeen();
    return rows().filter(notification=>!isRead(notification,seen)).length;
  }

  function icon(notification){
    const type=String(notification?.type||notification?.priority||notification?.category||'').toLowerCase();
    if(type.includes('sale')||type.includes('order'))return '🛍️';
    if(type.includes('settle')||type.includes('pay')||type.includes('finance'))return '💰';
    if(type.includes('reject'))return '❌';
    if(type.includes('approve')||type.includes('publish'))return '✅';
    if(type.includes('edit')||type.includes('review'))return '✏️';
    return '🔔';
  }

  function formatDate(value){
    if(!value)return 'بدون تاريخ';
    try{return new Intl.DateTimeFormat('ar-IQ',{dateStyle:'medium',timeStyle:'short'}).format(new Date(value))}
    catch(_){return String(value)}
  }

  function ensureTab(){
    const tabs=document.querySelector('#teacherPage .teacher-tabs');
    if(!tabs)return null;

    const candidates=[...tabs.querySelectorAll('[data-teacher-tab="notifications"],.teacher-notifications-tab')];
    let button=document.getElementById(BUTTON_ID)||candidates[0]||null;
    candidates.forEach(candidate=>{if(candidate!==button)candidate.remove()});

    if(!button){
      button=document.createElement('button');
      const before=tabs.querySelector('button[data-teacher-tab="requests"]');
      tabs.insertBefore(button,before||null);
    }

    button.type='button';
    button.id=BUTTON_ID;
    button.dataset.teacherTab='notifications';
    button.classList.add('teacher-notifications-tab');
    button.setAttribute('data-alin-click','teacherTab');button.setAttribute('data-alin-click-arg0','notifications');
    button.innerHTML=`<span aria-hidden="true">🔔</span><span>الإشعارات</span><span id="${BADGE_ID}" class="teacher-v160-badge" hidden>0</span>`;
    button.hidden=false;
    return button;
  }

  function updateBadge(){
    const button=ensureTab();
    if(!button)return;
    const badge=button.querySelector(`#${BADGE_ID}`);
    const count=unreadCount();
    if(badge){badge.textContent=String(count);badge.hidden=count===0}
  }

  function setActive(){
    document.querySelectorAll('#teacherPage .teacher-tabs button').forEach(button=>{
      const target=button.dataset.teacherTab||'';
      button.classList.toggle('active-teacher-tab',target==='notifications');
    });
  }

  function card(notification,seen){
    const read=isRead(notification,seen);
    const id=escapeHtml(notification.id??'');
    const title=escapeHtml(notification.title||'إشعار');
    const message=escapeHtml(notification.message||notification.text||'');
    const searchable=escapeHtml(`${notification.title||''} ${notification.message||notification.text||''}`.toLowerCase());
    return `<article class="teacher-v155-card ${read?'':'unread'}" data-notification-id="${id}" data-text="${searchable}" data-read="${read?'1':'0'}"><div class="teacher-v155-icon">${icon(notification)}</div><div><h3>${title}</h3><p>${message}</p><small>${escapeHtml(formatDate(notification.created_at))}</small></div><div class="teacher-v155-card-actions">${read?'':`<button type="button" data-alin-click="TeacherNotifications.mark" data-alin-click-arg0="${id}">مقروء</button>`}<button type="button" class="secondary" data-alin-click="TeacherNotifications.copy" data-alin-click-arg0="${id}">نسخ</button></div></article>`;
  }

  function render(){
    const container=host();
    if(!container)return false;

    const currentTeacher=teacher();
    if(!currentTeacher){
      container.innerHTML='<section class="teacher-v155-notifications"><div class="teacher-v155-empty">تعذر تحديد حساب المدرس.</div></section>';
      return false;
    }

    const notifications=rows();
    const seen=localSeen();
    const unread=notifications.filter(notification=>!isRead(notification,seen)).length;
    const today=new Date().toISOString().slice(0,10);
    const todayCount=notifications.filter(notification=>String(notification.created_at||'').slice(0,10)===today).length;

    container.innerHTML=`<section class="teacher-v155-notifications"><div class="teacher-v155-head"><div><h2>إشعاراتي</h2><p>تابع الموافقات والمبيعات والتسويات ورسائل الإدارة.</p></div><div class="teacher-v155-actions"><button type="button" data-alin-click="TeacherNotifications.markAll">تحديد الكل كمقروء</button><button type="button" class="secondary" data-alin-click="TeacherNotifications.refresh">تحديث</button></div></div><div class="teacher-v155-stats"><div class="teacher-v155-stat"><small>كل الإشعارات</small><b>${notifications.length}</b></div><div class="teacher-v155-stat"><small>غير المقروء</small><b>${unread}</b></div><div class="teacher-v155-stat"><small>اليوم</small><b>${todayCount}</b></div></div><div class="teacher-v155-toolbar"><input id="teacherNotificationSearch" placeholder="ابحث بعنوان الإشعار أو محتواه" data-alin-input="TeacherNotifications.filter"><select id="teacherNotificationFilter" data-alin-change="TeacherNotifications.filter"><option value="all">الكل</option><option value="unread">غير المقروء</option><option value="read">المقروء</option></select></div><div id="teacherNotificationList" class="teacher-v155-list">${notifications.map(notification=>card(notification,seen)).join('')||'<div class="teacher-v155-empty">لا توجد إشعارات حالياً.</div>'}</div></section>`;

    window.activeTeacherTab='notifications';
    setActive();
    updateBadge();
    return true;
  }

  async function mark(id){
    const notification=rows().find(item=>String(item.id)===String(id));
    if(!notification)return;
    if(window.AlinNotifications?.markRead)await window.AlinNotifications.markRead(id,{role:'teacher',id:teacherId()});
    else{
      const seen=localSeen();seen.add(String(id));saveLocalSeen(seen);
      notification.read_at=notification.read_at||new Date().toISOString();
    }
    render();
  }

  async function markAll(){
    if(window.AlinNotifications?.markAll)await window.AlinNotifications.markAll({role:'teacher',id:teacherId()});
    else{const seen=localSeen();rows().forEach(notification=>seen.add(String(notification.id)));saveLocalSeen(seen)}
    render();
  }

  function filter(){
    const query=(document.getElementById('teacherNotificationSearch')?.value||'').trim().toLowerCase();
    const mode=document.getElementById('teacherNotificationFilter')?.value||'all';
    document.querySelectorAll('#teacherNotificationList .teacher-v155-card').forEach(card=>{
      card.hidden=Boolean(
        (query&&!String(card.dataset.text||'').includes(query))||
        (mode==='unread'&&card.dataset.read==='1')||
        (mode==='read'&&card.dataset.read==='0')
      );
    });
  }

  async function copy(id){
    const notification=rows().find(item=>String(item.id)===String(id));
    if(!notification)return;
    const text=`${notification.title||'إشعار'}\n${notification.message||notification.text||''}`;
    try{
      await navigator.clipboard.writeText(text);
      if(typeof toast==='function')toast('تم نسخ الإشعار');
    }catch(_){ }
  }

  function refresh(){
    render();
    if(typeof toast==='function')toast('تم تحديث الإشعارات');
  }

  window.TeacherNotifications={render,mark,markAll,filter,copy,refresh,updateBadge,rows};
  // إبقاء الاسم السابق فقط للتوافق مع أي استدعاء قائم، بدون نظام إشعارات ثانٍ.
  window.TeacherV155=window.TeacherNotifications;

  if(!window.TeacherApp)throw new Error('TeacherApp must load before teacher/notifications.js');
  window.TeacherApp.registerTab('notifications',()=>render());
  window.AlinTeacherModules=window.AlinTeacherModules||{};
  window.AlinTeacherModules.renderNotifications=render;

  function init(){
    ensureTab();
    updateBadge();
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});
  else init();
})();


;
;

/* modules/teacher/profile.js */
// === teacher/profile.js ===
/* ===== teacher/js/teacher-profile-v156.js ===== */
(function(){
  const escx=v=>typeof esc==='function'?esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const cur=()=>typeof current!=='undefined'?current:(window.current||{});
  const database=()=>typeof db!=='undefined'?db:(window.db||{});
  const teacher=()=>{
    const c=cur(),d=database();
    return (d.accounts?.teachers||[]).find(x=>String(x.id)===String(c.id))||c||{};
  };
  const avatarUrl=t=>{const p=t.avatar_path||t.avatar||t.photo||'';if(!p)return'';try{return typeof mediaUrl==='function'?mediaUrl(p):p}catch(_){return p}};
  function stats(){
    const c=cur(),d=database(),books=(d.booklets||[]).filter(x=>String(x.teacher_id)===String(c.id));
    const ids=new Set(books.map(x=>String(x.id))),orders=(d.orders||[]).filter(x=>x.kind==='booklet'&&ids.has(String(x.item_id)));
    return {books:books.length,orders:orders.length,sales:orders.reduce((a,x)=>a+(+x.qty||0),0)};
  }
  function render(){
    const host=document.getElementById('teacherContent');if(!host)return;
    const t=teacher(),s=stats(),avatar=avatarUrl(t),initial=(t.name||'م').trim().charAt(0)||'م';
    host.innerHTML=`<section class="teacher-v156-profile"><header class="teacher-v156-hero"><div class="teacher-v156-hero-info"><div class="teacher-v156-avatar">${avatar?`<img src="${escx(avatar)}" alt="صورة المدرس">`:escx(initial)}</div><div><h2>${escx(t.name||'ملف المدرس')}</h2><p>${escx(t.specialty||'مدرس في منصة آلين')}</p></div></div><span class="teacher-v156-status">الحساب فعال</span></header><div class="teacher-v156-grid"><article class="teacher-v156-card"><h3>البيانات الشخصية</h3><div class="teacher-v156-form"><div class="teacher-v156-field"><label>الاسم</label><input value="${escx(t.name||'')}" disabled></div><div class="teacher-v156-field"><label>اسم الدخول</label><input id="v156Username" value="${escx(t.username||'')}" disabled title="يُغيّر اسم الدخول من الإدارة الآمنة"></div><div class="teacher-v156-field"><label>رقم الهاتف</label><input id="v156Phone" value="${escx(t.phone||t.mobile||'')}" placeholder="07xxxxxxxxx"></div><div class="teacher-v156-field"><label>المنطقة</label><input id="v156Area" value="${escx(t.area||'')}" placeholder="المنطقة"></div><div class="teacher-v156-field full"><label>الاختصاص</label><input id="v156Specialty" value="${escx(t.specialty||'')}" placeholder="مثال: مدرس رياضيات"></div><div class="teacher-v156-field full"><label>نبذة قصيرة</label><textarea id="v156Bio" placeholder="نبذة تظهر في ملفك">${escx(t.bio||'')}</textarea></div><div class="teacher-v156-field full"><label>الصورة الشخصية</label><div class="teacher-v156-upload"><div id="v156AvatarPreview" class="teacher-v156-upload-preview">${avatar?`<img src="${escx(avatar)}" alt="">`:'📷'}</div><input id="v156Avatar" type="file" accept="image/png,image/jpeg,image/webp" data-alin-change="v156PreviewAvatar" data-alin-change-arg0-source="self"></div></div></div><div class="teacher-v156-actions"><button class="teacher-v156-save" data-alin-click="v156SaveTeacherProfile">حفظ التعديلات</button></div></article><aside class="teacher-v156-card"><h3>ملخص الحساب</h3><div class="teacher-v156-stat-list"><div class="teacher-v156-stat"><span>الملازم</span><b>${s.books}</b></div><div class="teacher-v156-stat"><span>الطلبات</span><b>${s.orders}</b></div><div class="teacher-v156-stat"><span>النسخ المباعة</span><b>${s.sales}</b></div></div><h3 style="margin-top:20px">الأمان</h3><div class="teacher-v156-security"><input id="v156NewPassword" type="password" placeholder="كلمة المرور الجديدة"><input id="v156ConfirmPassword" type="password" placeholder="تأكيد كلمة المرور"><button data-alin-click="v156ChangeTeacherPassword">تغيير كلمة المرور</button></div><div class="teacher-v156-note">اسم المدرس وربط الملازم يبقى من صلاحية الإدارة، بينما تستطيع تعديل بيانات التواصل والصورة وكلمة المرور.</div><div class="teacher-v156-danger"><button data-alin-click="logout">تسجيل الخروج</button></div></aside></div></section>`;
  }
  window.v156PreviewAvatar=function(input){const f=input?.files?.[0],box=document.getElementById('v156AvatarPreview');if(!f||!box)return;if(!/^image\/(png|jpeg|webp)$/.test(f.type))return alert('اختر صورة PNG أو JPG أو WEBP');const r=new FileReader();r.onload=()=>box.innerHTML=`<img src="${r.result}" alt="معاينة">`;r.readAsDataURL(f)};
  window.v156SaveTeacherProfile=async function(){
    const c=cur(),t=teacher();if(!c?.id)return alert('تعذر تحديد حساب المدرس');
    const payload={phone:document.getElementById('v156Phone')?.value.trim()||'',area:document.getElementById('v156Area')?.value.trim()||'',specialty:document.getElementById('v156Specialty')?.value.trim()||'',bio:document.getElementById('v156Bio')?.value.trim()||'',avatar_path:t.avatar_path||''};
    try{
      const file=document.getElementById('v156Avatar')?.files?.[0];if(file)payload.avatar_path=await uploadFile('teachers',file,{type:'image'});
      const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)throw new Error('خدمة حفظ ملف المدرس غير متاحة');
      const {data,error}=await client.rpc('alin_teacher_update_profile',{p_phone:payload.phone,p_area:payload.area,p_specialty:payload.specialty,p_bio:payload.bio,p_avatar_path:payload.avatar_path});
      if(error)throw error;if(!data?.ok)throw new Error(data?.error||'لم يؤكد الخادم حفظ الملف');if(data.account)Object.assign(t,data.account);
      if(typeof audit==='function')await audit('teacher_profile','تحديث ملف المدرس');if(typeof load==='function')await load();
      if(typeof current!=='undefined')current.name=t.name||current.name;
      if(typeof toast==='function')toast('تم حفظ الملف الشخصي');render();
    }catch(e){alert('تعذر حفظ الملف: '+e.message)}
  };
  window.v156ChangeTeacherPassword=async function(){
    const c=cur(),p=document.getElementById('v156NewPassword')?.value||'',p2=document.getElementById('v156ConfirmPassword')?.value||'';
    if(p.length<12||!/[0-9]/.test(p)||!/[A-Za-z؀-ۿ]/.test(p))return alert('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');if(p!==p2)return alert('كلمتا المرور غير متطابقتين');
    try{const client=window.sb||(window.AlinCloud&&window.AlinCloud.client?.());if(!client?.auth)throw new Error('خدمة الدخول الآمن غير متاحة');const {error}=await client.auth.updateUser({password:p});if(error)throw error;if(typeof audit==='function')await audit('teacher_security','تغيير كلمة مرور المدرس');document.getElementById('v156NewPassword').value='';document.getElementById('v156ConfirmPassword').value='';if(typeof toast==='function')toast('تم تغيير كلمة المرور')}catch(e){alert('تعذر تغيير كلمة المرور: '+e.message)}
  };
  if(!window.TeacherApp)throw new Error('TeacherApp must load before teacher/profile.js');
  window.TeacherApp.registerTab('profile',()=>render());
  window.AlinTeacherModules=window.AlinTeacherModules||{};
  window.AlinTeacherModules.renderProfile=render;
  window.renderTeacherProfileV156=render;
})();


;
;

/* modules/library/dashboard.js */
/* ===== library/js/library-dashboard-v116.js ===== */
/* ALIN v2.0.9 - organized library dashboard */
(function(){
  window.AlinLibraryModules=window.AlinLibraryModules||{};
  const state={tab:'home',filter:'all',search:''};
  const arr=v=>Array.isArray(v)?v:[];
  const eq=(a,b)=>String(a??'')===String(b??'');
  const escx=v=>typeof esc==='function'?esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const moneyx=v=>typeof money==='function'?money(v):Number(v||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const currentUser=()=>window.current||null;
  const dbx=()=>window.db||{accounts:{libraries:[]},orders:[],ledger:[],notifications:[]};
  function getLibrary(){
    const c=currentUser(); if(c?.role!=='library') return null;
    const libs=arr(dbx().accounts?.libraries); const ids=[c.id,c.library_id,c.account_id,c.user_id].filter(Boolean);
    return libs.find(x=>ids.some(id=>eq(x.id,id)||eq(x.account_id,id)||eq(x.user_id,id)))||libs.find(x=>c.username&&eq(x.username,c.username))||libs.find(x=>c.name&&eq(x.name,c.name))||null;
  }
  function libId(){const l=getLibrary(),c=currentUser();return String(l?.id||c?.library_id||c?.id||'')}
  function orders(){const id=libId();return arr(dbx().orders).filter(o=>eq(o.library_id,id)||eq(o.pickup_library_id,id)||eq(o.assigned_library_id,id))}
  function statusKey(o){const s=String(o?.status||'new');if(['pending','new'].includes(s))return'new';if(['processing','printing','accepted'].includes(s))return'processing';if(s==='ready')return'ready';if(['completed','delivered'].includes(s))return'completed';if(['cancelled','canceled'].includes(s))return'cancelled';return s}
  function statusLabel(s){return({new:'جديد',processing:'قيد الطباعة',ready:'جاهز',completed:'تم التسليم',cancelled:'ملغي'})[s]||s}
  function isOpen(lib){return !(lib?.is_open===false||String(lib?.is_open)==='false'||lib?.open_status==='closed'||lib?.status==='closed')}
  function ledger(){const id=libId();return arr(dbx().ledger).filter(x=>eq(x.library_id,id))}
  function financeSummary(){return window.AlinV120Finance?.summary?.(libId())||{gross:0,libraryProfit:0,debtTotal:0,settled:0,debtRemaining:0,monthProfit:0,rows:[],settlements:[]}}
  function due(){return financeSummary().debtRemaining}
  function todayCount(){const d=new Date().toISOString().slice(0,10);return orders().filter(o=>statusKey(o)==='completed'&&String(o.updated_at||o.created_at||'').slice(0,10)===d).length}
  function notifications(){return window.AlinNotifications?.visible?.({role:'library',id:libId()})||arr(dbx().notifications).filter(n=>n.status!=='inactive'&&((n.target_id||n.library_id)?eq(n.target_id||n.library_id,libId()):['all','library'].includes(n.target_role||n.audience))) }
  function updateHeader(){
    const lib=getLibrary(),name=document.getElementById('libraryV116Name'),loc=document.getElementById('libraryV116Location'),status=document.getElementById('libraryV116Status');
    if(name)name.textContent=lib?.name||currentUser()?.name||'المكتبة';
    if(loc)loc.textContent=[lib?.area,lib?.landmark].filter(Boolean).join(' — ')||'إدارة الطلبات والطباعة والتسليم';
    if(status){const open=isOpen(lib);status.innerHTML=`<div class="library-v116-status-card ${open?'open':'closed'}"><span class="library-v116-status-dot"></span><div><b>${open?'المكتبة مفتوحة':'المكتبة مغلقة'}</b><small>${open?'تستقبل طلبات جديدة':'لا تستقبل طلبات جديدة'}</small></div><button type="button" data-alin-click="AlinLibraryV116.toggleOpen">${open?'إغلاق':'فتح'}</button></div>`}
    const ob=document.getElementById('libraryV116OrdersBadge'),nb=document.getElementById('libraryV116NotifyBadge');
    const oc=orders().filter(o=>statusKey(o)==='new').length,nc=window.AlinNotifications?.unreadCount?.({role:'library',id:libId()})??notifications().filter(n=>!(n.read_at||n.is_read)).length;
    if(ob){ob.textContent=oc;ob.hidden=!oc} if(nb){nb.textContent=nc;nb.hidden=!nc}
  }
  function statsHtml(){const os=orders();return `<section class="library-v116-stats"><article class="library-v116-stat"><small>طلبات جديدة</small><strong>${os.filter(o=>statusKey(o)==='new').length}</strong></article><article class="library-v116-stat"><small>قيد الطباعة</small><strong>${os.filter(o=>statusKey(o)==='processing').length}</strong></article><article class="library-v116-stat"><small>جاهزة للتسليم</small><strong>${os.filter(o=>statusKey(o)==='ready').length}</strong></article><article class="library-v116-stat"><small>تسليمات اليوم</small><strong>${todayCount()}</strong></article><article class="library-v116-stat"><small>طلبات ملغاة</small><strong>${os.filter(o=>statusKey(o)==='cancelled').length}</strong></article><article class="library-v116-stat accent"><small>المبلغ بذمة المكتبة</small><strong>${moneyx(due())} د.ع</strong></article></section>`}
  function orderCard(o){const s=statusKey(o);return `<article class="library-v116-order"><div><div style="display:flex;justify-content:space-between;gap:10px;align-items:center"><h4>${escx(o.order_number||o.id)} — ${escx(o.title||'طلب')}</h4><span class="library-v116-status ${s}">${statusLabel(s)}</span></div><p>${escx(o.student_name||'بدون اسم')} • ${escx(o.student_phone||'بدون رقم')} • الكمية ${o.qty||1}</p><div class="library-v116-order-meta"><span class="library-v116-chip">${o.kind==='booklet'?'ملزمة':'منتج'}</span><span class="library-v116-chip">${moneyx(o.total||0)} د.ع</span><span class="library-v116-chip">${escx(o.fulfillment_type==='delivery'?'توصيل':'استلام من المكتبة')}</span></div></div><div class="library-v116-actions"><button class="secondary" data-alin-click="AlinLibraryV116.details" data-alin-click-arg0="${escx(o.id)}">التفاصيل</button>${o.kind==='booklet'&&!['completed','cancelled'].includes(s)?`<button data-alin-click="openLibraryBookletPdf" data-alin-click-arg0="${escx(o.id)}">طباعة</button>`:''}${s==='new'?`<button data-alin-click="AlinLibraryV116.setStatus" data-alin-click-arg0="${escx(o.id)}" data-alin-click-arg1="processing">بدء الطباعة</button>`:''}${s==='processing'?`<button data-alin-click="AlinLibraryV116.setStatus" data-alin-click-arg0="${escx(o.id)}" data-alin-click-arg1="ready">جاهز للتسليم</button>`:''}${s==='ready'?`<button class="success" data-alin-click="AlinLibraryV116.setStatus" data-alin-click-arg0="${escx(o.id)}" data-alin-click-arg1="completed">تم التسليم</button>`:''}${!['completed','cancelled'].includes(s)?`<button class="danger" data-alin-click="AlinLibraryV116.cancel" data-alin-click-arg0="${escx(o.id)}">إلغاء</button>`:''}</div></article>`}
  function home(){const os=orders().filter(o=>!['completed','cancelled'].includes(statusKey(o))).slice(0,5);return `${statsHtml()}<section class="library-v116-grid"><div class="library-v116-panel"><h3>آخر الطلبات التي تحتاج إجراء</h3><div class="library-v116-order-list">${os.map(orderCard).join('')||'<div class="library-v116-empty">لا توجد طلبات تحتاج إجراء حالياً</div>'}</div></div><aside class="library-v116-panel"><h3>ملخص اليوم</h3><div class="library-v116-list"><div class="library-v116-row"><div><b>الطلبات الجاهزة</b><small>بانتظار استلام الطالب</small></div><span>${orders().filter(o=>statusKey(o)==='ready').length}</span></div><div class="library-v116-row"><div><b>تم التسليم اليوم</b><small>طلبات مكتملة اليوم</small></div><span>${todayCount()}</span></div><div class="library-v116-row"><div><b>المبلغ المطلوب تسليمه</b><small>حصة المنصة والمدرس بعد خصم ربح المكتبة</small></div><span class="library-v116-money debt">${moneyx(due())} د.ع</span></div></div></aside></section>`}
  function ordersView(){let list=orders();if(state.filter!=='all')list=list.filter(o=>statusKey(o)===state.filter);const q=state.search.trim().toLowerCase();if(q)list=list.filter(o=>[o.order_number,o.id,o.title,o.student_name,o.student_phone].some(v=>String(v||'').toLowerCase().includes(q)));return `<section class="library-v116-panel"><div class="library-v116-toolbar"><input id="libraryV116Search" value="${escx(state.search)}" placeholder="ابحث برقم الطلب أو اسم الطالب" data-alin-input="AlinLibraryV116.search" data-alin-input-arg0-source="value"><div class="library-v116-filter-row">${[['all','الكل'],['new','جديد'],['processing','قيد الطباعة'],['ready','جاهز'],['completed','تم التسليم'],['cancelled','ملغي']].map(([k,l])=>`<button class="${state.filter===k?'active':''}" data-alin-click="AlinLibraryV116.filter" data-alin-click-arg0="${k}">${l}</button>`).join('')}</div></div><div class="library-v116-order-list">${list.map(orderCard).join('')||'<div class="library-v116-empty">لا توجد طلبات مطابقة</div>'}</div></section>`}
  function financeView(){
    const f=financeSummary();
    const movements=f.rows.slice(0,30).map(x=>`<div class="library-v120-movement"><div><b>${escx(x.order_number||x.order_id)}</b><small>${escx(x.title||'طلب مكتمل')} — استلمت المكتبة ${moneyx(x.gross)} د.ع</small></div><div class="library-v120-split"><span class="profit">ربح المكتبة +${moneyx(x.libraryProfit)} د.ع</span><span class="debt">بذمة المكتبة ${moneyx(x.debt)} د.ع</span></div></div>`).join('')||'<div class="library-v116-empty">لا توجد حركات مالية بعد</div>';
    const settlements=f.settlements.slice(0,15).map(x=>`<div class="library-v116-row"><div><b>${escx(x.receipt_number||x.id||'تسوية')}</b><small>${escx(x.created_at||'')} — ${escx(x.payment_method||'')}</small></div><span class="library-v116-money settled">-${moneyx(x.amount)} د.ع</span></div>`).join('')||'<div class="library-v116-empty">لا توجد تسويات مثبتة بعد</div>';
    return `<section class="library-v120-finance-cards"><article><small>إجمالي المبالغ المستلمة من الطلبات</small><strong>${moneyx(f.gross)} د.ع</strong></article><article class="profit"><small>أرباح المكتبة المتراكمة</small><strong>${moneyx(f.libraryProfit)} د.ع</strong></article><article><small>أرباح هذا الشهر</small><strong>${moneyx(f.monthProfit)} د.ع</strong></article><article class="debt"><small>المبلغ بذمة المكتبة</small><strong>${moneyx(f.debtRemaining)} د.ع</strong></article><article class="settled"><small>المبالغ المسددة للمدير</small><strong>${moneyx(f.settled)} د.ع</strong></article></section><section class="library-v116-grid library-v120-grid"><div class="library-v116-panel"><h3>تفاصيل الطلبات المالية</h3><p class="library-v120-help">عند تسليم الطلب يُثبت ربح المكتبة، ويُسجل باقي المبلغ بذمتها لحين تصفية المدير.</p><div class="library-v120-movements">${movements}</div></div><aside class="library-v116-panel"><h3>التسويات مع الإدارة</h3><div class="library-v120-debt-box"><small>المطلوب تسليمه حالياً</small><strong>${moneyx(f.debtRemaining)} د.ع</strong><span>إجمالي الذمة ${moneyx(f.debtTotal)} د.ع — المسدد ${moneyx(f.settled)} د.ع</span></div><div class="library-v116-list">${settlements}</div><div class="library-v116-note" style="margin-top:12px">التصفية يثبتها المدير فقط. بعد تسجيل كامل المبلغ تصبح الذمة صفراً، وتبقى أرباح المكتبة وسجل الحركات محفوظة.</div></aside></section>`
  }
  function notificationsView(){const ns=notifications();return `<section class="library-v116-panel"><div class="library-v116-toolbar"><h3>إشعارات المكتبة</h3><button data-alin-click="AlinLibraryV116.markAllRead">تحديد الكل كمقروء</button></div><div class="library-v116-list">${ns.map(n=>{const read=window.AlinNotifications?.isRead?.(n,{role:'library',id:libId()})??Boolean(n.read_at||n.is_read);return `<article class="library-v116-notification ${read?'':'unread'}"><b>${escx(n.title||'إشعار')}</b><p>${escx(n.message||n.text||'')}</p><small>${escx(n.created_at||'')}</small></article>`}).join('')||'<div class="library-v116-empty">لا توجد إشعارات</div>'}</div></section>`}
  function settingsView(){const l=getLibrary()||{};return `<section class="library-v116-panel"><h3>إعدادات المكتبة</h3><div class="library-v116-settings"><div class="library-v116-field"><small>اسم المكتبة</small><b>${escx(l.name||'—')}</b></div><div class="library-v116-field"><small>المنطقة</small><b>${escx(l.area||'—')}</b></div><div class="library-v116-field"><small>أقرب نقطة دالة</small><b>${escx(l.landmark||'—')}</b></div><div class="library-v116-field"><small>واتساب</small><b>${escx(l.whatsapp||l.phone||'—')}</b></div><div class="library-v116-field"><small>اسم الدخول</small><b>${escx(l.username||currentUser()?.username||'—')}</b></div><div class="library-v116-field"><small>حالة المكتبة</small><b>${isOpen(l)?'مفتوحة':'مغلقة'}</b></div><div class="library-v116-settings-actions"><button data-alin-click="AlinLibraryV116.toggleOpen">${isOpen(l)?'إغلاق المكتبة':'فتح المكتبة'}</button><button class="secondary" data-alin-click="alert" data-alin-click-arg0="تغيير كلمة المرور يكون من إدارة الحسابات حالياً">تغيير كلمة المرور</button><button class="logout" data-alin-click="logout">تسجيل الخروج</button></div></div></section>`}
  function render(){if(currentUser()?.role!=='library')return;updateHeader();document.querySelectorAll('.library-v116-tabs button').forEach(b=>b.classList.toggle('active',b.dataset.libraryTab===state.tab));const c=document.getElementById('libraryV116Content');if(!c)return;c.innerHTML=state.tab==='orders'?ordersView():state.tab==='finance'?financeView():state.tab==='notifications'?notificationsView():state.tab==='settings'?settingsView():home()}
  async function toggleOpen(){
    const lib=getLibrary();if(!lib)return alert('تعذر تحديد حساب المكتبة');
    const open=!isOpen(lib);
    try{
      const client=window.ALINAuthRuntime?.client?.()||window.sb||window.AlinCloud?.client?.()||null;
      if(!client?.rpc)throw new Error('خدمة Supabase غير متاحة. سجل الدخول من جديد وحاول مرة أخرى.');
      const {data,error}=await client.rpc('alin_set_library_open',{p_open:open});
      if(error){
        const message=String(error.message||'');
        if(/alin_set_library_open|function .* does not exist|schema cache/i.test(message))throw new Error('خدمة حالة المكتبة غير مهيأة في مشروع Supabase الجديد. نفّذ ALIN_V4_CLEAN_PROJECT_MASTER.sql مرة واحدة.');
        throw error;
      }
      if(!data?.ok)throw new Error('لم يؤكد الخادم تحديث حالة المكتبة');
      const updated=data.library||{};
      Object.assign(lib,updated,{is_open:open,open_status:open?'open':'closed'});
      if(typeof audit==='function')await audit('library',open?'فتح المكتبة':'إغلاق المكتبة');
      if(typeof load==='function')await load({force:true,reason:'library-open-status'});
      render();
      if(typeof toast==='function')toast(open?'تم فتح المكتبة واستقبال الطلبات':'تم إغلاق المكتبة وإيقاف الطلبات الجديدة');
    }catch(e){console.error(e);alert(e?.message||'تعذر تحديث حالة المكتبة')}
  }
  async function setStatus(id,status){
    try{
      const action=window.AlinLibraryModules?.libraryOrderStatus||window.libraryOrderStatus;
      if(typeof action!=='function')throw new Error('خدمة تحديث الطلب غير جاهزة');
      await action(id,status);
      render();
    }catch(error){console.error(error);alert(error?.message||'تعذر تحديث حالة الطلب')}
  }
  async function cancel(id){
    const reason=prompt('اكتب سبب الإلغاء');
    if(!reason)return;
    try{
      const action=window.AlinLibraryModules?.cancelLibraryOrder||window.cancelLibraryOrder;
      if(typeof action!=='function')throw new Error('خدمة إلغاء الطلب غير جاهزة');
      await action(id,reason);
      render();
    }catch(error){console.error(error);alert(error?.message||'تعذر إلغاء الطلب')}
  }
  function details(id){const o=orders().find(x=>eq(x.id,id));if(!o)return;const html=`<h2>تفاصيل الطلب</h2><div class="library-v116-list"><div class="library-v116-row"><b>رقم الطلب</b><span>${escx(o.order_number||o.id)}</span></div><div class="library-v116-row"><b>الطالب</b><span>${escx(o.student_name||'—')}</span></div><div class="library-v116-row"><b>الهاتف</b><span>${escx(o.student_phone||'—')}</span></div><div class="library-v116-row"><b>الطلب</b><span>${escx(o.title||'—')}</span></div><div class="library-v116-row"><b>الكمية</b><span>${o.qty||1}</span></div><div class="library-v116-row"><b>المبلغ</b><span>${moneyx(o.total||0)} د.ع</span></div><div class="library-v116-row"><b>الملاحظات</b><span>${escx(o.notes||o.note||'لا توجد')}</span></div></div>`;if(window.checkoutBox&&window.checkoutModal){checkoutBox.innerHTML=html;checkoutModal.classList.remove('hidden')}}
  async function markAllRead(){if(window.AlinNotifications?.markAll)await window.AlinNotifications.markAll({role:'library',id:libId()});else notifications().forEach(n=>n.read_at=n.read_at||new Date().toISOString());render()}
  window.AlinLibraryV116={render,toggleOpen,setStatus,cancel,details,filter:k=>{state.filter=k;render()},search:q=>{state.search=q;render()},markAllRead};
  window.renderLibrary=render;window.AlinLibraryModules.renderLibrary=render;window.setLibraryOpen=toggleOpen;window.AlinLibraryModules.setLibraryOpen=toggleOpen;
  document.addEventListener('click',e=>{const b=e.target.closest('[data-library-tab]');if(!b)return;state.tab=b.dataset.libraryTab;render()});
  const boot=()=>{if(currentUser()?.role==='library')setTimeout(render,20)};if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();


;
;

/* modules/library/orders.js */
// === library/orders.js ===
/* ALIN v2.8.0 Stage 5 — atomic library workflow and finance RPC. */
(function(){
  'use strict';
  const modules=window.AlinLibraryModules=window.AlinLibraryModules||{};
  const allowed={
    new:['processing','cancelled'],
    pending:['processing','cancelled'],
    pending_admin:['processing','cancelled'],
    accepted:['processing','cancelled'],
    processing:['ready','cancelled'],
    printing:['ready','cancelled'],
    ready:['completed','delivered','cancelled'],
    completed:[],
    delivered:[],
    cancelled:[],
    canceled:[]
  };
  const normalize=status=>String(status||'new').toLowerCase()==='canceled'?'cancelled':String(status||'new').toLowerCase();
  const client=()=>window.ALINAuthRuntime?.client?.()||window.sb||window.AlinCloud?.client?.()||null;

  function findOrder(id){return (window.db?.orders||[]).find(row=>String(row.id)===String(id));}
  function currentLibraryId(){return String(window.current?.role==='library'?(window.current.id||window.current.library_id||''):'');}
  function orderLibraryId(order){return String(order?.library_id||order?.pickup_library_id||order?.assigned_library_id||'');}
  function ownsOrder(order){
    const id=currentLibraryId();
    if(!id)return false;
    return [order?.library_id,order?.pickup_library_id,order?.assigned_library_id].some(value=>String(value||'')===id);
  }
  function canMove(from,to){
    const source=normalize(from),target=normalize(to);
    return source===target||Boolean(allowed[source]?.includes(target));
  }
  function serviceError(error){
    const message=String(error?.message||error||'').trim();
    if(/alin_order_transition_atomic|function .* does not exist|schema cache/i.test(message)){
      return new Error('خدمة الطلبات والحسابات غير مهيأة في مشروع Supabase الجديد. نفّذ ملف ALIN_V4_CLEAN_PROJECT_MASTER.sql مرة واحدة.');
    }
    return error instanceof Error?error:new Error(message||'تعذر تحديث الطلب');
  }

  async function callOrderRpc(order,target,reason=''){
    const c=client();
    if(!c?.rpc)throw new Error('خدمة Supabase غير متاحة. تحقق من الاتصال وسجل الدخول من جديد.');
    const {data,error}=await c.rpc('alin_library_set_order_status',{
      p_order_id:String(order.id),
      p_status:target,
      p_reason:reason||null
    });
    if(error)throw serviceError(error);
    if(!data?.ok)throw new Error('لم يؤكد الخادم تحديث الطلب');
    if(data.order&&typeof data.order==='object')Object.assign(order,data.order);
    else Object.assign(order,{status:target,updated_at:new Date().toISOString()});
    return data;
  }

  async function libraryOrderStatus(id,status){
    const order=findOrder(id);
    if(!order)throw new Error('الطلب غير موجود');
    if(window.current?.role==='library'&&!ownsOrder(order))throw new Error('هذا الطلب غير مسند إلى مكتبتك');
    const target=normalize(status),source=normalize(order.status);
    if(!canMove(source,target))throw new Error('لا يمكن نقل الطلب من '+source+' إلى '+target);
    if(source===target)return order;

    await callOrderRpc(order,target);
    if(typeof audit==='function')await audit('order',`المكتبة حدثت الطلب ${order.order_number||order.id} من ${source} إلى ${target}`);
    if(typeof load==='function')await load({force:true,reason:'library-order-status'});
    else modules.renderLibrary?.();
    return order;
  }

  async function cancelLibraryOrder(id,reason){
    const text=String(reason||'').trim();
    if(!text)throw new Error('اكتب سبب الإلغاء');
    const order=findOrder(id);
    if(!order)throw new Error('الطلب غير موجود');
    if(window.current?.role==='library'&&!ownsOrder(order))throw new Error('هذا الطلب غير مسند إلى مكتبتك');
    await callOrderRpc(order,'cancelled',text);
    if(typeof audit==='function')await audit('order',`المكتبة ألغت الطلب ${order.order_number||order.id}: ${text}`);
    if(typeof load==='function')await load({force:true,reason:'library-order-cancel'});
    else modules.renderLibrary?.();
    return order;
  }

  function selectedLibraryLine(){
    const select=document.getElementById('libSelect');
    const info=document.getElementById('libInfo');
    if(!select||!info)return;
    const library=(window.db?.accounts?.libraries||[]).find(row=>String(row.id)===String(select.value));
    if(!library){info.innerHTML='';return;}
    const open=typeof libIsOpen==='function'?libIsOpen(library):library.is_open!==false;
    const escape=value=>typeof esc==='function'?esc(value):String(value??'');
    info.innerHTML=`<div class="library-one-line"><b>${escape(library.name)}</b><span class="${open?'open-badge':'closed-badge'}">${open?'مفتوح':'مغلق'}</span><small>${escape(library.area||'')}${library.landmark?' — '+escape(library.landmark):''}</small></div>`;
  }

  function alinLibraryOptions(){
    const libraries=typeof alinOpenLibraries==='function'?alinOpenLibraries():(window.db?.accounts?.libraries||[]).filter(row=>row.status!=='disabled'&&row.is_open!==false);
    const escape=value=>typeof esc==='function'?esc(value):String(value??'');
    return libraries.map(row=>`<option value="${escape(row.id)}">${escape(row.name)} - مفتوح</option>`).join('');
  }

  window.libraryOrderStatus=libraryOrderStatus;
  window.cancelLibraryOrder=cancelLibraryOrder;
  window.selectedLibraryLine=selectedLibraryLine;
  window.alinLibraryOptions=alinLibraryOptions;
  window.AlinLibraryOrderService=Object.freeze({libraryOrderStatus,cancelLibraryOrder,callOrderRpc,orderLibraryId});
  modules.libraryOrderStatus=libraryOrderStatus;
  modules.cancelLibraryOrder=cancelLibraryOrder;
  modules.selectedLibraryLine=selectedLibraryLine;
  modules.alinLibraryOptions=alinLibraryOptions;
})();
;

/* modules/library/finance.js */
/* ALIN v2.2.6 — library finance views backed only by AlinFinance. */
(function(){
  'use strict';
  window.AlinLibraryModules=window.AlinLibraryModules||{};
  const arr=value=>Array.isArray(value)?value:[];
  const same=(a,b)=>String(a??'')===String(b??'');
  const escv=value=>typeof window.esc==='function'?window.esc(value):String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const moneyv=value=>typeof window.money==='function'?window.money(value):Math.round(Number(value)||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const database=()=>window.db||{};
  const finance=()=>window.AlinFinance;

  function currentLibraryId(){
    const account=window.current||{};
    const libraries=arr(database().accounts?.libraries);
    const row=libraries.find(item=>[account.id,account.library_id,account.account_id,account.user_id].filter(Boolean).some(id=>same(item.id,id)||same(item.account_id,id)||same(item.user_id,id)))
      ||libraries.find(item=>account.username&&same(item.username,account.username));
    return String(row?.id||account.library_id||account.id||'');
  }

  function summary(libraryId=currentLibraryId()){
    return finance()?.librarySummary?.(libraryId)||{rows:[],settlements:[],gross:0,profit:0,libraryProfit:0,debtTotal:0,settled:0,remaining:0,debtRemaining:0,monthProfit:0};
  }

  function libraryName(id){const row=arr(database().accounts?.libraries).find(item=>same(item.id,id));return row?.name||row?.library_name||row?.display_name||row?.title||window.current?.name||'المكتبة'}

  function statementRows(id){
    return summary(id).rows.map(row=>`<tr><td>${escv(row.order?.order_number||row.order_number||row.order_id)}</td><td>${escv(String(row.at||'').slice(0,10)||'-')}</td><td>${moneyv(row.gross)} د.ع</td><td>${moneyv(row.profit)} د.ع</td><td>${moneyv(row.debt)} د.ع</td></tr>`).join('')||'<tr><td colspan="5">لا توجد حركات مالية.</td></tr>';
  }

  function printLibraryStatement(libraryId=currentLibraryId()){
    const data=summary(libraryId);
    const html=`<div class="receipt"><h2>كشف حساب المكتبة</h2><p>${escv(libraryName(libraryId))}</p><table><thead><tr><th>الطلب</th><th>التاريخ</th><th>المبلغ</th><th>ربح المكتبة</th><th>الذمة</th></tr></thead><tbody>${statementRows(libraryId)}</tbody></table><h3>ربح المكتبة: ${moneyv(data.libraryProfit)} د.ع</h3><h3>المسدد: ${moneyv(data.settled)} د.ع</h3><h3>المتبقي بذمة المكتبة: ${moneyv(data.debtRemaining)} د.ع</h3></div><div class="row-actions no-print"><button data-alin-click="print">طباعة</button><button class="secondary" data-alin-click="closeCheckout">إغلاق</button></div>`;
    if(window.checkoutBox&&window.checkoutModal){window.checkoutBox.innerHTML=html;window.checkoutModal.classList.remove('hidden');return true}
    return false;
  }

  function exportLibraryStatement(libraryId=currentLibraryId()){
    const data=summary(libraryId);
    const rows=[['رقم الطلب','التاريخ','المبلغ','ربح المكتبة','الذمة'],...data.rows.map(row=>[row.order?.order_number||row.order_number||row.order_id,String(row.at||'').slice(0,10),row.gross,row.profit,row.debt]),[],['ربح المكتبة',data.libraryProfit],['المسدد',data.settled],['المتبقي',data.debtRemaining]];
    const csv='\ufeff'+rows.map(row=>row.map(value=>`"${String(value??'').replace(/"/g,'""')}"`).join(',')).join('\n');
    const link=document.createElement('a');link.href=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));link.download=`library-finance-${libraryId}.csv`;link.click();setTimeout(()=>URL.revokeObjectURL(link.href),1000);
  }

  function printLibrarySettlement(id){
    const row=summary().settlements.find(item=>same(item.id,id)||same(item.receipt_number,id));if(!row)return false;
    const html=`<div class="receipt"><h2>منصة آلين</h2><h3>سند قبض تسوية مكتبة</h3><p>رقم السند: ${escv(row.receipt_number||row.id)}</p><p>المكتبة: ${escv(libraryName(row.library_id))}</p><p>المبلغ: ${moneyv(row.amount)} د.ع</p><p>طريقة الاستلام: ${escv(row.payment_method||'نقدي')}</p><p>التاريخ: ${escv(String(row.created_at||'').slice(0,10))}</p></div><div class="row-actions no-print"><button data-alin-click="print">طباعة</button><button class="secondary" data-alin-click="closeCheckout">إغلاق</button></div>`;
    if(window.checkoutBox&&window.checkoutModal){window.checkoutBox.innerHTML=html;window.checkoutModal.classList.remove('hidden');return true}return false;
  }

  async function reverseLibrarySettlement(id){
    const row=summary().settlements.find(item=>same(item.id,id)||same(item.receipt_number,id));
    if(!row||!window.confirm('إلغاء أثر سند التسوية؟'))return false;
    const reason=(window.prompt('اكتب سبب عكس سند التسوية')||'').trim();if(!reason)return false;
    if(!window.AlinFinance?.reverseSettlement)throw new Error('خدمة عكس التسوية غير جاهزة');
    await window.AlinFinance.reverseSettlement('library',row.id,reason);
    if(typeof window.audit==='function')await window.audit('finance',`عكس سند تسوية ${row.receipt_number||row.id}: ${reason}`);
    return true;
  }

  function renderLibraryFinance(){
    const root=document.getElementById('libraryV116Content')||document.getElementById('libraryContent');if(!root)return false;
    const id=currentLibraryId(),data=summary(id);
    root.innerHTML=`<section class="library-v116-finance"><div class="library-v116-finance-cards"><article><small>المبيعات المستلمة</small><b>${moneyv(data.gross)} د.ع</b></article><article><small>ربح المكتبة</small><b>${moneyv(data.libraryProfit)} د.ع</b></article><article><small>المسدد للإدارة</small><b>${moneyv(data.settled)} د.ع</b></article><article><small>المتبقي بذمة المكتبة</small><b>${moneyv(data.debtRemaining)} د.ع</b></article></div><div class="row-actions"><button data-alin-click="printLibraryStatement" data-alin-click-arg0="${escv(id)}">طباعة كشف الحساب</button><button class="secondary" data-alin-click="exportLibraryStatement" data-alin-click-arg0="${escv(id)}">تصدير CSV</button></div><div class="library-v116-panel"><h3>تفاصيل الحركات</h3><table><thead><tr><th>الطلب</th><th>التاريخ</th><th>المبلغ</th><th>ربح المكتبة</th><th>الذمة</th></tr></thead><tbody>${statementRows(id)}</tbody></table></div></section>`;
    return true;
  }

  window.printLibraryStatement=printLibraryStatement;
  window.exportLibraryStatement=exportLibraryStatement;
  window.printLibrarySettlement=printLibrarySettlement;
  window.reverseLibrarySettlement=reverseLibrarySettlement;
  window.renderLibraryFinance=renderLibraryFinance;
  window.AlinLibraryModules.printLibraryStatement=printLibraryStatement;
  window.AlinLibraryModules.renderLibraryFinance=renderLibraryFinance;
  window.AlinV120Finance=window.AlinV120Finance||{summary,settle:id=>finance()?.settleLibrary?.(id)};
})();
;

/* modules/library/printing.js */
// === library/printing.js ===
/* ===== library/js/print-canvas-v119.js ===== */
/* V119: protected in-app PDF canvas preview. No native PDF viewer and no download toolbar. */
(function(){
  'use strict';
  let activeOrder=null;
  let activePdf=null;
  let activeBytes=null;
  let rendering=false;

  const toastSafe=(m)=>typeof toast==='function'?toast(m):alert(m);
  const escSafe=(v)=>typeof esc==='function'?esc(v):String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const copies=(o)=>Math.max(1,Number(o?.qty||o?.quantity||1));
  function findOrder(id){try{return (db.orders||[]).find(x=>String(x.id)===String(id));}catch(_){return null;}}
  function findBooklet(order){
    try{
      if(typeof alinV59OrderBooklet==='function') return alinV59OrderBooklet(order);
      return (db.booklets||[]).find(x=>String(x.id)===String(order?.item_id));
    }catch(_){return null;}
  }
  async function resolveSource(path){
    if(typeof alinResolveStoredFile!=='function')throw new Error('خدمة المستندات الخاصة غير متاحة');
    const resolved=await alinResolveStoredFile(path,'booklets');
    if(!resolved?.blob&&!resolved?.url)throw new Error('ملف الملزمة غير محمي أو غير مرتبط بهذا الطلب');
    return resolved;
  }
  async function ensurePdfJs(){
    if(window.pdfjsLib) return window.pdfjsLib;
    await new Promise((resolve,reject)=>{
      const old=document.querySelector('script[data-alin-pdfjs]');
      if(old){old.addEventListener('load',resolve,{once:true});old.addEventListener('error',reject,{once:true});return;}
      const s=document.createElement('script');
      s.src='https://cdn.jsdelivr.net/npm/pdfjs-dist@3.11.174/build/pdf.min.js';
      s.dataset.alinPdfjs='1';s.onload=resolve;s.onerror=reject;document.head.appendChild(s);
    });
    if(!window.pdfjsLib) throw new Error('PDF.js unavailable');
    window.pdfjsLib.GlobalWorkerOptions.workerSrc='https://cdn.jsdelivr.net/npm/pdfjs-dist@3.11.174/build/pdf.worker.min.js';
    return window.pdfjsLib;
  }
  function renderShell(order){
    const qty=copies(order);
    checkoutBox.innerHTML=`
      <section class="alin-print-v119">
        <header class="alin-print-v119-head">
          <div><small>عرض آمن للطباعة فقط</small><h2>${escSafe(order?.title||'ملزمة')}</h2><p>رقم الطلب: <b>${escSafe(order?.order_number||order?.id||'—')}</b> • الطالب: <b>${escSafe(order?.student_name||'—')}</b></p></div>
          <span class="alin-print-v119-copies">المطلوب ${qty} نسخة</span>
        </header>
        <div class="alin-print-v119-toolbar no-print">
          <div><b>معاينة داخل المنصة</b><span>الملف لا يفتح في عارض PDF الأصلي ولا يظهر زر تنزيل.</span></div>
          <button type="button" class="alin-print-v119-print" data-alin-click="printLibraryCanvasV119">طباعة ${qty} نسخة</button>
          <button type="button" class="secondary" data-alin-click="closeCheckout">إغلاق</button>
        </div>
        <div id="alinPrintCanvasStatus" class="alin-print-v119-status"><span></span><b>جاري تجهيز صفحات الملزمة...</b></div>
        <div id="alinPrintCanvasPages" class="alin-print-v119-pages" aria-label="معاينة صفحات الملزمة"></div>
      </section>`;
  }
  async function renderPreview(pdf){
    const pages=document.getElementById('alinPrintCanvasPages');
    const status=document.getElementById('alinPrintCanvasStatus');
    if(!pages||!status) return;
    pages.innerHTML='';
    const maxWidth=Math.min(900,Math.max(320,pages.clientWidth-24));
    for(let n=1;n<=pdf.numPages;n++){
      const page=await pdf.getPage(n);
      const base=page.getViewport({scale:1});
      const scale=Math.min(1.45,maxWidth/base.width);
      const viewport=page.getViewport({scale});
      const wrap=document.createElement('article');
      wrap.className='alin-print-v119-page';
      const label=document.createElement('small');label.textContent=`صفحة ${n} من ${pdf.numPages}`;
      const surface=document.createElement('div');
      surface.className='alin-print-v119-surface';
      surface.style.maxWidth=`${Math.ceil(viewport.width)}px`;
      surface.style.aspectRatio=`${viewport.width} / ${viewport.height}`;
      const canvas=document.createElement('canvas');
      canvas.width=Math.ceil(viewport.width);canvas.height=Math.ceil(viewport.height);
      canvas.setAttribute('aria-label',`صفحة ${n}`);
      surface.appendChild(canvas);wrap.append(label,surface);pages.appendChild(wrap);
      await page.render({canvasContext:canvas.getContext('2d',{alpha:false}),viewport}).promise;
    }
    status.hidden=true;
    status.style.display='none';
  }
  async function openPreview(orderId){
    if(rendering) return;
    const order=findOrder(orderId);
    if(!order||order.kind!=='booklet') return toastSafe('هذا الطلب لا يحتوي ملف PDF');
    const booklet=findBooklet(order);
    if(!booklet?.file_path) return toastSafe('لا يوجد ملف PDF لهذه الملزمة');
    activeOrder=order; activePdf=null; activeBytes=null; rendering=true;
    checkoutModal.classList.remove('hidden');
    const close=document.querySelector('#checkoutModal .x');
    if(close){close.textContent='إغلاق';close.setAttribute('aria-label','إغلاق المعاينة');}
    renderShell(order);
    try{
      const pdfjs=await ensurePdfJs();
      const source=await resolveSource(booklet.file_path);
      if(source.blob){
        activeBytes=await source.blob.arrayBuffer();
      }else{
        const response=await fetch(String(source.url).split('#')[0],{cache:'no-store'});
        if(!response.ok) throw new Error('PDF '+response.status);
        activeBytes=await response.arrayBuffer();
      }
      activePdf=await pdfjs.getDocument({data:activeBytes.slice(0)}).promise;
      await renderPreview(activePdf);
    }catch(err){
      console.error('[ALIN preview error]',err);
      const status=document.getElementById('alinPrintCanvasStatus');
      const message=String(err?.message||'تعذر عرض ملف الملزمة');
      if(status) status.innerHTML=`<div class="alin-print-v119-error"><h3>تعذر تجهيز المعاينة</h3><p>${escSafe(message)}</p></div>`;
      toastSafe(message);
    }finally{rendering=false;}
  }
  async function printPreview(){
    if(!activePdf||!activeBytes) return toastSafe('انتظر حتى تكتمل معاينة الملف');
    const qty=copies(activeOrder);
    const button=document.querySelector('.alin-print-v119-print');
    if(button){button.disabled=true;button.textContent='جاري تجهيز الطباعة...';}
    try{
      const images=[];
      for(let n=1;n<=activePdf.numPages;n++){
        const page=await activePdf.getPage(n);
        const viewport=page.getViewport({scale:2});
        const canvas=document.createElement('canvas');canvas.width=Math.ceil(viewport.width);canvas.height=Math.ceil(viewport.height);
        await page.render({canvasContext:canvas.getContext('2d',{alpha:false}),viewport}).promise;
        images.push(canvas.toDataURL('image/jpeg',0.96));
      }
      let frame=document.getElementById('alinPrintFrameV119');
      if(frame) frame.remove();
      frame=document.createElement('iframe');frame.id='alinPrintFrameV119';frame.style.position='fixed';frame.style.left='-10000px';frame.style.width='1px';frame.style.height='1px';frame.style.border='0';document.body.appendChild(frame);
      const doc=frame.contentDocument;
      doc.open();
      doc.write(`<!doctype html><html dir="rtl"><head><meta charset="utf-8"><title>طباعة ملزمة</title><style>@page{size:auto;margin:8mm}html,body{margin:0;padding:0;background:#fff}.page{page-break-after:always;break-after:page;text-align:center}.page:last-child{page-break-after:auto;break-after:auto}img{display:block;width:100%;height:auto;max-width:100%;margin:0 auto}</style></head><body>${images.map(src=>`<div class="page"><img src="${src}"></div>`).join('')}</body></html>`);
      doc.close();
      await new Promise(resolve=>setTimeout(resolve,500));
      frame.contentWindow.focus();
      frame.contentWindow.print();
      toastSafe(`اختر الطابعة واضبط عدد النسخ على ${qty}`);
    }catch(err){
      console.error('[ALIN print error]',err);
      toastSafe('تعذر تجهيز الطباعة، أعد المحاولة');
    }finally{
      if(button){button.disabled=false;button.textContent=`طباعة ${qty} نسخة`;}
    }
  }
  window.openLibraryBookletPdf=openPreview;
  window.openOrderPdf=openPreview;
  window.printLibraryBookletDirect=openPreview;
  window.printLibraryPreviewV118=printPreview;
  window.printLibraryCanvasV119=printPreview;
  window.AlinLibraryModules=window.AlinLibraryModules||{};
  window.AlinLibraryModules.openLibraryBookletPdf=openPreview;
})();


;
;

/* modules/admin/dashboard.js */
// === admin/dashboard.js ===
/* ===== admin/js/admin-dashboard-v122.js ===== */

(function(){
  const escv=v=>typeof esc==='function'?esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const moneyv=v=>typeof money==='function'?money(v):Number(v||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const arr=v=>Array.isArray(v)?v:[];
  const num=v=>Number(v||0);
  function database(){try{return window.db||db||{}}catch(_){return window.db||{}}}
  function statusText(s){const map={new:'جديد',pending:'جديد',printing:'قيد الطباعة',processing:'قيد التجهيز',ready:'جاهز',delivered:'تم التسليم',completed:'مكتمل',cancelled:'ملغي',canceled:'ملغي'};return map[String(s||'').toLowerCase()]||s||'غير محدد'}
  function orderDate(o){return String(o?.created_at||o?.date||'').slice(0,10)}
  function orderTotal(o){return num(o?.total||o?.total_amount||o?.amount||o?.price)*Math.max(1,num(o?.qty||1))}
  function platformIncome(dbx){
    const rows=arr(dbx.ledger);
    return rows.reduce((a,x)=>a+num(x.platform_amount||x.alin||x.platform_profit),0);
  }
  function libraryDebt(dbx){
    try{
      if(typeof window.alinV121LibraryDebtTotal==='function') return num(window.alinV121LibraryDebtTotal());
      return arr(dbx.accounts?.libraries).reduce((sum,l)=>{try{return sum+(typeof libDebt==='function'?num(libDebt(l.id)?.remaining):0)}catch(_){return sum}},0);
    }catch(_){return 0}
  }
  function render(){
    const content=document.getElementById('adminContent'); if(!content)return;
    const dbx=database(),orders=arr(dbx.orders),products=arr(dbx.products),booklets=arr(dbx.booklets),teachers=arr(dbx.accounts?.teachers),libraries=arr(dbx.accounts?.libraries),couriers=arr(dbx.accounts?.couriers||dbx.couriers);
    const today=new Date().toISOString().slice(0,10),month=today.slice(0,7);
    const todayOrders=orders.filter(o=>orderDate(o)===today),monthOrders=orders.filter(o=>orderDate(o).startsWith(month));
    const newOrders=orders.filter(o=>['new','pending',''].includes(String(o.status||'').toLowerCase()));
    const delivered=monthOrders.filter(o=>['delivered','completed'].includes(String(o.status||'').toLowerCase()));
    const low=products.filter(p=>num(p.stock)<=num(p.low_stock_limit||dbx.settings?.low_stock_default||5));
    const inactiveLibraries=libraries.filter(l=>String(l.status||'').toLowerCase()!=='active'||l.is_open===false||String(l.open_status||'').toLowerCase()==='closed');
    const recent=[...orders].sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||''))).slice(0,6);
    const monthSales=monthOrders.reduce((a,o)=>a+orderTotal(o),0),income=platformIncome(dbx),debt=libraryDebt(dbx);
    const dateText=new Intl.DateTimeFormat('ar-IQ',{weekday:'long',year:'numeric',month:'long',day:'numeric'}).format(new Date());
    const recentHtml=recent.length?recent.map(o=>`<article class="admin-v122-order"><div><b>#${escv(o.order_no||o.code||o.id||'طلب')}</b><small>${escv(o.student_name||o.customer_name||'طالب')} • ${escv(orderDate(o)||'بدون تاريخ')}</small><span class="admin-v122-status">${escv(statusText(o.status))}</span></div><div class="admin-v122-order-total">${moneyv(orderTotal(o))} د.ع</div></article>`).join(''):'<div class="admin-v122-empty">لا توجد طلبات بعد.</div>';
    const alerts=[];
    if(newOrders.length)alerts.push(`<article class="admin-v122-alert"><div><b>طلبات تحتاج متابعة</b><small>طلبات جديدة لم يبدأ تجهيزها بعد.</small></div><em>${newOrders.length}</em></article>`);
    if(low.length)alerts.push(`<article class="admin-v122-alert danger"><div><b>مخزون منخفض</b><small>${escv(low.slice(0,3).map(x=>x.name||x.title).join('، '))}</small></div><em>${low.length}</em></article>`);
    if(debt>0)alerts.push(`<article class="admin-v122-alert"><div><b>ذمم مكتبات غير مسوّاة</b><small>تحتاج مراجعة من قسم المالية.</small></div><em>${moneyv(debt)}</em></article>`);
    if(inactiveLibraries.length)alerts.push(`<article class="admin-v122-alert"><div><b>مكتبات غير متاحة</b><small>مغلقة أو غير مفعلة حالياً.</small></div><em>${inactiveLibraries.length}</em></article>`);
    content.dataset.adminV122='dashboard';
    content.innerHTML=`<section class="admin-v122-dashboard"><header class="admin-v122-welcome"><div><h2>أهلاً بك في إدارة منصة آلين</h2><p>ملخص سريع لحالة المنصة والطلبات والحسابات المهمة.</p></div><span class="admin-v122-date">${escv(dateText)}</span></header><section class="admin-v122-metrics"><article class="admin-v122-metric"><small>طلبات اليوم</small><strong>${todayOrders.length}</strong><span>${newOrders.length} طلب جديد بانتظار المتابعة</span></article><article class="admin-v122-metric gold"><small>مبيعات الشهر</small><strong>${moneyv(monthSales)} د.ع</strong><span>${monthOrders.length} طلب خلال الشهر</span></article><article class="admin-v122-metric green"><small>طلبات مكتملة هذا الشهر</small><strong>${delivered.length}</strong><span>تم التسليم أو الإكمال</span></article><article class="admin-v122-metric red"><small>ذمم المكتبات</small><strong>${moneyv(debt)} د.ع</strong><span>الرصيد غير المسوّى</span></article><article class="admin-v122-metric"><small>الملازم والمنتجات</small><strong>${booklets.length+products.length}</strong><span>${booklets.length} ملزمة • ${products.length} منتج</span></article><article class="admin-v122-metric"><small>الشركاء</small><strong>${teachers.length+libraries.length+couriers.length}</strong><span>${teachers.length} مدرس • ${libraries.length} مكتبة • ${couriers.length} مندوب</span></article><article class="admin-v122-metric gold"><small>حصة المنصة المسجلة</small><strong>${moneyv(income)} د.ع</strong><span>بحسب السجلات المالية الحالية</span></article><article class="admin-v122-metric ${low.length?'red':''}"><small>مخزون منخفض</small><strong>${low.length}</strong><span>${low.length?escv(low.slice(0,2).map(x=>x.name||x.title).join('، ')):'لا توجد تنبيهات مخزون'}</span></article></section><section class="admin-v122-grid"><article class="admin-v122-card"><div class="admin-v122-card-head"><h3>أحدث الطلبات</h3><button type="button" data-alin-click="adminTab" data-alin-click-arg0="orders">عرض الكل</button></div><div class="admin-v122-orders">${recentHtml}</div></article><aside class="admin-v122-card"><div class="admin-v122-card-head"><h3>تنبيهات تحتاج انتباهك</h3></div><div class="admin-v122-alerts">${alerts.join('')||'<div class="admin-v122-empty">كل الأمور مستقرة حالياً.</div>'}</div></aside></section><section class="admin-v122-card"><div class="admin-v122-card-head"><h3>وصول سريع</h3></div><div class="admin-v122-actions"><button class="admin-v122-action" data-alin-click="adminTab" data-alin-click-arg0="orders"><i>🧾</i><span>إدارة الطلبات</span></button><button class="admin-v122-action" data-alin-click="adminTab" data-alin-click-arg0="products"><i>🛍️</i><span>إضافة منتج</span></button><button class="admin-v122-action" data-alin-click="adminTab" data-alin-click-arg0="booklets"><i>📘</i><span>إدارة الملازم</span></button><button class="admin-v122-action" data-alin-click="adminTab" data-alin-click-arg0="finance"><i>💳</i><span>المالية والتسويات</span></button></div></section></section>`;
  }
  window.renderAdminDashboard=render;
  if(window.AlinAdminModules?.register)window.AlinAdminModules.register('dashboard',render);
})();


;
;

/* modules/admin/orders.js */
// === admin/orders.js ===
// Authoritative admin order management. No adminTab wrapping and no legacy fallbacks.
(function(){
  'use strict';

  const $=id=>document.getElementById(id);
  const esc=v=>String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const moneyText=v=>typeof window.money==='function'?window.money(v):Number(v||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const arr=v=>Array.isArray(v)?v:[];
  const now=()=>new Date().toISOString();
  const dbx=()=>window.db||{};
  const orders=()=>arr(dbx().orders);
  const libraries=()=>arr(dbx().accounts?.libraries);
  const couriers=()=>{
    if(window.AlinCourierCore?.allCouriers)return window.AlinCourierCore.allCouriers();
    const accounts=arr(dbx().accounts?.couriers),rows=arr(dbx().couriers),map=new Map();
    [...accounts,...rows].forEach(row=>{const key=String(row?.id||row?.account_id||row?.username||'');if(key)map.set(key,{...(map.get(key)||{}),...row,role:'courier'})});
    return [...map.values()];
  };
  const products=()=>arr(dbx().products);
  const statusLabels={
    pending:'قيد الانتظار',new:'جديد',pending_admin:'بانتظار الإدارة',payment_pending:'بانتظار الدفع',paid:'مدفوع',
    assigned:'محول للمندوب',accepted:'مقبول من المندوب',picked_up:'استلمه المندوب',out_for_delivery:'قيد التوصيل',out_delivery:'قيد التوصيل',
    processing:'قيد التجهيز',printing:'قيد الطباعة',ready:'جاهز',completed:'مكتمل',delivered:'تم التسليم',cancelled:'ملغي',rejected:'مرفوض',receipt_rejected:'وصل مرفوض'
  };
  const state={q:'',status:'',library:'',courier:'',kind:'',period:'all',from:'',to:''};
  const metaKey='alin_admin_order_meta_v220';
  let busy=false;

  function normalizeArea(value){
    if(typeof window.alinNormalizeDeliveryArea==='function')return window.alinNormalizeDeliveryArea(value);
    return String(value||'').trim().replace(/\s+/g,' ').split(/[-–—]/)[0].trim().toLowerCase();
  }
  function courierAreas(c){
    let raw=c?.areas??c?.area_ids??c?.area??[];
    if(typeof raw==='string'){try{const parsed=JSON.parse(raw);raw=Array.isArray(parsed)?parsed:raw.split(/[,،|]/)}catch(_){raw=raw.split(/[,،|]/)}}
    return arr(raw).map(x=>typeof x==='object'?(x.name||x.area||x.id||''):x).map(x=>String(x).trim()).filter(Boolean);
  }
  function matchingCouriers(area){
    const target=normalizeArea(area);
    if(!target)return couriers().filter(c=>String(c.status||'active')!=='inactive');
    return couriers().filter(c=>String(c.status||'active')!=='inactive'&&courierAreas(c).some(a=>normalizeArea(a)===target));
  }
  function libraryName(id){const row=libraries().find(x=>String(x.id)===String(id));return row?.name||row?.library_name||row?.display_name||row?.title||'غير محددة'}
  function courierName(id){return couriers().find(x=>String(x.id)===String(id))?.name||'غير معيّن'}
  function statusOf(o){return String(o?.status||o?.payment_status||'new')}
  function labelOf(value){const s=typeof value==='object'?statusOf(value):String(value||'new');return statusLabels[s]||s}
  function orderDate(o){const d=new Date(o?.created_at||o?.createdAt||Date.now());return Number.isNaN(d.getTime())?new Date(0):d}
  function dateText(o){const d=orderDate(o);return d.getTime()?d.toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ'):'—'}
  function homeDelivery(o){return ['home_delivery','delivery','courier'].includes(String(o?.fulfillment_type||o?.delivery_type||''))}
  function metaLoad(){try{return JSON.parse(localStorage.getItem(metaKey)||'{}')}catch(_){return {}}}
  function metaSave(value){try{localStorage.setItem(metaKey,JSON.stringify(value))}catch(_){}}
  function orderMeta(id){return metaLoad()[String(id)]||{notes:[],history:[]}}
  function saveMeta(id,value){const all=metaLoad();all[String(id)]=value;metaSave(all)}
  function addHistory(id,action,details=''){
    const m=orderMeta(id);m.history=[...(m.history||[]),{at:now(),actor:window.current?.name||window.current?.username||'المدير',action,details}];saveMeta(id,m);
  }
  function notify(message,type='success'){
    if(typeof window.toast==='function')return window.toast(message);
    const old=document.querySelector('.alin-order-toast');if(old)old.remove();
    const el=document.createElement('div');el.className=`toast alin-order-toast ${type}`;el.textContent=message;document.body.appendChild(el);setTimeout(()=>el.remove(),2500);
  }
  function friendlyError(error){
    if(window.AlinCourierCore?.friendlyOrderError)return window.AlinCourierCore.friendlyOrderError(error);
    const text=String(error?.message||error||'').trim();
    if(text.includes('schema cache'))return 'خدمة الطلبات لم تتحدث بعد في Supabase.';
    if(/غير مسموح|صلاحية/.test(text))return text;
    return text||'تعذر تنفيذ العملية.';
  }
  function range(){
    const end=new Date();end.setHours(23,59,59,999);const start=new Date(end);start.setHours(0,0,0,0);
    if(state.period==='today')return[start,end];
    if(state.period==='week'){start.setDate(start.getDate()-6);return[start,end]}
    if(state.period==='month'){start.setDate(1);return[start,end]}
    if(state.period==='custom')return[state.from?new Date(state.from+'T00:00:00'):null,state.to?new Date(state.to+'T23:59:59'):null];
    return[null,null];
  }
  function filtered(){
    const q=state.q.trim().toLowerCase(),[from,to]=range();
    return orders().filter(o=>{
      const d=orderDate(o),hay=[o.order_number,o.id,o.title,o.student_name,o.student_phone,libraryName(o.library_id||o.pickup_library_id),courierName(o.courier_id||o.delegate_id),o.delivery_area,o.delivery_landmark].join(' ').toLowerCase();
      return(!q||hay.includes(q))&&(!state.status||statusOf(o)===state.status)&&(!state.library||String(o.library_id||o.pickup_library_id||'')===state.library)&&(!state.courier||String(o.courier_id||o.delegate_id||'')===state.courier)&&(!state.kind||String(o.kind||'')===state.kind)&&(!from||d>=from)&&(!to||d<=to);
    }).sort((a,b)=>orderDate(b)-orderDate(a));
  }
  function overdue(o){return !['ready','completed','delivered','cancelled','rejected'].includes(statusOf(o))&&Date.now()-orderDate(o).getTime()>86400000}
  function markTab(){
    window.activeAdminTab='orders';
    if(typeof window.markAdminTab==='function')window.markAdminTab('orders');
    document.querySelectorAll('#adminPage .admin-tabs button').forEach(b=>b.classList.toggle('active-admin-tab',b.dataset.adminTab==='orders'));
  }
  function render(){
    const content=$('adminContent');if(!content)return;
    markTab();if(typeof window.adminStatsRender==='function')window.adminStatsRender();
    const all=orders(),list=filtered(),count=s=>all.filter(o=>statusOf(o)===s).length;
    const revenue=all.filter(o=>['completed','delivered'].includes(statusOf(o))).reduce((a,o)=>a+Number(o.total||0),0);
    content.dataset.adminModule='orders';
    content.innerHTML=`<section class="admin-orders-v126"><header class="admin-orders-v126-head"><div><h2>إدارة الطلبات</h2><p>متابعة الطلب من إنشائه إلى التحويل والتسليم.</p></div><div class="admin-orders-v126-head-actions"><button type="button" class="secondary" data-alin-click="adminOrdersExport">تصدير Excel</button><span>${list.length}</span></div></header>
    <section class="admin-orders-v126-stats"><article><small>كل الطلبات</small><strong>${all.length}</strong></article><article><small>جديدة</small><strong>${count('new')+count('pending_admin')}</strong></article><article><small>قيد التنفيذ</small><strong>${count('processing')+count('printing')+count('assigned')+count('accepted')+count('picked_up')+count('out_for_delivery')}</strong></article><article><small>متأخرة</small><strong>${all.filter(overdue).length}</strong></article><article><small>المبيعات المكتملة</small><strong>${moneyText(revenue)} د.ع</strong></article></section>
    <section class="admin-orders-v126-tools"><input id="adminOrderSearch" value="${esc(state.q)}" placeholder="رقم الطلب، اسم الطالب أو الهاتف"><select id="adminOrderStatus"><option value="">كل الحالات</option>${Object.entries(statusLabels).map(([k,v])=>`<option value="${k}" ${state.status===k?'selected':''}>${v}</option>`).join('')}</select><select id="adminOrderLibrary"><option value="">كل المكتبات</option>${libraries().map(x=>`<option value="${esc(x.id)}" ${state.library===String(x.id)?'selected':''}>${esc(x.name)}</option>`).join('')}</select><select id="adminOrderCourier"><option value="">كل المندوبين</option>${couriers().map(x=>`<option value="${esc(x.id)}" ${state.courier===String(x.id)?'selected':''}>${esc(x.name)}</option>`).join('')}</select><select id="adminOrderKind"><option value="">كل الأنواع</option><option value="booklet" ${state.kind==='booklet'?'selected':''}>ملازم</option><option value="stationery" ${state.kind==='stationery'?'selected':''}>قرطاسية</option><option value="gift" ${state.kind==='gift'?'selected':''}>هدايا</option><option value="product" ${state.kind==='product'?'selected':''}>منتج</option></select><select id="adminOrderPeriod"><option value="all" ${state.period==='all'?'selected':''}>كل التواريخ</option><option value="today" ${state.period==='today'?'selected':''}>اليوم</option><option value="week" ${state.period==='week'?'selected':''}>آخر 7 أيام</option><option value="month" ${state.period==='month'?'selected':''}>هذا الشهر</option><option value="custom" ${state.period==='custom'?'selected':''}>فترة مخصصة</option></select><input id="adminOrderFrom" type="date" value="${esc(state.from)}" ${state.period==='custom'?'':'hidden'}><input id="adminOrderTo" type="date" value="${esc(state.to)}" ${state.period==='custom'?'':'hidden'}><button type="button" data-alin-click="adminOrdersClear">مسح</button></section>
    <section class="admin-orders-v126-list">${list.length?list.map(orderCard).join(''):'<div class="admin-orders-v126-empty">لا توجد طلبات مطابقة.</div>'}</section></section>`;
    bind();
  }
  function orderCard(o){
    const st=statusOf(o),late=overdue(o),m=orderMeta(o.id),assigned=o.courier_id||o.delegate_id;
    return `<article class="admin-order-v126 ${late?'is-overdue':''}"><div class="admin-order-v126-main"><div class="admin-order-v126-title"><span>${esc(o.order_number||o.id)}</span><b>${esc(o.title||'طلب')} × ${Number(o.qty||1)}</b>${late?'<em>متأخر</em>':''}</div><small>${esc(o.student_name||'بدون اسم')} • ${esc(o.student_phone||'بدون هاتف')}</small></div><div class="admin-order-v126-meta"><span>المبلغ <b>${moneyText(o.total||0)} د.ع</b></span><span>${homeDelivery(o)?'المنطقة':'المكتبة'} <b>${esc(homeDelivery(o)?(normalizeArea(o.delivery_area)||'غير محددة'):libraryName(o.library_id||o.pickup_library_id))}</b></span><span>المندوب <b>${esc(courierName(assigned))}</b></span></div><div class="admin-order-v126-state"><span class="pill ${esc(st)}">${esc(labelOf(st))}</span><small>${esc(dateText(o))}</small>${(m.notes||[]).length?`<small>ملاحظات الإدارة: ${(m.notes||[]).length}</small>`:''}</div><div class="admin-order-v126-actions"><button class="secondary" data-alin-click="adminOrderDetails" data-alin-click-arg0="${esc(o.id)}">تفاصيل</button><button class="secondary" data-alin-click="adminOrderPrint" data-alin-click-arg0="${esc(o.id)}">وصل</button>${o.student_phone?`<button class="whatsapp" data-alin-click="adminOrderWhatsapp" data-alin-click-arg0="${esc(o.id)}">واتساب</button>`:''}</div></article>`;
  }
  function bind(){
    const map={adminOrderSearch:['q','input'],adminOrderStatus:['status','change'],adminOrderLibrary:['library','change'],adminOrderCourier:['courier','change'],adminOrderKind:['kind','change'],adminOrderPeriod:['period','change'],adminOrderFrom:['from','change'],adminOrderTo:['to','change']};
    Object.entries(map).forEach(([id,[key,event]])=>{const el=$(id);if(el)el.addEventListener(event,()=>{state[key]=el.value;render()})});
  }
  async function assignOrderAuthoritative(id,courierId,libraryId){
    if(busy)throw new Error('العملية قيد التنفيذ');
    if(!window.AlinCourierCore?.assignOrder)throw new Error('خدمة تعيين المندوب v4.1.0 غير جاهزة');
    busy=true;
    try{return await window.AlinCourierCore.assignOrder(id,courierId||null,libraryId||null)}
    finally{busy=false}
  }
  async function changeStatus(id,status,reason=''){
    const order=orders().find(x=>String(x.id)===String(id));if(!order)return alert('الطلب غير موجود');
    try{
      if(!window.AlinFinance?.transitionOrder)throw new Error('خدمة الانتقال الذري غير جاهزة');
      await window.AlinFinance.transitionOrder(id,status,reason);
      addHistory(id,'تغيير الحالة',`${labelOf(status)}${reason?' — '+reason:''}`);
      if(typeof window.audit==='function')await window.audit('order',`تحديث الطلب ${order.order_number||id} إلى ${status}${reason?' بسبب: '+reason:''}`);
      if((status==='completed'||status==='delivered')&&window.AlinNotifications?.send)await window.AlinNotifications.send({role:'admin',title:'طلب مسلّم',message:`تم تسليم الطلب ${order.order_number||id}`});
      render();notify('تم تحديث حالة الطلب والحسابات');
    }catch(error){alert('تعذر تحديث الطلب: '+friendlyError(error))}
  }
  async function assign(id){
    const order=orders().find(x=>String(x.id)===String(id));if(!order)return;
    const libraryId=$('v220AssignLibrary')?.value||null,courierId=$('v220AssignCourier')?.value||null;
    if(homeDelivery(order)&&!courierId)return alert('اختر مندوبًا مطابقًا للمنطقة');
    try{
      await assignOrderAuthoritative(id,courierId,libraryId);
      addHistory(id,'تعيين الطلب',`المكتبة: ${libraryName(libraryId)}، المندوب: ${courierName(courierId)}`);
      if(typeof window.audit==='function')await window.audit('order',`تعيين الطلب ${order.order_number||id}`);
      render();details(id);notify('تم حفظ التعيين');
    }catch(error){alert('تعذر حفظ التعيين: '+friendlyError(error))}
  }
  function details(id){
    const o=orders().find(x=>String(x.id)===String(id));if(!o)return;const m=orderMeta(id),matches=homeDelivery(o)?matchingCouriers(o.delivery_area):couriers(),assigned=String(o.courier_id||o.delegate_id||'');
    if(assigned&&!matches.some(c=>String(c.id)===assigned)){const current=couriers().find(c=>String(c.id)===assigned);if(current)matches.unshift(current)}
    let modal=$('adminOrderDetailsModal');if(!modal){modal=document.createElement('div');modal.id='adminOrderDetailsModal';modal.className='modal hidden';modal.innerHTML='<div class="modal-card"><button class="x" data-alin-click="@hide-by-id" data-alin-click-target="adminOrderDetailsModal">×</button><div id="adminOrderDetailsBox"></div></div>';document.body.appendChild(modal)}
    $('adminOrderDetailsBox').innerHTML=`<div class="v126-detail-head"><div><small>رقم الطلب</small><h2>${esc(o.order_number||o.id)}</h2></div><span class="pill ${esc(statusOf(o))}">${esc(labelOf(o))}</span></div><section class="v126-detail-grid"><div><small>الطالب</small><b>${esc(o.student_name||'—')}</b></div><div><small>الهاتف</small><b>${esc(o.student_phone||'—')}</b></div><div><small>العنصر</small><b>${esc(o.title||'—')}</b></div><div><small>الكمية</small><b>${Number(o.qty||1)}</b></div><div><small>المجموع الفرعي</small><b>${moneyText(Number(o.total||0)+Number(o.discount||0)-Number(o.delivery_fee||0))} د.ع</b></div><div><small>الخصم</small><b>${moneyText(o.discount||0)} د.ع</b></div><div><small>أجرة التوصيل</small><b>${moneyText(o.delivery_fee||0)} د.ع</b></div><div><small>الإجمالي</small><b>${moneyText(o.total||0)} د.ع</b></div><div><small>طريقة الاستلام</small><b>${homeDelivery(o)?'عن طريق المندوب':'استلام من المكتبة'}</b></div><div><small>المنطقة</small><b>${esc(normalizeArea(o.delivery_area)||'—')}</b></div><div><small>أقرب نقطة دالة</small><b>${esc(o.delivery_landmark||'—')}</b></div><div><small>ملاحظات الطالب</small><b>${esc(o.notes||'—')}</b></div></section><section class="v126-assign"><h3>تعيين الطلب</h3><select id="v220AssignLibrary" ${homeDelivery(o)?'disabled':''}><option value="">بدون مكتبة</option>${libraries().map(x=>`<option value="${esc(x.id)}" ${String(o.library_id||o.pickup_library_id||'')===String(x.id)?'selected':''}>${esc(x.name)}</option>`).join('')}</select><select id="v220AssignCourier" ${homeDelivery(o)?'':'disabled'}><option value="">بدون مندوب</option>${matches.map(x=>`<option value="${esc(x.id)}" ${assigned===String(x.id)?'selected':''}>${esc(x.name)}${courierAreas(x).length?' — '+esc(courierAreas(x).join('، ')):''}</option>`).join('')}</select><button ${busy?'disabled':''} data-alin-click="adminOrderAssign" data-alin-click-arg0="${esc(o.id)}">حفظ التعيين</button>${homeDelivery(o)?`<small>المندوبون المطابقون لمنطقة ${esc(normalizeArea(o.delivery_area)||'غير محددة')}: ${matches.length}</small>`:''}</section><section class="v126-notes"><h3>ملاحظات الإدارة</h3><div class="v126-note-form"><textarea id="v220AdminNote" placeholder="اكتب ملاحظة داخلية على الطلب"></textarea><button data-alin-click="adminOrderAddNote" data-alin-click-arg0="${esc(o.id)}">إضافة</button></div>${arr(m.notes).slice().reverse().map(n=>`<article><b>${esc(n.actor||'المدير')}</b><small>${esc(new Date(n.at).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ'))}</small><p>${esc(n.text)}</p></article>`).join('')||'<p class="muted">لا توجد ملاحظات إدارية.</p>'}</section><section class="v126-history"><h3>سجل حركة الطلب</h3>${[...arr(o.status_history).map(h=>({at:h.at,actor:h.by||'النظام',action:'حالة الطلب',details:labelOf(h.status)})),...arr(m.history)].sort((a,b)=>String(b.at||'').localeCompare(String(a.at||''))).map(h=>`<article><b>${esc(h.action)}</b><span>${esc(h.actor||'المدير')}</span><small>${esc(h.at?new Date(h.at).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ'):'—')}</small><p>${esc(h.details||'')}</p></article>`).join('')||'<p class="muted">لا توجد حركة مسجلة بعد.</p>'}</section><div class="v126-detail-actions"><button data-alin-click="adminOrderStatus" data-alin-click-arg0="${esc(o.id)}" data-alin-click-arg1="processing">قيد التجهيز</button><button data-alin-click="adminOrderStatus" data-alin-click-arg0="${esc(o.id)}" data-alin-click-arg1="ready">جاهز</button><button data-alin-click="adminOrderStatus" data-alin-click-arg0="${esc(o.id)}" data-alin-click-arg1="completed">مكتمل</button><button class="secondary" data-alin-click="adminOrderPrint" data-alin-click-arg0="${esc(o.id)}">طباعة وصل</button>${o.student_phone?`<button class="whatsapp" data-alin-click="adminOrderWhatsapp" data-alin-click-arg0="${esc(o.id)}">واتساب</button>`:''}<button class="danger" data-alin-click="adminOrderCancel" data-alin-click-arg0="${esc(o.id)}">إلغاء مع سبب</button></div>`;
    modal.classList.remove('hidden');
  }
  function printOrder(id){
    const o=orders().find(x=>String(x.id)===String(id));if(!o)return;const w=window.open('','_blank','width=760,height=900');if(!w)return alert('اسمح بالنوافذ المنبثقة للطباعة');
    w.document.write(`<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>وصل طلب ${esc(o.order_number||o.id)}</title><style>body{font-family:Tahoma;padding:36px;color:#102b50}.receipt{max-width:680px;margin:auto;border:1px solid #dbe3ed;border-radius:24px;padding:28px}.brand{text-align:center;border-bottom:2px solid #d9a72d;padding-bottom:16px}.row{display:flex;justify-content:space-between;padding:11px 0;border-bottom:1px dashed #dbe3ed}.total{font-size:22px;font-weight:bold;color:#96680f}.note{margin-top:20px;color:#667085;text-align:center}@media print{button{display:none}}</style></head><body><div class="receipt"><div class="brand"><h1>منصة آلين</h1><p>وصل طلب</p></div><div class="row"><span>رقم الطلب</span><b>${esc(o.order_number||o.id)}</b></div><div class="row"><span>الطالب</span><b>${esc(o.student_name||'—')}</b></div><div class="row"><span>الهاتف</span><b>${esc(o.student_phone||'—')}</b></div><div class="row"><span>العنصر</span><b>${esc(o.title||'—')} × ${Number(o.qty||1)}</b></div><div class="row"><span>المنطقة/المكتبة</span><b>${esc(homeDelivery(o)?(normalizeArea(o.delivery_area)||'—'):libraryName(o.library_id||o.pickup_library_id))}</b></div><div class="row"><span>المندوب</span><b>${esc(courierName(o.courier_id||o.delegate_id))}</b></div><div class="row"><span>الخصم</span><b>${moneyText(o.discount||0)} د.ع</b></div><div class="row"><span>أجرة التوصيل</span><b>${moneyText(o.delivery_fee||0)} د.ع</b></div><div class="row"><span>الحالة</span><b>${esc(labelOf(o))}</b></div><div class="row total"><span>الإجمالي</span><b>${moneyText(o.total||0)} د.ع</b></div><p class="note">تاريخ الطباعة: ${new Date().toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')}</p><button id="alinOrderReceiptPrint" type="button">طباعة</button></div></body></html>`);w.document.close();const printButton=w.document.getElementById('alinOrderReceiptPrint');if(printButton)printButton.addEventListener('click',()=>w.print());w.focus();
  }

  window.renderOrdersAdmin=render;
  window.adminOrdersClear=()=>{Object.assign(state,{q:'',status:'',library:'',courier:'',kind:'',period:'all',from:'',to:''});render()};
  window.adminOrderStatus=changeStatus;
  window.orderStatus=changeStatus;
  window.adminOrderAssign=assign;
  window.adminOrderDetails=details;
  window.adminOrderAddNote=id=>{const input=$('v220AdminNote'),text=input?.value.trim();if(!text)return alert('اكتب الملاحظة أولاً');const m=orderMeta(id);m.notes=[...arr(m.notes),{at:now(),actor:window.current?.name||'المدير',text}];saveMeta(id,m);addHistory(id,'ملاحظة إدارية',text);details(id)};
  window.adminOrderCancel=id=>{const reason=prompt('اكتب سبب إلغاء الطلب:');if(reason===null)return;if(!reason.trim())return alert('سبب الإلغاء مطلوب');changeStatus(id,'cancelled',reason.trim());$('adminOrderDetailsModal')?.classList.add('hidden')};
  window.adminOrderWhatsapp=id=>{const o=orders().find(x=>String(x.id)===String(id));if(!o?.student_phone)return alert('لا يوجد رقم هاتف');let phone=String(o.student_phone).replace(/\D/g,'');if(phone.startsWith('0'))phone='964'+phone.slice(1);const text=encodeURIComponent(`مرحباً ${o.student_name||''}، بخصوص طلبك رقم ${o.order_number||o.id} في منصة آلين، حالته الحالية: ${labelOf(o)}.`);window.open(`https://wa.me/${phone}?text=${text}`,'_blank','noopener')};
  window.adminOrderPrint=printOrder;
  window.adminOrdersExport=()=>{const rows=[['رقم الطلب','الطالب','الهاتف','العنصر','الكمية','الإجمالي','الخصم','أجرة التوصيل','الحالة','المكتبة','المندوب','المنطقة','التاريخ'],...filtered().map(o=>[o.order_number||o.id,o.student_name||'',o.student_phone||'',o.title||'',o.qty||1,o.total||0,o.discount||0,o.delivery_fee||0,labelOf(o),libraryName(o.library_id||o.pickup_library_id),courierName(o.courier_id||o.delegate_id),normalizeArea(o.delivery_area),dateText(o)])];const csv='\ufeff'+rows.map(r=>r.map(v=>`"${String(v).replace(/"/g,'""')}"`).join(',')).join('\n');const blob=new Blob([csv],{type:'text/csv;charset=utf-8'}),a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=`alin-orders-${new Date().toISOString().slice(0,10)}.csv`;a.click();setTimeout(()=>URL.revokeObjectURL(a.href),250)};
})();
;

/* modules/admin/booklets.js */
// ALIN Admin Booklets — single implementation (v2.2.6)
(function(){
  'use strict';

  const state={q:'',status:'all',grade:'all',subject:'all',teacher:'all'};
  const escv=value=>typeof window.esc==='function'?window.esc(value):String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const moneyv=value=>typeof window.money==='function'?window.money(value):Number(value||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const books=()=>Array.isArray(window.db?.booklets)?window.db.booklets:[];
  const teachers=()=>Array.isArray(window.db?.accounts?.teachers)?window.db.accounts.teachers:[];
  const orders=()=>Array.isArray(window.db?.orders)?window.db.orders:[];
  const root=()=>window.adminContent||document.getElementById('adminContent');
  const statusValue=book=>String(book?.publish_status||book?.status||'draft').toLowerCase();
  const statusLabel=status=>({published:'منشورة',hidden:'مخفية',draft:'مسودة',review:'قيد المراجعة',pending:'قيد المراجعة',archived:'مؤرشفة'}[String(status||'draft').toLowerCase()]||String(status||'مسودة'));
  const teacherName=id=>teachers().find(item=>String(item.id)===String(id))?.name||'مدرس غير محدد';
  const unique=values=>[...new Set(values.map(value=>String(value||'').trim()).filter(Boolean))];
  const orderCount=id=>orders().filter(order=>{
    const itemId=order.item_id||order.booklet_id||order.item?.id;
    const kind=String(order.kind||order.item_kind||order.item_type||'booklet').toLowerCase();
    return String(itemId)===String(id)&&kind==='booklet';
  }).length;
  const coverUrl=book=>{
    const value=book?.cover_path||book?.cover_url||book?.cover||'';
    if(!value)return '';
    try{return typeof window.mediaUrl==='function'?window.mediaUrl(value):value}catch(_){return value}
  };
  const upload=async(bucket,file,options)=>{
    if(!file||!file.name)return '';
    const uploader=window.uploadFileV52||window.uploadFile;
    if(typeof uploader!=='function')throw new Error('خدمة رفع الملفات غير متاحة');
    return uploader(bucket,file,options);
  };
  const statusPayload=status=>{
    const normalized=String(status||'draft');
    return {
      status:normalized,
      publish_status:normalized,
      published:normalized==='published',
      is_published:normalized==='published'
    };
  };

  async function reloadAndRender(){
    if(typeof window.load==='function')await window.load();
    renderBookletsAdmin();
  }

  function filteredBooks(){
    let list=[...books()];
    const q=state.q.trim().toLowerCase();
    if(q)list=list.filter(book=>[book.title,book.subject,book.grade,teacherName(book.teacher_id)].some(value=>String(value||'').toLowerCase().includes(q)));
    if(state.status!=='all')list=list.filter(book=>statusValue(book)===state.status||(state.status==='review'&&statusValue(book)==='pending'));
    if(state.grade!=='all')list=list.filter(book=>String(book.grade||'')===state.grade);
    if(state.subject!=='all')list=list.filter(book=>String(book.subject||'')===state.subject);
    if(state.teacher!=='all')list=list.filter(book=>String(book.teacher_id||'')===state.teacher);
    return list.sort((a,b)=>String(b.updated_at||b.created_at||b.id||'').localeCompare(String(a.updated_at||a.created_at||a.id||'')));
  }

  function ensureModal(){
    let modal=document.getElementById('alinBookletEditorModal');
    if(modal)return modal;
    modal=document.createElement('div');
    modal.id='alinBookletEditorModal';
    modal.className='modal hidden';
    modal.innerHTML='<div class="modal-card"><button class="x" type="button" data-alin-click="closeBookletEditor">×</button><div id="alinBookletEditorBody"></div></div>';
    document.body.appendChild(modal);
    return modal;
  }

  function formHtml(book={}){
    return `<form id="alinBookletEditorForm" class="form-grid" data-id="${escv(book.id||'')}">
      <input name="title" value="${escv(book.title||'')}" placeholder="اسم الملزمة" required>
      <select name="teacherId" required><option value="">اختر المدرس</option>${teachers().filter(item=>String(item.status||'active')==='active'||String(item.id)===String(book.teacher_id)).map(item=>`<option value="${escv(item.id)}" ${String(item.id)===String(book.teacher_id)?'selected':''}>${escv(item.name)}</option>`).join('')}</select>
      <input name="subject" value="${escv(book.subject||'')}" placeholder="المادة">
      <input name="grade" value="${escv(book.grade||'')}" placeholder="الصف">
      <input name="term" value="${escv(book.term||'')}" placeholder="الفصل">
      <input name="edition" value="${escv(book.edition||book.year||'')}" placeholder="الإصدار أو السنة">
      <input name="price" type="number" min="0" value="${Number(book.price||0)}" placeholder="السعر" required>
      <input name="teacherShare" type="number" min="0" max="100" value="${Number(book.teacher_share_percent||0)}" placeholder="نسبة المدرس %">
      <label>غلاف الملزمة<input name="cover" type="file" accept="image/*"></label>
      <label>ملف PDF ${book.file_path?'(اتركه فارغًا للاحتفاظ بالحالي)':''}<input name="bookletFile" type="file" accept=".pdf,application/pdf" ${book.file_path?'':'required'}></label>
      <textarea name="adminNote" rows="3" placeholder="ملاحظة داخلية">${escv(book.admin_note||'')}</textarea>
      <div class="row-actions"><button type="button" class="secondary" data-alin-click="saveBooklet" data-alin-click-arg0="draft">حفظ مسودة</button><button type="button" class="warning" data-alin-click="saveBooklet" data-alin-click-arg0="review">قيد المراجعة</button><button type="button" data-alin-click="saveBooklet" data-alin-click-arg0="published">حفظ ونشر</button></div>
    </form>`;
  }

  function openBookletEditor(id=''){
    const book=id?books().find(item=>String(item.id)===String(id)):{};
    if(id&&!book)return;
    const modal=ensureModal();
    modal.querySelector('#alinBookletEditorBody').innerHTML=`<h2>${id?'تعديل الملزمة':'إضافة ملزمة'}</h2>${formHtml(book||{})}`;
    modal.classList.remove('hidden');
    modal.hidden=false;
  }

  function closeBookletEditor(){
    const modal=document.getElementById('alinBookletEditorModal');
    if(!modal)return;
    modal.classList.add('hidden');
    modal.hidden=true;
  }

  async function saveBooklet(status='published'){
    const form=document.getElementById('alinBookletEditorForm')||document.getElementById('bookForm');
    if(!form)return;
    const data=new FormData(form);
    const id=String(form.dataset.id||'');
    const existing=id?books().find(item=>String(item.id)===id):null;
    const bookletId=existing?.id||(typeof window.uid==='function'?window.uid('B'):`B-${Date.now()}`);
    const title=String(data.get('title')||'').trim();
    const teacherId=String(data.get('teacherId')||'').trim();
    const price=Number(data.get('price')||0);
    if(!title)return alert('اكتب اسم الملزمة');
    if(!teacherId)return alert('اختر المدرس');
    if(!Number.isFinite(price)||price<0)return alert('السعر غير صحيح');
    try{
      const coverFile=data.get('cover');
      const pdfFile=data.get('bookletFile');
      let coverPath=existing?.cover_path||'';
      let filePath=existing?.file_path||'';
      let fileName=existing?.file_name||'';
      if(coverFile&&coverFile.name)coverPath=await upload('covers',coverFile,{type:'image'});
      if(pdfFile&&pdfFile.name){filePath=await upload('booklets',pdfFile,{type:'pdf',required:true,entityId:bookletId,maxBytes:25*1024*1024});fileName=pdfFile.name}
      if(!filePath)throw new Error('ملف PDF مطلوب');
      const payload={
        title,teacher_id:teacherId,
        subject:String(data.get('subject')||'').trim(),
        grade:String(data.get('grade')||'').trim(),
        term:String(data.get('term')||'').trim(),
        edition:String(data.get('edition')||'').trim(),
        year:String(data.get('edition')||'').trim(),
        price,
        teacher_share_percent:Math.max(0,Math.min(100,Number(data.get('teacherShare')||0))),
        admin_note:String(data.get('adminNote')||'').trim(),
        cover_path:coverPath,file_path:filePath,file_name:fileName,
        updated_at:new Date().toISOString(),
        ...statusPayload(status)
      };
      if(existing){
        await window.update('booklets',payload,{id:existing.id});
        if(typeof window.audit==='function')await window.audit('booklet',`تعديل الملزمة ${title} وحفظها بحالة ${statusLabel(status)}`);
      }else{
        payload.id=bookletId;
        payload.created_at=new Date().toISOString();
        await window.insert('booklets',payload);
        if(typeof window.audit==='function')await window.audit('booklet',`إضافة الملزمة ${title} بحالة ${statusLabel(status)}`);
      }
      closeBookletEditor();
      await reloadAndRender();
      if(typeof window.renderStore==='function')window.renderStore();
      if(typeof window.toast==='function')window.toast(existing?'تم تحديث الملزمة':'تمت إضافة الملزمة');
    }catch(error){
      console.error('[ALIN booklet save]',error);
      alert(error?.message||'تعذر حفظ الملزمة');
    }
  }

  async function setBookStatus(id,status){
    const book=books().find(item=>String(item.id)===String(id));if(!book)return;
    try{
      await window.update('booklets',{...statusPayload(status),updated_at:new Date().toISOString()},{id:book.id});
      if(typeof window.audit==='function')await window.audit('booklet',`تغيير حالة الملزمة ${book.title||book.id} إلى ${statusLabel(status)}`);
      await reloadAndRender();
      if(typeof window.renderStore==='function')window.renderStore();
      if(typeof window.toast==='function')window.toast(`تم تغيير الحالة إلى ${statusLabel(status)}`);
    }catch(error){alert(error?.message||'تعذر تغيير حالة الملزمة')}
  }

  async function deleteBooklet(id){
    const book=books().find(item=>String(item.id)===String(id));if(!book)return;
    const count=orderCount(id);
    if(count>0){
      if(confirm(`الملزمة مرتبطة بـ ${count} طلب ولا يمكن حذفها. هل تريد إخفاءها؟`))await setBookStatus(id,'hidden');
      return;
    }
    if(!confirm(`حذف الملزمة ${book.title||''} نهائيًا؟`))return;
    try{
      await window.removeRow('booklets',{id:book.id});
      if(typeof window.audit==='function')await window.audit('booklet',`حذف الملزمة ${book.title||book.id}`);
      await reloadAndRender();
      if(typeof window.renderStore==='function')window.renderStore();
      if(typeof window.toast==='function')window.toast('تم حذف الملزمة');
    }catch(error){alert(error?.message||'تعذر حذف الملزمة')}
  }

  async function previewBooklet(id){
    const book=books().find(item=>String(item.id)===String(id));if(!book?.file_path)return alert('ملف PDF غير متاح');
    const preview=window.open('about:blank','_blank');
    if(preview){preview.opener=null;preview.document.write('<p dir="rtl" style="font-family:Arial;padding:24px">جاري تجهيز المعاينة الآمنة...</p>');}
    try{
      const resolved=await window.alinResolveStoredFile(book.file_path,'booklets');
      if(!resolved?.url)throw new Error('الملف غير محمي أو غير متاح');
      if(preview)preview.location.replace(resolved.url);else window.location.href=resolved.url;
    }catch(error){
      try{preview?.close();}catch(_){ }
      alert(error?.message||'تعذر فتح المعاينة أو لا توجد صلاحية');
    }
  }

  function card(book){
    const status=statusValue(book);
    const cover=coverUrl(book);
    return `<article class="admin-v128-card"><div class="admin-v128-cover">${cover?`<img src="${escv(cover)}" alt="غلاف ${escv(book.title||'الملزمة')}">`:'<span>آ</span>'}<em class="admin-v128-status ${escv(status)}">${statusLabel(status)}</em></div><div class="admin-v128-card-body"><h3>${escv(book.title||'ملزمة بدون اسم')}</h3><div class="admin-v128-card-meta"><div><small>المدرس</small><b>${escv(teacherName(book.teacher_id))}</b></div><div><small>المادة / الصف</small><b>${escv(book.subject||'—')} • ${escv(book.grade||'—')}</b></div><div><small>الإصدار</small><b>${escv(book.edition||book.year||'—')}</b></div><div><small>الطلبات</small><b>${orderCount(book.id)}</b></div><div><small>السعر</small><b class="price">${moneyv(book.price)} د.ع</b></div></div><div class="admin-v128-card-actions"><button type="button" class="secondary" data-alin-click="previewBooklet" data-alin-click-arg0="${escv(book.id)}">معاينة</button><button type="button" class="secondary" data-alin-click="editBooklet" data-alin-click-arg0="${escv(book.id)}">تعديل</button><button type="button" class="warning" data-alin-click="setBookStatus" data-alin-click-arg0="${escv(book.id)}" data-alin-click-arg1="${status==='published'?'hidden':'published'}">${status==='published'?'إخفاء':'نشر'}</button><button type="button" class="danger" data-alin-click="deleteBooklet" data-alin-click-arg0="${escv(book.id)}">حذف</button></div></div></article>`;
  }

  function renderBookletsAdmin(){
    const container=root();if(!container)return;
    const all=books();
    const list=filteredBooks();
    const grades=unique(all.map(item=>item.grade));
    const subjects=unique(all.map(item=>item.subject));
    const counts={published:0,hidden:0,draft:0,review:0};
    all.forEach(item=>{const status=statusValue(item)==='pending'?'review':statusValue(item);if(Object.prototype.hasOwnProperty.call(counts,status))counts[status]++});
    container.innerHTML=`<section class="admin-v128-booklets"><header class="admin-v128-head"><div><h2>إدارة الملازم</h2><p>إضافة وتعديل ونشر الملازم من تنفيذ واحد مستقل عن platform.js.</p></div><button type="button" data-alin-click="uploadBooklet">إضافة ملزمة</button></header><section class="admin-v128-stats"><article><small>الإجمالي</small><strong>${all.length}</strong></article><article class="green"><small>المنشورة</small><strong>${counts.published}</strong></article><article class="gray"><small>المخفية</small><strong>${counts.hidden}</strong></article><article class="gold"><small>المسودات والمراجعة</small><strong>${counts.draft+counts.review}</strong></article></section><section class="admin-v128-toolbar"><input id="alinBookletSearch" value="${escv(state.q)}" placeholder="بحث باسم الملزمة أو المدرس أو المادة"><select id="alinBookletStatus"><option value="all">كل الحالات</option><option value="published" ${state.status==='published'?'selected':''}>منشورة</option><option value="hidden" ${state.status==='hidden'?'selected':''}>مخفية</option><option value="draft" ${state.status==='draft'?'selected':''}>مسودة</option><option value="review" ${state.status==='review'?'selected':''}>قيد المراجعة</option><option value="archived" ${state.status==='archived'?'selected':''}>مؤرشفة</option></select><select id="alinBookletGrade"><option value="all">كل الصفوف</option>${grades.map(value=>`<option value="${escv(value)}" ${state.grade===value?'selected':''}>${escv(value)}</option>`).join('')}</select><select id="alinBookletSubject"><option value="all">كل المواد</option>${subjects.map(value=>`<option value="${escv(value)}" ${state.subject===value?'selected':''}>${escv(value)}</option>`).join('')}</select><select id="alinBookletTeacher"><option value="all">كل المدرسين</option>${teachers().map(item=>`<option value="${escv(item.id)}" ${state.teacher===String(item.id)?'selected':''}>${escv(item.name)}</option>`).join('')}</select></section><div class="admin-v128-results"><span>تم العثور على <b>${list.length}</b> ملزمة</span></div>${list.length?`<section class="admin-v128-grid">${list.map(card).join('')}</section>`:'<div class="empty">لا توجد ملازم مطابقة.</div>'}</section>`;
    const bind=(id,key,event='change')=>document.getElementById(id)?.addEventListener(event,eventObject=>{state[key]=eventObject.target.value;renderBookletsAdmin()});
    bind('alinBookletSearch','q','input');bind('alinBookletStatus','status');bind('alinBookletGrade','grade');bind('alinBookletSubject','subject');bind('alinBookletTeacher','teacher');
  }

  window.renderBookletsAdmin=renderBookletsAdmin;
  window.uploadBooklet=()=>openBookletEditor('');
  window.editBooklet=openBookletEditor;
  window.saveBooklet=saveBooklet;
  window.closeBookletEditor=closeBookletEditor;
  window.setBookStatus=setBookStatus;
  window.deleteBooklet=deleteBooklet;
  window.archiveBooklet=id=>setBookStatus(id,'archived');
  window.previewBooklet=previewBooklet;
  window.AlinAdminModules?.register?.('booklets',renderBookletsAdmin);
})();
;

/* modules/admin/products.js */
// ALIN Admin Products & Categories — single implementation (v2.2.6)
(function(){
  'use strict';

  const state={q:'',type:'',status:'',stock:'',sort:'newest'};
  const escv=value=>typeof window.esc==='function'?window.esc(value):String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const moneyv=value=>typeof window.money==='function'?window.money(value):Number(value||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const products=()=>Array.isArray(window.db?.products)?window.db.products:[];
  const categories=()=>Array.isArray(window.db?.categories)?window.db.categories:[];
  const orders=()=>Array.isArray(window.db?.orders)?window.db.orders:[];
  const root=()=>window.adminContent||document.getElementById('adminContent');
  const normalizeType=value=>{
    const type=String(value||'stationery').trim().toLowerCase();
    if(type==='gift'||type==='gifts')return 'gift';
    if(type==='stationary'||type==='stationery')return 'stationery';
    return type||'stationery';
  };
  const typeLabel=value=>normalizeType(value)==='gift'?'هدايا':'قرطاسية';
  const statusLabel=value=>({published:'منشور',hidden:'مخفي',draft:'مسودة',archived:'مؤرشف',inactive:'غير فعال'}[String(value||'published').toLowerCase()]||'منشور');
  const categoryList=type=>categories().filter(item=>normalizeType(item.type)===normalizeType(type)&&String(item.status||'active')==='active');
  const uploadImage=async file=>{
    if(!file||!file.name)return '';
    const uploader=window.uploadFileV52||window.uploadFile;
    if(typeof uploader!=='function')throw new Error('خدمة رفع الصور غير متاحة');
    return uploader('products',file,{type:'image'});
  };

  const CATEGORY_ICON_PREFIX='store_category_icon_';
  const SECTION_VISIBLE_PREFIX='store_section_visible_';
  const builtinCategoryKey=item=>{
    const type=normalizeType(item?.type);
    const name=String(item?.name||'').trim();
    if(type==='booklet'&&name==='ملازم')return 'booklet';
    if(type==='stationery'&&name==='قرطاسية')return 'stationery';
    if(type==='gift'&&name==='هدايا')return 'gift';
    return '';
  };
  const categorySectionKey=item=>String(item?.id||'')==='__deal__'?'deal':(builtinCategoryKey(item)||`category:${item?.id||''}`);
  const categoryIconKey=item=>`${CATEGORY_ICON_PREFIX}${categorySectionKey(item)}`;
  const categoryIconPath=item=>String(window.db?.settings?.[categoryIconKey(item)]||'').trim();
  const categoryVisible=item=>{
    const value=window.db?.settings?.[`${SECTION_VISIBLE_PREFIX}${categorySectionKey(item)}`];
    if(value===undefined||value===null||value==='')return String(item?.status||'active')==='active';
    return !['false','0','no','off','inactive','hidden'].includes(String(value).toLowerCase());
  };
  const categoryTypeLabel=value=>({booklet:'ملازم',stationery:'قرطاسية',gift:'هدايا',deal:'عروض'}[normalizeType(value)]||String(value||''));
  const categoryIconUrl=item=>{const path=categoryIconPath(item);if(!path)return '';try{return typeof window.mediaUrl==='function'?window.mediaUrl(path):path}catch(_){return path}};
  async function saveSetting(key,value){
    if(typeof window.settingsSet==='function')return window.settingsSet(key,String(value??''));
    const rows=typeof window.query==='function'?await window.query('settings'):[];
    const existing=Array.isArray(rows)?rows.find(row=>String(row.key)===String(key)):null;
    if(existing&&typeof window.update==='function')await window.update('settings',{value:String(value??'')},{key});
    else if(typeof window.insert==='function')await window.insert('settings',{key,value:String(value??'')});
    window.db=window.db||{};window.db.settings=window.db.settings||{};window.db.settings[key]=String(value??'');
    window.dispatchEvent(new CustomEvent('alin:settings-updated',{detail:{keys:[key]}}));
    return true;
  }
  const imageUrl=item=>{
    const value=item?.image_path||item?.image_url||item?.image||'';
    if(!value)return '';
    try{return typeof window.mediaUrl==='function'?window.mediaUrl(value):value}catch(_){return value}
  };
  const lowStockLimit=item=>Number(item?.low_stock_limit||window.db?.settings?.low_stock_default||5);
  const linkedOrders=id=>orders().filter(order=>{
    const itemId=order.item_id||order.product_id||order.item?.id;
    const kind=String(order.kind||order.item_kind||order.item_type||'product').toLowerCase();
    return String(itemId)===String(id)&&kind!=='booklet';
  });

  async function reloadAndRender(renderFn){
    if(typeof window.load==='function')await window.load();
    if(typeof renderFn==='function')renderFn();
  }

  function filteredProducts(){
    let list=[...products()];
    const q=state.q.trim().toLowerCase();
    if(q)list=list.filter(item=>[item.name,item.title,item.category,item.description,item.details].some(value=>String(value||'').toLowerCase().includes(q)));
    if(state.type)list=list.filter(item=>normalizeType(item.type||item.category_id)===state.type);
    if(state.status)list=list.filter(item=>String(item.status||'published')===state.status);
    if(state.stock==='available')list=list.filter(item=>Number(item.stock)>lowStockLimit(item));
    if(state.stock==='low')list=list.filter(item=>Number(item.stock)>0&&Number(item.stock)<=lowStockLimit(item));
    if(state.stock==='out')list=list.filter(item=>Number(item.stock)<=0);
    if(state.sort==='name')list.sort((a,b)=>String(a.name||a.title||'').localeCompare(String(b.name||b.title||''),'ar'));
    else if(state.sort==='priceAsc')list.sort((a,b)=>Number(a.sale_price||a.deal_price||a.price)-Number(b.sale_price||b.deal_price||b.price));
    else if(state.sort==='priceDesc')list.sort((a,b)=>Number(b.sale_price||b.deal_price||b.price)-Number(a.sale_price||a.deal_price||a.price));
    else if(state.sort==='stock')list.sort((a,b)=>Number(a.stock)-Number(b.stock));
    else list.sort((a,b)=>String(b.created_at||b.id||'').localeCompare(String(a.created_at||a.id||'')));
    return list;
  }

  function categoryOptions(type,selected=''){
    const list=categoryList(type);
    const options=list.map(item=>`<option value="${escv(item.name)}" ${String(selected)===String(item.name)?'selected':''}>${escv(item.name)}</option>`).join('');
    return options||`<option value="${escv(selected||'عام')}">${escv(selected||'عام')}</option>`;
  }

  function productForm(item={}){
    const editing=Boolean(item.id);
    const type=normalizeType(item.type||item.category_id||'stationery');
    return `<form id="alinProductEditorForm" class="form-grid admin-product-editor" data-id="${escv(item.id||'')}">
      <select name="type" id="alinProductType" data-alin-change="refreshProductCategories"><option value="stationery" ${type==='stationery'?'selected':''}>قرطاسية</option><option value="gift" ${type==='gift'?'selected':''}>هدايا</option></select>
      <input name="name" value="${escv(item.name||item.title||'')}" placeholder="اسم المنتج" required>
      <select name="category" id="alinProductCategory">${categoryOptions(type,item.category||'')}</select>
      <input name="currentPrice" type="number" min="0" value="${Number(item.sale_price||item.deal_price||item.price||0)}" placeholder="السعر الحالي" required>
      <input name="previousPrice" type="number" min="0" value="${Number((item.sale_price||item.deal_price)?item.price:0)}" placeholder="السعر السابق (اختياري)">
      <input name="stock" type="number" min="0" value="${Number(item.stock||0)}" placeholder="المخزون" required>
      <input name="lowStockLimit" type="number" min="0" value="${Number(item.low_stock_limit||window.db?.settings?.low_stock_default||5)}" placeholder="حد تنبيه المخزون">
      <textarea name="description" rows="3" placeholder="تفاصيل المنتج">${escv(item.description||item.details||'')}</textarea>
      <label>صورة المنتج<input name="image" type="file" accept="image/*"></label>
      <div class="row-actions"><button type="button" data-alin-click="saveProduct">${editing?'حفظ التعديل':'إضافة المنتج'}</button><button type="button" class="secondary" data-alin-click="closeProductEditor">إلغاء</button></div>
    </form>`;
  }

  function ensureEditor(){
    let modal=document.getElementById('alinProductEditorModal');
    if(modal)return modal;
    modal=document.createElement('div');
    modal.id='alinProductEditorModal';
    modal.className='modal hidden';
    modal.innerHTML='<div class="modal-card"><button class="x" type="button" data-alin-click="closeProductEditor">×</button><div id="alinProductEditorBody"></div></div>';
    document.body.appendChild(modal);
    return modal;
  }

  function openProductEditor(id=''){
    const item=id?products().find(row=>String(row.id)===String(id)):{};
    if(id&&!item)return;
    const modal=ensureEditor();
    modal.querySelector('#alinProductEditorBody').innerHTML=`<h2>${id?'تعديل المنتج':'إضافة منتج جديد'}</h2>${productForm(item||{})}`;
    modal.classList.remove('hidden');
    modal.hidden=false;
  }

  function closeProductEditor(){
    const modal=document.getElementById('alinProductEditorModal');
    if(!modal)return;
    modal.classList.add('hidden');
    modal.hidden=true;
  }

  async function saveProduct(){
    const form=document.getElementById('alinProductEditorForm');
    if(!form)return;
    const data=new FormData(form);
    const id=String(form.dataset.id||'');
    const existing=id?products().find(item=>String(item.id)===id):null;
    const name=String(data.get('name')||'').trim();
    const type=normalizeType(data.get('type'));
    const category=String(data.get('category')||'عام').trim()||'عام';
    const categoryRow=categories().find(item=>normalizeType(item.type)===type&&String(item.name||'')===category)||null;
    const currentPrice=Number(data.get('currentPrice')||0);
    const previousPrice=Number(data.get('previousPrice')||0);
    const stock=Number(data.get('stock')||0);
    const lowStockLimit=Number(data.get('lowStockLimit')||5);
    const description=String(data.get('description')||'').trim();
    if(!name)return alert('اكتب اسم المنتج');
    if(!Number.isFinite(currentPrice)||currentPrice<0)return alert('السعر الحالي غير صحيح');
    if(previousPrice&&(!Number.isFinite(previousPrice)||previousPrice<=currentPrice))return alert('السعر السابق يجب أن يكون أعلى من السعر الحالي');
    if(!Number.isFinite(stock)||stock<0)return alert('المخزون غير صحيح');
    try{
      const imageFile=data.get('image');
      const uploaded=imageFile&&imageFile.name?await uploadImage(imageFile):'';
      const payload={
        name,title:name,type,category,category_id:categoryRow?.id||null,
        price:previousPrice>currentPrice?previousPrice:currentPrice,
        sale_price:previousPrice>currentPrice?currentPrice:null,stock,
        low_stock_limit:Math.max(0,lowStockLimit||0),description,details:description,
        status:existing?.status||'published',updated_at:new Date().toISOString()
      };
      if(uploaded)payload.image_path=uploaded;
      if(existing){
        await window.update('products',payload,{id});
        if(typeof window.audit==='function')await window.audit('product',`تعديل المنتج ${name}`);
      }else{
        payload.id=typeof window.uid==='function'?window.uid('PR'):`PR-${Date.now()}`;
        payload.created_at=new Date().toISOString();
        await window.insert('products',payload);
        if(typeof window.audit==='function')await window.audit('product',`إضافة المنتج ${name}`);
      }
      closeProductEditor();
      await reloadAndRender(renderProductsAdmin);
      if(typeof window.renderStore==='function')window.renderStore();
      if(typeof window.toast==='function')window.toast(existing?'تم تعديل المنتج':'تمت إضافة المنتج وظهر في المتجر');
    }catch(error){
      console.error('[ALIN products save]',error);
      alert(error?.message||'تعذر حفظ المنتج');
    }
  }

  async function setProductStatus(id,status){
    const item=products().find(row=>String(row.id)===String(id));
    if(!item)return;
    try{
      await window.update('products',{status,updated_at:new Date().toISOString()},{id:item.id});
      if(typeof window.audit==='function')await window.audit('product',`تغيير حالة المنتج ${item.name||item.id} إلى ${statusLabel(status)}`);
      await reloadAndRender(renderProductsAdmin);
      if(typeof window.renderStore==='function')window.renderStore();
      if(typeof window.toast==='function')window.toast(status==='published'?'تم إظهار المنتج':'تم إخفاء المنتج');
    }catch(error){alert(error?.message||'تعذر تغيير حالة المنتج')}
  }

  async function deleteProduct(id){
    const item=products().find(row=>String(row.id)===String(id));
    if(!item)return;
    const linked=linkedOrders(id);
    if(linked.length){
      if(confirm(`هذا المنتج مرتبط بـ ${linked.length} طلب ولا يمكن حذفه. هل تريد إخفاءه من المتجر؟`))await setProductStatus(id,'hidden');
      return;
    }
    if(!confirm(`حذف المنتج ${item.name||''} نهائيًا؟`))return;
    try{
      await window.removeRow('products',{id:item.id});
      if(typeof window.audit==='function')await window.audit('product',`حذف المنتج ${item.name||item.id}`);
      await reloadAndRender(renderProductsAdmin);
      if(typeof window.renderStore==='function')window.renderStore();
      if(typeof window.toast==='function')window.toast('تم حذف المنتج');
    }catch(error){alert(error?.message||'تعذر حذف المنتج')}
  }

  function productCard(item){
    const image=imageUrl(item);
    const status=String(item.status||'published');
    const stock=Number(item.stock||0);
    const low=lowStockLimit(item);
    const stockClass=stock<=0?'out':stock<=low?'low':'ok';
    const stockText=stock<=0?'نافد':stock<=low?'مخزون قليل':'متوفر';
    const currentPrice=Number(item.sale_price||item.deal_price||item.price||0),previousPrice=currentPrice<Number(item.price||0)?Number(item.price||0):0;
    return `<article class="admin-product-v129-card">
      <div class="admin-product-v129-image">${image?`<img src="${escv(image)}" alt="${escv(item.name||'منتج')}">`:`<span>${normalizeType(item.type)==='gift'?'🎁':'✏️'}</span>`}<em class="status ${escv(status)}">${statusLabel(status)}</em></div>
      <div class="admin-product-v129-body">
        <div class="admin-product-v129-title"><div><small>${typeLabel(item.type)} • ${escv(item.category||'عام')}</small><h3>${escv(item.name||item.title||'منتج')}</h3></div><div class="admin-product-price-pair"><strong>${moneyv(currentPrice)} د.ع</strong>${previousPrice?`<del>${moneyv(previousPrice)} د.ع</del>`:''}</div></div>
        <p>${escv(item.description||item.details||'')}</p>
        <div class="admin-product-v129-meta"><span class="stock ${stockClass}">${stockText}: ${moneyv(stock)}</span><span>الرمز: ${escv(item.id||'—')}</span></div>
        <div class="admin-product-v129-actions"><button type="button" class="secondary" data-alin-click="editProduct" data-alin-click-arg0="${escv(item.id)}">تعديل</button><button type="button" data-alin-click="setProductStatus" data-alin-click-arg0="${escv(item.id)}" data-alin-click-arg1="${status==='published'?'hidden':'published'}">${status==='published'?'إخفاء':'نشر'}</button><button type="button" class="danger" data-alin-click="deleteProduct" data-alin-click-arg0="${escv(item.id)}">حذف</button></div>
      </div>
    </article>`;
  }

  function renderProductsAdmin(){
    const container=root();if(!container)return;
    const list=filteredProducts();
    const all=products();
    const published=all.filter(item=>String(item.status||'published')==='published').length;
    const hidden=all.filter(item=>String(item.status)==='hidden').length;
    const low=all.filter(item=>Number(item.stock)>0&&Number(item.stock)<=lowStockLimit(item)).length;
    const out=all.filter(item=>Number(item.stock)<=0).length;
    container.innerHTML=`<section class="admin-products-v129">
      <header class="admin-products-v129-head"><div><h2>إدارة المنتجات</h2><p>إدارة القرطاسية والهدايا والمخزون من تنفيذ واحد مستقل عن platform.js.</p></div><button type="button" data-alin-click="addProduct">إضافة منتج</button></header>
      <section class="admin-products-v129-stats"><article><small>الإجمالي</small><strong>${all.length}</strong></article><article><small>المنشورة</small><strong>${published}</strong></article><article><small>المخفية</small><strong>${hidden}</strong></article><article class="warn"><small>قليل المخزون</small><strong>${low}</strong></article><article class="danger"><small>النافدة</small><strong>${out}</strong></article></section>
      <section class="admin-products-v129-tools"><input id="alinProductSearch" value="${escv(state.q)}" placeholder="بحث بالاسم أو القسم"><select id="alinProductFilterType"><option value="">كل الأنواع</option><option value="stationery" ${state.type==='stationery'?'selected':''}>قرطاسية</option><option value="gift" ${state.type==='gift'?'selected':''}>هدايا</option></select><select id="alinProductFilterStatus"><option value="">كل الحالات</option><option value="published" ${state.status==='published'?'selected':''}>منشور</option><option value="hidden" ${state.status==='hidden'?'selected':''}>مخفي</option></select><select id="alinProductFilterStock"><option value="">كل المخزون</option><option value="available" ${state.stock==='available'?'selected':''}>متوفر</option><option value="low" ${state.stock==='low'?'selected':''}>قليل</option><option value="out" ${state.stock==='out'?'selected':''}>نافد</option></select><select id="alinProductSort"><option value="newest" ${state.sort==='newest'?'selected':''}>الأحدث</option><option value="name" ${state.sort==='name'?'selected':''}>الاسم</option><option value="priceAsc" ${state.sort==='priceAsc'?'selected':''}>السعر تصاعدي</option><option value="priceDesc" ${state.sort==='priceDesc'?'selected':''}>السعر تنازلي</option><option value="stock" ${state.sort==='stock'?'selected':''}>الأقل مخزونًا</option></select></section>
      <section class="admin-products-v129-grid">${list.length?list.map(productCard).join(''):'<div class="empty">لا توجد منتجات مطابقة.</div>'}</section>
    </section>`;
    const bind=(id,key,event='change')=>document.getElementById(id)?.addEventListener(event,eventObject=>{state[key]=eventObject.target.value;renderProductsAdmin()});
    bind('alinProductSearch','q','input');bind('alinProductFilterType','type');bind('alinProductFilterStatus','status');bind('alinProductFilterStock','stock');bind('alinProductSort','sort');
  }

  function refreshProductCategories(){
    const type=document.getElementById('alinProductType')?.value||'stationery';
    const select=document.getElementById('alinProductCategory');
    if(!select)return;
    const previous=select.value;
    select.innerHTML=categoryOptions(type,previous);
  }

  function categoryAdminRows(){
    const rows=[...categories()].sort((a,b)=>Number(a.sort_order||0)-Number(b.sort_order||0)||String(a.name||'').localeCompare(String(b.name||''),'ar'));
    rows.push({id:'__deal__',type:'deal',name:'عروض',status:categoryVisible({id:'__deal__'})?'active':'inactive',sort_order:Number(window.db?.settings?.store_section_order_deal||4),virtual:true});
    return rows;
  }

  function categoryIconMarkupAdmin(item){
    const src=categoryIconUrl(item);
    if(src)return `<span class="admin-category-icon"><img src="${escv(src)}" alt=""></span>`;
    const fallback=normalizeType(item.type)==='booklet'?'📘':normalizeType(item.type)==='gift'?'🎁':normalizeType(item.type)==='deal'?'%':'✏️';
    return `<span class="admin-category-icon fallback">${fallback}</span>`;
  }

  function categoryRowHtml(item){
    const builtIn=Boolean(builtinCategoryKey(item))||item.virtual;
    const visible=categoryVisible(item);
    return `<article class="admin-category-card ${visible?'':'is-hidden'}">
      ${categoryIconMarkupAdmin(item)}
      <div class="admin-category-copy"><b>${escv(item.name)}</b><small>${escv(categoryTypeLabel(item.type))} • ترتيب ${Number(item.sort_order||0)}${builtIn?' • قسم رئيسي':' • قسم إضافي'}</small></div>
      <div class="row-actions"><button type="button" class="secondary" data-alin-click="editCategory" data-alin-click-arg0="${escv(item.id)}">تعديل</button><button type="button" data-alin-click="toggleCategory" data-alin-click-arg0="${escv(item.id)}" data-alin-click-arg1="${visible?'inactive':'active'}">${visible?'إخفاء':'إظهار'}</button>${builtIn?'':`<button type="button" class="danger" data-alin-click="deleteCategory" data-alin-click-arg0="${escv(item.id)}">حذف</button>`}</div>
    </article>`;
  }

  function renderCategoriesAdmin(){
    const container=root();if(!container)return;
    const rows=categoryAdminRows();
    container.innerHTML=`<section class="admin-categories admin-store-sections-v1">
      <header><div><h2>أقسام واجهة المتجر</h2><p>تحكم بالملازم والقرطاسية والهدايا والعروض، وأضف أقساماً جديدة مع أيقونة خاصة لكل قسم.</p></div></header>
      <form id="alinCategoryForm" class="form-grid admin-category-create">
        <select name="type"><option value="stationery">قرطاسية</option><option value="gift">هدايا</option><option value="booklet">ملازم</option></select>
        <input name="name" placeholder="اسم القسم الجديد" required>
        <input name="sortOrder" type="number" min="1" value="10" placeholder="ترتيب الظهور">
        <label class="admin-category-file">أيقونة القسم<input name="icon" type="file" accept="image/*"></label>
        <button type="button" data-alin-click="addCategory">إضافة القسم</button>
      </form>
      <div class="admin-category-note">القسم الجديد يظهر في واجهة المتجر، وعند الضغط عليه تفتح صفحة مستقلة تعرض المنتجات المطابقة له.</div>
      <div class="admin-category-list">${rows.length?rows.map(categoryRowHtml).join(''):'<div class="empty">لا توجد أقسام.</div>'}</div>
    </section>`;
  }

  async function addCategory(){
    const form=document.getElementById('alinCategoryForm');if(!form)return;
    const data=new FormData(form),name=String(data.get('name')||'').trim(),type=normalizeType(data.get('type'));
    const sortOrder=Math.max(1,Number(data.get('sortOrder')||10));
    if(!name)return alert('اكتب اسم القسم');
    if(categories().some(item=>normalizeType(item.type)===type&&String(item.name||'').trim().toLowerCase()===name.toLowerCase()))return alert('هذا القسم موجود مسبقًا');
    const id=typeof window.uid==='function'?window.uid('C'):`C-${Date.now()}`;
    try{
      await window.insert('categories',{id,type,name,status:'active',sort_order:sortOrder,created_at:new Date().toISOString()});
      const iconFile=data.get('icon');
      if(iconFile&&iconFile.name){const uploaded=await uploadImage(iconFile);if(uploaded)await saveSetting(`${CATEGORY_ICON_PREFIX}category:${id}`,uploaded)}
      await saveSetting(`${SECTION_VISIBLE_PREFIX}category:${id}`,'true');
      if(typeof window.audit==='function')await window.audit('category',`إضافة قسم واجهة المتجر ${name}`);
      await reloadAndRender(renderCategoriesAdmin);
      if(typeof window.renderStore==='function')window.renderStore();
      if(typeof window.toast==='function')window.toast('تمت إضافة القسم وأصبح جاهزاً في واجهة المتجر');
    }catch(error){console.error('[ALIN category add]',error);alert(error?.message||'تعذر إضافة القسم')}
  }

  function ensureCategoryEditor(){
    let modal=document.getElementById('alinCategoryEditorModal');
    if(modal)return modal;
    modal=document.createElement('div');modal.id='alinCategoryEditorModal';modal.className='modal hidden';
    modal.innerHTML='<div class="modal-card"><button class="x" type="button" data-alin-click="closeCategoryEditor">×</button><div id="alinCategoryEditorBody"></div></div>';
    document.body.appendChild(modal);return modal;
  }

  function closeCategoryEditor(){const modal=document.getElementById('alinCategoryEditorModal');if(modal){modal.classList.add('hidden');modal.hidden=true}}

  function editCategory(id){
    const item=id==='__deal__'?{id:'__deal__',type:'deal',name:'عروض',sort_order:Number(window.db?.settings?.store_section_order_deal||4),virtual:true}:categories().find(row=>String(row.id)===String(id));
    if(!item)return;
    const builtIn=Boolean(builtinCategoryKey(item))||item.virtual;
    const modal=ensureCategoryEditor();
    modal.querySelector('#alinCategoryEditorBody').innerHTML=`<h2>تعديل قسم ${escv(item.name)}</h2><form id="alinCategoryEditForm" class="form-grid" data-id="${escv(item.id)}">
      ${builtIn?`<div class="admin-category-locked"><small>اسم القسم الرئيسي</small><b>${escv(item.name)}</b></div>`:`<select name="type"><option value="stationery" ${normalizeType(item.type)==='stationery'?'selected':''}>قرطاسية</option><option value="gift" ${normalizeType(item.type)==='gift'?'selected':''}>هدايا</option><option value="booklet" ${normalizeType(item.type)==='booklet'?'selected':''}>ملازم</option></select><input name="name" value="${escv(item.name||'')}" placeholder="اسم القسم" required>`}
      <input name="sortOrder" type="number" min="1" value="${Number(item.sort_order||1)}" placeholder="ترتيب الظهور">
      <label>تغيير الأيقونة<input name="icon" type="file" accept="image/*"></label>
      ${categoryIconUrl(item)?`<div class="admin-category-current-icon">${categoryIconMarkupAdmin(item)}<small>الأيقونة الحالية</small></div>`:''}
      <div class="row-actions"><button type="button" data-alin-click="saveCategoryEdit">حفظ التعديل</button><button type="button" class="secondary" data-alin-click="closeCategoryEditor">إلغاء</button></div>
    </form>`;
    modal.classList.remove('hidden');modal.hidden=false;
  }

  async function saveCategoryEdit(){
    const form=document.getElementById('alinCategoryEditForm');if(!form)return;
    const data=new FormData(form),id=String(form.dataset.id||'');
    const virtual=id==='__deal__';
    const item=virtual?{id:'__deal__',type:'deal',name:'عروض',virtual:true}:categories().find(row=>String(row.id)===id);
    if(!item)return;
    const builtIn=Boolean(builtinCategoryKey(item))||virtual;
    const name=builtIn?item.name:String(data.get('name')||'').trim();
    const type=builtIn?normalizeType(item.type):normalizeType(data.get('type'));
    const sortOrder=Math.max(1,Number(data.get('sortOrder')||item.sort_order||1));
    if(!name)return alert('اكتب اسم القسم');
    try{
      if(virtual)await saveSetting('store_section_order_deal',String(sortOrder));
      else{
        const oldName=item.name;
        await window.update('categories',{name,type,sort_order:sortOrder,updated_at:new Date().toISOString()},{id});
        if(!builtIn&&oldName!==name){
          const linked=products().filter(product=>String(product.category_id||'')===id||String(product.category||'')===String(oldName||''));
          for(const product of linked)await window.update('products',{category:name,type:normalizeType(product.type||type),updated_at:new Date().toISOString()},{id:product.id});
        }
      }
      const iconFile=data.get('icon');
      if(iconFile&&iconFile.name){const uploaded=await uploadImage(iconFile);if(uploaded)await saveSetting(categoryIconKey(item),uploaded)}
      if(typeof window.audit==='function')await window.audit('category',`تعديل قسم واجهة المتجر ${name}`);
      closeCategoryEditor();await reloadAndRender(renderCategoriesAdmin);if(typeof window.renderStore==='function')window.renderStore();
      if(typeof window.toast==='function')window.toast('تم تحديث القسم');
    }catch(error){console.error('[ALIN category edit]',error);alert(error?.message||'تعذر تعديل القسم')}
  }

  async function toggleCategory(id,status){
    const virtual=id==='__deal__';
    const item=virtual?{id:'__deal__',type:'deal',name:'عروض',virtual:true}:categories().find(row=>String(row.id)===String(id));
    if(!item)return;
    const visible=status==='active';
    try{
      if(!virtual)await window.update('categories',{status:visible?'active':'inactive',updated_at:new Date().toISOString()},{id});
      await saveSetting(`${SECTION_VISIBLE_PREFIX}${categorySectionKey(item)}`,String(visible));
      await reloadAndRender(renderCategoriesAdmin);if(typeof window.renderStore==='function')window.renderStore();
      if(typeof window.toast==='function')window.toast(visible?'تم إظهار القسم في المتجر':'تم إخفاء القسم من المتجر');
    }catch(error){console.error('[ALIN category toggle]',error);alert(error?.message||'تعذر تغيير حالة القسم')}
  }

  async function deleteCategory(id){
    const item=categories().find(row=>String(row.id)===String(id));if(!item)return;
    if(builtinCategoryKey(item))return alert('القسم الرئيسي لا يُحذف، يمكنك إخفاؤه فقط.');
    const linked=products().filter(product=>String(product.category_id||'')===String(item.id)||String(product.category||'')===String(item.name||''));
    if(linked.length)return alert(`لا يمكن حذف القسم لأنه مرتبط بـ ${linked.length} منتج. أخفِ القسم بدلًا من حذفه.`);
    if(!confirm(`حذف القسم ${item.name||''}؟`))return;
    try{
      await window.removeRow('categories',{id:item.id});
      await saveSetting(categoryIconKey(item),'');await saveSetting(`${SECTION_VISIBLE_PREFIX}${categorySectionKey(item)}`,'false');
      if(typeof window.audit==='function')await window.audit('category',`حذف القسم ${item.name||item.id}`);
      await reloadAndRender(renderCategoriesAdmin);if(typeof window.renderStore==='function')window.renderStore();
      if(typeof window.toast==='function')window.toast('تم حذف القسم');
    }catch(error){alert(error?.message||'تعذر حذف القسم')}
  }

  window.renderProductsAdmin=renderProductsAdmin;
  window.renderCategoriesAdmin=renderCategoriesAdmin;
  window.refreshProductCategories=refreshProductCategories;
  window.addProduct=()=>openProductEditor('');
  window.editProduct=openProductEditor;
  window.saveProduct=saveProduct;
  window.closeProductEditor=closeProductEditor;
  window.setProductStatus=setProductStatus;
  window.deleteProduct=deleteProduct;
  window.addCategory=addCategory;
  window.editCategory=editCategory;
  window.saveCategoryEdit=saveCategoryEdit;
  window.closeCategoryEditor=closeCategoryEditor;
  window.toggleCategory=toggleCategory;
  window.deleteCategory=deleteCategory;
  // Compatibility aliases point to the same implementation, not wrappers.
  window.alinV73AddProduct=window.addProduct;
  window.alinV73EditProduct=window.editProduct;
  window.alinV73DeleteProduct=window.deleteProduct;
  window.alinV79ToggleProduct=id=>{const item=products().find(row=>String(row.id)===String(id));return item?setProductStatus(id,String(item.status||'published')==='published'?'hidden':'published'):undefined};
  window.AlinAdminModules?.register?.('products',renderProductsAdmin);
  window.AlinAdminModules?.register?.('categories',renderCategoriesAdmin);
})();
;

/* modules/admin/accounts-advanced.js */
// === admin/accounts-advanced.js ===
/* ===== admin/js/admin-accounts-v133.js ===== */

(function(){
  'use strict';
  const escx=v=>typeof esc==='function'?esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const arr=v=>Array.isArray(v)?v:[];
  const roleLabel={teacher:'مدرس',library:'مكتبة',courier:'مندوب',accountant:'محاسب',admin:'مدير'};
  const permissionLabels={dashboard:'الرئيسية',orders:'الطلبات',booklets:'الملازم',products:'المنتجات',accounts:'الحسابات',finance:'المالية',settlements:'التسويات',reports:'التقارير',notifications:'الإشعارات',settings:'الإعدادات'};
  const canEditPermissions=()=>window.current?.admin_level==='super_admin';
  let editingId=null;

  function parseAreas(v){return window.AlinCourierAreas?.parse?.(v)||[]}
  function areaList(){return window.AlinCourierAreas?.list?.()||[]}
  function accountAreas(x){return window.AlinCourierAreas?.forAccount?.(x)||parseAreas(x?.areas||x?.area)}
  function allAccounts(){
    const canonical=arr(window.db?.accounts?.all);
    const courierRows=arr(window.db?.couriers||window.db?.accounts?.couriers);
    if(canonical.length){
      const couriersById=new Map(courierRows.map(x=>[String(x.id),x]));
      return canonical.map(x=>{
        if(x.role!=='courier')return {...x};
        const courier=couriersById.get(String(x.id))||{};
        return {...x,...courier,id:x.id,role:'courier',auth_user_id:x.auth_user_id,status:x.status||courier.status};
      });
    }
    const teachers=arr(window.db?.accounts?.teachers).map(x=>({...x,role:'teacher'}));
    const libraries=arr(window.db?.accounts?.libraries).map(x=>({...x,role:'library'}));
    const couriers=courierRows.map(x=>({...x,role:'courier'}));
    const accountants=arr(window.db?.accounts?.accountants).map(x=>({...x,role:'accountant'}));
    return [...teachers,...libraries,...couriers,...accountants];
  }
  function account(id){return allAccounts().find(x=>String(x.id)===String(id))}
  function ordersFor(x){return arr(window.db?.orders).filter(o=>String(o.teacher_id||'')===String(x.id)||String(o.library_id||o.pickup_library_id||'')===String(x.id)||String(o.courier_id||o.delegate_id||'')===String(x.id))}
  function settlementsFor(x){return arr(window.db?.settlements).filter(s=>String(s.party_id||'')===String(x.id))}
  function permsFor(x){const rows=arr(window.db?.accountPermissions).filter(row=>String(row.account_id)===String(x.id)&&row.granted!==false).map(row=>row.permission);return rows.length?rows:defaultPerms(x.role)}
  function defaultPerms(role){if(role==='teacher')return ['dashboard','booklets','orders','finance'];if(role==='library')return ['dashboard','orders','finance','settlements','notifications'];if(role==='courier')return ['dashboard','orders','finance','settlements'];return ['dashboard']}
  function history(id){return arr(window.db?.audit).filter(row=>String(row.entity_id||row.meta?.account_id||'')===String(id)).slice(0,80).map(row=>({at:row.created_at,action:row.summary||row.action,details:row.meta?.details||'',by:row.actor_account_id||row.actor_role||'النظام'}))}
  function log(id,action,details=''){if(typeof window.audit==='function')Promise.resolve(window.audit('account_activity',action,{entity_type:'accounts',entity_id:String(id),details})).catch(()=>{})}
  function strongPassword(value){return String(value||'').length>=12&&/[A-Za-z؀-ۿ]/.test(value)&&/[0-9]/.test(value)}
  function areaPicker(x){
    const selected=new Set(accountAreas(x));
    const names=[...new Set([...areaList(),...selected])].sort((a,b)=>a.localeCompare(b,'ar'));
    return `<section id="v132CourierFields" class="v132-courier-fields" ${x.role==='courier'?'':'hidden'}>
      <div class="v163-area-toolbar"><div><h4>مناطق عمل المندوب</h4><small>يمكن تحديد أكثر من منطقة ويظهر المندوب فقط للطلبات المطابقة.</small></div><div><button type="button" class="secondary" data-alin-click="v132CourierAreasSelectAll">تحديد الكل</button><button type="button" class="secondary" data-alin-click="v132CourierAreasClear">إلغاء التحديد</button></div></div>
      <div id="v132CourierAreaPicker" class="v163-area-picker">${names.map(name=>`<label><input type="checkbox" value="${escx(name)}" ${selected.has(name)?'checked':''} data-alin-change="v132CourierAreaCount"><span>${escx(name)}</span></label>`).join('')}</div>
      <div class="v132-courier-meta"><label>حالة توفر المندوب<select id="v132Availability"><option value="available" ${String(x.availability||'available')==='available'?'selected':''}>متاح</option><option value="busy" ${String(x.availability||'')==='busy'?'selected':''}>مشغول</option><option value="offline" ${String(x.availability||'')==='offline'?'selected':''}>غير متصل</option></select></label><p><b id="v132CourierAreaCount">${selected.size}</b> منطقة محددة</p></div>
    </section>`;
  }
  function renderEditor(x){
    const host=document.getElementById('v132AccountEditorHost');if(!host)return;
    const os=ordersFor(x),ss=settlementsFor(x),perms=permsFor(x),role=x.role||'teacher',linked=Boolean(x.auth_user_id);
    host.innerHTML=`<section class="v132-account-editor"><header class="v132-editor-head"><div><h3>تعديل حساب ${escx(x.name||'')}</h3><p>${linked?'الحساب مربوط بخدمة الدخول ويمكن تحديث بياناته وكلمة مروره.':'الحساب قديم وغير مربوط؛ تعيين كلمة مرور جديدة يربطه تلقائياً.'}</p></div><span class="v131-status ${linked?'active':'pending'}">${linked?'مربوط':'يحتاج ربط'}</span><button type="button" class="v132-editor-close" data-alin-click="v132CloseAccountEditor">إغلاق</button></header><div class="v132-account-form"><label>نوع الحساب<select id="v132Role" data-alin-change="v132SyncRoleFields"><option value="teacher" ${role==='teacher'?'selected':''}>مدرس</option><option value="library" ${role==='library'?'selected':''}>مكتبة</option><option value="courier" ${role==='courier'?'selected':''}>مندوب</option></select></label><label class="span-2">الاسم الكامل<input id="v132Name" value="${escx(x.name||'')}"></label><label>الحالة<select id="v132Status"><option value="active" ${String(x.status||'active')==='active'?'selected':''}>فعال</option><option value="inactive" ${String(x.status||'')==='inactive'?'selected':''}>موقوف</option><option value="pending" ${String(x.status||'')==='pending'?'selected':''}>قيد المراجعة</option></select></label><label>اسم الدخول<input id="v132Username" value="${escx(x.username||'')}"></label><label>رقم الهاتف<input id="v132Phone" value="${escx(x.phone||x.mobile||'')}"></label><label id="v132AreaLabel">المنطقة<input id="v132Area" value="${escx(x.area||'')}"></label><label id="v132LandmarkLabel">أقرب نقطة دالة<input id="v132Landmark" value="${escx(x.landmark||'')}"></label>${areaPicker(x)}<label class="span-4">ملاحظات الحساب<textarea id="v132Notes">${escx(x.notes||'')}</textarea></label><section class="v132-password-box"><h4>${linked?'إعادة تعيين كلمة المرور':'ربط الحساب وتعيين كلمة المرور'}</h4><div class="v132-password-row"><input id="v132NewPassword" type="password" placeholder="اكتب كلمة مرور من 12 حرفاً تتضمن حروفاً وأرقاماً"><button data-alin-click="v132ResetPassword">${linked?'تغيير كلمة المرور':'ربط وحفظ'}</button></div></section><section class="v132-permissions"><h4>الصلاحيات</h4><div class="v132-permission-grid">${Object.entries(permissionLabels).map(([k,v])=>`<label><input type="checkbox" data-v132-permission="${k}" ${perms.includes(k)?'checked':''} ${canEditPermissions()?'':'disabled'}>${v}</label>`).join('')}</div></section><section class="v132-link-summary"><article><small>الطلبات المرتبطة</small><b>${os.length}</b></article><article><small>التسويات المرتبطة</small><b>${ss.length}</b></article><article><small>سجل النشاط</small><b>${history(x.id).length}</b></article></section><div class="v132-form-actions"><button type="button" class="secondary" data-alin-click="v132OpenActivity" data-alin-click-arg0="${escx(x.id)}">سجل النشاط</button><button type="button" class="v132-save" data-alin-click="v132SaveAccount">حفظ التعديلات</button></div></div></section>`;
    window.v132SyncRoleFields();
    host.scrollIntoView({behavior:'smooth',block:'start'});
  }

  window.v132SyncRoleFields=()=>{
    const courier=document.getElementById('v132Role')?.value==='courier';
    const fields=document.getElementById('v132CourierFields');if(fields)fields.hidden=!courier;
    const area=document.getElementById('v132AreaLabel'),landmark=document.getElementById('v132LandmarkLabel');
    if(area)area.hidden=courier;if(landmark)landmark.hidden=courier;
    window.v132CourierAreaCount();
  };
  window.v132CourierAreaCount=()=>{const count=document.querySelectorAll('#v132CourierAreaPicker input:checked').length;const el=document.getElementById('v132CourierAreaCount');if(el)el.textContent=String(count);return count};
  window.v132CourierAreasSelectAll=()=>{document.querySelectorAll('#v132CourierAreaPicker input').forEach(x=>x.checked=true);window.v132CourierAreaCount()};
  window.v132CourierAreasClear=()=>{document.querySelectorAll('#v132CourierAreaPicker input').forEach(x=>x.checked=false);window.v132CourierAreaCount()};
  window.v132OpenAccountEditor=id=>{const x=account(id);if(!x)return alert('تعذر العثور على الحساب');editingId=id;renderEditor(x)};
  window.v132CloseAccountEditor=()=>{editingId=null;const h=document.getElementById('v132AccountEditorHost');if(h)h.innerHTML=''};
  window.v132SaveAccount=async()=>{
    const x=account(editingId);if(!x)return alert('تعذر العثور على الحساب');
    const button=document.querySelector('#v132AccountEditorHost .v132-save');
    if(button?.disabled)return;
    const originalLabel=button?.textContent||'حفظ التعديلات';
    const role=document.getElementById('v132Role')?.value||x.role;
    const typedPassword=document.getElementById('v132NewPassword')?.value.trim()||'';
    const selectedAreas=[...document.querySelectorAll('#v132CourierAreaPicker input:checked')].map(el=>String(el.value||'').trim()).filter(Boolean);
    const payload={account_id:x.id,role,name:document.getElementById('v132Name')?.value.trim()||'',username:document.getElementById('v132Username')?.value.trim()||'',status:document.getElementById('v132Status')?.value||'active',phone:document.getElementById('v132Phone')?.value.trim()||'',area:role==='courier'?(selectedAreas[0]||''):(document.getElementById('v132Area')?.value.trim()||''),areas:role==='courier'?selectedAreas:undefined,availability:role==='courier'?(document.getElementById('v132Availability')?.value||'available'):undefined,landmark:role==='courier'?'':(document.getElementById('v132Landmark')?.value.trim()||''),notes:document.getElementById('v132Notes')?.value.trim()||'',password:typedPassword||undefined};
    if(!payload.name||!payload.username)return alert('أكمل الاسم واسم الدخول');
    if(role==='courier'&&!selectedAreas.length)return alert('اختر منطقة عمل واحدة على الأقل للمندوب');
    if(role==='courier'&&!payload.phone)return alert('أدخل رقم هاتف المندوب');
    if(typedPassword&&!strongPassword(typedPassword))return alert('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');
    try{
      if(button){button.disabled=true;button.textContent='جارٍ الحفظ...'}
      if(!window.ALINAuth?.updateAccountFromAdmin)throw new Error('خدمة تعديل الحساب الآمن غير جاهزة');
      const saved=await window.ALINAuth.updateAccountFromAdmin(payload);
      if(!saved)throw new Error('لم ترجع خدمة الحسابات نتيجة الحفظ');
      let permissionWarning='';
      if(canEditPermissions()){
        try{
          const perms=[...document.querySelectorAll('[data-v132-permission]:checked')].map(el=>el.dataset.v132Permission);
          const client=window.sb||window.AlinCloud?.client?.();
          if(client?.rpc){const {error:permError}=await client.rpc('alin_admin_set_account_permissions',{p_account_id:String(x.id),p_permissions:perms});if(permError)throw permError}
          else permissionWarning='تعذر تحديث الصلاحيات فقط';
        }catch(permissionError){
          permissionWarning='تم حفظ بيانات الحساب، لكن تعذر تحديث الصلاحيات';
          console.warn('[ALIN account permissions]',permissionError);
        }
      }
      log(x.id,'تعديل الحساب',role==='courier'?`تم تحديث البيانات ومناطق العمل: ${selectedAreas.join('، ')}`:'تم تحديث بيانات الحساب');
      try{if(typeof audit==='function')await audit('account','تعديل آمن لحساب '+x.id)}catch(auditError){console.warn('[ALIN account audit]',auditError)}
      try{if(typeof load==='function')await load()}catch(loadError){console.warn('[ALIN account refresh]',loadError)}
      editingId=null;
      if(typeof renderAccountsAdmin==='function')renderAccountsAdmin();
      const saveWarning=String(saved?.warning||'').trim();
      const warnings=[saveWarning,permissionWarning].filter(Boolean);
      const message=warnings.length?warnings.join(' — '):(role==='courier'?'تم حفظ حساب المندوب ومناطق عمله':'تم حفظ تعديلات الحساب');
      if(typeof toast==='function')toast(message);else alert(message);
    }catch(e){alert('تعذر حفظ الحساب: '+(e?.message||'خطأ غير معروف'))}
    finally{if(button){button.disabled=false;button.textContent=originalLabel}}
  };
  window.v132ResetPassword=async()=>{const x=account(editingId),pass=document.getElementById('v132NewPassword')?.value.trim();if(!x||!pass)return alert('اكتب كلمة المرور الجديدة');if(!strongPassword(pass))return alert('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');try{if(!window.ALINAuth?.resetPasswordFromAdmin)throw new Error('خدمة تغيير كلمة المرور غير متاحة');await window.ALINAuth.resetPasswordFromAdmin(x.id,pass);log(x.id,x.auth_user_id?'إعادة تعيين كلمة المرور':'ربط الحساب الموجود وتعيين كلمة المرور');if(typeof audit==='function')await audit('account','تحديث كلمة مرور '+x.id);if(typeof load==='function')await load();if(typeof renderAccountsAdmin==='function')renderAccountsAdmin();if(typeof toast==='function')toast('تم تغيير كلمة المرور وربط الحساب بنجاح')}catch(e){alert('تعذر تغيير كلمة المرور: '+e.message)}};
  window.v132ToggleAccount=async(id,status)=>{const x=account(id);if(!x)return;try{if(!window.ALINAuth?.updateAccountFromAdmin)throw new Error('خدمة تحديث الحساب الآمنة غير جاهزة');await window.ALINAuth.updateAccountFromAdmin({account_id:id,status});log(id,status==='active'?'تفعيل الحساب':'إيقاف الحساب');if(typeof audit==='function')await audit('account',(status==='active'?'تفعيل ':'إيقاف ')+id);if(typeof load==='function')await load();if(typeof renderAccountsAdmin==='function')renderAccountsAdmin();if(typeof toast==='function')toast(status==='active'?'تم تفعيل الحساب':'تم إيقاف الحساب')}catch(e){alert('تعذر تحديث الحالة: '+e.message)}};
  window.v132SafeDeleteAccount=async id=>{const x=account(id);if(!x)return;const os=ordersFor(x),ss=settlementsFor(x);const details=os.length||ss.length?`\nسيبقى مرتبطاً بـ ${os.length} طلب و${ss.length} تسوية محفوظة.`:'';if(!confirm(`أرشفة الحساب وإيقاف دخوله؟${details}\nلن تُحذف طلباته أو حساباته القديمة.`))return;try{if(!window.ALINAuth?.deleteAccountFromAdmin)throw new Error('خدمة أرشفة الحساب الآمنة غير جاهزة');await window.ALINAuth.deleteAccountFromAdmin(id);log(id,'أرشفة الحساب');if(typeof audit==='function')await audit('account','أرشفة حساب '+id);if(typeof load==='function')await load();if(typeof renderAccountsAdmin==='function')renderAccountsAdmin();if(typeof toast==='function')toast('تمت أرشفة الحساب وإيقاف دخوله')}catch(e){alert('تعذر أرشفة الحساب: '+e.message)}};
  window.v132OpenActivity=id=>{const x=account(id);if(!x)return;const rows=history(id);const host=document.getElementById('v132AccountEditorHost');if(!host)return;host.innerHTML=`<section class="v132-account-editor"><header class="v132-editor-head"><div><h3>سجل نشاط ${escx(x.name||'')}</h3><p>آخر التعديلات والإجراءات المسجلة على الحساب.</p></div><button type="button" class="v132-editor-close" data-alin-click="v132CloseAccountEditor">إغلاق</button></header><div class="v132-activity">${rows.map(r=>`<article><b>${escx(r.action)}</b><small>${new Date(r.at).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')} — ${escx(r.by||'المدير')}${r.details?' — '+escx(r.details):''}</small></article>`).join('')||'<div class="v132-warning">لا يوجد نشاط مسجل لهذا الحساب بعد.</div>'}</div></section>`;host.scrollIntoView({behavior:'smooth',block:'start'})};
})();

;
;

/* modules/admin/finance.js */
// === admin/finance.js ===
/* ALIN v2.2.6 — authoritative admin finance UI. No wrapper chains. */
(function(){
  'use strict';
  const arr=value=>Array.isArray(value)?value:[];
  const num=value=>Number.isFinite(Number(value))?Number(value):0;
  const escv=value=>typeof window.esc==='function'?window.esc(value):String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const moneyv=value=>typeof window.money==='function'?window.money(value):Math.round(num(value)).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const finance=()=>window.AlinFinance;
  const database=()=>window.db||{};

  function parties(){
    const accounts=database().accounts||{};
    return [
      {role:'admin',id:'admin',name:'منصة آلين',label:'ربح المنصة'},
      ...arr(accounts.teachers).map(row=>({role:'teacher',id:row.id,name:row.name,label:'مدرس'})),
      ...arr(accounts.libraries).map(row=>({role:'library',id:row.id,name:row.name,label:'مكتبة'})),
      ...arr(database().delegates||accounts.couriers||database().couriers).map(row=>({role:'delegate',id:row.id,name:row.name,label:'مندوب'}))
    ];
  }

  function totals(){
    return (finance()?.canonicalLedger?.()||[]).reduce((out,row)=>{
      out.sales+=num(row.total);out.admin+=num(row.admin||row.alin);out.teacher+=num(row.teacher);out.library+=num(row.library);out.delegate+=num(row.delegate||row.courier);return out;
    },{sales:0,admin:0,teacher:0,library:0,delegate:0});
  }

  function balanceCards(){
    return parties().map(p=>{
      const summary=finance()?.partySummary?.(p.role,p.id)||{earned:0,paid:0,remaining:0};
      const libraryDebt=p.role==='library'?(summary.debt||finance()?.librarySummary?.(p.id)):null;
      const delegateDebt=['delegate','courier'].includes(String(p.role||'').toLowerCase())?(finance()?.delegateSummary?.(p.id)||summary):null;
      const payoutRole=['admin','teacher'].includes(p.role);
      return `<article class="admin-v137-party-card" data-role="${escv(p.role)}" data-search="${escv(`${p.name||''} ${p.label}`.toLowerCase())}">
        <div><b>${escv(p.name||p.label)}</b><small>${escv(p.label)} — الإجمالي ${moneyv(summary.earned||summary.earnings)} د.ع</small></div>
        ${payoutRole?`<div class="admin-v137-party-values"><span>المسدد <b>${moneyv(summary.paid)}</b></span><span class="remain">المتبقي <b>${moneyv(summary.remaining)}</b></span>${summary.remaining>0?`<button data-alin-click="AlinFinance.payBalance" data-alin-click-arg0="${escv(p.role)}" data-alin-click-arg1="${escv(p.id)}">${p.role==='admin'?'استلام الربح':'تسديد الأرباح'}</button>`:'<em>مصفّى</em>'}</div>`:''}
        ${libraryDebt?`<div class="admin-v223-library-debt"><span>ربح المكتبة <b>${moneyv(libraryDebt.libraryProfit)} د.ع</b> • ذمتها للإدارة <b>${moneyv(libraryDebt.remaining)} د.ع</b></span>${libraryDebt.remaining>0?`<button class="secondary" data-alin-click="AlinFinance.settleLibrary" data-alin-click-arg0="${escv(p.id)}">تثبيت التسوية</button>`:'<em>الذمة مصفّاة</em>'}</div>`:''}
        ${delegateDebt?`<div class="admin-v223-library-debt"><span>ربح المندوب <b>${moneyv(delegateDebt.earnings||delegateDebt.earned)} د.ع</b> • ذمته للإدارة <b>${moneyv(delegateDebt.debt||delegateDebt.remaining)} د.ع</b></span>${(delegateDebt.debt||delegateDebt.remaining)>0?`<button class="secondary" data-alin-click="AlinFinance.settleDelegate" data-alin-click-arg0="${escv(p.id)}">تثبيت تسوية المندوب</button>`:'<em>الذمة مصفّاة</em>'}</div>`:''}
      </article>`;
    }).join('');
  }

  function withdrawals(){
    const rows=arr(database().withdrawals).slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||'')));
    return rows.map(row=>`<div class="admin-v137-finance-row"><div><b>${escv(row.role||'حساب')} — ${moneyv(row.amount)} د.ع</b><small>${escv(row.account_id||'')} • ${escv(String(row.created_at||'').slice(0,10))}</small></div><div class="row-actions"><span>${escv(row.status||'pending')}</span>${row.status==='pending'?`<button data-alin-click="withdrawStatus" data-alin-click-arg0="${escv(row.id)}" data-alin-click-arg1="approved">موافقة</button><button data-alin-click="withdrawStatus" data-alin-click-arg0="${escv(row.id)}" data-alin-click-arg1="paid">دفع</button><button class="danger" data-alin-click="withdrawStatus" data-alin-click-arg0="${escv(row.id)}" data-alin-click-arg1="rejected">رفض</button>`:''}</div></div>`).join('')||'<div class="empty">لا توجد طلبات سحب.</div>';
  }

  function settlementRows(){
    const rows=arr(database().settlements).slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||'')));
    return rows.map(row=>{
      const role=String(row.party_role||'').toLowerCase().replace('courier','delegate');
      const name=finance()?.partyName?.(role,row.party_id)||role||'حساب';
      return `<div class="admin-v137-finance-row"><div><b>${escv(name)}</b><small>${escv(row.receipt_number||row.id||'')} • ${escv(String(row.created_at||'').slice(0,10))} • ${escv(row.payment_method||'نقدي')}</small></div><div><strong>${moneyv(row.amount)} د.ع</strong><span>${escv(row.status||'')}</span></div></div>`;
    }).join('')||'<div class="empty">لا توجد سندات أو تسويات.</div>';
  }

  function ledgerRows(){
    const rows=finance()?.canonicalLedger?.()||[];
    return rows.slice().sort((a,b)=>String(b.settled_at||b.created_at||'').localeCompare(String(a.settled_at||a.created_at||''))).map(row=>`<div class="admin-v137-finance-row"><div><b>${escv(row.order_number||row.order_id)}</b><small>منصة ${moneyv(row.admin||row.alin)} • مدرس ${moneyv(row.teacher)} • مكتبة ${moneyv(row.library)} • مندوب ${moneyv(row.delegate||row.courier)}</small></div><span>${moneyv(row.total)} د.ع</span></div>`).join('')||'<div class="empty">لا توجد طلبات مسلّمة محتسبة.</div>';
  }

  function renderFinanceAdmin(){
    const root=document.getElementById('adminContent');if(!root)return false;
    const t=totals();
    const libraryDebt=arr(database().accounts?.libraries).reduce((sum,row)=>sum+num(finance()?.librarySummary?.(row.id)?.remaining),0);
    const delegateDebt=arr(database().delegates||database().accounts?.couriers||database().couriers).reduce((sum,row)=>sum+num(finance()?.delegateSummary?.(row.id)?.debt),0);
    const debt=libraryDebt+delegateDebt;
    root.innerHTML=`<section class="admin-v137-finance">
      <header class="admin-v137-finance-head"><div><h2>المالية والتسويات</h2><p>مسار مالي واحد للطلبات المسلّمة، الأرباح، ذمم المكتبات وسندات التسديد.</p></div><span class="admin-v137-finance-date">${new Date().toLocaleDateString(window.AlinI18n?.locale?.()||'ar-IQ')}</span></header>
      <section class="admin-v137-finance-metrics">
        <article class="admin-v137-finance-metric gold"><small>المبيعات المسلّمة</small><strong>${moneyv(t.sales)} د.ع</strong></article>
        <article class="admin-v137-finance-metric green"><small>ربح المنصة</small><strong>${moneyv(t.admin)} د.ع</strong></article>
        <article class="admin-v137-finance-metric"><small>أرباح المدرسين</small><strong>${moneyv(t.teacher)} د.ع</strong></article>
        <article class="admin-v137-finance-metric"><small>أرباح المكتبات</small><strong>${moneyv(t.library)} د.ع</strong></article>
        <article class="admin-v137-finance-metric"><small>أرباح المندوبين</small><strong>${moneyv(t.delegate)} د.ع</strong></article>
        <article class="admin-v137-finance-metric red"><small>ذمم المكتبات والمندوبين</small><strong>${moneyv(debt)} د.ع</strong></article>
      </section>
      <nav class="admin-v137-finance-tabs"><button class="active" data-finance-tab="balances">الأرصدة</button><button data-finance-tab="ledger">القيود</button><button data-finance-tab="settlements">السندات والتسويات</button><button data-finance-tab="withdrawals">طلبات السحب</button></nav>
      <section data-finance-panel="balances"><div class="admin-v137-finance-panel"><div class="admin-v137-finance-search"><input id="financeSearch" placeholder="ابحث باسم الحساب"><select id="financeRole"><option value="">كل الحسابات</option><option value="teacher">المدرسون</option><option value="library">المكتبات</option><option value="delegate">المندوبون</option><option value="admin">المنصة</option></select></div><div id="financeBalances" class="admin-v137-finance-list">${balanceCards()}</div></div></section>
      <section data-finance-panel="ledger" hidden><div class="admin-v137-finance-panel"><div class="row-actions"><button data-alin-click="AlinAdminFinance.exportLedger">تصدير CSV</button></div>${ledgerRows()}</div></section>
      <section data-finance-panel="settlements" hidden><div class="admin-v137-finance-panel">${settlementRows()}</div></section>
      <section data-finance-panel="withdrawals" hidden><div class="admin-v137-finance-panel">${withdrawals()}</div></section>
    </section>`;
    bind();return true;
  }

  function bind(){
    const tabs=[...document.querySelectorAll('[data-finance-tab]')];
    tabs.forEach(button=>button.addEventListener('click',()=>{
      tabs.forEach(item=>item.classList.toggle('active',item===button));
      document.querySelectorAll('[data-finance-panel]').forEach(panel=>panel.hidden=panel.dataset.financePanel!==button.dataset.financeTab);
    }));
    const filter=()=>{
      const q=(document.getElementById('financeSearch')?.value||'').trim().toLowerCase();
      const role=document.getElementById('financeRole')?.value||'';
      document.querySelectorAll('#financeBalances .admin-v137-party-card').forEach(card=>card.hidden=!((!q||card.dataset.search.includes(q))&&(!role||card.dataset.role===role)));
    };
    document.getElementById('financeSearch')?.addEventListener('input',filter);
    document.getElementById('financeRole')?.addEventListener('change',filter);
  }

  function csvEscape(value){return `"${String(value??'').replace(/"/g,'""')}"`}
  function exportLedger(){
    const rows=finance()?.canonicalLedger?.()||[];
    const csv='\ufeff'+[['الطلب','الإجمالي','المنصة','المدرس','المكتبة','المندوب','التاريخ'],...rows.map(row=>[row.order_number||row.order_id,row.total,row.admin||row.alin,row.teacher,row.library,row.delegate||row.courier,row.settled_at||row.created_at])].map(row=>row.map(csvEscape).join(',')).join('\n');
    const link=document.createElement('a');link.href=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));link.download=`alin-finance-${new Date().toISOString().slice(0,10)}.csv`;link.click();setTimeout(()=>URL.revokeObjectURL(link.href),1000);
  }

  window.renderFinanceAdmin=renderFinanceAdmin;
  window.AlinAdminFinance=Object.freeze({render:renderFinanceAdmin,exportLedger});
  window.AlinAdminModules?.register?.('finance',renderFinanceAdmin);
})();
;

/* modules/admin/coupons.js */
// === admin/coupons.js ===
/* ALIN v2.1.0: single admin coupon implementation. */

let alinEditingCouponId = null;
let alinCouponSaving = false;

function alinCouponAdminEscape(value){
  return typeof window.esc === 'function' ? window.esc(value) : String(value ?? '');
}
function alinCouponAdminMoney(value){
  return typeof window.money === 'function' ? window.money(value) : Number(value || 0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
}
function alinCouponAdminDate(value){
  if(!value) return 'غير محدد';
  try{return new Date(value).toLocaleDateString(window.AlinI18n?.locale?.()||'ar-IQ')}catch(_){return String(value)}
}
function alinCouponAdminRows(){
  return Array.isArray(window.db?.coupons) ? window.db.coupons : [];
}
function alinCouponUsed(coupon){return Number(coupon.used_count ?? coupon.usage_count ?? 0)}
function alinCouponLimit(coupon){return Number(coupon.max_uses ?? coupon.usage_limit ?? 0)}
function alinCouponIsActive(coupon){
  return String(coupon.status || 'active') === 'active' && (!coupon.expires_at || new Date(coupon.expires_at).getTime() >= Date.now());
}
function alinCouponDuplicate(rows, code, ignoreId = null){
  return rows.find(coupon => window.AlinCoupons.normalizeCode(coupon.code) === code && String(coupon.id) !== String(ignoreId ?? ''));
}
function alinCouponDuplicateMessage(){
  return 'هذا كود الخصم موجود مسبقًا. اختره من القائمة واضغط تعديل بدل إضافته مرة ثانية.';
}
function alinCouponRowsHtml(rows){
  if(!rows.length) return '<div class="admin-v140-empty">لا توجد كوبونات</div>';
  return rows.map(coupon => {
    const limit = alinCouponLimit(coupon);
    const used = alinCouponUsed(coupon);
    const active = alinCouponIsActive(coupon);
    const code = alinCouponAdminEscape(coupon.code);
    const value = coupon.discount_type === 'fixed'
      ? `${alinCouponAdminMoney(coupon.discount_value)} د.ع`
      : `${alinCouponAdminMoney(coupon.discount_value)}%`;
    return `<div class="admin-v140-item coupon-v140-item" data-search="${code}"><div><h4 class="coupon-code">${code}</h4><p>${value} خصم — ${alinCouponAdminEscape(coupon.applies_to || 'كل المتجر')}</p><div class="admin-v140-meta"><span class="admin-v140-pill ${active?'active':'off'}">${active?'نشط':'متوقف/منتهي'}</span><span class="admin-v140-pill">استخدام ${used}/${limit || '∞'}</span><span class="admin-v140-pill">ينتهي ${alinCouponAdminDate(coupon.expires_at)}</span></div></div><div class="admin-v140-item-actions"><button class="coupon-copy" data-alin-click="copyCoupon" data-alin-click-arg0="${code}">نسخ</button><button class="secondary" data-alin-click="editCoupon" data-alin-click-arg0="${alinCouponAdminEscape(coupon.id)}">تعديل</button><button data-alin-click="toggleCoupon" data-alin-click-arg0="${alinCouponAdminEscape(coupon.id)}" data-alin-click-arg1="${String(coupon.status || 'active') === 'active' ? 'disabled' : 'active'}">${String(coupon.status || 'active') === 'active' ? 'إيقاف' : 'تشغيل'}</button><button class="danger" data-alin-click="deleteCoupon" data-alin-click-arg0="${alinCouponAdminEscape(coupon.id)}">حذف</button></div></div>`;
  }).join('');
}

function renderCouponsAdmin(){
  const rows = alinCouponAdminRows();
  const active = rows.filter(alinCouponIsActive).length;
  const used = rows.reduce((sum,coupon)=>sum+alinCouponUsed(coupon),0);
  const expired = rows.filter(coupon=>coupon.expires_at && new Date(coupon.expires_at).getTime() < Date.now()).length;
  const content = document.getElementById('adminContent');
  if(!content) return;
  content.innerHTML = `<section class="admin-v140"><header class="admin-v140-head"><div><h2>العروض والكوبونات</h2><p>إنشاء أكواد خصم وتحديد القيمة، عدد الاستخدامات، القسم المستهدف وتاريخ الانتهاء.</p></div></header><div class="admin-v140-stats"><div class="admin-v140-stat"><span>${rows.length}</span><small>إجمالي الكوبونات</small></div><div class="admin-v140-stat"><span>${active}</span><small>نشطة</small></div><div class="admin-v140-stat"><span>${used}</span><small>مرات الاستخدام</small></div><div class="admin-v140-stat"><span>${expired}</span><small>منتهية</small></div></div><div class="admin-v140-grid"><article class="admin-v140-card"><h3>${alinEditingCouponId?'تعديل الكوبون':'إضافة كوبون'}</h3><form class="admin-v140-form" data-alin-submit="@prevent"><label>كود الخصم<input id="couponAdminCode" placeholder="ALIN20" maxlength="24"></label><div class="admin-v140-form-row"><label>نوع الخصم<select id="couponAdminType"><option value="percent">نسبة مئوية</option><option value="fixed">مبلغ ثابت</option></select></label><label>قيمة الخصم<input id="couponAdminValue" type="number" min="1"></label></div><div class="admin-v140-form-row"><label>عدد الاستخدامات<input id="couponAdminLimit" type="number" min="0" placeholder="0 = بلا حد"></label><label>تاريخ الانتهاء<input id="couponAdminExpiry" type="date"></label></div><label>يطبق على<select id="couponAdminApplies"><option value="all">كل المتجر</option><option value="booklet">الملازم</option><option value="stationery">القرطاسية</option><option value="gift">الهدايا</option></select></label><label>الحالة<select id="couponAdminStatus"><option value="active">نشط</option><option value="disabled">متوقف</option></select></label><div class="admin-v140-actions"><button id="couponAdminSave" data-alin-click="saveCoupon">${alinEditingCouponId?'حفظ التعديل':'إضافة الكوبون'}</button>${alinEditingCouponId?'<button class="secondary" data-alin-click="cancelCouponEdit">إلغاء</button>':''}</div></form></article><article class="admin-v140-card"><div class="admin-v140-toolbar"><h3>قائمة الكوبونات</h3><input id="couponAdminSearch" placeholder="بحث بالكود" data-alin-input="filterCoupons"></div><div id="couponAdminList" class="admin-v140-list">${alinCouponRowsHtml(rows)}</div></article></div></section>`;
  if(alinEditingCouponId){
    const coupon = rows.find(row=>String(row.id)===String(alinEditingCouponId));
    if(coupon){
      document.getElementById('couponAdminCode').value = coupon.code || '';
      document.getElementById('couponAdminType').value = coupon.discount_type || 'percent';
      document.getElementById('couponAdminValue').value = coupon.discount_value || 0;
      document.getElementById('couponAdminLimit').value = coupon.max_uses ?? coupon.usage_limit ?? 0;
      document.getElementById('couponAdminExpiry').value = String(coupon.expires_at || '').slice(0,10);
      document.getElementById('couponAdminApplies').value = coupon.applies_to || 'all';
      document.getElementById('couponAdminStatus').value = coupon.status || 'active';
    }
  }
}

function filterCoupons(){
  const queryText = String(document.getElementById('couponAdminSearch')?.value || '').trim().toLowerCase();
  document.querySelectorAll('#couponAdminList .admin-v140-item').forEach(item=>{
    item.hidden = !String(item.dataset.search || '').toLowerCase().includes(queryText);
  });
}
async function copyCoupon(code){
  try{await navigator.clipboard.writeText(code); if(typeof window.toast==='function')window.toast('تم نسخ الكود')}
  catch(_){window.prompt('انسخ الكود',code)}
}
function editCoupon(id){
  alinEditingCouponId = id;
  renderCouponsAdmin();
  document.getElementById('adminContent')?.scrollIntoView({behavior:'smooth'});
}
function cancelCouponEdit(){
  alinEditingCouponId = null;
  renderCouponsAdmin();
}
async function saveCoupon(){
  if(alinCouponSaving) return;
  const button = document.getElementById('couponAdminSave');
  try{
    alinCouponSaving = true;
    if(button){button.disabled=true;button.textContent='جارٍ الحفظ...'}
    const codeInput = document.getElementById('couponAdminCode');
    const code = window.AlinCoupons.normalizeCode(codeInput?.value || '');
    const value = Number(document.getElementById('couponAdminValue')?.value || 0);
    if(codeInput) codeInput.value = code;
    if(!code || value <= 0) throw new Error('أكمل كود وقيمة الخصم');
    if(!/^[\p{L}\p{N}_-]{2,24}$/u.test(code)) throw new Error('كود الخصم يقبل حروفًا وأرقامًا وشرطة فقط، بدون مسافات');
    let rows = alinCouponAdminRows();
    try{rows = await window.AlinCoupons.refresh()}catch(error){console.warn('[ALIN coupons] pre-save refresh failed',error)}
    if(alinCouponDuplicate(rows,code,alinEditingCouponId)) throw new Error(alinCouponDuplicateMessage());
    const payload = {
      code,
      discount_type: document.getElementById('couponAdminType')?.value || 'percent',
      discount_value: value,
      max_uses: Number(document.getElementById('couponAdminLimit')?.value || 0),
      expires_at: document.getElementById('couponAdminExpiry')?.value ? new Date(document.getElementById('couponAdminExpiry').value+'T23:59:59').toISOString() : null,
      applies_to: document.getElementById('couponAdminApplies')?.value || 'all',
      status: document.getElementById('couponAdminStatus')?.value || 'active',
    };
    const editedId = alinEditingCouponId;
    if(editedId) await window.update('coupons',payload,{id:editedId});
    else await window.insert('coupons',{id:window.uid('CP'),used_count:0,usage_count:0,...payload});
    if(typeof window.audit === 'function') await window.audit('coupon',(editedId?'تعديل':'إضافة')+' كوبون '+code);
    await window.AlinCoupons.refresh();
    alinEditingCouponId = null;
    renderCouponsAdmin();
    if(typeof window.toast === 'function') window.toast('تم حفظ الكوبون وظهر في القائمة');
  }catch(error){
    const message = String(error?.message || error || 'تعذر حفظ الكوبون');
    window.alert(/coupons_code_key|duplicate key|23505/i.test(message) ? alinCouponDuplicateMessage() : message);
  }finally{
    alinCouponSaving = false;
    if(button && document.body.contains(button)){
      button.disabled = false;
      button.textContent = alinEditingCouponId ? 'حفظ التعديل' : 'إضافة الكوبون';
    }
  }
}
async function toggleCoupon(id,status){
  try{
    await window.update('coupons',{status},{id});
    await window.AlinCoupons.refresh();
    renderCouponsAdmin();
  }catch(error){window.alert(error?.message || 'تعذر تحديث الكوبون')}
}
async function deleteCoupon(id){
  if(!window.confirm('حذف الكوبون؟')) return;
  try{
    await window.removeRow('coupons',{id});
    await window.AlinCoupons.refresh();
    renderCouponsAdmin();
    if(typeof window.toast === 'function') window.toast('تم حذف الكوبون');
  }catch(error){window.alert(error?.message || 'تعذر حذف الكوبون')}
}

window.renderCouponsAdmin = renderCouponsAdmin;
window.filterCoupons = filterCoupons;
window.copyCoupon = copyCoupon;
window.editCoupon = editCoupon;
window.cancelCouponEdit = cancelCouponEdit;
window.saveCoupon = saveCoupon;
window.toggleCoupon = toggleCoupon;
window.deleteCoupon = deleteCoupon;
;

/* modules/admin/reports.js */
// === admin/reports.js ===
/* ===== admin/js/admin-reports-v143.js ===== */
(function(){
  const escx=v=>typeof esc==='function'?esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const moneyx=v=>typeof money==='function'?money(v):Number(v||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const arr=v=>Array.isArray(v)?v:[];
  const num=v=>Number(v||0);
  const state={period:'month',from:'',to:'',kind:'all',q:''};
  function dbx(){try{return window.db||db||{}}catch(_){return window.db||{}}}
  function orderDate(o){return String(o?.created_at||o?.date||o?.updated_at||'').slice(0,10)}
  function statusKey(v){const s=String(v||'').toLowerCase();if(['delivered','completed','done'].includes(s))return'done';if(['cancelled','canceled','refunded'].includes(s))return'cancelled';if(['ready'].includes(s))return'ready';if(['printing','processing','preparing'].includes(s))return'processing';return'new'}
  function statusLabel(v){return({done:'مكتمل',cancelled:'ملغي',ready:'جاهز',processing:'قيد التنفيذ',new:'جديد'})[statusKey(v)]}
  function itemKind(o){const k=String(o?.kind||o?.item_type||o?.type||'').toLowerCase();return k.includes('book')||k==='booklet'?'booklet':'product'}
  function orderQty(o){return Math.max(1,num(o?.qty||o?.quantity||1))}
  function orderTotal(o){const explicit=num(o?.total||o?.total_amount||o?.grand_total||o?.amount);return explicit||num(o?.price||o?.unit_price)*orderQty(o)}
  function dateRange(){
    const now=new Date(),today=now.toISOString().slice(0,10);let from='',to=today;
    if(state.period==='today')from=today;
    else if(state.period==='week'){const d=new Date(now);d.setDate(d.getDate()-6);from=d.toISOString().slice(0,10)}
    else if(state.period==='month')from=today.slice(0,8)+'01';
    else if(state.period==='custom'){from=state.from||'';to=state.to||today}
    return{from,to};
  }
  function accountsByRole(role){const d=dbx();return arr(d.accounts?.[role+'s']||d.accounts?.[role]||d[role+'s'])}
  function accountName(role,id){if(!id)return'غير محدد';const rows=accountsByRole(role);const x=rows.find(a=>String(a.id)===String(id));return x?.name||x?.title||x?.username||'غير محدد'}
  function filteredOrders(){const d=dbx(),range=dateRange();return arr(d.orders).filter(o=>{const dt=orderDate(o),kind=itemKind(o),txt=`${o.order_no||o.code||o.id||''} ${o.student_name||o.customer_name||''} ${o.title||o.item_title||''}`.toLowerCase();return(!range.from||dt>=range.from)&&(!range.to||dt<=range.to)&&(state.kind==='all'||kind===state.kind)&&(!state.q||txt.includes(state.q.toLowerCase()))}).sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||'')))}
  function paidOrders(rows){return rows.filter(o=>statusKey(o.status)==='done')}
  function profits(rows){return rows.reduce((a,o)=>{a.platform+=num(o.platform_profit||o.admin_profit||o.platform_amount);a.teacher+=num(o.teacher_profit||o.teacher_amount);a.library+=num(o.library_profit||o.library_amount);a.courier+=num(o.courier_profit||o.delivery_fee||o.courier_amount);return a},{platform:0,teacher:0,library:0,courier:0})}
  function titleOf(o){return o.title||o.item_title||o.product_name||o.booklet_name||(itemKind(o)==='booklet'?'ملزمة':'منتج')}
  function rankBy(rows,keyFn,labelFn){const map=new Map();rows.forEach(o=>{const key=String(keyFn(o)||'unknown');const old=map.get(key)||{key,label:labelFn(o),qty:0,total:0};old.qty+=orderQty(o);old.total+=orderTotal(o);map.set(key,old)});return[...map.values()].sort((a,b)=>b.qty-a.qty||b.total-a.total)}
  function bestLibrary(rows){return rankBy(rows,o=>o.library_id||o.pickup_library_id,o=>accountName('library',o.library_id||o.pickup_library_id))}
  function bestTeacher(rows){return rankBy(rows,o=>o.teacher_id,o=>accountName('teacher',o.teacher_id))}
  function bestCourier(rows){return rankBy(rows,o=>o.courier_id,o=>accountName('courier',o.courier_id))}
  function rankHtml(rows,empty='لا توجد بيانات كافية'){if(!rows.length)return`<div class="admin-v143-empty">${empty}</div>`;return`<div class="admin-v143-rank-list">${rows.slice(0,5).map((r,i)=>`<div class="admin-v143-rank"><em>${i+1}</em><div><b>${escx(r.label||'غير محدد')}</b><small>${r.qty} قطعة أو نسخة</small></div><strong>${moneyx(r.total)} د.ع</strong></div>`).join('')}</div>`}
  function ensureButton(){const tabs=document.querySelector('#adminPage .admin-tabs');if(!tabs)return;let btn=tabs.querySelector('button[data-admin-tab="reports"]');if(!btn){btn=document.createElement('button');btn.type='button';btn.dataset.adminTab='reports';btn.setAttribute('data-alin-click','adminTab');btn.setAttribute('data-alin-click-arg0','reports');const settings=tabs.querySelector('button[data-admin-tab="settings"]');tabs.insertBefore(btn,settings||null)}btn.textContent='التقارير'}
  function markTab(){document.querySelectorAll('#adminPage .admin-tabs button').forEach(b=>b.classList.toggle('active-admin-tab',b.dataset.adminTab==='reports'))}
  function render(){
    ensureButton();markTab();window.activeAdminTab='reports';const root=document.getElementById('adminContent');if(!root)return;
    const rows=filteredOrders(),paid=paidOrders(rows),sales=paid.reduce((a,o)=>a+orderTotal(o),0),profit=profits(paid),cancelled=rows.filter(o=>statusKey(o.status)==='cancelled'),processing=rows.filter(o=>['new','processing','ready'].includes(statusKey(o.status)));
    const booklets=rankBy(paid.filter(o=>itemKind(o)==='booklet'),o=>o.item_id||o.booklet_id||titleOf(o),o=>titleOf(o));
    const products=rankBy(paid.filter(o=>itemKind(o)==='product'),o=>o.item_id||o.product_id||titleOf(o),o=>titleOf(o));
    const libraries=bestLibrary(paid),teachers=bestTeacher(paid),couriers=bestCourier(paid);
    const counts={new:0,processing:0,ready:0,done:0,cancelled:0};rows.forEach(o=>counts[statusKey(o.status)]++);const max=Math.max(1,...Object.values(counts));
    const statusHtml=Object.entries(counts).map(([k,v])=>`<div class="admin-v143-status"><span>${({new:'جديد',processing:'قيد التنفيذ',ready:'جاهز',done:'مكتمل',cancelled:'ملغي'})[k]}</span><div class="admin-v143-bar"><i style="width:${Math.round(v/max*100)}%"></i></div><b>${v}</b></div>`).join('');
    const table=rows.length?`<div class="admin-v143-table-wrap"><table class="admin-v143-table"><thead><tr><th>رقم الطلب</th><th>الطالب</th><th>العنصر</th><th>النوع</th><th>الجهة</th><th>الحالة</th><th>التاريخ</th><th>المبلغ</th></tr></thead><tbody>${rows.slice(0,300).map(o=>`<tr><td>#${escx(o.order_no||o.code||o.id||'—')}</td><td>${escx(o.student_name||o.customer_name||'—')}</td><td>${escx(titleOf(o))}</td><td>${itemKind(o)==='booklet'?'ملزمة':'منتج'}</td><td>${escx(accountName('library',o.library_id||o.pickup_library_id)||accountName('courier',o.courier_id))}</td><td><span class="admin-v143-status-pill ${statusKey(o.status)}">${statusLabel(o.status)}</span></td><td>${escx(orderDate(o)||'—')}</td><td>${moneyx(orderTotal(o))} د.ع</td></tr>`).join('')}</tbody></table></div>`:'<div class="admin-v143-empty">لا توجد طلبات ضمن الفترة المختارة.</div>';
    root.innerHTML=`<section class="admin-v143-reports"><header class="admin-v143-head"><div><h2>التقارير والتحليلات</h2><p>ملخص المبيعات والأرباح وأفضل العناصر والشركاء حسب الفترة المختارة.</p></div><div class="admin-v143-head-icon">📊</div></header><section class="admin-v143-toolbar"><input value="${escx(state.q)}" placeholder="بحث برقم الطلب أو اسم الطالب أو العنصر" data-alin-input="alinV143ReportFilter" data-alin-input-arg0="q" data-alin-input-arg1-source="value"><select data-alin-change="alinV143ReportFilter" data-alin-change-arg0="period" data-alin-change-arg1-source="value"><option value="today" ${state.period==='today'?'selected':''}>اليوم</option><option value="week" ${state.period==='week'?'selected':''}>آخر 7 أيام</option><option value="month" ${state.period==='month'?'selected':''}>هذا الشهر</option><option value="all" ${state.period==='all'?'selected':''}>كل الفترات</option><option value="custom" ${state.period==='custom'?'selected':''}>فترة مخصصة</option></select><input type="date" value="${escx(state.from)}" data-alin-change="alinV143ReportFilter" data-alin-change-arg0="from" data-alin-change-arg1-source="value" ${state.period==='custom'?'':'disabled'}><input type="date" value="${escx(state.to)}" data-alin-change="alinV143ReportFilter" data-alin-change-arg0="to" data-alin-change-arg1-source="value" ${state.period==='custom'?'':'disabled'}><select data-alin-change="alinV143ReportFilter" data-alin-change-arg0="kind" data-alin-change-arg1-source="value"><option value="all" ${state.kind==='all'?'selected':''}>كل الأنواع</option><option value="booklet" ${state.kind==='booklet'?'selected':''}>الملازم</option><option value="product" ${state.kind==='product'?'selected':''}>المنتجات</option></select><button class="secondary" data-alin-click="alinV143ExportReports">تصدير Excel</button><button class="gold" data-alin-click="print">طباعة / PDF</button></section><section class="admin-v143-metrics"><article class="admin-v143-metric gold"><small>إجمالي المبيعات</small><strong>${moneyx(sales)} د.ع</strong><span>${paid.length} طلب مكتمل</span></article><article class="admin-v143-metric"><small>عدد الطلبات</small><strong>${rows.length}</strong><span>${processing.length} طلب قيد المتابعة</span></article><article class="admin-v143-metric green"><small>حصة المنصة</small><strong>${moneyx(profit.platform)} د.ع</strong><span>حسب السجلات الحالية</span></article><article class="admin-v143-metric red"><small>الطلبات الملغاة</small><strong>${cancelled.length}</strong><span>${rows.length?Math.round(cancelled.length/rows.length*100):0}% من النتائج</span></article><article class="admin-v143-metric"><small>أرباح المدرسين</small><strong>${moneyx(profit.teacher)} د.ع</strong><span>من الطلبات المكتملة</span></article><article class="admin-v143-metric"><small>أرباح المكتبات</small><strong>${moneyx(profit.library)} د.ع</strong><span>من الطلبات المكتملة</span></article><article class="admin-v143-metric"><small>أرباح المندوبين</small><strong>${moneyx(profit.courier)} د.ع</strong><span>رسوم وعمولات التوصيل</span></article><article class="admin-v143-metric"><small>متوسط الطلب</small><strong>${moneyx(paid.length?sales/paid.length:0)} د.ع</strong><span>متوسط الطلب المكتمل</span></article></section><section class="admin-v143-grid"><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>أفضل الملازم</h3><small>حسب عدد النسخ</small></div>${rankHtml(booklets,'لا توجد مبيعات ملازم ضمن الفترة.')}</article><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>أفضل المنتجات</h3><small>حسب الكمية</small></div>${rankHtml(products,'لا توجد مبيعات منتجات ضمن الفترة.')}</article><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>أفضل المكتبات</h3><small>حسب المبيعات</small></div>${rankHtml(libraries,'لا توجد بيانات مكتبات ضمن الفترة.')}</article><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>أفضل المدرسين</h3><small>حسب مبيعات الملازم</small></div>${rankHtml(teachers,'لا توجد بيانات مدرسين ضمن الفترة.')}</article><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>أفضل المندوبين</h3><small>حسب الطلبات المسلّمة</small></div>${rankHtml(couriers,'لا توجد بيانات مندوبين ضمن الفترة.')}</article><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>حالات الطلبات</h3><small>توزيع النتائج</small></div><div class="admin-v143-statuses">${statusHtml}</div></article></section><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>تفاصيل الطلبات</h3><small>يتم عرض أول 300 طلب مطابق</small></div>${table}</article></section>`;
  }
  window.alinV143ReportFilter=(k,v)=>{state[k]=v;if(k==='period'&&v!=='custom'){state.from='';state.to=''}render()};
  window.alinV143ExportReports=()=>{const rows=filteredOrders();const data=[['رقم الطلب','الطالب','العنصر','النوع','المكتبة','المندوب','الحالة','التاريخ','الكمية','المبلغ'],...rows.map(o=>[o.order_no||o.code||o.id||'',o.student_name||o.customer_name||'',titleOf(o),itemKind(o)==='booklet'?'ملزمة':'منتج',accountName('library',o.library_id||o.pickup_library_id),accountName('courier',o.courier_id),statusLabel(o.status),orderDate(o),orderQty(o),orderTotal(o)])];const csv='\ufeff'+data.map(r=>r.map(v=>'"'+String(v??'').replace(/"/g,'""')+'"').join(',')).join('\n');const blob=new Blob([csv],{type:'text/csv;charset=utf-8'}),a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='alin-reports-'+new Date().toISOString().slice(0,10)+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1500)};
  function install(){ensureButton();window.AlinAdminModules?.register?.('reports',render)}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install);else install();
})();


;
;

/* modules/admin/settings.js */
// === admin/settings.js ===
/* ALIN v2.4.2 — authoritative platform settings. No router wrapping. */
(function(){
  'use strict';

  const escv=value=>typeof window.esc==='function'?window.esc(value):String(value??'');
  const state=()=>window.db?.settings||{};
  const value=(key,fallback='')=>state()[key]??fallback;
  const root=()=>document.getElementById('adminContent');

  async function settingsSet(key,nextValue){
    const normalized=String(nextValue??'');
    const existing=typeof window.query==='function'?(await window.query('settings')).find(row=>String(row.key)===String(key)):null;
    if(existing&&typeof window.update==='function')await window.update('settings',{value:normalized},{key});
    else if(typeof window.insert==='function')await window.insert('settings',{key,value:normalized});
    else throw new Error('خدمة حفظ الإعدادات غير متاحة');
    window.db=window.db||{};window.db.settings=window.db.settings||{};window.db.settings[key]=normalized;
    return normalized;
  }

  async function saveMany(values,messageElement){
    if(messageElement){messageElement.className='as144-status';messageElement.textContent='جارٍ الحفظ...'}
    try{
      for(const [key,nextValue] of Object.entries(values))await settingsSet(key,nextValue);
      if(typeof window.audit==='function')await window.audit('settings','تحديث إعدادات المنصة');
      if(typeof window.applyBrand==='function')window.applyBrand();
      window.dispatchEvent(new CustomEvent('alin:settings-updated',{detail:{keys:Object.keys(values)}}));
      if(messageElement){messageElement.className='as144-status ok';messageElement.textContent='تم حفظ الإعدادات بنجاح'}
      window.toast?.('تم حفظ الإعدادات');
      return true;
    }catch(error){
      if(messageElement){messageElement.className='as144-status err';messageElement.textContent=error.message||'تعذر حفظ الإعدادات'}
      throw error;
    }
  }

  function currentAdmin(){
    if(window.current?.role==='admin')return window.current;
    return (window.db?.accounts?.all||[]).find(account=>account.role==='admin')||null;
  }
  function adminUser(){return currentAdmin()?.username||value('admin_username','admin')}
  async function saveAdminSecurity(){
    const message=document.getElementById('adminSecurityMsg');
    try{
      const account=currentAdmin();if(!account?.id)throw new Error('تعذر تحديد حساب المدير الحالي');
      const username=document.getElementById('adminLoginName')?.value.trim()||'';
      const password=document.getElementById('adminNewPass')?.value.trim()||'';
      const confirmPassword=document.getElementById('adminNewPass2')?.value.trim()||'';
      if(!username)throw new Error('اكتب اسم دخول المدير');
      if(password&&(password.length<12||!/[0-9]/.test(password)||!/[A-Za-z\u0600-\u06FF]/.test(password)))throw new Error('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');
      if(password!==confirmPassword)throw new Error('تأكيد كلمة المرور غير مطابق');
      if(!window.ALINAuth?.updateAccountFromAdmin)throw new Error('خدمة الحسابات الآمنة غير جاهزة');
      await window.ALINAuth.updateAccountFromAdmin({account_id:account.id,role:'admin',name:account.name||'مدير المنصة',username,status:'active'});
      if(password){
        if(!window.ALINAuth?.resetPasswordFromAdmin)throw new Error('خدمة تغيير كلمة المرور غير متاحة');
        await window.ALINAuth.resetPasswordFromAdmin(account.id,password);
      }
      await settingsSet('admin_username',username);
      if(typeof window.audit==='function')await window.audit('security','تحديث بيانات دخول المدير عبر Supabase Auth');
      if(typeof window.load==='function')await window.load();
      if(message){message.className='as144-status ok';message.textContent='تم تحديث بيانات المدير وحساب الدخول بنجاح'}
      window.toast?.('تم تحديث حساب المدير');
      return true;
    }catch(error){
      if(message){message.className='as144-status err';message.textContent=error.message||'تعذر تحديث بيانات المدير'}
      throw error;
    }
  }

  function render(content=root()){
    if(!content)return;
    content.className='panel admin-settings-v144';
    const version=window.ALIN_CONFIG?.version||'2.4.2';
    content.innerHTML=`
      <div class="as144-head"><div><h2>إعدادات المنصة</h2><p>إدارة الإعدادات العامة والأرباح والطلبات والتواصل وأمان المدير.</p></div><span class="as144-version">v${escv(version)}</span></div>
      <div class="as144-tabs" role="tablist"><button class="active" data-as144-tab="general">عام</button><button data-as144-tab="profits">الأرباح</button><button data-as144-tab="orders">الطلبات</button><button data-as144-tab="contact">تواصل معنا</button><button data-as144-tab="about">حول منصة آلين</button><button data-as144-tab="security">أمان المدير</button></div>
      <section class="as144-panel active" data-as144-panel="general"><div class="as144-card"><h3>الإعدادات العامة</h3><div class="as144-grid">
        <div class="as144-field"><label>اسم المنصة</label><input id="as144PlatformName" value="${escv(value('platform_name','منصة آلين'))}"></div>
        <div class="as144-field"><label>الاسم المختصر</label><input id="as144ShortName" value="${escv(value('platform_short_name','آلين'))}"></div>
        <div class="as144-field"><label>حد تنبيه المخزون</label><input id="as144LowStock" type="number" min="0" value="${escv(value('low_stock_default','5'))}"></div>
        <div class="as144-field"><label>حد تنبيه ذمة المكتبة</label><input id="as144DebtLimit" type="number" min="0" value="${escv(value('library_debt_alert_limit','500000'))}"></div>
        <div class="as144-field full"><label>ملاحظة إدارية داخلية</label><textarea id="as144AdminNote">${escv(value('admin_internal_note',''))}</textarea></div>
      </div><div class="as144-actions"><button class="as144-save" data-save="general">حفظ الإعدادات العامة</button><button class="secondary" data-alin-click="adminTab" data-alin-click-arg0="brandIdentity">فتح الهوية البصرية</button></div><div id="as144GeneralMsg" class="as144-status"></div></div></section>
      <section class="as144-panel" data-as144-panel="profits"><div class="as144-card"><h3>نسب الأرباح الافتراضية</h3><div class="as144-grid">
        <div class="as144-field"><label>حصة المنصة %</label><input id="as144AdminProfit" type="number" min="0" max="100" value="${escv(value('admin_profit_percent','20'))}"></div>
        <div class="as144-field"><label>حصة المدرس %</label><input id="as144TeacherProfit" type="number" min="0" max="100" value="${escv(value('teacher_profit_percent','50'))}"></div>
        <div class="as144-field"><label>حصة المكتبة %</label><input id="as144LibraryProfit" type="number" min="0" max="100" value="${escv(value('library_profit_percent','30'))}"></div>
        <div class="as144-field"><label>عمولة المندوب %</label><input id="as144CourierProfit" type="number" min="0" max="100" value="${escv(value('delegate_profit_percent','30'))}"></div>
      </div><div id="as144ProfitTotal" class="as144-profit-total"></div><div class="as144-actions"><button class="as144-save" data-save="profits">حفظ نسب الأرباح</button></div><div id="as144ProfitsMsg" class="as144-status"></div></div></section>
      <section class="as144-panel" data-as144-panel="orders"><div class="as144-card"><h3>الطلبات والتوصيل</h3><div class="as144-grid">
        <div class="as144-field"><label>أجور التوصيل الافتراضية</label><input id="as144DeliveryFee" type="number" min="0" value="${escv(value('delivery_fee','0'))}"></div>
        <div class="as144-field"><label>حالة استقبال الطلبات</label><select id="as144PauseScope"><option value="" ${value('order_pause_scope','')===''?'selected':''}>الطلبات مفتوحة</option><option value="all" ${value('order_pause_scope','')==='all'?'selected':''}>إيقاف الكل</option><option value="booklet" ${value('order_pause_scope','')==='booklet'?'selected':''}>إيقاف الملازم</option><option value="stationery" ${value('order_pause_scope','')==='stationery'?'selected':''}>إيقاف القرطاسية</option><option value="gift" ${value('order_pause_scope','')==='gift'?'selected':''}>إيقاف الهدايا</option></select></div>
        <div class="as144-field full"><label>سبب إيقاف الطلبات</label><textarea id="as144PauseReason">${escv(value('order_pause_reason',''))}</textarea></div>
      </div><div class="as144-toggle"><div><b>التوصيل للبيت</b><small style="display:block;color:#667085">السماح للطالب باختيار التوصيل عن طريق المندوب.</small></div><input id="as144DeliveryEnabled" type="checkbox" ${String(value('delivery_enabled','true'))!=='false'?'checked':''}></div><div class="as144-actions"><button class="as144-save" data-save="orders">حفظ إعدادات الطلبات</button></div><div id="as144OrdersMsg" class="as144-status"></div></div></section>
      <section class="as144-panel" data-as144-panel="contact"><div class="as144-card"><h3>تواصل معنا وروابط المنصة</h3><div class="as144-grid">
        <div class="as144-field"><label>عنوان الواجهة</label><input id="as144HeroTitle" value="${escv(value('hero_title','كل ما تحتاجه للدراسة بمكان واحد'))}"></div>
        <div class="as144-field"><label>عنوان التواصل</label><input id="as144ContactTitle" value="${escv(value('contact_title','تواصل معنا'))}"></div>
        <div class="as144-field full"><label>نص الواجهة</label><textarea id="as144HeroText">${escv(value('hero_text','اختر ملزمتك أو قرطاسيتك واطلبها بسهولة.'))}</textarea></div>
        <div class="as144-field full"><label>نص التواصل</label><textarea id="as144ContactText">${escv(value('contact_text','للاستفسار أو الانضمام، تواصل مع إدارة منصة آلين.'))}</textarea></div>
        <div class="as144-field"><label>رقم واتساب المنصة</label><input id="as144Whatsapp" inputmode="tel" placeholder="07xxxxxxxxx" value="${escv(value('whatsapp',value('platform_phone','')))}"></div>
        <div class="as144-field"><label>رابط صفحة فيسبوك</label><input id="as144Facebook" type="url" inputmode="url" placeholder="https://www.facebook.com/..." value="${escv(value('facebook_url',''))}"></div>
        <div class="as144-field"><label>رابط صفحة إنستغرام</label><input id="as144Instagram" type="url" inputmode="url" placeholder="https://www.instagram.com/..." value="${escv(value('instagram_url',''))}"></div>
        <div class="as144-field"><label>رابط صفحة تيك توك</label><input id="as144Tiktok" type="url" inputmode="url" placeholder="https://www.tiktok.com/@..." value="${escv(value('tiktok_url',''))}"></div>
      </div><div class="as144-note">ألصق رابط الصفحة الكامل. إذا تركت أي رابط فارغاً فلن يظهر زرّه للزبون.</div><div class="as144-actions"><button class="as144-save" data-save="contact">حفظ التواصل والروابط</button></div><div id="as144ContactMsg" class="as144-status"></div></div></section>
      <section class="as144-panel" data-as144-panel="about"><div class="as144-card"><h3>حول منصة آلين</h3><div class="as144-grid">
        <div class="as144-field full"><label>عنوان حول المنصة</label><input id="as144AboutTitle" value="${escv(value('about_title','حول منصة آلين'))}"></div>
        <div class="as144-field full"><label>نبذة عن منصة آلين</label><textarea id="as144AboutText" rows="7">${escv(value('about_text','منصة آلين تجمع الملازم والقرطاسية والهدايا في مكان واحد، وتربط الطالب بالمدرس والمكتبة وخدمة التوصيل.'))}</textarea></div>
      </div><div class="as144-actions"><button class="as144-save" data-save="about">حفظ معلومات حول المنصة</button></div><div id="as144AboutMsg" class="as144-status"></div></div></section>
      <section class="as144-panel" data-as144-panel="security"><div class="as144-card as144-danger"><h3>أمان حساب المدير</h3><div class="as144-grid">
        <div class="as144-field"><label>اسم دخول المدير</label><input id="adminLoginName" value="${escv(adminUser())}"></div>
        <div class="as144-field"><label>كلمة المرور الجديدة</label><input id="adminNewPass" type="password" autocomplete="new-password"></div>
        <div class="as144-field"><label>تأكيد كلمة المرور</label><input id="adminNewPass2" type="password" autocomplete="new-password"></div>
      </div><div class="as144-note">يتم تحديث حساب المدير الحقيقي في Supabase Auth، وليس رمزاً محلياً داخل المتصفح.</div><div class="as144-actions"><button class="as144-save" id="as144SecuritySave">حفظ بيانات المدير</button></div><div id="adminSecurityMsg" class="as144-status"></div></div></section>`;

    content.querySelectorAll('[data-as144-tab]').forEach(button=>button.addEventListener('click',()=>{
      content.querySelectorAll('[data-as144-tab]').forEach(item=>item.classList.toggle('active',item===button));
      content.querySelectorAll('[data-as144-panel]').forEach(panel=>panel.classList.toggle('active',panel.dataset.as144Panel===button.dataset.as144Tab));
    }));
    const profitIds=['as144AdminProfit','as144TeacherProfit','as144LibraryProfit'];
    const updateTotal=()=>{const total=profitIds.reduce((sum,id)=>sum+(Number(document.getElementById(id)?.value)||0),0);const label=document.getElementById('as144ProfitTotal');if(label)label.textContent=`مجموع نسب المنصة والمدرس والمكتبة: ${total}%`};profitIds.forEach(id=>document.getElementById(id)?.addEventListener('input',updateTotal));updateTotal();
    content.querySelector('[data-save="general"]')?.addEventListener('click',()=>saveMany({platform_name:document.getElementById('as144PlatformName').value.trim(),platform_short_name:document.getElementById('as144ShortName').value.trim()||'آلين',low_stock_default:document.getElementById('as144LowStock').value||5,library_debt_alert_limit:document.getElementById('as144DebtLimit').value||0,admin_internal_note:document.getElementById('as144AdminNote').value.trim()},document.getElementById('as144GeneralMsg')).catch(()=>{}));
    content.querySelector('[data-save="profits"]')?.addEventListener('click',()=>saveMany({admin_profit_percent:document.getElementById('as144AdminProfit').value||20,teacher_profit_percent:document.getElementById('as144TeacherProfit').value||50,library_profit_percent:document.getElementById('as144LibraryProfit').value||30,delegate_profit_percent:document.getElementById('as144CourierProfit').value||30},document.getElementById('as144ProfitsMsg')).catch(()=>{}));
    content.querySelector('[data-save="orders"]')?.addEventListener('click',()=>saveMany({delivery_fee:document.getElementById('as144DeliveryFee').value||0,order_pause_scope:document.getElementById('as144PauseScope').value,order_pause_reason:document.getElementById('as144PauseReason').value.trim(),delivery_enabled:document.getElementById('as144DeliveryEnabled').checked?'true':'false'},document.getElementById('as144OrdersMsg')).catch(()=>{}));
    content.querySelector('[data-save="contact"]')?.addEventListener('click',()=>saveMany({hero_title:document.getElementById('as144HeroTitle').value.trim(),hero_text:document.getElementById('as144HeroText').value.trim(),whatsapp:document.getElementById('as144Whatsapp').value.trim(),platform_phone:document.getElementById('as144Whatsapp').value.trim(),facebook_url:document.getElementById('as144Facebook').value.trim(),instagram_url:document.getElementById('as144Instagram').value.trim(),tiktok_url:document.getElementById('as144Tiktok').value.trim(),contact_title:document.getElementById('as144ContactTitle').value.trim(),contact_text:document.getElementById('as144ContactText').value.trim()},document.getElementById('as144ContactMsg')).catch(()=>{}));
    content.querySelector('[data-save="about"]')?.addEventListener('click',()=>saveMany({about_title:document.getElementById('as144AboutTitle').value.trim(),about_text:document.getElementById('as144AboutText').value.trim()},document.getElementById('as144AboutMsg')).catch(()=>{}));
    document.getElementById('as144SecuritySave')?.addEventListener('click',()=>saveAdminSecurity().catch(()=>{}));
  }

  Object.assign(window,{settingsSet,adminUser,saveAdminSecurity,renderSettingsAdmin:render,saveSystemSettings:()=>Promise.resolve(true),openSystemSettings:()=>window.adminTab?.('settings')});
  function install(){const button=document.querySelector('#adminPage .admin-tabs button[data-admin-tab="settings"]');if(button)button.textContent='الإعدادات';window.AlinAdminModules?.register?.('settings',render)}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
  window.AlinSettings=Object.freeze({render,set:settingsSet,saveMany,saveAdminSecurity});
})();

;
;

/* modules/admin/notifications.js */
// === admin/notifications.js ===
/* ALIN v2.2.6 — admin notification center registered directly in the admin shell. */
(function(){
  'use strict';

  const escapeHtml=value=>String(value??'').replace(/[&<>"']/g,char=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[char]));
  const roleLabel=role=>({
    all:'الجميع',teacher:'المدرسون',library:'المكتبات',student:'الطلبة والمتجر',courier:'المندوبون',accountant:'المحاسب'
  })[String(role||'all')]||'الجميع';
  const state={query:'',role:'',sending:false};

  function service(){return window.AlinNotifications}
  function rows(){return service()?.rows?.()||[]}
  function users(){
    const accounts=window.db?.accounts||{};
    return [
      ...(accounts.teachers||[]),
      ...(accounts.libraries||[]),
      ...(accounts.couriers||[]),
      ...(accounts.accountants||[])
    ];
  }
  function dateText(value){
    try{return new Date(value).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')}
    catch(_){return ''}
  }
  function filteredRows(){
    const query=state.query.trim().toLowerCase();
    return rows().filter(row=>{
      const searchable=`${row.title||''} ${row.message||row.text||''}`.toLowerCase();
      const role=String(row.target_role||row.audience||'all');
      return (!query||searchable.includes(query))&&(!state.role||role===state.role);
    });
  }

  function render(){
    const root=document.getElementById('adminContent');
    if(!root)return false;
    const all=rows();
    const list=filteredRows();
    const week=all.filter(row=>Date.now()-new Date(row.created_at||0).getTime()<=7*864e5).length;
    const accountOptions=users().map(account=>`<option value="${escapeHtml(account.id)}">${escapeHtml(account.name||account.username||account.email||'حساب')}</option>`).join('');
    root.innerHTML=`<section class="admin-v146-notifications">
      <header class="admin-v146-head"><div><h2>مركز الإشعارات</h2><p>إرسال الإشعارات ومراجعة السجل من مصدر واحد.</p></div><div class="admin-v146-bell">🔔</div></header>
      <div class="admin-v146-grid">
        <article class="admin-v146-card"><h3>إرسال إشعار جديد</h3><div class="admin-v146-form">
          <select id="v146Audience"><option value="all">الجميع</option><option value="teacher">المدرسون</option><option value="library">المكتبات</option><option value="student">الطلبة والمتجر</option><option value="courier">المندوبون</option><option value="accountant">المحاسب</option></select>
          <select id="v146Priority"><option value="normal">عادي</option><option value="important">مهم</option><option value="urgent">عاجل</option></select>
          <select id="v146Target" class="full"><option value="">بدون حساب محدد</option>${accountOptions}</select>
          <input id="v146Title" class="full" placeholder="عنوان الإشعار">
          <textarea id="v146Message" class="full" placeholder="اكتب نص الإشعار"></textarea>
          <button id="v146SendButton" class="admin-v146-send" type="button" data-alin-click="AlinAdminNotifications.send">إرسال الإشعار</button>
          <div id="v146Status" class="admin-v146-status"></div>
        </div></article>
        <article class="admin-v146-card"><div class="admin-v146-list-head"><h3>سجل الإشعارات</h3><button type="button" data-alin-click="AlinAdminNotifications.refresh">تحديث</button></div>
          <div class="admin-v146-stats"><div><small>الإجمالي</small><b>${all.length}</b></div><div><small>آخر 7 أيام</small><b>${week}</b></div><div><small>النتائج</small><b>${list.length}</b></div></div>
          <div class="admin-v146-tools"><input placeholder="بحث" value="${escapeHtml(state.query)}" data-alin-input="AlinAdminNotifications.filter" data-alin-input-arg0="query" data-alin-input-arg1-source="value"><select data-alin-change="AlinAdminNotifications.filter" data-alin-change-arg0="role" data-alin-change-arg1-source="value"><option value="">كل الفئات</option>${['all','teacher','library','student','courier','accountant'].map(role=>`<option value="${role}" ${state.role===role?'selected':''}>${roleLabel(role)}</option>`).join('')}</select></div>
          <div class="admin-v146-list">${list.length?list.map(row=>`<div class="admin-v146-item"><div><h4>${escapeHtml(row.title||'إشعار')}</h4><p>${escapeHtml(row.message||row.text||'')}</p><div class="admin-v146-meta"><span>${roleLabel(row.target_role||row.audience||'all')}</span><span>${escapeHtml(row.priority||'normal')}</span><span>${escapeHtml(dateText(row.created_at))}</span></div></div><button type="button" class="danger" data-alin-click="AlinAdminNotifications.remove" data-alin-click-arg0="${escapeHtml(row.id)}">حذف</button></div>`).join(''):'<div class="admin-v146-empty">لا توجد إشعارات حالياً.</div>'}</div>
        </article>
      </div>
    </section>`;
    return true;
  }

  async function send(){
    if(state.sending)return;
    const status=document.getElementById('v146Status');
    const button=document.getElementById('v146SendButton');
    const title=document.getElementById('v146Title')?.value.trim()||'';
    const message=document.getElementById('v146Message')?.value.trim()||'';
    const role=document.getElementById('v146Audience')?.value||'all';
    const priority=document.getElementById('v146Priority')?.value||'normal';
    const targetId=document.getElementById('v146Target')?.value||'';
    if(!title||!message){if(status)status.textContent='اكتب العنوان ونص الإشعار.';return false}
    if(!service()?.send){if(status)status.textContent='خدمة الإشعارات غير جاهزة.';return false}
    state.sending=true;
    if(button){button.disabled=true;button.textContent='جارٍ الإرسال...'}
    try{
      const result=await service().send({title,message,role,target_id:targetId||null,priority,from_user:'admin'});
      if(typeof window.audit==='function')await window.audit('notification',`إرسال إشعار ${title}`);
      if(status)status.textContent=result.remote?'تم إرسال الإشعار بنجاح.':'تم حفظ الإشعار محليًا، وتعذر رفعه إلى الخادم.';
      render();
      return true;
    }catch(error){
      console.error('[ALIN admin notifications]',error);
      if(status)status.textContent=error?.message||'تعذر إرسال الإشعار.';
      return false;
    }finally{
      state.sending=false;
      if(button){button.disabled=false;button.textContent='إرسال الإشعار'}
    }
  }

  async function refresh(){
    await service()?.refresh?.();
    render();
  }

  async function remove(id){
    if(!confirm('حذف هذا الإشعار؟'))return false;
    try{await service()?.remove?.(id);render();return true}
    catch(error){console.error(error);alert(error?.message||'تعذر حذف الإشعار');return false}
  }

  function filter(key,value){state[key]=value;render()}

  const api=Object.freeze({render,send,refresh,remove,filter});
  window.AlinAdminNotifications=api;
  window.renderNotificationsAdmin=render;
  window.AlinAdminModules?.register?.('notifications',render);

  window.addEventListener('alin:notifications-updated',()=>{
    if(window.activeAdminTab==='notifications')render();
  });
})();
;

/* modules/admin/couriers.js */
// === admin/couriers.js ===
/*
  إدارة المندوبين ومناطقهم موجودة في modules/courier/admin.js و modules/courier/areas.js.
  نموذج إنشاء حساب المندوب أصبح جزءاً أصيلاً من modules/admin/accounts.js
  بدون تغليف renderAccountsAdmin أو addAccount.
*/
(function(){
  'use strict';
  window.AlinAdminModules?.register?.('couriers',root=>{
    if(root)root.dataset.courierAccountsIntegrated='true';
  });
})();

;
;

/* modules/courier/core.js */
// === courier/core.js ===
/* ALIN v4.1.2 — courier assignment compatibility for old and new Supabase backends. */
(function(){
  'use strict';

  const $=s=>document.querySelector(s), $$=s=>Array.from(document.querySelectorAll(s));
  const arr=v=>Array.isArray(v)?v:[];
  const escv=v=>typeof esc==='function'?esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const moneyv=v=>typeof money==='function'?money(v):Number(v||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const now=()=>new Date().toISOString();
  const notify=m=>typeof toast==='function'?toast(m):alert(m);
  const currentAccount=()=>{try{return window.current||current||null}catch(_){return window.current||null}};
  const dbx=()=>window.db||{};
  const client=()=>window.sb||window.AlinCloud?.client?.()||null;
  const DEFAULT_AREAS=['القادسية','الحرية','الإسكان','عرفة','رحيم آوه','شوراو','طريق بغداد','الواسطي','دوميز','بنجا علي','تسعين','حي النصر','حي النداء','الخضراء','المصلى','القورية','الشورجة','واحد حزيران','الحي العسكري','حي المعلمين','حي الجامعة','حي عدن','حي الزوراء','حي الحسين','حي العمل الشعبي','غرناطة','المنصور','البلديات','الشرطة','النداء'];
  let refreshPromise=null,lastRefresh=0;

  window.AlinCourierModules=window.AlinCourierModules||{};
  window.ALIN_KIRKUK_AREAS=DEFAULT_AREAS.slice();
  window.alinNormalizeDeliveryArea=window.alinNormalizeDeliveryArea||function(value){
    return String(value||'').replace(/[ـً-ٰٟ]/g,'').replace(/\s+/g,' ').trim().split(/\s*[—–-]\s*/)[0].trim();
  };

  function keyOf(row){return String(row?.account_id||row?.accountId||row?.user_id||row?.id||row?.auth_user_id||row?.username||'')}
  function normalizeCourier(row){
    if(!row)return null;
    const accountId=String(row.account_id||row.accountId||row.user_id||row.id||'');
    const rawId=String(row.id||'');
    return {...row,id:accountId||rawId,account_id:accountId||rawId,courier_row_id:(rawId&&accountId&&rawId!==accountId)?rawId:(row.courier_row_id||null),role:'courier'};
  }
  function allCouriers(){
    const database=dbx(),accounts=database.accounts||{};
    const roleOk=x=>['courier','delegate'].includes(String(x?.role||'').toLowerCase());
    const sources=[...arr(accounts.couriers),...arr(accounts.delegates),...arr(accounts.all).filter(roleOk),...arr(database.couriers),...arr(database.delegates),...arr(window.couriers)];
    const map=new Map();
    for(const raw of sources){const row=normalizeCourier(raw),key=keyOf(row);if(key)map.set(key,{...(map.get(key)||{}),...row,id:key,account_id:key,role:'courier'})}
    return [...map.values()];
  }
  function areasOf(c){
    if(!c)return[];let raw=c.areas||c.area_ids||c.area||[];
    if(Array.isArray(raw))return [...new Set(raw.map(String).map(x=>x.trim()).filter(Boolean))];
    if(typeof raw==='string'){
      try{const parsed=JSON.parse(raw);if(Array.isArray(parsed))return [...new Set(parsed.map(String).map(x=>x.trim()).filter(Boolean))]}catch(_){ }
      return [...new Set(raw.split(/[,،|]/).map(x=>x.trim()).filter(Boolean))];
    }
    return[];
  }
  function areaRows(){
    const rows=arr(dbx().delivery_areas||dbx().deliveryAreas).filter(x=>x.active!==false&&String(x.status||'active')!=='inactive');
    return rows.length?rows:DEFAULT_AREAS.map((name,index)=>({id:`KA${index+1}`,name,status:'active',sort_order:index+1}));
  }
  function statusOf(c){if(!c||c.status==='inactive')return'inactive';const s=String(c.availability||c.work_status||'available');return ['available','busy','offline'].includes(s)?s:'available'}
  function statusLabel(s){return({available:'متاح',busy:'مشغول',offline:'خارج الخدمة',inactive:'موقوف',active:'فعال'})[s]||s}
  function resolveCourier(){
    const me=currentAccount();if(!me||String(me.role)!=='courier')return null;
    const rows=allCouriers();
    const found=rows.find(c=>[c.id,c.account_id,c.courier_row_id].filter(Boolean).map(String).includes(String(me.id)))
      ||rows.find(c=>me.auth_user_id&&String(c.auth_user_id||'')===String(me.auth_user_id))
      ||rows.find(c=>me.username&&String(c.username||'').toLowerCase()===String(me.username).toLowerCase());
    const merged={...me,...(found||{}),id:found?.id||me.id,role:'courier'};
    if(!merged.areas&&merged.area)merged.areas=[merged.area];
    return merged;
  }
  function allOrders(){return arr(dbx().orders)}
  function courierAliases(c=resolveCourier()){
    const ids=new Set([c?.id,c?.account_id,c?.courier_row_id,c?.auth_user_id,currentAccount()?.id,currentAccount()?.auth_user_id].filter(Boolean).map(String));
    let changed=true;
    const sources=allCouriers();
    while(changed){
      changed=false;
      for(const row of sources){
        const values=[row?.id,row?.account_id,row?.courier_row_id,row?.auth_user_id,row?.user_id].filter(Boolean).map(String);
        if(values.some(value=>ids.has(value)))for(const value of values)if(!ids.has(value)){ids.add(value);changed=true}
      }
    }
    return ids;
  }
  function orderCourierIds(o){return [o?.courier_id,o?.delegate_id,o?.courier_account_id,o?.assigned_courier_id,o?.assigned_delegate_id].filter(Boolean).map(String)}
  function myOrders(c=resolveCourier()){
    if(!c)return[];
    const ids=courierAliases(c);
    return allOrders().filter(o=>orderCourierIds(o).some(id=>ids.has(id)))
      .sort((a,b)=>String(b.created_at||b.updated_at||'').localeCompare(String(a.created_at||a.updated_at||'')));
  }
  function confirmedSettlement(row){
    if(!row)return false;
    const status=String(row.status||'').toLowerCase();if(!['received','paid'].includes(status))return false;
    const receipt=String(row.receipt_number||row.voucher_number||'').trim(),id=String(row.id||'').trim(),note=String(row.note||row.notes||'').trim();
    return (/^STL/i.test(id)&&/^RC-/i.test(receipt))||/تسوية\s*(ذمة\s*)?(مندوب|المندوب)|تسديد\s*(ذمة\s*)?(مندوب|المندوب)|delegate\s+settlement|courier\s+settlement/i.test(note);
  }
  function settlements(){
    const seen=new Set(),rows=arr(dbx().settlements);
    return rows.filter(row=>{if(!confirmedSettlement(row))return false;const key=String(row?.id||row?.receipt_number||`${row?.party_id}-${row?.created_at}-${row?.amount}`);if(!key||seen.has(key))return false;seen.add(key);return true});
  }
  function done(o){return ['completed','delivered'].includes(String(o.status||''))}
  function cancelled(o){return ['cancelled','rejected','assignment_expired'].includes(String(o.status||''))}
  function active(o){return !done(o)&&!cancelled(o)}
  function activeLoad(c){return myOrders(c).filter(active).length}
  function today(o){const x=o.delivered_at||o.completed_at||o.updated_at||o.created_at||'';return String(x).slice(0,10)===new Date().toISOString().slice(0,10)}
  function todayDone(c){return myOrders(c).filter(o=>done(o)&&today(o)).length}
  function orderCollectedAmount(o){
    const values=[o?.delegate_cash_collected,o?.courier_cash_collected,o?.cash_collected,o?.amount_collected,o?.total,o?.grand_total,o?.final_total,o?.amount_due,o?.payable_total];
    for(const value of values){const n=Number(value);if(Number.isFinite(n)&&n>0)return n}
    return 0;
  }
  function orderCourierProfit(o){
    const persisted=Number(o?.delegate_profit||o?.courier_profit||0);
    if(Number.isFinite(persisted)&&persisted>0)return persisted;
    return Math.max(0,Number(window.AlinFinance?.shares?.(o)?.delegate||0));
  }
  function financials(c){
    if(!c)return{collected:0,earnings:0,paid:0,debt:0,balance:0,debtTotal:0,rows:[]};
    const ids=courierAliases(c);
    // Courier debt is authoritative from delivered orders themselves, not from a possibly stale ledger summary.
    const rows=allOrders().filter(o=>done(o)&&orderCourierIds(o).some(id=>ids.has(String(id))));
    const details=rows.map(o=>{
      const collected=Math.max(0,orderCollectedAmount(o));
      const profit=Math.max(0,orderCourierProfit(o));
      return {order:o,collected,profit,debt:Math.max(0,collected-profit)};
    });
    const collected=details.reduce((sum,row)=>sum+row.collected,0);
    const earnings=details.reduce((sum,row)=>sum+row.profit,0);
    const debtTotal=details.reduce((sum,row)=>sum+row.debt,0);
    const paid=settlements().filter(s=>[s.courier_id,s.delegate_id,s.party_id,s.account_id].filter(Boolean).map(String).some(id=>ids.has(id)))
      .reduce((sum,s)=>sum+Math.max(0,Number(s.amount)||0),0);
    const debt=Math.max(0,debtTotal-paid);
    return{collected,earnings,paid,debt,balance:earnings,debtTotal,rows:details};
  }
  function orderState(st){return({pending:'جديد',pending_admin:'بانتظار التعيين',assigned:'بانتظار القبول',new:'طلب جديد',accepted:'مقبول',picked_up:'تم استلام الطلب',out_for_delivery:'في الطريق',out_delivery:'في الطريق',processing:'قيد التنفيذ',printing:'قيد الطباعة',ready:'جاهز',completed:'تم التسليم',delivered:'تم التسليم',cancelled:'ملغي',rejected:'مرفوض'})[st]||st||'جديد'}
  function messageText(error){
    const direct=String(error?.message||error||'').trim();
    const details=String(error?.details||'').trim();
    const hint=String(error?.hint||'').trim();
    return [direct,details,hint].filter(Boolean).join(' — ');
  }
  function friendlyOrderError(error){
    const msg=messageText(error);
    if(/failed to fetch|networkerror|load failed|fetch failed/i.test(msg))return 'تعذر الاتصال بخدمة الطلبات. تحقق من الإنترنت ثم أعد المحاولة.';
    if(/jwt|session|token|auth session missing|not authenticated/i.test(msg))return 'انتهت جلسة الحساب. سجل الخروج ثم ادخل مرة ثانية.';
    if(/المندوب غير مرتبط بمنطقة الطلب|حساب المندوب غير موجود|حساب المندوب غير فعال|الطلب غير موجود|غير مسموح|الحالة الحالية|سبب الرفض|مكتمل|ملغي/.test(msg))return msg;
    return msg||'تعذر تحديث طلب المندوب.';
  }
  function courierById(id){return allCouriers().find(c=>[c.id,c.account_id,c.courier_row_id].filter(Boolean).map(String).includes(String(id)))||null}
  function mergeOrder(order){
    if(!order?.id)return;
    const rows=allOrders(),index=rows.findIndex(x=>String(x.id)===String(order.id));
    if(index>=0)Object.assign(rows[index],order);else rows.unshift(order);
  }
  async function rpc(name,args){
    const c=client();if(!c?.rpc)throw new Error('خدمة Supabase غير متاحة');
    const {data,error}=await c.rpc(name,args);if(error)throw error;
    if(!data?.ok)throw new Error(data?.error||'لم يؤكد الخادم تنفيذ العملية');
    if(data.order)mergeOrder(data.order);
    return data;
  }
  async function assignOrder(orderId,courierId=null,libraryId=null){
    const courier=courierId?courierById(courierId):null;
    const canonicalCourier=courier?String(courier.account_id||courier.id||courierId):(courierId?String(courierId):null);
    const result=await rpc('alin_admin_assign_order',{
      p_order_id:String(orderId),
      p_courier_id:canonicalCourier,
      p_library_id:libraryId?String(libraryId):null
    });
    if(typeof window.load==='function')await window.load({force:true,reason:'courier-assignment-rc7'});
    return result;
  }
  async function transitionOrder(orderId,status,reason=''){
    if(!window.AlinFinance?.transitionOrder)throw new Error('خدمة حركة الطلبات غير جاهزة');
    const result=await window.AlinFinance.transitionOrder(String(orderId),String(status),String(reason||''));
    if(result?.order)mergeOrder(result.order);
    return result;
  }
  function gpsCoords(o){
    const lat=Number(o?.delivery_latitude??o?.delivery_lat??o?.latitude);
    const lng=Number(o?.delivery_longitude??o?.delivery_lng??o?.longitude);
    return Number.isFinite(lat)&&Number.isFinite(lng)&&lat>=-90&&lat<=90&&lng>=-180&&lng<=180?{lat,lng}:null;
  }
  function hasExactGps(o){return Boolean(gpsCoords(o))}
  function safeStoredMapUrl(o){
    const raw=String(o?.delivery_location_url||o?.delivery_map_url||o?.gps_url||'').trim();
    if(!raw)return '';
    try{const u=new URL(raw);return u.protocol==='https:'?u.href:''}catch(_){return ''}
  }
  function landmarkMapLink(o){
    const parts=[o?.delivery_landmark,window.alinNormalizeDeliveryArea?.(o?.delivery_area)||o?.delivery_area,'كركوك','العراق']
      .map(value=>String(value||'').trim()).filter(Boolean);
    return parts.length>2?`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(parts.join('، '))}`:'';
  }
  function mapLink(o){
    const stored=safeStoredMapUrl(o);if(stored)return stored;
    const gps=gpsCoords(o);if(gps)return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${gps.lat},${gps.lng}`)}`;
    return landmarkMapLink(o);
  }
  window.alinCourierOpenMap=function(orderId){
    const order=allOrders().find(row=>String(row.id)===String(orderId)||String(row.order_number)===String(orderId));
    if(!order){notify('تعذر العثور على الطلب');return false}
    const url=mapLink(order);
    if(!url){notify('لا يوجد موقع GPS أو نقطة دالة محفوظة لهذا الطلب');return false}
    if(!hasExactGps(order))notify('هذا الطلب لا يحتوي GPS دقيقاً؛ سيتم فتح النقطة الدالة على الخريطة.');
    window.location.assign(url);
    return true;
  };
  function phoneLink(p){p=String(p||'').replace(/\D/g,'');return p?`tel:+${p.startsWith('964')?p:'964'+p.replace(/^0/,'')}`:'#'}
  function waLink(p){p=String(p||'').replace(/\D/g,'');return p?`https://wa.me/${p.startsWith('964')?p:'964'+p.replace(/^0/,'')}`:'#'}
  function fmtDate(v){if(!v)return'—';try{return new Date(v).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')}catch(_){return String(v)}}
  function matchingCouriers(area){const target=window.alinNormalizeDeliveryArea(area);return allCouriers().filter(c=>c.status!=='inactive'&&areasOf(c).some(name=>window.alinNormalizeDeliveryArea(name)===target)).sort((a,b)=>activeLoad(a)-activeLoad(b))}
  function activeCouriers(){return allCouriers().filter(c=>c.status!=='inactive')}
  function alinCouriersOptions(){return activeCouriers().map(c=>`<option value="${escv(c.id)}">${escv(c.name||'مندوب')}${areasOf(c).length?' — '+escv(areasOf(c).join('، ')):''}</option>`).join('')}

  function mergeOwnRows(courierRow,orderRows){
    const database=dbx();
    if(courierRow){
      const rows=allCouriers().filter(x=>String(x.id)!==String(courierRow.id));rows.push(courierRow);
      database.couriers=rows;database.accounts=database.accounts||{};database.accounts.couriers=rows;
      try{window.couriers=rows}catch(_){ }
    }
    if(Array.isArray(orderRows)){
      const ids=courierAliases(resolveCourier()),freshIds=new Set(orderRows.map(x=>String(x.id)));
      const retained=allOrders().filter(x=>!freshIds.has(String(x.id))&&!orderCourierIds(x).some(id=>ids.has(id)));
      database.orders=[...orderRows,...retained];
    }
  }
  async function refreshCourierData(force=false){
    const me=currentAccount();if(!me||me.role!=='courier')return null;
    if(!force&&Date.now()-lastRefresh<1500)return resolveCourier();
    if(refreshPromise)return refreshPromise;
    refreshPromise=(async()=>{
      const c=client();if(!c)return resolveCourier();
      let courierRow=null;
      const primary=await c.from('couriers').select('*').eq('id',me.id).maybeSingle();
      if(!primary.error&&primary.data)courierRow=primary.data;else if(primary.error)console.warn('[ALIN courier row]',primary.error);
      // Build every known alias before querying orders. Old orders may store courier-row id while login uses account id.
      const local=normalizeCourier(courierRow)||resolveCourier()||me;
      const aliases=[...courierAliases(local)];
      if(!aliases.includes(String(me.id)))aliases.push(String(me.id));
      const results=await Promise.all(aliases.map(id=>c.from('orders').select('*').or(`courier_id.eq.${id},delegate_id.eq.${id}`).order('created_at',{ascending:false})));
      const map=new Map();
      for(const result of results){
        if(result.error){console.warn('[ALIN courier orders alias]',result.error);continue}
        for(const row of (result.data||[])){const key=String(row.id||row.order_number||'');if(key)map.set(key,{...(map.get(key)||{}),...row})}
      }
      mergeOwnRows(courierRow,[...map.values()]);lastRefresh=Date.now();return resolveCourier();
    })().catch(error=>{console.error('[ALIN courier refresh]',error);return resolveCourier()}).finally(()=>{refreshPromise=null});
    return refreshPromise;
  }
  function resetRefresh(){lastRefresh=0}

  window.AlinCourierCore=Object.freeze({
    version:window.ALIN_CONFIG?.version||'4.2.0-rc.21',$, $$, arr, escv, moneyv, now, notify, currentAccount, dbx,
    allCouriers, areasOf, areaRows, statusOf, statusLabel, resolveCourier,
    allOrders, courierAliases, orderCourierIds, myOrders, settlements, done, cancelled, active, activeLoad, today, todayDone, financials,
    orderState, friendlyOrderError, mapLink, hasExactGps, phoneLink, waLink, fmtDate,
    matchingCouriers, activeCouriers, alinCouriersOptions, assignOrder, transitionOrder,
    refreshCourierData, resetRefresh
  });
})();

;
;

/* modules/courier/admin.js */
// === courier/admin.js ===
/* ALIN v2.4.2 — courier account administration only. */
(function(){
  'use strict';
  const core=window.AlinCourierCore;if(!core)throw new Error('AlinCourierCore is required before courier/admin.js');
  const {$,$$,escv,moneyv,notify,now,allCouriers,areasOf,areaRows,statusOf,statusLabel,myOrders,financials,active,done,activeLoad,todayDone,orderState,activeCouriers,alinCouriersOptions}=core;
  function renderCouriersAdmin(){
    const rows=allCouriers(),areas=[...new Set([...areaRows().map(x=>x.name),...rows.flatMap(areasOf)])];
    const debt=rows.reduce((sum,c)=>sum+financials(c).debt,0);
    adminContent.innerHTML=`<section class="v164-admin-couriers"><header class="v164-admin-head"><div><small>نظام التوصيل</small><h2>إدارة المندوبين</h2><p>الحسابات والمناطق والحالة والطلبات والذمم من مكان واحد.</p></div><div><button data-alin-click="adminTab" data-alin-click-arg0="deliveryOrders">طلبات التوصيل</button><button data-alin-click="adminTab" data-alin-click-arg0="courierAreas">إدارة المناطق</button><button data-alin-click="alinV161CourierForm">+ إضافة مندوب</button></div></header><section class="v164-admin-metrics"><article><small>إجمالي المندوبين</small><strong>${rows.length}</strong></article><article><small>فعالون</small><strong>${rows.filter(c=>c.status!=='inactive').length}</strong></article><article><small>متاحون</small><strong>${rows.filter(c=>statusOf(c)==='available').length}</strong></article><article><small>طلبات جارية</small><strong>${rows.reduce((sum,c)=>sum+activeLoad(c),0)}</strong></article><article><small>إجمالي الذمم</small><strong>${moneyv(debt)} د.ع</strong></article></section><section class="v164-admin-tools"><input id="v216CourierQ" placeholder="بحث بالاسم أو الهاتف أو المنطقة" data-alin-input="alinV216FilterCouriers"><select id="v216CourierStatus" data-alin-change="alinV216FilterCouriers"><option value="">كل الحالات</option><option value="available">متاح</option><option value="busy">مشغول</option><option value="offline">خارج الخدمة</option><option value="inactive">موقوف</option></select><select id="v216CourierArea" data-alin-change="alinV216FilterCouriers"><option value="">كل المناطق</option>${areas.map(a=>`<option value="${escv(a)}">${escv(a)}</option>`).join('')}</select></section><div class="v164-admin-grid" id="v216CourierGrid">${rows.map(adminCourierCard).join('')||'<div class="empty">لا يوجد مندوبون بعد.</div>'}</div></section>`;
  }
  function adminCourierCard(c){const status=c.status==='inactive'?'inactive':statusOf(c),areas=areasOf(c),f=financials(c);return `<article class="v164-admin-card" data-search="${escv(((c.name||'')+' '+(c.phone||'')+' '+(c.username||'')+' '+areas.join(' ')).toLowerCase())}" data-status="${status}" data-areas="${escv(areas.join('|'))}"><header><div class="v161-avatar">${escv((c.name||'م').slice(0,1))}</div><div><h3>${escv(c.name||'مندوب')}</h3><p>${escv(c.phone||'بدون هاتف')} • ${escv(c.username||'بدون اسم دخول')}</p></div><span class="v161-status ${status}">${statusLabel(status)}</span></header><div class="v164-card-metrics"><div><small>الطلبات الحالية</small><b>${activeLoad(c)}</b></div><div><small>مكتملة اليوم</small><b>${todayDone(c)}</b></div><div><small>الذمة</small><b>${moneyv(f.debt)} د.ع</b></div></div><div class="v161-area-chips">${areas.map(a=>`<span>${escv(a)}</span>`).join('')||'<span>غير مرتبط بمنطقة</span>'}</div><footer><button data-alin-click="alinV164CourierDetails" data-alin-click-arg0="${escv(c.id)}">التفاصيل</button><button data-alin-click="alinV161CourierForm" data-alin-click-arg0="${escv(c.id)}">تعديل</button><button class="secondary" data-alin-click="alinV164AdminStatus" data-alin-click-arg0="${escv(c.id)}">تغيير الحالة</button><button class="danger" data-alin-click="alinV161ToggleCourier" data-alin-click-arg0="${escv(c.id)}">${c.status==='inactive'?'تفعيل':'إيقاف'}</button></footer></article>`}
  window.alinV216FilterCouriers=function(){const q=String($('#v216CourierQ')?.value||'').toLowerCase(),status=$('#v216CourierStatus')?.value||'',area=$('#v216CourierArea')?.value||'';$$('#v216CourierGrid .v164-admin-card').forEach(card=>card.hidden=!((!q||card.dataset.search.includes(q))&&(!status||card.dataset.status===status)&&(!area||card.dataset.areas.split('|').includes(area))))};
  window.alinV161CourierForm=function(id=''){
    const c=allCouriers().find(x=>String(x.id)===String(id))||{},selected=areasOf(c),box=window.checkoutBox||$('#checkoutBox'),modal=window.checkoutModal||$('#checkoutModal');if(!box||!modal)return;
    box.innerHTML=`<div class="v161-form"><h2>${id?'تعديل المندوب':'إضافة مندوب'}</h2><div class="form-grid"><input id="v161CourierName" value="${escv(c.name||'')}" placeholder="اسم المندوب"><input id="v161CourierPhone" value="${escv(c.phone||'')}" placeholder="رقم الهاتف"><input id="v161CourierUsername" value="${escv(c.username||'')}" placeholder="اسم المستخدم"><input id="v161CourierPassword" type="password" autocomplete="new-password" placeholder="${id?'كلمة مرور جديدة من 12 حرفاً (اختياري)':'كلمة مرور من 12 حرفاً وحروف وأرقام'}"><select id="v161CourierAvailability"><option value="available" ${statusOf(c)==='available'?'selected':''}>متاح</option><option value="busy" ${statusOf(c)==='busy'?'selected':''}>مشغول</option><option value="offline" ${statusOf(c)==='offline'?'selected':''}>خارج الخدمة</option></select></div><h3>مناطق العمل</h3><div class="v161-area-picker">${areaRows().map(a=>`<label><input type="checkbox" value="${escv(a.name)}" ${selected.includes(a.name)?'checked':''}> ${escv(a.name)}</label>`).join('')}</div><button data-alin-click="alinV161SaveCourier" data-alin-click-arg0="${escv(id)}">حفظ المندوب</button></div>`;modal.classList.remove('hidden');
  };
  window.alinV161SaveCourier=async function(id=''){
    try{
      const name=$('#v161CourierName')?.value.trim()||'',phone=$('#v161CourierPhone')?.value.trim()||'',username=$('#v161CourierUsername')?.value.trim()||'',password=$('#v161CourierPassword')?.value||'',availability=$('#v161CourierAvailability')?.value||'available',areas=$$('.v161-area-picker input:checked').map(x=>x.value);
      if(!name||!username||(!id&&!password))throw new Error('أكمل الاسم واسم المستخدم وكلمة المرور');if(!phone)throw new Error('أدخل رقم هاتف المندوب');if(!areas.length)throw new Error('اختر منطقة عمل واحدة على الأقل');if(password&&(password.length<12||!/[0-9]/.test(password)||!/[A-Za-z\u0600-\u06FF]/.test(password)))throw new Error('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');
      const api=window.ALINAuth;if(!api)throw new Error('خدمة الحسابات الآمنة غير جاهزة');
      const payload={role:'courier',name,username,phone,area:areas[0],areas,availability,status:'active'};if(password)payload.password=password;
      if(id)await api.updateAccountFromAdmin({account_id:id,...payload});else await api.createAccount(payload);
      if(typeof audit==='function')await audit('courier',`${id?'تعديل':'إضافة'} مندوب ${name}`);if(typeof load==='function')await load();if(typeof closeCheckout==='function')closeCheckout();renderCouriersAdmin();notify('تم حفظ حساب المندوب ومناطق عمله');
    }catch(error){alert(error.message||'تعذر حفظ المندوب')}
  };
  window.alinV161ToggleCourier=async function(id){const c=allCouriers().find(x=>String(x.id)===String(id));if(!c)return;const next=c.status==='inactive'?'active':'inactive';try{const api=window.ALINAuth;if(!api?.updateAccountFromAdmin)throw new Error('خدمة الحسابات الآمنة غير جاهزة');await api.updateAccountFromAdmin({account_id:id,role:'courier',status:next,name:c.name,username:c.username,phone:c.phone,area:areasOf(c)[0]||'',areas:areasOf(c),availability:statusOf(c)});if(typeof load==='function')await load();renderCouriersAdmin()}catch(error){alert(error.message||'تعذر تحديث الحساب')}};
  window.alinV164AdminStatus=async function(id){const c=allCouriers().find(x=>String(x.id)===String(id));if(!c)return;const value=prompt('الحالة: available أو busy أو offline',statusOf(c));if(!['available','busy','offline'].includes(String(value)))return;try{await update('couriers',{availability:value,updated_at:now()},{id});if(typeof load==='function')await load();renderCouriersAdmin()}catch(error){alert(error.message||'تعذر تحديث الحالة')}};
  window.alinV164CourierDetails=function(id){const c=allCouriers().find(x=>String(x.id)===String(id)),box=window.checkoutBox||$('#checkoutBox'),modal=window.checkoutModal||$('#checkoutModal');if(!c||!box||!modal)return;const rows=myOrders(c),f=financials(c);box.innerHTML=`<section class="v164-details"><header><div class="v161-avatar">${escv((c.name||'م').slice(0,1))}</div><div><h2>${escv(c.name||'مندوب')}</h2><p>${escv(c.phone||'')} • ${escv(c.username||'')}</p></div><span class="v161-status ${statusOf(c)}">${statusLabel(statusOf(c))}</span></header><div class="v164-admin-metrics"><article><small>طلبات حالية</small><strong>${rows.filter(active).length}</strong></article><article><small>طلبات مكتملة</small><strong>${rows.filter(done).length}</strong></article><article><small>أرباحه</small><strong>${moneyv(f.earnings)} د.ع</strong></article><article><small>ذمته</small><strong>${moneyv(f.debt)} د.ع</strong></article></div><h3>مناطق العمل</h3><div class="v161-area-chips">${areasOf(c).map(a=>`<span>${escv(a)}</span>`).join('')}</div><h3>آخر الطلبات</h3><div class="v164-mini-orders">${rows.slice(0,8).map(o=>`<div><span>${escv(o.order_number||o.id)}</span><span>${escv(o.delivery_area||'')}</span><b>${moneyv(o.total)} د.ع</b><small>${escv(orderState(o.status))}</small></div>`).join('')||'<p class="empty">لا توجد طلبات.</p>'}</div></section>`;modal.classList.remove('hidden')};


  window.renderCouriersAdmin=renderCouriersAdmin;
  window.activeCouriers=activeCouriers;
  window.alinCouriersOptions=alinCouriersOptions;
  window.addCourier=()=>window.alinV161CourierForm();
  window.toggleCourier=window.alinV161ToggleCourier;
  Object.assign(window.AlinCourierModules,{activeCouriers,renderCouriersAdmin,addCourier:window.addCourier,toggleCourier:window.toggleCourier,alinCouriersOptions});
  window.AlinAdminModules?.register?.('couriers',renderCouriersAdmin);
})();

;
;

/* modules/courier/areas.js */
// === courier/areas.js ===
/* ALIN v2.4.2 — delivery area administration only. */
(function(){
  'use strict';
  const core=window.AlinCourierCore;if(!core)throw new Error('AlinCourierCore is required before courier/areas.js');
  const {escv,notify,now,allCouriers,areasOf,areaRows}=core;
  function renderCourierAreasAdmin(){const rows=areaRows();adminContent.innerHTML=`<section class="v161-admin"><header class="v161-title"><div><small>مناطق التوصيل</small><h2>إدارة المناطق</h2><p>هذه القائمة تظهر للطالب وعند تحديد مناطق عمل المندوب.</p></div><button data-alin-click="alinV161AddArea">+ إضافة منطقة</button></header><div class="v161-area-admin">${rows.map(a=>{const count=allCouriers().filter(c=>areasOf(c).includes(a.name)).length;return `<article><div><h3>${escv(a.name)}</h3><p>مرتبطة بـ ${count} مندوب</p></div><div><button data-alin-click="alinV161EditArea" data-alin-click-arg0="${escv(a.id)}" data-alin-click-arg1="${escv(a.name)}">تعديل</button><button class="danger" data-alin-click="alinV161DeleteArea" data-alin-click-arg0="${escv(a.id)}" data-alin-click-arg1="${escv(a.name)}">حذف</button></div></article>`}).join('')}</div></section>`}
  window.alinV161AddArea=async function(){const name=(prompt('اسم المنطقة الجديدة')||'').trim();if(!name)return;try{await insert('delivery_areas',{id:typeof uid==='function'?uid('A'):`A${Date.now()}`,name,city:'كركوك',status:'active',sort_order:areaRows().length+1});if(typeof load==='function')await load();renderCourierAreasAdmin();notify('تمت إضافة المنطقة')}catch(error){alert(error.message||'تعذر إضافة المنطقة')}};
  window.alinV161EditArea=async function(id,oldName){const name=(prompt('تعديل اسم المنطقة',oldName)||'').trim();if(!name||name===oldName)return;try{await update('delivery_areas',{name},{id});for(const c of allCouriers()){const areas=areasOf(c);if(areas.includes(oldName))await update('couriers',{areas:areas.map(x=>x===oldName?name:x),area:c.area===oldName?name:c.area,updated_at:now()},{id:c.id})}if(typeof load==='function')await load();renderCourierAreasAdmin();notify('تم تعديل المنطقة')}catch(error){alert(error.message||'تعذر تعديل المنطقة')}};
  window.alinV161DeleteArea=async function(id,name){if(allCouriers().some(c=>areasOf(c).includes(name)))return alert('لا يمكن حذف منطقة مرتبطة بمندوب');if(!confirm(`حذف منطقة ${name}؟`))return;try{await update('delivery_areas',{status:'inactive'},{id});if(typeof load==='function')await load();renderCourierAreasAdmin();notify('تم حذف المنطقة')}catch(error){alert(error.message||'تعذر حذف المنطقة')}};


  window.renderCourierAreasAdmin=renderCourierAreasAdmin;
  window.AlinAdminModules?.register?.('courierAreas',renderCourierAreasAdmin);
})();

;
;

/* modules/courier/assignment.js */
// === courier/assignment.js ===
/* ALIN v4.1.2 — one authoritative admin assignment path. */
(function(){
  'use strict';
  const core=window.AlinCourierCore;if(!core)throw new Error('AlinCourierCore is required before courier/assignment.js');
  const {$,escv,moneyv,notify,allOrders,active,done,matchingCouriers,allCouriers,mapLink,hasExactGps,orderState,statusLabel,statusOf,activeLoad,friendlyOrderError,assignOrder,transitionOrder}=core;
  const pending=new Set();

  function deliveryOrders(){return allOrders().filter(o=>o.fulfillment_type==='home_delivery'||o.delivery_type==='courier')}
  function setBusy(id,value){const key=String(id);if(value)pending.add(key);else pending.delete(key);document.querySelectorAll(`[data-order-action="${CSS.escape(key)}"]`).forEach(button=>button.disabled=value)}
  function renderDeliveryOrdersAdmin(){
    const rows=deliveryOrders();
    adminContent.innerHTML=`<section class="v164-admin-couriers"><header class="v164-admin-head"><div><small>توزيع الطلبات</small><h2>طلبات التوصيل</h2><p>اختيار المندوب حسب المنطقة مع تحديث الطلب من الخادم بمسار واحد.</p></div><button data-alin-click="renderCouriersAdmin">إدارة المندوبين</button></header><section class="v164-admin-metrics"><article><small>كل طلبات التوصيل</small><strong>${rows.length}</strong></article><article><small>بانتظار التعيين</small><strong>${rows.filter(o=>!o.courier_id&&!o.delegate_id).length}</strong></article><article><small>قيد التوصيل</small><strong>${rows.filter(o=>active(o)&&(o.courier_id||o.delegate_id)).length}</strong></article><article><small>مكتملة</small><strong>${rows.filter(done).length}</strong></article></section><div class="v164-delivery-admin-list">${rows.map(deliveryAdminCard).join('')||'<div class="empty">لا توجد طلبات توصيل.</div>'}</div></section>`;
  }
  function deliveryAdminCard(o){
    const area=window.alinNormalizeDeliveryArea(o.delivery_area)||'غير محددة';
    const matches=matchingCouriers(area);
    const assigned=allCouriers().find(c=>String(c.id)===String(o.courier_id||o.delegate_id||''));
    const map=mapLink(o),exactGps=hasExactGps(o),locked=done(o)||['cancelled','rejected'].includes(String(o.status||''));
    return `<article class="v164-delivery-admin-card"><header><div><small>${escv(o.order_number||o.id)}</small><h3>${escv(o.title||'طلب توصيل')}</h3></div><span>${escv(area)}</span></header>${o.delivery_note?`<div class="v164-issue">ملاحظة المندوب: ${escv(o.delivery_note)}</div>`:''}<div class="v164-order-grid"><div><small>الطالب</small><b>${escv(o.student_name||'—')}</b></div><div><small>الهاتف</small><b>${escv(o.student_phone||'—')}</b></div><div class="wide"><small>أقرب نقطة دالة</small><b>${escv(o.delivery_landmark||'—')}</b></div><div><small>المبلغ</small><b>${moneyv(o.total)} د.ع</b></div><div><small>الحالة</small><b>${escv(orderState(o.status))}</b></div></div>${map?`<button type="button" class="v164-map-btn" data-alin-click="alinCourierOpenMap" data-alin-click-arg0="${escv(o.id)}">${exactGps?'فتح موقع الطالب GPS':'فتح النقطة الدالة على الخريطة'}</button>`:''}<div class="v164-match-list"><h4>المندوبون المطابقون للمنطقة (${matches.length})</h4>${matches.map(c=>`<label><input type="radio" name="v216assign_${escv(o.id)}" value="${escv(c.id)}" ${assigned&&String(assigned.id)===String(c.id)?'checked':''} ${locked?'disabled':''}><span><b>${escv(c.name)}</b><small>${statusLabel(statusOf(c))} • ${activeLoad(c)} طلب حالي • ${escv(c.phone||'')}</small></span></label>`).join('')||'<p class="warning-text">لا يوجد مندوب مرتبط بهذه المنطقة.</p>'}</div><footer><button data-order-action="${escv(o.id)}" ${locked||!matches.length?'disabled':''} data-alin-click="alinV164Assign" data-alin-click-arg0="${escv(o.id)}">${assigned?'حفظ المندوب':'تحويل للمندوب'}</button>${assigned&&!locked?`<button class="secondary" data-order-action="${escv(o.id)}" data-alin-click="alinV410Unassign" data-alin-click-arg0="${escv(o.id)}">إلغاء التعيين</button>`:''}${assigned?`<span>المندوب الحالي: <b>${escv(assigned.name)}</b></span>`:'<span>لم يتم تعيين مندوب</span>'}</footer></article>`;
  }
  async function runAssignment(id,courierId){
    const key=String(id);if(pending.has(key)){notify('العملية قيد التنفيذ');return false}
    setBusy(key,true);
    try{
      const result=await assignOrder(key,courierId||null,null);
      if(typeof audit==='function')await audit('courier',courierId?`تحويل الطلب ${key} إلى المندوب ${courierId}`:`إلغاء تعيين المندوب عن الطلب ${key}`);
      renderDeliveryOrdersAdmin();
      notify(courierId?'تم تحويل الطلب للمندوب':'تم إلغاء تعيين المندوب');
      return result;
    }catch(error){console.error('[ALIN courier assignment v4.1.2]',error);notify(friendlyOrderError(error));return false}
    finally{setBusy(key,false)}
  }
  window.alinV164Assign=async function(id){
    const selected=document.querySelector(`input[name="v216assign_${CSS.escape(String(id))}"]:checked`)?.value;
    if(!selected){notify('اختر مندوباً أولاً');return false}
    return runAssignment(id,selected);
  };
  window.alinV410Unassign=async function(id){if(!confirm('تأكيد إلغاء تعيين المندوب عن الطلب؟'))return false;return runAssignment(id,null)};
  window.alinV161AssignOrder=window.alinV164Assign;

  async function assignCourier(id){
    const selected=$(`#assign_${CSS.escape(String(id))}`)?.value||null;
    const result=await runAssignment(id,selected);
    if(result&&typeof renderCourierSettlementsAdmin==='function')renderCourierSettlementsAdmin();
    return Boolean(result);
  }
  async function courierOrderStatus(id,status){
    const key=String(id);if(pending.has(key)){notify('العملية قيد التنفيذ');return false}
    setBusy(key,true);
    try{
      await transitionOrder(key,status);
      if(typeof renderCourierSettlementsAdmin==='function')renderCourierSettlementsAdmin();
      notify('تم تحديث حالة الطلب');
      return true;
    }catch(error){console.error('[ALIN courier status admin v4.1.2]',error);notify(friendlyOrderError(error));return false}
    finally{setBusy(key,false)}
  }

  window.renderDeliveryOrdersAdmin=renderDeliveryOrdersAdmin;
  window.assignCourier=assignCourier;
  window.courierOrderStatus=courierOrderStatus;
  Object.assign(window.AlinCourierModules,{assignCourier,courierOrderStatus,renderDeliveryOrdersAdmin});
  window.AlinAdminModules?.register?.('deliveryOrders',renderDeliveryOrdersAdmin);
})();

;
;

/* modules/courier/dashboard.js */
// === courier/dashboard.js ===
/* ALIN v4.1.2 — courier-facing dashboard using the authoritative server workflow. */
(function(){
  'use strict';
  const core=window.AlinCourierCore;if(!core)throw new Error('AlinCourierCore is required before courier/dashboard.js');
  const {$,$$,arr,escv,moneyv,now,notify,currentAccount,dbx,areasOf,statusOf,statusLabel,resolveCourier,allOrders,myOrders,done,active,today,financials,orderState,friendlyOrderError,mapLink,hasExactGps,phoneLink,waLink,fmtDate,transitionOrder,refreshCourierData,resetRefresh}=core;
  let renderSerial=0;
  const pendingOrders=new Set();
  function ensureTabs(){const nav=$('.courier-v161-tabs');if(!nav)return;const wanted=[['home','الرئيسية'],['current','طلبات التوصيل'],['completed','المكتملة'],['finance','الحسابات'],['receipts','الوصولات'],['notifications','الإشعارات'],['profile','حسابي']];nav.innerHTML=wanted.map(([key,label])=>key==='receipts'?`<button type="button" id="courierReceiptsTab" data-courier-tab="receipts" data-alin415-receipts-role="courier">${label}</button>`:`<button type="button" data-courier-tab="${key}" data-alin-click="renderCourierDashboard" data-alin-click-arg0="${key}">${label}${key==='current'?'<span id="courierCurrentBadge" hidden>0</span>':''}${key==='notifications'?'<span id="courierNotifyBadge" hidden>0</span>':''}</button>`).join('')}
  function notificationsFor(c){return window.AlinNotifications?.visible?.({role:'courier',id:String(c?.id||'')})||arr(dbx().notifications).filter(n=>String(n.courier_id||n.user_id||n.recipient_id||n.target_id||'')===String(c?.id)||['courier','delegate','all'].includes(String(n.target_role||n.role||n.audience||''))).sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||'')))}
  function setHeader(c,tab){const name=$('#courierV161Name'),areas=$('#courierV161Areas');if(name)name.textContent=c?.name||currentAccount()?.name||'المندوب';if(areas)areas.textContent=areasOf(c).join('، ')||'غير محددة';$$('.courier-v161-tabs [data-courier-tab]').forEach(b=>b.classList.toggle('active',b.dataset.courierTab===tab));const cb=$('#courierCurrentBadge'),nb=$('#courierNotifyBadge'),activeCount=myOrders(c).filter(active).length,unread=window.AlinNotifications?.unreadCount?.({role:'courier',id:String(c?.id||'')})??notificationsFor(c).filter(n=>!(n.read_at||n.is_read)).length;if(cb){cb.textContent=activeCount;cb.hidden=!activeCount}if(nb){nb.textContent=unread;nb.hidden=!unread}}
  function summary(c,rows){const f=financials(c);return `<section class="v174-metrics"><article><small>طلبات جديدة</small><strong>${rows.filter(o=>['assigned','new','pending_admin'].includes(String(o.status||''))).length}</strong></article><article><small>قيد التوصيل</small><strong>${rows.filter(o=>['accepted','picked_up','out_for_delivery','processing'].includes(String(o.status||''))).length}</strong></article><article><small>تم التسليم اليوم</small><strong>${rows.filter(o=>done(o)&&today(o)).length}</strong></article><article><small>كل المكتملة</small><strong>${rows.filter(done).length}</strong></article><article><small>أرباح التوصيل</small><strong>${moneyv(f.earnings)} د.ع</strong></article><article class="debt"><small>ذمتك للإدارة</small><strong>${moneyv(f.debt)} د.ع</strong></article></section>`}
  function homeHtml(c,rows){const currentRows=rows.filter(active).slice(0,5),notes=notificationsFor(c).slice(0,4);return `${summary(c,rows)}<section class="v174-home-grid"><article class="v174-panel"><header><div><small>حالة العمل</small><h2>${statusLabel(statusOf(c))}</h2></div><span class="v174-status ${statusOf(c)}"></span></header><div class="v174-status-actions"><button data-alin-click="alinV174QuickStatus" data-alin-click-arg0="available">متاح</button><button data-alin-click="alinV174QuickStatus" data-alin-click-arg0="busy">مشغول</button><button data-alin-click="alinV174QuickStatus" data-alin-click-arg0="offline">خارج الخدمة</button></div><p>مناطق العمل: ${escv(areasOf(c).join('، ')||'غير محددة')}</p></article><article class="v174-panel"><header><div><small>طلبات تحتاج متابعة</small><h2>طلباتك الحالية</h2></div><button data-alin-click="renderCourierDashboard" data-alin-click-arg0="current">عرض الكل</button></header><div class="v174-mini-list">${currentRows.map(o=>`<button data-alin-click="renderCourierDashboard" data-alin-click-arg0="current"><b>${escv(o.order_number||o.id)}</b><span>${escv(window.alinNormalizeDeliveryArea(o.delivery_area)||'—')}</span><small>${escv(orderState(String(o.status||'')))}</small></button>`).join('')||'<p class="empty">لا توجد طلبات حالياً.</p>'}</div></article><article class="v174-panel wide"><header><div><small>آخر الإشعارات</small><h2>تنبيهات المندوب</h2></div><button data-alin-click="renderCourierDashboard" data-alin-click-arg0="notifications">عرض الإشعارات</button></header><div class="v174-mini-list">${notes.map(n=>`<div><b>${escv(n.title||'إشعار')}</b><span>${escv(n.message||n.body||'')}</span><small>${escv(fmtDate(n.created_at))}</small></div>`).join('')||'<p class="empty">لا توجد إشعارات جديدة.</p>'}</div></article></section>`}
  function orderCard(o,actions=true){const st=String(o.status||'assigned'),phone=o.student_phone||'',map=mapLink(o),exactGps=hasExactGps(o),first=['assigned','new','pending_admin'].includes(st),accepted=st==='accepted',picked=st==='picked_up',moving=st==='out_for_delivery';return `<article class="v174-order" data-courier-order="${escv(o.id)}"><header><div><small>${escv(o.order_number||o.id)}</small><h3>${escv(o.title||'طلب توصيل')}</h3></div><span class="v174-order-state ${escv(st)}">${escv(orderState(st))}</span></header><div class="v174-order-data"><div><small>الطالب</small><b>${escv(o.student_name||'—')}</b></div><div><small>الهاتف</small><b>${escv(phone||'—')}</b></div><div><small>المنطقة</small><b>${escv(window.alinNormalizeDeliveryArea(o.delivery_area)||'—')}</b></div><div><small>المبلغ المطلوب</small><b>${moneyv(o.total)} د.ع</b></div><div><small>ربح التوصيل</small><b>${moneyv(o.delegate_profit||o.courier_profit||window.AlinFinance?.shares?.(o)?.delegate||0)} د.ع</b></div><div class="wide"><small>أقرب نقطة دالة</small><b>${escv(o.delivery_landmark||'—')}</b></div></div><div class="v174-links">${phone?`<a href="${phoneLink(phone)}">اتصال</a><a href="${waLink(phone)}" target="_blank" rel="noopener">واتساب</a>`:''}${map?`<button type="button" class="map" data-alin-click="alinCourierOpenMap" data-alin-click-arg0="${escv(o.id)}">${exactGps?'فتح الموقع GPS':'فتح النقطة على الخريطة'}</button>`:''}</div>${actions?`<div class="v174-actions">${first?`<button data-alin-click="alinV164CourierStep" data-alin-click-arg0="${escv(o.id)}" data-alin-click-arg1="accepted">قبول الطلب</button><button class="reject" data-alin-click="alinV174Reject" data-alin-click-arg0="${escv(o.id)}">رفض الطلب</button>`:''}${accepted?`<button data-alin-click="alinV164CourierStep" data-alin-click-arg0="${escv(o.id)}" data-alin-click-arg1="picked_up">استلمت الطلب</button>`:''}${picked?`<button data-alin-click="alinV164CourierStep" data-alin-click-arg0="${escv(o.id)}" data-alin-click-arg1="out_for_delivery">بدء التوصيل</button>`:''}${moving?`<button class="success" data-alin-click="alinV164CourierComplete" data-alin-click-arg0="${escv(o.id)}">تم التسليم واستلام المبلغ</button>`:''}<button class="secondary" data-alin-click="alinV164ReportIssue" data-alin-click-arg0="${escv(o.id)}">إرسال ملاحظة للإدارة</button></div>`:`<footer>تم التسليم: ${escv(fmtDate(o.delivered_at||o.completed_at||o.updated_at))}</footer>`}</article>`}
  function ordersHtml(c,rows,completed=false){const list=rows.filter(completed?done:active);return `${summary(c,rows)}<section class="v174-head"><div><small>${completed?'سجل الإنجاز':'طلبات التوصيل'}</small><h2>${completed?'الطلبات المكتملة':'طلباتك الحالية'}</h2></div><span>${list.length}</span></section><div class="v174-orders">${list.map(o=>orderCard(o,!completed)).join('')||`<div class="empty">${completed?'لا توجد طلبات مكتملة بعد.':'لا توجد طلبات مسندة إليك حالياً.'}</div>`}</div>`}
  function financeHtml(c,rows){const f=financials(c),doneRows=rows.filter(done);return `${summary(c,rows)}<section class="v164-finance-grid"><article><small>المبالغ المستلمة</small><strong>${moneyv(f.collected)} د.ع</strong></article><article><small>أرباح التوصيل</small><strong>${moneyv(f.earnings)} د.ع</strong></article><article><small>المسدّد للإدارة</small><strong>${moneyv(f.paid)} د.ع</strong></article><article class="debt"><small>المبلغ بذمتك</small><strong>${moneyv(f.debt)} د.ع</strong></article></section><section class="v164-table-card"><h2>كشف الطلبات المالية</h2><div class="v164-finance-list">${doneRows.map(o=>`<div><span>${escv(o.order_number||o.id)}</span><span>${moneyv(o.total)} د.ع</span><span>ربح التوصيل ${moneyv(o.delegate_profit||o.courier_profit||window.AlinFinance?.shares?.(o)?.delegate||0)} د.ع</span><span>${escv(fmtDate(o.delivered_at||o.updated_at))}</span></div>`).join('')||'<p class="empty">لا توجد حركات مالية بعد.</p>'}</div></section>`}
  function notificationsHtml(c,rows){const notes=notificationsFor(c);return `${summary(c,rows)}<section class="v164-section-head"><div><h2>إشعارات المندوب</h2><p>الطلبات الجديدة ورسائل الإدارة والتسويات.</p></div><button data-alin-click="alinV164CourierReadAll">تحديد الكل كمقروء</button></section><div class="v164-notifications">${notes.map(n=>{const read=window.AlinNotifications?.isRead?.(n,{role:'courier',id:String(c?.id||'')})??Boolean(n.read_at||n.is_read);return `<article class="${read?'read':''}"><div><h3>${escv(n.title||'إشعار')}</h3><p>${escv(n.message||n.body||'')}</p><small>${escv(fmtDate(n.created_at))}</small></div>${read?'':`<button data-alin-click="alinV164CourierRead" data-alin-click-arg0="${escv(n.id)}">مقروء</button>`}</article>`}).join('')||'<div class="empty">لا توجد إشعارات.</div>'}</div>`}
  function profileHtml(c,rows){return `${summary(c,rows)}<section class="v164-profile"><div class="v164-profile-head"><div class="v161-avatar">${escv((c.name||'م').slice(0,1))}</div><div><h2>${escv(c.name||'مندوب')}</h2><p>${escv(c.phone||currentAccount()?.phone||'بدون هاتف')}</p></div><span class="v161-status ${statusOf(c)}">${statusLabel(statusOf(c))}</span></div><div class="v164-profile-fields"><label>حالة العمل<select id="v161MyAvailability"><option value="available" ${statusOf(c)==='available'?'selected':''}>متاح</option><option value="busy" ${statusOf(c)==='busy'?'selected':''}>مشغول</option><option value="offline" ${statusOf(c)==='offline'?'selected':''}>خارج الخدمة</option></select></label><div><small>مناطق العمل</small><div class="v161-area-chips">${areasOf(c).map(a=>`<span>${escv(a)}</span>`).join('')||'<span>غير محددة</span>'}</div></div></div><button data-alin-click="alinV161SaveMyStatus">حفظ الحالة</button></section>`}
  function unavailableHtml(){return `<section class="v174-panel"><h2>تعذر ربط صفحة المندوب بالحساب</h2><p>اضغط إعادة المحاولة. إذا استمرت الحالة افتح حساب المندوب من لوحة المدير واحفظه مرة واحدة.</p><button data-alin-click="alinRefreshCourierPage">إعادة تحميل بيانات المندوب</button></section>`}
  async function renderCourierDashboard(tab='home',options={}){const serial=++renderSerial,box=$('#courierV161Content');if(!box)return false;ensureTabs();let c=resolveCourier();setHeader(c,tab);if(!c){box.innerHTML=unavailableHtml();return false}let rows=myOrders(c);const paint=()=>{if(serial!==renderSerial)return;setHeader(c,tab);if(tab==='home')box.innerHTML=homeHtml(c,rows);else if(tab==='current')box.innerHTML=ordersHtml(c,rows,false);else if(tab==='completed')box.innerHTML=ordersHtml(c,rows,true);else if(tab==='finance')box.innerHTML=financeHtml(c,rows);else if(tab==='notifications')box.innerHTML=notificationsHtml(c,rows);else box.innerHTML=profileHtml(c,rows)};paint();if(options.refresh!==false){c=await refreshCourierData(Boolean(options.force));if(serial!==renderSerial)return true;if(!c){box.innerHTML=unavailableHtml();return false}rows=myOrders(c);paint()}return true}
  async function transitionCourierOrder(id,status,reason=''){
    const key=String(id);
    if(pendingOrders.has(key)){notify('العملية قيد التنفيذ');return false}
    pendingOrders.add(key);
    document.querySelectorAll(`[data-courier-order="${CSS.escape(key)}"] button`).forEach(button=>button.disabled=true);
    try{
      await transitionOrder(key,status,reason);
      await refreshCourierData(true);
      await renderCourierDashboard('current',{refresh:false});
      notify(status==='completed'?'تم تسجيل التسليم والحسابات':'تم تحديث حالة الطلب');
      return true;
    }catch(error){console.error('[ALIN courier transition]',error);notify(friendlyOrderError(error));return false}
    finally{pendingOrders.delete(key)}
  }
  window.alinV164CourierStep=async function(id,status){return transitionCourierOrder(id,status)};
  window.alinV164CourierComplete=async function(id){if(!confirm('تأكيد تسليم الطلب واستلام المبلغ من الطالب؟'))return false;return transitionCourierOrder(id,'completed')};
  window.alinV164ReportIssue=async function(id){
    const note=(prompt('اكتب الملاحظة أو المشكلة لإرسالها إلى الإدارة')||'').trim();if(!note)return false;
    try{const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)throw new Error('خدمة إرسال الملاحظة غير متاحة');const {data,error}=await client.rpc('alin_courier_set_order_note',{p_order_id:String(id),p_note:note});if(error)throw error;if(!data?.ok)throw new Error(data?.error||'لم يؤكد الخادم حفظ الملاحظة');const row=allOrders().find(x=>String(x.id)===String(id));if(row&&data.order)Object.assign(row,data.order);await refreshCourierData(true);await renderCourierDashboard('current',{refresh:false});notify('تم إرسال الملاحظة للإدارة');return true}catch(error){console.error('[ALIN courier note]',error);notify(friendlyOrderError(error));return false}
  };
  window.alinV174Reject=async function(id){const reason=(prompt('اكتب سبب رفض الطلب')||'').trim();if(!reason)return false;if(!confirm('تأكيد رفض الطلب؟'))return false;return transitionCourierOrder(id,'rejected',reason)};
  window.alinV174QuickStatus=async function(value){const c=resolveCourier();if(!c)return false;try{const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)throw new Error('خدمة تحديث حالة المندوب غير متاحة');const {data,error}=await client.rpc('alin_courier_set_availability',{p_value:String(value||'')});if(error)throw error;if(!data?.ok)throw new Error(data?.error||'لم يؤكد الخادم تحديث الحالة');if(data.courier)Object.assign(c,data.courier);else c.availability=value;await refreshCourierData(true);await renderCourierDashboard('home',{refresh:false});notify('تم تحديث حالة المندوب');return true}catch(error){alert(error.message||'تعذر تحديث الحالة');return false}};
  window.alinV161SaveMyStatus=async function(){return window.alinV174QuickStatus($('#v161MyAvailability')?.value||'available')};
  window.alinV161CourierStatus=window.alinV164CourierStep;
  window.alinV164CourierRead=async function(id){try{const c=resolveCourier();if(window.AlinNotifications?.markRead)await window.AlinNotifications.markRead(id,{role:'courier',id:String(c?.id||'')});else await update('notifications',{is_read:true,read_at:now()},{id});await renderCourierDashboard('notifications',{refresh:false})}catch(error){alert(error.message||'تعذر تحديث الإشعار')}};
  window.alinV164CourierReadAll=async function(){const c=resolveCourier();if(window.AlinNotifications?.markAll)await window.AlinNotifications.markAll({role:'courier',id:String(c?.id||'')});await renderCourierDashboard('notifications',{refresh:false})};
  window.alinRefreshCourierPage=async function(){resetRefresh();const box=$('#courierV161Content');if(box)box.innerHTML='<div class="empty">جاري تحميل بيانات المندوب والطلبات...</div>';await refreshCourierData(true);return renderCourierDashboard('home',{refresh:false})};


  window.renderCourierDashboard=renderCourierDashboard;
  window.AlinCourierDashboard=Object.freeze({version:window.ALIN_CONFIG?.version||'4.2.0-rc.21',resolveCourier,myOrders,refreshCourierData,render:renderCourierDashboard});

  window.addEventListener('alin:page-open',event=>{if(event.detail?.page==='courier')renderCourierDashboard('home',{force:true})});
  window.addEventListener('alin:data-refreshed',()=>{if($('#courierPage:not(.hidden)'))renderCourierDashboard($('.courier-v161-tabs .active')?.dataset.courierTab||'home',{refresh:false})});
  window.addEventListener('alin:auth-login',event=>{if(event.detail?.account?.role==='courier')setTimeout(()=>renderCourierDashboard('home',{force:true}),0)});
  window.addEventListener('alin:auth-restored',event=>{if(event.detail?.account?.role==='courier')setTimeout(()=>renderCourierDashboard('home',{force:true}),0)});
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',ensureTabs,{once:true});else ensureTabs();
})();

;
;

/* modules/courier/finance.js */
// === courier/finance.js ===
/* ===== courier/js/settlements.js ===== */
/* V111: actual courier code moved from core/js/platform-legacy.js */
window.AlinCourierModules=window.AlinCourierModules||{};
function renderCourierSettlementsAdmin(){
  const deliveryOrders=(db.orders||[]).filter(o=>o.fulfillment_type==='home_delivery');
  const courierSettlements=(db.settlements||[]).filter(s=>['delegate','courier'].includes(String(s.party_role||'').toLowerCase()));
  adminContent.innerHTML='<h2>تسويات المندوبين</h2><p class="muted">المندوب يستلم مبلغ الطلب من الطالب عند التسليم، ثم يسلم المبلغ للإدارة بسند قبض.</p>'+deliveryOrders.map(o=>`<div class="row"><div><b>${esc(o.order_number||o.id)} — ${esc(o.title)}</b><small>الطالب: ${esc(o.student_name)} • المنطقة: ${esc(o.delivery_area||'')} • أقرب نقطة: ${esc(o.delivery_landmark||'')} • المبلغ ${money(o.total)} د.ع • الحالة ${esc(o.status||'')}</small></div><div class="row-actions"><select id="assign_${o.id}"><option value="">مندوب</option>${couriers.map(c=>`<option value="${c.id}" ${o.courier_id===c.id?'selected':''}>${esc(c.name)}</option>`).join('')}</select><button data-alin-click="assignCourier" data-alin-click-arg0="${o.id}">حفظ</button><button data-alin-click="courierOrderStatus" data-alin-click-arg0="${o.id}" data-alin-click-arg1="out_for_delivery">قيد التوصيل</button><button data-alin-click="courierOrderStatus" data-alin-click-arg0="${o.id}" data-alin-click-arg1="completed">تم التسليم</button></div></div>`).join('')+(deliveryOrders.length?'':'لا توجد طلبات توصيل')+'<h3>سندات تسوية المندوبين</h3>'+(courierSettlements.map(s=>`<div class="row"><b>${esc(s.receipt_number)}</b><span>${money(s.amount)} د.ع</span></div>`).join('')||emptyState('لا توجد تسويات'));
}

async function recordCourierSettlementForOrder(orderId){
  const o=(db.orders||[]).find(x=>x.id===orderId);if(!o)return false;
  const courierId=o.delegate_id||o.courier_id;if(!courierId)return alert('الطلب غير مرتبط بمندوب');
  if(!window.AlinFinance?.settleDelegate)throw new Error('خدمة تسوية المندوب غير جاهزة');
  const result=await window.AlinFinance.settleDelegate(courierId);
  if(result&&typeof audit==='function')await audit('courier','تسوية مندوب للطلب '+(o.order_number||o.id));
  if(typeof renderCourierSettlementsAdmin==='function')renderCourierSettlementsAdmin();
  return result;
}
window.AlinCourierModules['renderCourierSettlementsAdmin']=typeof renderCourierSettlementsAdmin==='function'?renderCourierSettlementsAdmin:window['renderCourierSettlementsAdmin'];window['renderCourierSettlementsAdmin']=window.AlinCourierModules['renderCourierSettlementsAdmin'];
window.AlinCourierModules['recordCourierSettlementForOrder']=typeof recordCourierSettlementForOrder==='function'?recordCourierSettlementForOrder:window['recordCourierSettlementForOrder'];window['recordCourierSettlementForOrder']=window.AlinCourierModules['recordCourierSettlementForOrder'];


;
;

/* modules/core/security.js */
// === core/security.js ===
/* ===== core/js/auth-security-v214.js ===== */
/* ALIN V214 — idle-session protection without replacing navigation or auth functions. */
(function(){
  'use strict';
  const SESSION='alin_secure_session_v214';
  const IDLE_BY_ROLE={admin:15,accountant:15,teacher:30,library:30,courier:30,student:60,store:60};
  const WARN_MS=2*60*1000;
  let idleTimer=null,warningTimer=null,lastActivity=Date.now(),warningBox=null;
  const currentNow=()=>{try{return window.current||null}catch(_){return null}};
  function setSession(user){
    if(!user?.role)return;
    const data={role:user.role,id:user.id||'',username:user.username||'',startedAt:Date.now(),lastActivity:Date.now()};
    try{sessionStorage.setItem(SESSION,JSON.stringify(data))}catch(_){}
    lastActivity=Date.now();scheduleIdle();
  }
  function clearTimers(){if(idleTimer)clearTimeout(idleTimer);if(warningTimer)clearTimeout(warningTimer);idleTimer=warningTimer=null}
  function hideWarning(){if(warningBox)warningBox.hidden=true}
  function clearSession(){try{sessionStorage.removeItem(SESSION)}catch(_){}clearTimers();hideWarning()}
  function idleLimit(){return (IDLE_BY_ROLE[String(currentNow()?.role||'')]||30)*60*1000}
  function touch(){
    if(!currentNow())return;
    lastActivity=Date.now();
    try{const data=JSON.parse(sessionStorage.getItem(SESSION)||'{}');data.lastActivity=lastActivity;sessionStorage.setItem(SESSION,JSON.stringify(data))}catch(_){}
    hideWarning();scheduleIdle();
  }
  function scheduleIdle(){
    clearTimers();if(!currentNow())return;
    const remain=Math.max(0,idleLimit()-(Date.now()-lastActivity));
    if(remain<=0)return expireSession();
    warningTimer=setTimeout(showWarning,Math.max(0,remain-WARN_MS));
    idleTimer=setTimeout(expireSession,remain);
  }
  function showWarning(){
    if(!currentNow())return;
    if(!warningBox){warningBox=document.createElement('div');warningBox.className='alin-session-warning';warningBox.innerHTML='<strong>ستنتهي الجلسة قريباً</strong><span>اضغط استمرار حتى تبقى داخل الحساب.</span><button type="button">استمرار</button>';warningBox.querySelector('button').addEventListener('click',touch);document.body.appendChild(warningBox)}
    warningBox.hidden=false;
  }
  function expireSession(){
    if(!currentNow())return;clearSession();
    try{window.toast?.('انتهت الجلسة لعدم النشاط')}catch(_){}
    Promise.resolve(window.logout?.()).catch(error=>console.error('[ALIN idle logout]',error));
  }
  function install(){
    window.addEventListener('alin:auth-login',event=>setSession(event.detail?.account||currentNow()));
    window.addEventListener('alin:auth-restored',event=>setSession(event.detail?.account||currentNow()));
    window.addEventListener('alin:page-open',()=>{if(currentNow())setSession(currentNow())});
    window.addEventListener('alin:logout',clearSession);
    ['click','keydown','touchstart','pointerdown'].forEach(ev=>document.addEventListener(ev,touch,{passive:true}));
    document.addEventListener('visibilitychange',()=>{if(!document.hidden)touch()});
    if(currentNow())setSession(currentNow());
    window.ALINSecureSession=Object.freeze({version:'214.1',touch,expire:expireSession,clear:clearSession});
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
})();

/* ===== core/js/file-security-v168.js ===== */
/* ALIN V168 — file upload and URL safety without changing current auth. */
(function(){
  'use strict';
  const RULES={
    image:{ext:['png','jpg','jpeg','webp'],mime:['image/png','image/jpeg','image/webp'],max:5*1024*1024},
    pdf:{ext:['pdf'],mime:['application/pdf'],max:25*1024*1024},
    word:{ext:['docx'],mime:['application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/octet-stream'],max:20*1024*1024}
  };
  const BLOCKED=['exe','msi','bat','cmd','com','scr','ps1','js','mjs','html','htm','svg','php','jar','apk','sh','dll'];
  const safeName=v=>String(v||'file').normalize('NFKC').replace(/[\\/:*?"<>|\u0000-\u001f]/g,'_').replace(/\s+/g,' ').trim().slice(0,120)||'file';
  const ext=n=>{const s=String(n||'').toLowerCase().split('.');return s.length>1?s.pop():''};
  function kindFor(input){
    const a=String(input.getAttribute('accept')||'').toLowerCase(),id=(input.id+' '+input.name+' '+input.className).toLowerCase();
    if(a.includes('pdf')||id.includes('pdf'))return 'pdf';
    if(a.includes('word')||a.includes('docx')||id.includes('word')||id.includes('source_file'))return 'word';
    if(a.includes('image')||id.includes('image')||id.includes('cover')||id.includes('logo')||id.includes('icon'))return 'image';
    return '';
  }
  function signatureOK(file,kind){
    return file.slice(0,8).arrayBuffer().then(b=>{
      const x=[...new Uint8Array(b)];
      if(kind==='pdf')return x[0]===0x25&&x[1]===0x50&&x[2]===0x44&&x[3]===0x46;
      if(kind==='word')return x[0]===0x50&&x[1]===0x4b&&x[2]===0x03&&x[3]===0x04;
      if(kind==='image')return (x[0]===0x89&&x[1]===0x50&&x[2]===0x4e&&x[3]===0x47)||(x[0]===0xff&&x[1]===0xd8&&x[2]===0xff)||(x[0]===0x52&&x[1]===0x49&&x[2]===0x46&&x[3]===0x46);
      return true;
    }).catch(()=>false);
  }
  async function validate(file,kind){
    const e=ext(file.name);
    if(BLOCKED.includes(e))return {ok:false,msg:'هذا النوع من الملفات محظور لأسباب أمنية.'};
    const rule=RULES[kind];
    if(!rule)return {ok:true,name:safeName(file.name)};
    if(!rule.ext.includes(e))return {ok:false,msg:'صيغة الملف غير مسموحة في هذا الحقل.'};
    if(file.size<=0||file.size>rule.max)return {ok:false,msg:`حجم الملف غير مسموح. الحد الأعلى ${Math.round(rule.max/1024/1024)} MB.`};
    if(file.type&&!rule.mime.includes(file.type))return {ok:false,msg:'نوع الملف لا يطابق الصيغة المطلوبة.'};
    if(!(await signatureOK(file,kind)))return {ok:false,msg:'محتوى الملف لا يطابق امتداده وقد يكون غير آمن.'};
    return {ok:true,name:safeName(file.name)};
  }
  function notify(msg){try{if(typeof window.toast==='function')return window.toast(msg)}catch(_){};alert(msg)}
  async function onFile(e){
    const input=e.target;if(!(input instanceof HTMLInputElement)||input.type!=='file'||!input.files?.length)return;
    const kind=kindFor(input),files=[...input.files];
    for(const file of files){const r=await validate(file,kind);if(!r.ok){input.value='';notify(r.msg);input.setCustomValidity(r.msg);return}}
    input.setCustomValidity('');input.dataset.alinValidated='true';
  }
  function safeURL(value){
    try{
      const u=new URL(value,location.href);
      if(!['https:','http:','blob:','data:'].includes(u.protocol))return false;
      if(u.protocol==='data:'&&!String(value).startsWith('data:image/'))return false;
      return true;
    }catch(_){return false}
  }
  function harden(root){
    (root||document).querySelectorAll('a[href]').forEach(a=>{if(!safeURL(a.href)){a.removeAttribute('href');a.setAttribute('aria-disabled','true')}});
    (root||document).querySelectorAll('iframe[src]').forEach(f=>{if(!safeURL(f.src)){f.removeAttribute('src')}f.setAttribute('referrerpolicy','no-referrer');if(!f.hasAttribute('sandbox'))f.setAttribute('sandbox','allow-scripts allow-same-origin allow-forms allow-modals')});
  }
  function install(){
    document.addEventListener('change',onFile,true);harden(document);
    window.ALINFileSecurity=Object.freeze({version:'168.1',validate,safeName,safeURL,harden});
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
})();

/* ===== core/js/sensitive-operations-v169.js ===== */
(function(){
  'use strict';

  const state = {
    lastActionAt: new Map(),
    pending: new Set()
  };

  const now = () => Date.now();
  const safeText = value => String(value == null ? '' : value).replace(/[<>]/g, '');
  const getCurrentRole = () => {
    try {
      if (window.current && current.role) return String(current.role);
      if (window.currentUser && currentUser.role) return String(currentUser.role);
      const raw = sessionStorage.getItem('alin_current_user') || localStorage.getItem('alin_current_user');
      if (raw) return String(JSON.parse(raw)?.role || '');
    } catch (_) {}
    return '';
  };

  const toastMessage = message => {
    if (typeof window.toast === 'function') return window.toast(message);
    const node = document.createElement('div');
    node.className = 'toast';
    node.textContent = safeText(message);
    document.body.appendChild(node);
    setTimeout(() => node.remove(), 2800);
  };

  function rateLimit(key, milliseconds){
    const last = state.lastActionAt.get(key) || 0;
    if (now() - last < milliseconds) return false;
    state.lastActionAt.set(key, now());
    return true;
  }

  function requireRole(allowed){
    const role = getCurrentRole();
    if (!allowed.includes(role)) {
      toastMessage('هذه العملية غير مسموحة لهذا الحساب.');
      return false;
    }
    return true;
  }

  function confirmSensitiveAction(options){
    const title = safeText(options?.title || 'تأكيد العملية');
    const message = safeText(options?.message || 'هل أنت متأكد من تنفيذ هذه العملية؟');
    const phrase = safeText(options?.phrase || 'تأكيد');
    const input = window.prompt(`${title}\n\n${message}\n\nاكتب كلمة: ${phrase}`);
    return input === phrase;
  }

  async function guardedOperation(options, operation){
    const key = safeText(options?.key || 'operation');
    const allowedRoles = Array.isArray(options?.roles) ? options.roles : ['admin'];
    const cooldown = Number(options?.cooldown || 1500);

    if (!requireRole(allowedRoles)) return { ok:false, reason:'role' };
    if (!rateLimit(key, cooldown)) {
      toastMessage('انتظر قليلاً قبل تكرار العملية.');
      return { ok:false, reason:'rate_limit' };
    }
    if (state.pending.has(key)) {
      toastMessage('العملية قيد التنفيذ حالياً.');
      return { ok:false, reason:'pending' };
    }
    if (options?.confirm && !confirmSensitiveAction(options.confirm)) {
      return { ok:false, reason:'cancelled' };
    }

    state.pending.add(key);
    try {
      const result = await operation();
      return { ok:true, result };
    } catch (error) {
      console.error('[V169 guarded operation]', error);
      toastMessage('تعذّر إكمال العملية بأمان.');
      return { ok:false, reason:'error', error };
    } finally {
      state.pending.delete(key);
    }
  }

  function hardenDangerousButtons(){
    document.addEventListener('click', function(event){
      const button = event.target.closest('button,[role="button"]');
      if (!button) return;
      const text = (button.textContent || '').trim();
      const dangerous = /حذف نهائي|تصفية الحساب|تثبيت التسوية|إلغاء الطلب|تغيير النسب|تحويل للمندوب|إيقاف الحساب/.test(text);
      if (!dangerous) return;
      button.setAttribute('data-sensitive-operation', 'true');
      button.setAttribute('autocomplete', 'off');
    }, true);
  }

  function protectForms(){
    document.addEventListener('submit', function(event){
      const form = event.target;
      if (!(form instanceof HTMLFormElement)) return;
      if (form.dataset.submitting === '1') {
        event.preventDefault();
        return;
      }
      form.dataset.submitting = '1';
      setTimeout(() => { form.dataset.submitting = '0'; }, 1800);
    }, true);
  }

  window.AlinSecurityV169 = Object.freeze({
    guardedOperation,
    requireRole,
    rateLimit,
    confirmSensitiveAction,
    getCurrentRole
  });

  hardenDangerousButtons();
  protectForms();
})();

/* Legacy auth stabilizer removed: navigation and Supabase Auth now have single owners. */



;
;

/* modules/admin/backup.js */
// === admin/backup.js ===
/* ALIN v2.4.2 — authoritative backup owner. No admin router wrapping. */
(function(){
  'use strict';
  const VERSION='3.0.3';
  const LOG_KEY='alin_backup_log_v227';
  const RESTORABLE=['categories','products','booklets','banners','coupons'];
  let pending=null;
  const escv=value=>typeof window.esc==='function'?window.esc(value):String(value??'');
  const clone=value=>JSON.parse(JSON.stringify(value??{}));
  const bytesLabel=value=>{const n=Number(value||0);if(n<1024)return `${n} B`;if(n<1048576)return `${(n/1024).toFixed(1)} KB`;return `${(n/1048576).toFixed(1)} MB`};
  const filename=()=>`Alin_Backup_${new Date().toISOString().replace(/[:T]/g,'-').slice(0,19)}.json`;
  const rows=value=>Array.isArray(value)?value:[];
  function logs(){try{return JSON.parse(localStorage.getItem(LOG_KEY)||'[]')}catch(_){return[]}}
  function saveLogs(value){localStorage.setItem(LOG_KEY,JSON.stringify(rows(value).slice(0,30)))}
  function addLog(name,size,type='manual',status='created'){
    const value=logs();value.unshift({id:`B${Date.now()}`,name,size,type,status,created_at:new Date().toISOString()});saveLogs(value);
  }
  function snapshot(){
    const source=clone(window.db||{});
    const data={
      settings:source.settings||{},categories:rows(source.categories),products:rows(source.products),
      booklets:rows(source.booklets).map(({pdf_url,pdf_path,file_url,file_path,...row})=>row),
      banners:rows(source.banners),coupons:rows(source.coupons)
    };
    return {
      app:'ALIN',format:'alin-cloud-backup',backup_version:VERSION,created_at:new Date().toISOString(),
      schema:'catalog-settings-v2-no-personal-data',
      counts:{booklets:data.booklets.length,products:data.products.length,categories:data.categories.length,banners:data.banners.length,coupons:data.coupons.length},
      data
    };
  }
  function downloadObject(object,name){
    const blob=new Blob([JSON.stringify(object,null,2)],{type:'application/json;charset=utf-8'}),link=document.createElement('a');
    link.href=URL.createObjectURL(blob);link.download=name;document.body.appendChild(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(link.href),1000);return blob.size;
  }
  function validate(object){
    if(!object||object.app!=='ALIN'||object.format!=='alin-cloud-backup'||!object.data||typeof object.data!=='object')throw new Error('الملف ليس نسخة احتياطية صالحة لمنصة آلين');
    if(!object.backup_version)throw new Error('نسخة الاحتياط غير معروفة الإصدار');
    return object;
  }
  function cleanRow(row){
    const result={};for(const [key,value] of Object.entries(row||{})){if(key.startsWith('_')||value===undefined)continue;result[key]=value}return result;
  }
  async function cloudUpsert(table,value){
    const list=rows(value).map(cleanRow);if(!list.length)return 0;
    const client=window.sb;if(!client)throw new Error('الاتصال بـ Supabase غير متاح');
    const {error}=await client.from(table).upsert(list);if(error)throw new Error(`تعذر استعادة ${table}: ${error.message||error}`);return list.length;
  }
  async function restoreSettings(settings){
    if(!settings||typeof settings!=='object')return 0;let count=0;
    for(const [key,value] of Object.entries(settings)){
      if(key==='storeType'||value===undefined||value===null||typeof value==='object')continue;
      await window.settingsSet(key,String(value));count++;
    }
    return count;
  }
  async function restoreSafe(object){
    validate(object);if(!window.current||window.current.role!=='admin')throw new Error('الاستعادة متاحة للمدير فقط');
    const result={settings:0};result.settings=await restoreSettings(object.data.settings||{});
    for(const table of RESTORABLE)result[table]=await cloudUpsert(table,object.data[table]);
    if(typeof window.audit==='function')await window.audit('backup_restore',`استعادة آمنة للكتالوج والإعدادات من نسخة ${object.created_at||''}`);
    if(typeof window.load==='function')await window.load();
    return result;
  }
  function render(){
    const root=document.getElementById('adminContent');if(!root)return;const data=window.db||{},history=logs();
    root.dataset.adminModule='backup';
    root.innerHTML=`<section class="admin-backup-rc1"><header class="admin-backup-head"><div><h2>النسخ الاحتياطي والاستعادة</h2><p>نسخة كتالوج آمنة لا تحتوي أرقام الطلاب أو الطلبات أو الحسابات أو القيود المالية أو روابط ملفات الملازم الخاصة.</p></div><span class="status">v${VERSION}</span></header>
      <section class="admin-backup-summary"><article class="admin-backup-stat"><small>الطلبات</small><b>${rows(data.orders).length}</b></article><article class="admin-backup-stat"><small>الحسابات</small><b>${rows(data.accounts?.all).length}</b></article><article class="admin-backup-stat"><small>الملازم</small><b>${rows(data.booklets).length}</b></article><article class="admin-backup-stat"><small>المنتجات</small><b>${rows(data.products).length}</b></article></section>
      <section class="admin-backup-grid"><article class="admin-backup-card"><h3>إنشاء نسخة</h3><p>ينزّل ملف JSON للكتالوج والإعدادات العامة فقط، بدون بيانات شخصية أو مالية.</p><div class="admin-backup-actions"><button type="button" data-alin-click="alinCreateBackup">إنشاء وتنزيل النسخة</button></div></article>
      <article class="admin-backup-card"><h3>استعادة آمنة</h3><p>لا يتم المساس بالطلبات والحسابات والمالية أثناء الاستعادة.</p><div class="admin-backup-file"><input id="alinBackupFile" type="file" accept=".json,application/json" data-alin-change="alinReadBackup" data-alin-change-arg0-source="file0"><div id="alinBackupStatus" class="admin-backup-warning">لم يتم اختيار ملف.</div><div id="alinBackupPreview"></div><div class="admin-backup-actions"><button id="alinRestoreBtn" class="admin-backup-danger" disabled type="button" data-alin-click="alinRestoreBackup">استعادة الكتالوج والإعدادات</button></div></div></article></section>
      <article class="admin-backup-card"><h3>سجل النسخ</h3><div class="admin-backup-log">${history.length?history.map(item=>`<article><div><b>${escv(item.name)}</b><small>${new Date(item.created_at).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')} — ${bytesLabel(item.size)}</small></div><span>${item.type==='restore'?'استعادة':'نسخة'}</span></article>`).join(''):'<p class="muted">لا توجد عمليات مسجلة بعد.</p>'}</div></article></section>`;
  }
  function alinCreateBackup(){
    try{const object=snapshot(),name=filename(),size=downloadObject(object,name);addLog(name,size);render();window.toast?.('تم إنشاء النسخة الاحتياطية')}catch(error){alert(error.message||'تعذر إنشاء النسخة')}
  }
  async function alinReadBackup(file){
    pending=null;const status=document.getElementById('alinBackupStatus'),preview=document.getElementById('alinBackupPreview'),button=document.getElementById('alinRestoreBtn');if(!status||!preview||!button)return;
    if(!file){status.textContent='لم يتم اختيار ملف.';button.disabled=true;return}
    try{const object=validate(JSON.parse(await file.text()));pending=object;status.className='admin-backup-ok';status.textContent=`الملف صالح — ${file.name} — ${bytesLabel(file.size)}`;preview.innerHTML=`<pre class="admin-backup-preview">${escv(JSON.stringify({created_at:object.created_at,version:object.backup_version,settings:Object.keys(object.data.settings||{}).length,booklets:rows(object.data.booklets).length,products:rows(object.data.products).length,banners:rows(object.data.banners).length,coupons:rows(object.data.coupons).length},null,2))}</pre>`;button.disabled=false}catch(error){status.className='admin-backup-warning';status.textContent=error.message||'تعذر قراءة الملف';preview.innerHTML='';button.disabled=true}
  }
  async function alinRestoreBackup(){
    if(!pending)return alert('اختر نسخة صالحة أولاً');if(!confirm('سيتم تحديث الكتالوج والإعدادات من النسخة المختارة. الطلبات والحسابات والمالية لن تتغير. متابعة؟'))return;
    const status=document.getElementById('alinBackupStatus'),button=document.getElementById('alinRestoreBtn');if(button)button.disabled=true;if(status){status.className='admin-backup-warning';status.textContent='جارٍ الاستعادة الآمنة...'}
    try{const result=await restoreSafe(pending);addLog(`Restore_${Date.now()}.json`,0,'restore','completed');if(status){status.className='admin-backup-ok';status.textContent=`تمت الاستعادة: ${Object.values(result).reduce((sum,n)=>sum+Number(n||0),0)} سجل`};window.toast?.('تمت الاستعادة الآمنة');render()}catch(error){if(status){status.className='admin-backup-warning';status.textContent=error.message||'تعذرت الاستعادة'};if(button)button.disabled=false}
  }
  function addButton(){
    document.querySelectorAll('#adminPage .admin-tabs').forEach(tabs=>{let button=tabs.querySelector('[data-admin-tab="backup"]');if(button)return;button=document.createElement('button');button.type='button';button.textContent='النسخ الاحتياطي';button.dataset.adminTab='backup';button.setAttribute('data-alin-click','adminTab');button.setAttribute('data-alin-click-arg0','backup');const settings=tabs.querySelector('[data-admin-tab="settings"]');settings?tabs.insertBefore(button,settings):tabs.appendChild(button)})
  }
  function install(){addButton();window.AlinAdminModules?.register?.('backup',render)}
  Object.assign(window,{alinCreateBackup,alinReadBackup,alinRestoreBackup});
  window.AlinBackup=Object.freeze({snapshot,validate,restoreSafe,render});
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
})();

;
;

/* modules/core/backend-check.js */
// === core/backend-check.js ===
/* ALIN 2.0.1 — backend readiness diagnostics */
(function(){
  'use strict';
  async function checkBackendReadiness(){
    const result={ok:true,auth:false,accounts:false,orderRpc:false,issues:[]};
    try{
      const c=window.sb||(window.AlinCloud&&window.AlinCloud.client?.());
      if(!c){result.ok=false;result.issues.push('Supabase client unavailable');return result}
      result.auth=!!c.auth;
      const probe=await c.from('accounts').select('id',{head:true,count:'exact'}).limit(1);
      if(probe.error){result.ok=false;result.issues.push('accounts: '+probe.error.message)}else result.accounts=true;
      const rpc=await c.rpc('alin_create_store_orders_guarded',{p_items:[],p_customer:{name:'',phone:''},p_fulfillment:{},p_coupon_code:null,p_request_key:'00000000-0000-4000-8000-000000000000',p_device_id:'alin-readiness-device-0001'});
      if(!rpc.error){result.orderRpc=true}
      else{
        const text=String(rpc.error.message||'')+' '+String(rpc.error.code||'');
        if(/PGRST202|Could not find the function|schema cache/i.test(text)){
          result.ok=false;result.issues.push('alin_create_store_orders_guarded RPC missing');
        }else result.orderRpc=true;
      }
    }catch(error){result.ok=false;result.issues.push(error?.message||String(error))}
    window.__ALIN_BACKEND_STATUS__=result;
    return result;
  }
  window.AlinBackendCheck=checkBackendReadiness;
})();
;

/* modules/core/account-admin-service.js */
// === core/account-admin-service.js ===
/* ALIN RC7 — account administration through authenticated Edge Functions only. */
(function(){
  'use strict';
  const runtime=()=>window.ALINAuthRuntime||{};
  const client=()=>runtime().client?.()||window.sb||window.AlinCloud?.client?.()||null;
  const strongPassword=value=>String(value||'').length>=12&&/[0-9]/.test(value)&&/[A-Za-z\u0600-\u06FF]/.test(value);
  const invokeAdmin=(name,body)=>{
    const invoke=runtime().invokeAdmin;
    if(typeof invoke!=='function')throw new Error('خدمة إدارة الحسابات غير جاهزة');
    return invoke(name,body);
  };


  async function createAccount(payload){
    if(!payload?.name||!payload?.username||!payload?.password)throw new Error('أكمل الاسم واسم الدخول وكلمة المرور');
    if(!strongPassword(payload.password))throw new Error('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');
    try{
      const data=await invokeAdmin('admin-create-account',payload);
      if(typeof load==='function')await load();
      return data.account;
    }catch(error){throw new Error(error?.message||'تعذر إنشاء الحساب عبر خدمة الإدارة الآمنة')}
  }

  async function createAccountFromAdmin(){
    const button=document.getElementById('v131SaveAccountButton');
    if(button?.disabled)return null;
    const originalLabel=button?.textContent||'حفظ الحساب';
    try{
      if(button){button.disabled=true;button.textContent='جارٍ الحفظ...'}
      const role=document.getElementById('aRole')?.value||'';
      const selectedAreas=[...document.querySelectorAll('#v163CourierAreaPicker input:checked')].map(x=>String(x.value||'').trim()).filter(Boolean);
      const payload={
        role,
        name:document.getElementById('aName')?.value?.trim()||'',
        username:document.getElementById('aUser')?.value?.trim()||'',
        password:document.getElementById('aPass')?.value||'',
        phone:document.getElementById('aPhone')?.value?.trim()||document.getElementById('v163CourierPhone')?.value?.trim()||'',
        area:role==='courier'?(selectedAreas[0]||''):(document.getElementById('aArea')?.value?.trim()||''),
        landmark:role==='courier'?'':(document.getElementById('aLandmark')?.value?.trim()||''),
        availability:document.getElementById('v163CourierAvailability')?.value||'available',
        areas:selectedAreas,
        status:'active'
      };
      if(!['teacher','library','courier','accountant'].includes(role))throw new Error('اختر نوع الحساب');
      if(role==='courier'&&!payload.areas.length)throw new Error('اختر منطقة عمل واحدة على الأقل');
      if(role==='courier'&&!payload.phone)throw new Error('أدخل رقم هاتف المندوب');
      const account=await createAccount(payload);
      ['aName','aUser','aPass','aPhone','aArea','aLandmark'].forEach(id=>{const el=document.getElementById(id);if(el)el.value=''});
      document.querySelectorAll('#v163CourierAreaPicker input').forEach(el=>{el.checked=false});
      window.v131CourierAreaCount?.();
      window.v131ToggleAccountForm?.(false);
      if(typeof renderAccountsAdmin==='function')renderAccountsAdmin();
      if(typeof toast==='function')toast(`تم إنشاء الحساب: ${account.username}`);else alert(`تم إنشاء الحساب بنجاح: ${account.username}`);
      return account;
    }catch(e){
      alert(e?.message||'تعذر إنشاء الحساب');
      return null;
    }finally{
      if(button){button.disabled=false;button.textContent=originalLabel}
    }
  }

  async function repairAuthLink(accountId){
    const c=client();if(!c?.rpc||!accountId)return 0;
    const {data,error}=await c.rpc('alin_repair_auth_links',{p_account_id:String(accountId)});
    if(error){
      const text=String(error.message||'');
      if(/PGRST202|Could not find the function|schema cache/i.test(text))throw new Error('خدمة ربط الحسابات غير مهيأة في مشروع Supabase الجديد');
      throw error;
    }
    return Number(data||0);
  }
  async function updateAccountFromAdmin(payload){
    const data=await invokeAdmin('admin-update-account',payload);
    if(typeof load==='function')await load();
    return data.account;
  }
  async function resetPasswordFromAdmin(accountId,password){
    if(!strongPassword(password))throw new Error('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');
    try{
      await repairAuthLink(accountId);
      return await invokeAdmin('admin-reset-password',{account_id:accountId,password});
    }catch(error){throw new Error(error?.message||'تعذر تغيير كلمة المرور عبر خدمة الإدارة الآمنة')}
  }
  async function deleteAccountFromAdmin(accountId){return invokeAdmin('admin-delete-account',{account_id:accountId})}
  window.ALINAuth=Object.assign(window.ALINAuth||{},
    {createAccount,createAccountFromAdmin,updateAccountFromAdmin,resetPasswordFromAdmin,repairAuthLink,deleteAccountFromAdmin});
  window.addAccount=createAccountFromAdmin;
  window.ALINAccountAdmin=Object.freeze({createAccount,createAccountFromAdmin,updateAccountFromAdmin,resetPasswordFromAdmin,repairAuthLink,deleteAccountFromAdmin});
  window.dispatchEvent(new CustomEvent('alin:account-admin-ready'));
})();
;

/* modules/core/order-bell.js */
// === core/order-bell.js ===
/* ALIN v4.1.6 prepublish 1s — high quality bell + immediate assignment alerts + resilient realtime. */
(function(){
  'use strict';
  if(window.__ALIN_ORDER_BELL__)return;
  window.__ALIN_ORDER_BELL__=true;

  const VERSION='4.2.0-rc.21';
  const SOUND_URL='./assets/audio/alin-order-chime.wav?v=4.2.0-rc.21';
  const ROLE_PAGES={admin:'adminPage',library:'libraryPage',courier:'courierPage'};
  const roleState=new Map();
  const sessionSeen=new Set();
  let audioContext=null;
  let audioBuffer=null;
  let audioLoading=null;
  let realtimeChannel=null;
  let realtimeRetry=null;
  let toastTimer=null;

  const text=value=>String(value??'').trim();
  const orders=()=>Array.isArray(window.db?.orders)?window.db.orders:[];

  function role(){
    const value=text(window.current?.role).toLowerCase();
    return value==='admin'||value==='library'||value==='courier'?value:'';
  }

  function pageIsOpen(currentRole=role()){
    if(!currentRole||document.visibilityState!=='visible')return false;
    const page=document.getElementById(ROLE_PAGES[currentRole]);
    if(!page||page.hidden)return false;
    const style=getComputedStyle(page);
    return style.display!=='none'&&style.visibility!=='hidden'&&page.getClientRects().length>0;
  }

  function accountIds(currentRole=role()){
    const current=window.current||{};
    const ids=new Set([
      current.id,current.account_id,current.library_id,current.courier_id,current.delegate_id,
      current.auth_user_id,current.username
    ].filter(Boolean).map(text));

    const sources=currentRole==='courier'?
      [
        ...(Array.isArray(window.db?.accounts?.couriers)?window.db.accounts.couriers:[]),
        ...(Array.isArray(window.db?.couriers)?window.db.couriers:[]),
        ...(Array.isArray(window.couriers)?window.couriers:[])
      ]:
      currentRole==='library'?
      [
        ...(Array.isArray(window.db?.accounts?.libraries)?window.db.accounts.libraries:[]),
        ...(Array.isArray(window.db?.libraries)?window.db.libraries:[]),
        ...(Array.isArray(window.libraries)?window.libraries:[])
      ]:[];

    for(const item of sources){
      const related=[item?.id,item?.account_id,item?.library_row_id,item?.courier_row_id,item?.user_id,item?.auth_user_id,item?.username].filter(Boolean).map(text);
      if(related.some(id=>ids.has(id)))related.forEach(id=>ids.add(id));
    }
    return ids;
  }

  function libraryOrderIds(order){
    return [order?.library_id,order?.pickup_library_id,order?.assigned_library_id].filter(Boolean).map(text);
  }

  function courierOrderIds(order){
    return [order?.courier_id,order?.delegate_id,order?.courier_account_id,order?.assigned_courier_id].filter(Boolean).map(text);
  }

  function relevant(order,currentRole=role()){
    if(!order||!currentRole)return false;
    if(currentRole==='admin')return true;
    const ids=accountIds(currentRole);
    if(currentRole==='library')return libraryOrderIds(order).some(id=>ids.has(id));
    if(currentRole==='courier')return courierOrderIds(order).some(id=>ids.has(id));
    return false;
  }

  function orderId(order){return text(order?.id||order?.order_id||order?.order_number||order?.tracking_code)}
  function signature(order,currentRole=role()){
    const assignment=currentRole==='library'?libraryOrderIds(order).join('|'):currentRole==='courier'?courierOrderIds(order).join('|'):text(order?.created_at||order?.id);
    return `${currentRole}:${orderId(order)}:${assignment}`;
  }

  function markSeen(key){
    if(!key)return;
    sessionSeen.add(key);
    try{sessionStorage.setItem(`alin_order_bell_seen_${key}`,'1')}catch(_){ }
  }
  function wasSeen(key){
    if(!key)return true;
    if(sessionSeen.has(key))return true;
    try{return sessionStorage.getItem(`alin_order_bell_seen_${key}`)==='1'}catch(_){return false}
  }
  function unmarkSeen(key){
    if(!key)return;
    sessionSeen.delete(key);
    try{sessionStorage.removeItem(`alin_order_bell_seen_${key}`)}catch(_){ }
  }

  function ensureAudioContext(){
    try{
      const AudioCtx=window.AudioContext||window.webkitAudioContext;
      if(!AudioCtx)return false;
      if(!audioContext){try{audioContext=new AudioCtx({latencyHint:'interactive'})}catch(_){audioContext=new AudioCtx()}}
      if(audioContext.state==='suspended')audioContext.resume().catch(()=>{});
      return true;
    }catch(_){return false}
  }

  async function loadBellAudio(){
    if(audioBuffer)return audioBuffer;
    if(audioLoading)return audioLoading;
    if(!ensureAudioContext()||!audioContext)return null;
    audioLoading=(async()=>{
      try{
        const response=await fetch(SOUND_URL,{cache:'force-cache'});
        if(!response.ok)throw new Error(`sound ${response.status}`);
        const data=await response.arrayBuffer();
        audioBuffer=await audioContext.decodeAudioData(data.slice(0));
        return audioBuffer;
      }catch(error){
        console.warn('[ALIN order bell] sound load',error);
        return null;
      }finally{audioLoading=null}
    })();
    return audioLoading;
  }

  function fallbackBell(){
    if(!ensureAudioContext()||!audioContext)return false;
    try{
      const now=audioContext.currentTime;
      const master=audioContext.createGain();
      const compressor=audioContext.createDynamicsCompressor();
      compressor.threshold.value=-20;compressor.knee.value=16;compressor.ratio.value=3;compressor.attack.value=.003;compressor.release.value=.2;
      master.gain.setValueAtTime(0.0001,now);
      master.gain.exponentialRampToValueAtTime(0.42,now+0.012);
      master.gain.exponentialRampToValueAtTime(0.0001,now+1.25);
      master.connect(compressor);compressor.connect(audioContext.destination);
      [[783.99,0],[1046.5,.30]].forEach(([frequency,delay])=>{
        [1,2.01,3.97].forEach((partial,index)=>{
          const oscillator=audioContext.createOscillator();
          const gain=audioContext.createGain();
          const start=now+delay;
          oscillator.type=index===0?'sine':'triangle';
          oscillator.frequency.setValueAtTime(frequency*partial,start);
          gain.gain.setValueAtTime(0.0001,start);
          gain.gain.exponentialRampToValueAtTime([0.65,0.18,0.07][index],start+0.008);
          gain.gain.exponentialRampToValueAtTime(0.0001,start+[0.9,0.55,0.34][index]);
          oscillator.connect(gain);gain.connect(master);
          oscillator.start(start);oscillator.stop(start+1.0);
        });
      });
      return true;
    }catch(error){console.warn('[ALIN order bell] fallback audio',error);return false}
  }

  function bell(){
    if(!ensureAudioContext()||!audioContext)return false;
    if(audioBuffer){
      try{
        const source=audioContext.createBufferSource();
        const gain=audioContext.createGain();
        const compressor=audioContext.createDynamicsCompressor();
        source.buffer=audioBuffer;
        gain.gain.value=0.92;
        source.connect(gain);gain.connect(compressor);compressor.connect(audioContext.destination);
        source.start(0);
        return true;
      }catch(error){console.warn('[ALIN order bell] buffered audio',error)}
    }
    loadBellAudio().catch(()=>{});
    return fallbackBell();
  }

  function message(order,currentRole,reason='new'){
    const number=text(order?.order_number||order?.tracking_code||order?.id)||'—';
    const title=text(order?.title||order?.item_name||order?.product_name||order?.booklet_name);
    const suffix=title?` — ${title}`:'';
    if(currentRole==='library')return {title:reason==='assigned'?'تم تحويل طلب للمكتبة':'طلب طباعة جديد',body:`وصل طلب إلى مكتبتك: ${number}${suffix}`};
    if(currentRole==='courier')return {title:reason==='assigned'?'تم تحويل طلب للمندوب':'طلب توصيل جديد',body:`وصل طلب توصيل جديد إلك: ${number}${suffix}`};
    return {title:'طلب جديد',body:`وصل طلب طالب جديد إلى الإدارة: ${number}${suffix}`};
  }

  function showToast(order,currentRole,reason){
    let node=document.getElementById('alinOrderBellToast');
    if(!node){
      node=document.createElement('div');
      node.id='alinOrderBellToast';
      node.className='alin-order-bell-toast';
      node.setAttribute('role','status');
      node.setAttribute('aria-live','assertive');
      node.innerHTML='<span class="alin-order-bell-icon" aria-hidden="true">🔔</span><div><strong></strong><p></p></div><button type="button" aria-label="إغلاق">×</button>';
      node.querySelector('button').addEventListener('click',()=>node.classList.remove('show'));
      document.body.appendChild(node);
    }
    const content=message(order,currentRole,reason);
    node.querySelector('strong').textContent=content.title;
    node.querySelector('p').textContent=content.body;
    node.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer=setTimeout(()=>node.classList.remove('show'),7000);
  }

  function notify(order,currentRole=role(),reason='new'){
    if(!relevant(order,currentRole))return false;
    const key=signature(order,currentRole);
    if(wasSeen(key))return false;
    markSeen(key);
    if(!pageIsOpen(currentRole))return false;
    bell();
    showToast(order,currentRole,reason);
    try{navigator.vibrate?.([100,55,100,55,150])}catch(_){ }
    window.dispatchEvent(new CustomEvent('alin:new-order-bell',{detail:{role:currentRole,order,reason,at:new Date().toISOString()}}));
    return true;
  }

  function snapshotRelevant(currentRole){
    const map=new Map();
    for(const order of orders())if(relevant(order,currentRole))map.set(orderId(order),signature(order,currentRole));
    return map;
  }

  function rememberRealtimeRow(order,currentRole){
    const id=orderId(order);if(!id)return {changed:false,had:false};
    const state=roleState.get(currentRole)||new Map();
    const had=state.has(id),old=state.get(id),isRelevant=relevant(order,currentRole);
    if(!isRelevant){if(old)unmarkSeen(old);state.delete(id);roleState.set(currentRole,state);return {changed:false,had}}
    const next=signature(order,currentRole);
    state.set(id,next);roleState.set(currentRole,state);
    return {changed:!had||old!==next,had};
  }

  function handleRealtime(payload){
    const currentRole=role();
    if(!currentRole)return;
    const event=text(payload?.eventType||payload?.event).toUpperCase();
    const next=payload?.new||payload?.record||null;
    if(!next)return;

    // Admin rings only for a genuinely new student order.
    if(currentRole==='admin'){
      rememberRealtimeRow(next,currentRole);
      if(event==='INSERT')notify(next,currentRole,'new');
      return;
    }

    // Library/courier: use the live assignment signature rather than relying on payload.old.
    // This makes a transfer ring immediately even when Supabase does not return the old row.
    const change=rememberRealtimeRow(next,currentRole);
    if(relevant(next,currentRole)&&change.changed)notify(next,currentRole,event==='UPDATE'?'assigned':'new');
  }

  function compareSnapshot(){
    const currentRole=role();
    if(!currentRole)return;
    const current=snapshotRelevant(currentRole);
    const previous=roleState.get(currentRole);
    if(!previous){roleState.set(currentRole,current);return}
    for(const order of orders()){
      if(!relevant(order,currentRole))continue;
      const id=orderId(order),sig=signature(order,currentRole);
      if(!previous.has(id)||previous.get(id)!==sig)notify(order,currentRole,previous.has(id)?'assigned':'new');
    }
    roleState.set(currentRole,current);
  }

  function scheduleRealtimeRetry(){
    clearTimeout(realtimeRetry);
    realtimeRetry=setTimeout(()=>{realtimeChannel=null;startRealtime()},900);
  }

  function startRealtime(){
    const client=window.sb||window.AlinCloud?.client?.()||null;
    if(!client?.channel||realtimeChannel)return;
    try{
      realtimeChannel=client.channel(`alin-order-bell-${Math.random().toString(36).slice(2,8)}`)
        .on('postgres_changes',{event:'INSERT',schema:'public',table:'orders'},handleRealtime)
        .on('postgres_changes',{event:'UPDATE',schema:'public',table:'orders'},handleRealtime)
        .subscribe(status=>{
          if(status==='CHANNEL_ERROR'||status==='TIMED_OUT'||status==='CLOSED'){
            try{client.removeChannel?.(realtimeChannel)}catch(_){ }
            realtimeChannel=null;
            scheduleRealtimeRetry();
          }
        });
    }catch(error){
      realtimeChannel=null;
      console.warn('[ALIN order bell] realtime',error);
      scheduleRealtimeRetry();
    }
  }

  function resetRoleState(){
    const currentRole=role();
    if(currentRole)roleState.set(currentRole,snapshotRelevant(currentRole));
  }

  function unlockAudio(){
    if(ensureAudioContext())loadBellAudio().catch(()=>{});
  }

  ['pointerdown','touchstart','keydown'].forEach(type=>document.addEventListener(type,unlockAudio,{capture:true,once:true,passive:true}));
  window.addEventListener('alin:data-refreshed',compareSnapshot);
  window.addEventListener('alin:cloud-mutation',event=>{if(text(event?.detail?.table)==='orders')setTimeout(compareSnapshot,0)});
  window.addEventListener('alin:logout',()=>{roleState.clear();sessionSeen.clear()});
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible'){resetRoleState();startRealtime()}});
  document.addEventListener('DOMContentLoaded',()=>{setTimeout(()=>{resetRoleState();startRealtime()},500)},{once:true});

  // Fast fallback only when realtime/data events are unavailable.
  setInterval(()=>{if(role()){startRealtime();compareSnapshot()}},1500);

  window.AlinOrderBell=Object.freeze({version:VERSION,ring:bell,check:compareSnapshot,notify,enabled:()=>Boolean(role())});
})();
;

/* modules/teacher/admin-word-download.js */
(function(){
  'use strict';

  const originalOpen=window.openTeacherRequestSource;
  if(typeof originalOpen!=='function')return;

  async function downloadTeacherRequestSource(id){
    try{
      const cur=typeof current!=='undefined'?current:(window.current||{});
      if(String(cur.role||'')!=='admin')throw new Error('تنزيل الملف متاح للمدير فقط');

      const database=typeof db!=='undefined'?db:(window.db||{});
      const rows=database.teacherRequests||database.teacher_requests||[];
      const request=rows.find(x=>String(x.id)===String(id));

      if(!request?.source_file_path)throw new Error('لا يوجد ملف Word مرفوع');
      if(typeof alinResolveStoredFile!=='function')throw new Error('خدمة الملفات غير جاهزة');

      const resolved=await alinResolveStoredFile(request.source_file_path,'teacher-requests');
      if(!resolved?.url)throw new Error('تعذر تجهيز رابط الملف');

      const response=await fetch(resolved.url,{cache:'no-store'});
      if(!response.ok)throw new Error('تعذر تنزيل ملف Word');

      const blob=await response.blob();
      const objectUrl=URL.createObjectURL(blob);
      const link=document.createElement('a');

      link.href=objectUrl;
      link.download=request.source_file_name||`${request.title||'ملزمة المدرس'}.docx`;
      document.body.appendChild(link);
      link.click();
      link.remove();

      setTimeout(()=>URL.revokeObjectURL(objectUrl),1500);

      if(typeof audit==='function'){
        await audit('teacher_request','تنزيل ملف Word للتصميم: '+(request.title||request.id));
      }
    }catch(error){
      alert(error.message||'تعذر تنزيل الملف');
    }
  }

  window.downloadTeacherRequestSource=downloadTeacherRequestSource;

  window.openTeacherRequestSource=async function(id){
    const result=await originalOpen(id);
    const cur=typeof current!=='undefined'?current:(window.current||{});

    if(String(cur.role||'')==='admin'){
      const actions=document.querySelector('#checkoutBox .teacher-word-viewer .row-actions');

      if(actions&&!actions.querySelector('[data-admin-word-download]')){
        const button=document.createElement('button');
        button.type='button';
        button.dataset.adminWordDownload='1';
        button.textContent='تنزيل ملف Word للتصميم';
        button.addEventListener('click',()=>downloadTeacherRequestSource(id));
        actions.prepend(button);
      }
    }

    return result;
  };

  if(window.AlinTeacherModules){
    window.AlinTeacherModules.openTeacherRequestSource=window.openTeacherRequestSource;
  }
})();
;

/* core/v2-runtime.js */
(()=>{
  'use strict';
  window.addEventListener('error',e=>console.error('[ALIN v2 runtime]',e.error||e.message));
  window.addEventListener('unhandledrejection',e=>console.error('[ALIN v2 promise]',e.reason));
})();
;

/* modules/core/receipts-center.js */
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
;

/* modules/core/receipts-navigation-guard.js */
/* ALIN v4.1.5 — receipt preview lifecycle guard for every role and device. */
(function(){
  'use strict';
  if(window.__ALIN_RECEIPTS_NAV_GUARD__)return;
  window.__ALIN_RECEIPTS_NAV_GUARD__=true;

  const navigationSelector=[
    '#adminPage .admin-tabs button',
    '#teacherPage .teacher-tabs button',
    '#libraryPage .library-v116-tabs button',
    '#courierPage .courier-v161-tabs button',
    '[data-admin-tab]',
    '[data-teacher-tab]',
    '[data-library-tab]',
    '[data-courier-tab]',
    ''
  ].join(',');

  function isReceiptsNavigation(node){
    if(!node)return false;
    if(node.matches?.('[data-alin415-receipts-role]'))return true;
    if(String(node.dataset?.adminTab||'')==='receipts')return true;
    if(String(node.dataset?.teacherTab||'')==='receipts')return true;
    if(String(node.dataset?.libraryTab||'')==='receipts')return true;
    if(String(node.dataset?.courierTab||'')==='receipts')return true;
    return false;
  }

  function leaveReceipts(){
    try{window.Alin415Receipts?.closePreview?.()}catch(error){console.warn('[ALIN receipts] close preview',error)}
    try{delete document.body.dataset.alin415ReceiptsRole}catch(_){document.body.removeAttribute('data-alin415-receipts-role')}
    document.body.classList.remove('alin415r-modal-open');
    const modal=document.getElementById('alin415rPreviewModal');
    if(modal){
      modal.hidden=true;
      const body=modal.querySelector('.alin415r-modal-body');
      if(body)body.innerHTML='';
    }
  }

  function receiptCenterIsActive(){
    const role=String(document.body.dataset.alin415ReceiptsRole||'');
    if(!role)return false;
    const hostId=role==='admin'||role==='accountant'?'adminContent':role==='teacher'?'teacherContent':role==='library'?'libraryV116Content':'courierV161Content';
    const host=document.getElementById(hostId);
    if(!host||host.closest('.hidden')||host.hidden)return false;
    const center=host.querySelector(`.alin415r-center[data-alin415r-role="${role}"]`);
    return Boolean(center&&!center.closest('.hidden')&&!center.hidden);
  }

  document.addEventListener('click',event=>{
    const navigation=event.target.closest?.(navigationSelector);
    if(!navigation||navigation.closest('#alin415rPreviewModal')||isReceiptsNavigation(navigation))return;
    leaveReceipts();
  },true);

  function wrapNavigation(name,shouldLeave){
    const original=window[name];
    if(typeof original!=='function'||original.__alinReceiptsGuarded)return false;
    function guarded(...args){
      if(shouldLeave(...args))leaveReceipts();
      return original.apply(this,args);
    }
    Object.defineProperty(guarded,'__alinReceiptsGuarded',{value:true});
    window[name]=guarded;
    return true;
  }

  function installWrappers(){
    wrapNavigation('adminTab',tab=>String(tab||'')!=='receipts');
    wrapNavigation('teacherTab',tab=>String(tab||'')!=='receipts');
    wrapNavigation('renderCourierDashboard',tab=>String(tab||'')!=='receipts');
    wrapNavigation('logout',()=>true);
    wrapNavigation('openPage',()=>true);
    wrapNavigation('showPage',()=>true);
  }

  let scheduled=false;
  const verify=()=>{
    if(scheduled)return;
    scheduled=true;
    requestAnimationFrame(()=>{
      scheduled=false;
      installWrappers();
      if((document.body.classList.contains('alin415r-modal-open')||document.body.dataset.alin415ReceiptsRole)&&!receiptCenterIsActive())leaveReceipts();
    });
  };

  const observer=new MutationObserver(verify);
  const start=()=>{
    installWrappers();
    observer.observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:['class','hidden','style']});
    [120,500,1200,2600].forEach(delay=>setTimeout(installWrappers,delay));
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();

  ['popstate','hashchange','pagehide'].forEach(type=>window.addEventListener(type,leaveReceipts));
  ['alin:admin-tab','alin:teacher-tab','alin:library-tab','alin:courier-tab','alin:page-changed'].forEach(type=>window.addEventListener(type,verify));
  window.AlinReceiptsNavigationGuard=Object.freeze({leave:leaveReceipts,verify,isActive:receiptCenterIsActive});
})();
;

/* modules/core/section-header.js */
/* ALIN v4.1.5 prepublish 1f — style the existing section header only; never insert a second header. */
(()=>{
  'use strict';
  if(window.__ALIN_EXISTING_SECTION_HEADER__)return;
  window.__ALIN_EXISTING_SECTION_HEADER__=true;

  const roles={
    admin:{page:'adminPage',host:'adminContent',nav:'.admin-tabs'},
    teacher:{page:'teacherPage',host:'teacherContent',nav:'.teacher-tabs'},
    library:{page:'libraryPage',host:'libraryV116Content',nav:'.library-v116-tabs',pageHeader:'.library-v116-header'},
    courier:{page:'courierPage',host:'courierV161Content',nav:'.courier-v161-tabs',pageHeader:'.courier-v161-hero'}
  };

  function findExistingHeader(host){
    if(!host)return null;
    const selectors=[
      ':scope > .alin415r-heading',
      ':scope > section:first-child > .alin415r-heading:first-child',
      ':scope > header:first-child',
      ':scope > section:first-child > header:first-child',
      ':scope > [class*="-head"]:first-child',
      ':scope > section:first-child > [class*="-head"]:first-child',
      ':scope > *:first-child > [class*="-head"]:first-child',
      ':scope > [class*="-hero"]:first-child',
      ':scope > section:first-child > [class*="-hero"]:first-child',
      ':scope > [class*="-welcome"]:first-child',
      ':scope > section:first-child > [class*="-welcome"]:first-child'
    ];
    for(const selector of selectors){
      try{const node=host.querySelector(selector);if(node)return node}catch(_){ }
    }
    return null;
  }

  function decorate(role){
    const cfg=roles[role],page=document.getElementById(cfg?.page),host=document.getElementById(cfg?.host);
    if(!cfg||!page||!host)return;
    page.querySelectorAll('.alin-existing-section-header').forEach(node=>node.classList.remove('alin-existing-section-header'));
    const fixedHeader=cfg.pageHeader?page.querySelector(cfg.pageHeader):null;
    const header=fixedHeader||findExistingHeader(host);
    if(header)header.classList.add('alin-existing-section-header');
  }

  function decorateAll(){Object.keys(roles).forEach(decorate)}

  function wrapNavigation(name,role){
    const original=window[name];
    if(typeof original!=='function'||original.__alinExistingHeaderWrapped)return;
    function wrapped(tab,...args){
      if(String(tab||'')!=='receipts')try{window.AlinReceiptsNavigationGuard?.leave?.()}catch(_){ }
      const result=original.call(this,tab,...args);
      requestAnimationFrame(()=>decorate(role));
      setTimeout(()=>decorate(role),80);
      return result;
    }
    Object.defineProperty(wrapped,'__alinExistingHeaderWrapped',{value:true});
    Object.defineProperty(wrapped,'__alinReceiptsGuarded',{value:true});
    window[name]=wrapped;
  }

  function install(){
    wrapNavigation('adminTab','admin');
    wrapNavigation('teacherTab','teacher');
    wrapNavigation('renderCourierDashboard','courier');
    decorateAll();
  }

  document.addEventListener('click',event=>{
    const button=event.target.closest?.('#adminPage .admin-tabs button,#teacherPage .teacher-tabs button,#libraryPage .library-v116-tabs button,#courierPage .courier-v161-tabs button');
    if(!button)return;
    const role=button.closest('#adminPage')?'admin':button.closest('#teacherPage')?'teacher':button.closest('#libraryPage')?'library':button.closest('#courierPage')?'courier':'';
    if(role){requestAnimationFrame(()=>decorate(role));setTimeout(()=>decorate(role),100)}
  },true);

  const start=()=>{
    install();
    [120,500,1100,2200].forEach(delay=>setTimeout(install,delay));
    const observer=new MutationObserver(records=>{
      if(records.some(record=>record.type==='childList'))requestAnimationFrame(decorateAll);
    });
    observer.observe(document.body,{subtree:true,childList:true});
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
  window.AlinExistingSectionHeader=Object.freeze({refresh:decorateAll});
})();
;

/* modules/admin/remove-diagnostic-tabs.js */
/* ALIN v4.1.6 prepublish 1n — permanently hide removed admin diagnostic tabs. */
(()=>{
  'use strict';
  const remove=()=>document.querySelectorAll('#adminPage .admin-tabs button').forEach(button=>{
    const key=String(button.dataset.adminTab||'');
    if(key==='systemHealth'||key==='supabaseReadiness')button.remove();
  });
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',remove,{once:true});else remove();
})();
;
