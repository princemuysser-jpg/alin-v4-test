// === core/platform.js ===
/* ALIN v4.0.0 Clean Project — small authoritative runtime core. Business features live in their own modules. */
(function(){
  'use strict';

  const config=window.ALIN_CONFIG||{};
  const emptyDb=()=>({
    accounts:{all:[],teachers:[],libraries:[],couriers:[],accountants:[]},
    booklets:[],products:[],categories:[],banners:[],coupons:[],notifications:[],orders:[],
    permits:[],ledger:[],settlements:[],withdrawals:[],audit:[],auditLogs:[],couriers:[],deliveryAreas:[],
    teacherRequests:[],orderTimeline:[],backupLogs:[],systemHealthLogs:[],settings:{storeType:'booklet'}
  });
  let stateDb=window.db&&typeof window.db==='object'?window.db:emptyDb();
  let stateCurrent=window.current||null;
  let statePendingRole=window.pendingRole||'';
  let stateCheckoutItem=window.checkoutItem||null;
  let stateClient=window.sb||null;

  function expose(name,getter,setter){
    const descriptor=Object.getOwnPropertyDescriptor(window,name);
    if(!descriptor||descriptor.configurable)Object.defineProperty(window,name,{configurable:true,enumerable:true,get:getter,set:setter});
  }
  expose('db',()=>stateDb,value=>{stateDb=value&&typeof value==='object'?value:emptyDb()});
  expose('current',()=>stateCurrent,value=>{stateCurrent=value||null});
  expose('pendingRole',()=>statePendingRole,value=>{statePendingRole=String(value||'')});
  expose('checkoutItem',()=>stateCheckoutItem,value=>{stateCheckoutItem=value||null});
  expose('sb',()=>stateClient,value=>{stateClient=value||null});
  expose('couriers',()=>stateDb.couriers||stateDb.accounts?.couriers||[],value=>{stateDb.couriers=value||[]});

  function validConfig(){
    const url=String(config.supabaseUrl||'').trim();
    const key=String(config.supabaseAnonKey||'').trim();
    return /^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(url)
      && key.length>40
      && !url.includes('PASTE_NEW_')
      && !key.includes('PASTE_NEW_');
  }
  function init(){
    if(stateClient)return true;
    if(!window.supabase||!validConfig())return false;
    try{
      stateClient=window.supabase.createClient(config.supabaseUrl,config.supabaseAnonKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
      return true;
    }catch(error){
      console.error('[ALIN Supabase config]',error);
      stateClient=null;
      return false;
    }
  }
  function requireConnection(){
    if(init())return true;
    window.toast?.('تعذر الاتصال بخدمة المنصة');
    return false;
  }
  async function audit(kind,text,meta={}){
    try{
      const client=window.sb||window.AlinCloud?.client?.();
      if(!client||!window.current?.id)return false;
      const entityType=String(meta?.entity_type||meta?.table||'').slice(0,80)||null;
      const entityId=String(meta?.entity_id||meta?.id||'').slice(0,120)||null;
      const safeMeta={...(meta||{})};delete safeMeta.entity_type;delete safeMeta.entity_id;delete safeMeta.table;delete safeMeta.id;
      const {error}=await client.rpc('alin_audit_write',{
        p_action:String(kind||'event').slice(0,80),p_summary:String(text||'').slice(0,1000),
        p_meta:safeMeta,p_entity_type:entityType,p_entity_id:entityId
      });
      if(error)throw error;return true;
    }catch(error){console.warn('[ALIN audit]',error);return false}
  }
  function teacherName(id){return (stateDb.accounts?.teachers||[]).find(row=>String(row.id)===String(id))?.name||''}
  function libIsOpen(library){return !(library?.is_open===false||String(library?.is_open)==='false'||String(library?.open_status||'').toLowerCase()==='closed')}
  function libStatusText(library){return libIsOpen(library)?'مفتوح الآن':library?.open_note||'مغلق حالياً'}
  function activeLibraries(){return (stateDb.accounts?.libraries||[]).filter(library=>library.status==='active')}
  function deliveryFee(){return Number(stateDb.settings?.delivery_fee||0)}
  function isMissingTableError(error,table=''){
    const message=String(error?.message||error||'').toLowerCase();
    return (message.includes('does not exist')||message.includes('schema cache')||message.includes('not found'))&&(!table||message.includes(String(table).toLowerCase()));
  }
  async function usePermit(id){
    const permit=(stateDb.permits||[]).find(row=>String(row.id)===String(id));
    if(!permit){window.toast?.('إذن النسخ غير موجود');return false}
    const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)throw new Error('خدمة أذونات الطباعة غير متاحة');
    const {data,error}=await client.rpc('alin_use_print_permit',{p_permit_id:String(id)});if(error)throw error;if(!data?.ok)throw new Error(data?.error||'لم يؤكد الخادم استخدام الإذن');
    if(data.permit)Object.assign(permit,data.permit);await audit('copy',`استخدام إذن نسخة ${id}`);return true;
  }
  function renderAll(){
    try{window.applyBrand?.()}catch(error){console.warn('[ALIN brand]',error)}
    for(const name of ['renderStore','renderTeacher','renderLibrary','adminStatsRender']){
      try{if(typeof window[name]==='function')window[name]()}catch(error){console.warn(`[ALIN render ${name}]`,error)}
    }
    window.dispatchEvent(new CustomEvent('alin:rendered'));
  }
  async function seedData(){throw new Error('البيانات التجريبية معطلة في النسخة المستقرة')}

  Object.assign(window,{
    ALIN_VERSION:window.ALIN_CONFIG?.version||'4.2.0-rc.8',init,requireConnection,audit,renderAll,seedData,
    teacherName,libIsOpen,libStatusText,activeLibraries,alinOpenLibraries:activeLibraries,
    alinLibOpen:libIsOpen,deliveryFee,isMissingTableError,usePermit
  });
  window.AlinRuntime=Object.freeze({version:window.ALIN_CONFIG?.version||'4.2.0-rc.8',init,requireConnection,renderAll,getDb:()=>stateDb,getCurrent:()=>stateCurrent});

  /* PLATFORM STEP 1: coupons are owned by modules/store/coupons.js and modules/admin/coupons.js. */
  /* PLATFORM STEP 2: cart and order creation are owned by modules/store/cart.js and modules/store/order-routing.js. */
  /* PLATFORM STEP 3: navigation and session are owned by modules/core/navigation.js and modules/core/cloud-status-ui.js. */
  /* PLATFORM STEP 4: catalog administration is owned by modules/admin/products.js and modules/admin/booklets.js. */
  /* PLATFORM STEP 5: admin orders are owned by modules/admin/orders.js. */
  /* PLATFORM STEP 6/7: library and teacher roles are owned by their modules. */
  /* PLATFORM STEP 8: finance is owned by core/finance-runtime.js and modules/admin/finance.js. */
  /* PLATFORM STEP 9: admin routing is owned by modules/admin/shell.js. */
  /* PLATFORM STEP 9: account administration is owned by modules/admin/accounts.js. */
  /* PLATFORM STEP 10: storefront ownership moved to modules/store/discovery.js. */
  /* PLATFORM STEP 11: banner administration lives in store/banners.js. */
  /* PLATFORM STEP 11: notifications are owned by modules/core/notifications.js and role-specific views. */
  /* PLATFORM STEP 11: favorites are owned by modules/store/discovery.js. */
  /* PLATFORM STEP 12: UI, storage, settings, branding, backup and student profile are owned by dedicated modules. */

})();

;
