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
    version:window.ALIN_CONFIG?.version||'4.2.0-rc.20',$, $$, arr, escv, moneyv, now, notify, currentAccount, dbx,
    allCouriers, areasOf, areaRows, statusOf, statusLabel, resolveCourier,
    allOrders, courierAliases, orderCourierIds, myOrders, settlements, done, cancelled, active, activeLoad, today, todayDone, financials,
    orderState, friendlyOrderError, mapLink, hasExactGps, phoneLink, waLink, fmtDate,
    matchingCouriers, activeCouriers, alinCouriersOptions, assignOrder, transitionOrder,
    refreshCourierData, resetRefresh
  });
})();

;
