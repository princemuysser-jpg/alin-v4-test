// === admin/books.js ===
// ALIN — Independent Books Administration.
(function(){
  'use strict';
  const esc=v=>typeof window.esc==='function'?window.esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const money=v=>typeof window.money==='function'?window.money(v):Number(v||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const books=()=>Array.isArray(window.db?.products)?window.db.products.filter(p=>String(p.type||'').toLowerCase()==='book'):[];
  const libraries=()=>Array.isArray(window.db?.accounts?.libraries)?window.db.accounts.libraries.filter(a=>String(a.status||'active')==='active'&&!a.deleted_at):[];
  const root=()=>window.adminContent||document.getElementById('adminContent');
  let balances=[];

  const imageUrl=item=>{const p=item?.image_path||item?.image_url||'';try{return p&&typeof window.mediaUrl==='function'?window.mediaUrl(p):p}catch(_){return p}};
  const supplierLabel=item=>{
    const type=String(item?.supplier_type||'platform');
    if(type==='library')return `مكتبة ${item.supplier_name||libraries().find(x=>String(x.id)===String(item.supplier_account_id))?.name||'غير محددة'}`;
    if(type==='printer')return `مطبعة ${item.supplier_name||'غير محددة'}`;
    return 'منصة آلين';
  };
  const statusLabel=s=>String(s||'published')==='published'?'منشور':'مخفي';

  async function uploadImage(file){
    if(!file?.name)return '';
    const uploader=window.uploadFileV52||window.uploadFile;
    if(typeof uploader!=='function')throw new Error('خدمة رفع الصور غير متاحة');
    return uploader('products',file,{type:'image'});
  }

  function ensureTab(){
    const nav=document.querySelector('#adminPage .admin-tabs');
    if(!nav||nav.querySelector('[data-admin-tab="books"]'))return;
    const btn=document.createElement('button');
    btn.type='button';btn.dataset.adminTab='books';btn.textContent='الكتب';
    btn.addEventListener('click',()=>window.adminTab?.('books'));
    const products=nav.querySelector('[data-admin-tab="products"]');
    if(products?.nextSibling)nav.insertBefore(btn,products.nextSibling);else nav.appendChild(btn);
  }

  function libraryOptions(selected=''){
    return `<option value="">اختر المكتبة</option>`+libraries().map(x=>`<option value="${esc(x.id)}" ${String(x.id)===String(selected)?'selected':''}>${esc(x.name||x.username||x.id)}</option>`).join('');
  }

  function editorHtml(item={}){
    const editing=Boolean(item.id),supplier=String(item.supplier_type||'platform'),platform=Number(item.platform_share_percent??100),supplierPct=Number(item.supplier_share_percent??0);
    return `<form id="alinBookForm" class="form-grid admin-product-editor" data-id="${esc(item.id||'')}">
      <input name="name" value="${esc(item.name||item.title||'')}" placeholder="اسم الكتاب" required>
      <input name="price" type="number" min="0" step="1" value="${Number(item.unit_price??item.sale_price??item.price??0)}" placeholder="سعر البيع" required>
      <input name="stock" type="number" min="0" step="1" value="${Number(item.stock||0)}" placeholder="المخزون" required>
      <input name="lowStockLimit" type="number" min="0" step="1" value="${Number(item.low_stock_limit||5)}" placeholder="حد تنبيه المخزون">
      <label><span>حصة المنصة %</span><input id="alinBookPlatformShare" name="platformShare" type="number" min="0" max="100" step="1" value="${platform}" required></label>
      <label><span>حصة المورد %</span><input id="alinBookSupplierShare" name="supplierShare" type="number" min="0" max="100" step="1" value="${supplierPct}" required></label>
      <label><span>نوع مصدر الكتاب</span><select id="alinBookSupplierType" name="supplierType"><option value="platform" ${supplier==='platform'?'selected':''}>مخزون منصة آلين</option><option value="library" ${supplier==='library'?'selected':''}>مكتبة</option><option value="printer" ${supplier==='printer'?'selected':''}>مطبعة</option></select></label>
      <label id="alinBookLibraryField"><span>المكتبة الموردة</span><select name="supplierAccountId">${libraryOptions(item.supplier_account_id||'')}</select></label>
      <label id="alinBookPrinterField"><span>اسم المطبعة</span><input name="supplierName" value="${esc(supplier==='printer'?item.supplier_name||'':'')}" placeholder="اسم المطبعة"></label>
      <textarea name="description" rows="3" class="span-2" placeholder="وصف الكتاب">${esc(item.description||item.details||'')}</textarea>
      <label class="span-2"><span>صورة الكتاب</span><input name="image" type="file" accept="image/*"></label>
      ${imageUrl(item)?`<div class="span-2"><img src="${esc(imageUrl(item))}" alt="" style="max-width:120px;border-radius:14px"></div>`:''}
      <div class="span-2 notice"><b>التوصيل:</b> أجرة المندوب مستقلة عن نسب الكتاب. الاستلام المباشر من المورد غير مفعّل في هذه المرحلة.</div>
      <div class="row-actions span-2"><button type="submit">${editing?'حفظ التعديل':'إضافة الكتاب'}</button><button type="button" class="secondary" data-alin-click="alinCloseBookEditor">إلغاء</button></div>
    </form>`;
  }

  function ensureModal(){
    let modal=document.getElementById('alinBookModal');
    if(modal)return modal;
    modal=document.createElement('div');modal.id='alinBookModal';modal.className='modal hidden';
    modal.innerHTML='<div class="modal-card"><button class="x" type="button" data-alin-click="alinCloseBookEditor">×</button><div id="alinBookModalBody"></div></div>';
    document.body.appendChild(modal);return modal;
  }

  function syncSupplierFields(){
    const type=document.getElementById('alinBookSupplierType')?.value||'platform';
    const lib=document.getElementById('alinBookLibraryField'),printer=document.getElementById('alinBookPrinterField');
    if(lib)lib.hidden=type!=='library';if(printer)printer.hidden=type!=='printer';
    const p=document.getElementById('alinBookPlatformShare'),s=document.getElementById('alinBookSupplierShare');
    if(type==='platform'){if(p)p.value='100';if(s)s.value='0';if(p)p.readOnly=true;if(s)s.readOnly=true}else{if(p)p.readOnly=false;if(s)s.readOnly=false}
  }

  function openEditor(id=''){
    const item=id?books().find(x=>String(x.id)===String(id)):{};if(id&&!item)return;
    const modal=ensureModal();modal.querySelector('#alinBookModalBody').innerHTML=`<h2>${id?'تعديل الكتاب':'إضافة كتاب'}</h2>${editorHtml(item||{})}`;
    modal.hidden=false;modal.classList.remove('hidden');syncSupplierFields();
    document.getElementById('alinBookSupplierType')?.addEventListener('change',syncSupplierFields);
    document.getElementById('alinBookForm')?.addEventListener('submit',saveBook);
  }

  function closeEditor(){const m=document.getElementById('alinBookModal');if(m){m.hidden=true;m.classList.add('hidden')}}

  async function saveBook(event){
    event?.preventDefault();const form=document.getElementById('alinBookForm');if(!form)return;
    const d=new FormData(form),id=String(form.dataset.id||''),existing=id?books().find(x=>String(x.id)===id):null;
    const name=String(d.get('name')||'').trim(),price=Number(d.get('price')||0),stock=Number(d.get('stock')||0),low=Number(d.get('lowStockLimit')||5);
    const supplierType=String(d.get('supplierType')||'platform'),platformShare=Number(d.get('platformShare')||0),supplierShare=Number(d.get('supplierShare')||0);
    const supplierAccountId=supplierType==='library'?String(d.get('supplierAccountId')||'').trim():'';
    const library=libraries().find(x=>String(x.id)===supplierAccountId);
    const supplierName=supplierType==='library'?(library?.name||''):supplierType==='printer'?String(d.get('supplierName')||'').trim():'منصة آلين';
    if(!name)return alert('اكتب اسم الكتاب');
    if(!Number.isFinite(price)||price<0)return alert('سعر الكتاب غير صحيح');
    if(!Number.isFinite(stock)||stock<0)return alert('المخزون غير صحيح');
    if(platformShare<0||platformShare>100||supplierShare<0||supplierShare>100||platformShare+supplierShare!==100)return alert('مجموع حصة المنصة والمورد يجب أن يساوي 100%');
    if(supplierType==='library'&&!library)return alert('اختر المكتبة الموردة');
    if(supplierType==='printer'&&!supplierName)return alert('اكتب اسم المطبعة');
    try{
      let imagePath=existing?.image_path||'';const file=form.querySelector('input[name="image"]')?.files?.[0];if(file?.name)imagePath=await uploadImage(file);
      const payload={name,title:name,type:'book',category:'كتب',category_id:'CAT-BOOKS',unit_price:price,price,sale_price:null,stock,low_stock_limit:Math.max(0,low||0),description:String(d.get('description')||'').trim(),details:String(d.get('description')||'').trim(),image_path:imagePath||null,images:imagePath?[imagePath]:[],platform_share_percent:platformShare,supplier_share_percent:supplierShare,supplier_type:supplierType,supplier_account_id:supplierAccountId||null,supplier_name:supplierName||null,supplier_pickup_enabled:false,status:existing?.status||'published',updated_at:new Date().toISOString()};
      if(existing)await window.update('products',payload,{id});
      else await window.insert('products',{id:typeof window.uid==='function'?window.uid('BK'):`BK-${Date.now()}`,...payload,created_at:new Date().toISOString()});
      if(typeof window.audit==='function')await window.audit('book',`${existing?'تعديل':'إضافة'} كتاب ${name}`);
      closeEditor();if(typeof window.load==='function')await window.load();render();window.renderStore?.();window.toast?.(existing?'تم تعديل الكتاب':'تمت إضافة الكتاب');
    }catch(error){console.error('[ALIN books save]',error);alert(error?.message||'تعذر حفظ الكتاب')}
  }

  async function setStatus(id,status){
    try{await window.update('products',{status,updated_at:new Date().toISOString()},{id});if(typeof window.load==='function')await window.load();render();window.renderStore?.()}catch(e){alert(e?.message||'تعذر تغيير حالة الكتاب')}
  }

  function bookCard(item){
    const img=imageUrl(item),stock=Number(item.stock||0),p=Number(item.platform_share_percent??100),s=Number(item.supplier_share_percent??0);
    return `<article class="admin-product-v129-card"><div class="admin-product-v129-image">${img?`<img src="${esc(img)}" alt="${esc(item.name||'كتاب')}">`:'<span>📚</span>'}</div><div class="admin-product-v129-body"><div class="admin-product-v129-title"><div><small>كتاب • ${esc(supplierLabel(item))}</small><h3>${esc(item.name||item.title||'كتاب')}</h3></div><strong>${money(item.unit_price??item.price)} د.ع</strong></div><p>${esc(item.description||'')}</p><div class="admin-product-v129-meta"><span>المخزون: ${money(stock)}</span><span>المنصة ${p}%</span><span>المورد ${s}%</span><span>${statusLabel(item.status)}</span></div><div class="admin-product-v129-actions"><button class="secondary" data-alin-click="alinOpenBookEditor" data-alin-click-arg0="${esc(item.id)}">تعديل</button><button data-alin-click="alinSetBookStatus" data-alin-click-arg0="${esc(item.id)}" data-alin-click-arg1="${String(item.status||'published')==='published'?'hidden':'published'}">${String(item.status||'published')==='published'?'إخفاء':'نشر'}</button></div></div></article>`;
  }

  async function loadBalances(){
    try{const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)return[];const {data,error}=await client.rpc('alin_admin_book_supplier_balances');if(error)throw error;balances=Array.isArray(data)?data:[];return balances}catch(e){console.warn('[ALIN book supplier balances]',e);balances=[];return[]}
  }

  async function settleSupplier(key){
    if(!key||!confirm('تثبيت تسوية هذا المورد؟ لن يؤثر ذلك على تسويات الملازم أو المندوبين.'))return;
    try{const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)throw new Error('خدمة التسويات غير متاحة');const {data,error}=await client.rpc('alin_admin_settle_book_supplier',{p_supplier_key:key,p_note:null});if(error)throw error;window.toast?.(`تمت تسوية ${money(data?.amount||0)} د.ع`);await loadBalances();render()}catch(e){alert(e?.message||'تعذر تثبيت تسوية المورد')}
  }

  function supplierBalancesHtml(){
    if(!balances.length)return '<div class="empty">لا توجد مبالغ مستحقة لموردي الكتب حالياً.</div>';
    return `<div class="v164-finance-list">${balances.map(x=>`<div><span><b>${esc(x.supplier_name||'مورد كتب')}</b><small>${x.supplier_type==='library'?'مكتبة':'مطبعة'}</small></span><span>المستحق ${money(x.pending_amount)} د.ع</span><span>${Number(x.orders_count||0)} طلب</span><span>${Number(x.pending_amount||0)>0?`<button data-alin-click="alinSettleBookSupplier" data-alin-click-arg0="${esc(x.supplier_key)}">تسديد المورد</button>`:'مسدد'}</span></div>`).join('')}</div>`;
  }

  function render(){
    ensureTab();const host=root();if(!host)return;
    const rows=books(),published=rows.filter(x=>String(x.status||'published')==='published').length,stock=rows.reduce((s,x)=>s+Number(x.stock||0),0);
    host.innerHTML=`<section class="admin-products-v129"><header class="admin-products-v129-head"><div><h2>إدارة الكتب</h2><p>نظام كتب مستقل ماليًا عن الملازم، ويستخدم نفس الطلب والتوصيل والمخزون.</p></div><button data-alin-click="alinOpenBookEditor">+ إضافة كتاب</button></header><section class="admin-products-v129-stats"><article><small>الكتب</small><strong>${rows.length}</strong></article><article><small>المنشورة</small><strong>${published}</strong></article><article><small>إجمالي المخزون</small><strong>${money(stock)}</strong></article><article><small>طريقة التسليم</small><strong>مندوب</strong></article></section><section class="admin-product-v129-grid">${rows.map(bookCard).join('')||'<div class="empty">لا توجد كتب مضافة بعد.</div>'}</section><section class="v164-table-card"><header><div><h2>حسابات موردي الكتب</h2><p>مستقلة عن حسابات المدرسين والمكتبات الخاصة بالملازم.</p></div><button class="secondary" data-alin-click="alinRefreshBookSupplierBalances">تحديث</button></header>${supplierBalancesHtml()}</section></section>`;
    host.dataset.adminModule='books';loadBalances().then(()=>{if(window.activeAdminTab==='books'&&root()?.dataset.adminModule==='books'){const box=root()?.querySelector('.v164-table-card');if(box){const old=box.querySelector('.v164-finance-list,.empty');old?.remove();box.insertAdjacentHTML('beforeend',supplierBalancesHtml())}}});
  }

  window.alinOpenBookEditor=openEditor;window.alinCloseBookEditor=closeEditor;window.alinSyncBookSupplierFields=syncSupplierFields;window.alinSetBookStatus=setStatus;window.alinSettleBookSupplier=settleSupplier;window.alinRefreshBookSupplierBalances=async()=>{await loadBalances();render()};window.renderBooksAdmin=render;
  ensureTab();
  if(window.AlinAdminModules?.register)window.AlinAdminModules.register('books',render);
  window.addEventListener('alin:data-refreshed',ensureTab);
})();
