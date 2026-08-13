// ALIN Admin Products & Categories — single implementation (v2.2.6)
(function(){
  'use strict';

  const state={q:'',type:'',status:'',stock:'',sort:'newest'};
  const escv=value=>typeof window.esc==='function'?window.esc(value):String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const moneyv=value=>typeof window.money==='function'?window.money(value):Number(value||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const products=()=>Array.isArray(window.db?.products)?window.db.products:[];
  const categories=()=>Array.isArray(window.db?.categories)?window.db.categories:[];
  const subcategories=()=>Array.isArray(window.db?.productSubcategories)?window.db.productSubcategories:[];
  const subcategoryById=id=>subcategories().find(item=>String(item.id)===String(id))||null;
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

  const normalizeImages=item=>{
    const rows=[];
    const add=value=>{value=String(value||'').trim();if(value&&!rows.includes(value))rows.push(value)};
    if(Array.isArray(item?.images))item.images.forEach(add);
    else if(typeof item?.images==='string'){try{const parsed=JSON.parse(item.images);if(Array.isArray(parsed))parsed.forEach(add)}catch(_){add(item.images)}}
    add(item?.image_path);
    return rows.slice(0,8);
  };
  const imagePreviewUrl=path=>{try{return typeof window.mediaUrl==='function'?window.mediaUrl(path):path}catch(_){return path||''}};

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

  function subcategoryOptions(type,categoryName,selected=''){
    const categoryRow=categories().find(item=>normalizeType(item.type)===normalizeType(type)&&String(item.name||'')===String(categoryName||''));
    const list=categoryRow?subcategories().filter(item=>String(item.parent_category_id)===String(categoryRow.id)&&String(item.status||'active')==='active').sort((a,b)=>Number(a.sort_order||0)-Number(b.sort_order||0)||String(a.name||'').localeCompare(String(b.name||''),'ar')):[];
    return `<option value="">بدون شعبة</option>`+list.map(item=>`<option value="${escv(item.id)}" ${String(selected)===String(item.id)?'selected':''}>${escv(item.name)}</option>`).join('');
  }

  function productForm(item={}){
    const editing=Boolean(item.id);
    const type=normalizeType(item.type||item.category_id||'stationery');
    const unitPrice=Number(item.unit_price??item.sale_price??item.deal_price??item.price??0);
    const previousPrice=Number((item.sale_price||item.deal_price)?item.price:0);
    const packPrice=Number(item.pack_price||0);
    const packSize=Number(item.pack_size||0);
    const existingImages=normalizeImages(item);
    const gallery=existingImages.length?`<div class="admin-product-existing-images">${existingImages.map((path,index)=>`<label class="admin-product-existing-image"><img src="${escv(imagePreviewUrl(path))}" alt="صورة ${index+1}"><span><input type="checkbox" name="removeImage" value="${escv(path)}"> حذف</span>${index===0?'<em>رئيسية</em>':''}</label>`).join('')}</div>`:'<small class="muted">لا توجد صور محفوظة حالياً.</small>';
    return `<form id="alinProductEditorForm" class="form-grid admin-product-editor" data-id="${escv(item.id||'')}">
      <select name="type" id="alinProductType" data-alin-change="refreshProductCategories"><option value="stationery" ${type==='stationery'?'selected':''}>قرطاسية</option><option value="gift" ${type==='gift'?'selected':''}>هدايا</option></select>
      <input name="name" value="${escv(item.name||item.title||'')}" placeholder="اسم المنتج" required>
      <select name="category" id="alinProductCategory" data-alin-change="refreshProductSubcategories">${categoryOptions(type,item.category||'')}</select>
      <select name="subcategoryId" id="alinProductSubcategory">${subcategoryOptions(type,item.category||'',item.subcategory_id||'')}</select>
      <input name="unitPrice" type="number" min="0" step="1" value="${unitPrice}" placeholder="سعر المفرد" required>
      <input name="previousPrice" type="number" min="0" step="1" value="${previousPrice}" placeholder="سعر المفرد السابق (اختياري)">
      <input name="packPrice" type="number" min="0" step="1" value="${packPrice||''}" placeholder="سعر الباكيت (اختياري)">
      <input name="packSize" type="number" min="2" step="1" value="${packSize>=2?packSize:''}" placeholder="عدد القطع داخل الباكيت">
      <input name="stock" type="number" min="0" value="${Number(item.stock||0)}" placeholder="المخزون بالقطع" required>
      <input name="lowStockLimit" type="number" min="0" value="${Number(item.low_stock_limit||window.db?.settings?.low_stock_default||5)}" placeholder="حد تنبيه المخزون">
      <textarea name="description" rows="3" placeholder="تفاصيل المنتج">${escv(item.description||item.details||'')}</textarea>
      <label class="admin-product-images-field"><span>صور المنتج — يمكنك اختيار عدة صور (حد أقصى 8)</span><input name="images" type="file" accept="image/*" multiple></label>
      ${gallery}
      <small class="muted">أول صورة محفوظة تكون الصورة الرئيسية في بطاقة المتجر.</small>
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
    const subcategoryId=String(data.get('subcategoryId')||'').trim();
    const subcategoryRow=subcategoryId?subcategories().find(item=>String(item.id)===subcategoryId&&String(item.parent_category_id)===String(categoryRow?.id||'')):null;
    if(subcategoryId&&!subcategoryRow)return alert('الشعبة المختارة لا تتبع هذا القسم');
    const unitPrice=Number(data.get('unitPrice')||0);
    const previousPrice=Number(data.get('previousPrice')||0);
    const packPriceRaw=String(data.get('packPrice')||'').trim();
    const packSizeRaw=String(data.get('packSize')||'').trim();
    const packPrice=packPriceRaw===''?null:Number(packPriceRaw);
    const packSize=packSizeRaw===''?null:Number(packSizeRaw);
    const stock=Number(data.get('stock')||0);
    const lowStockLimit=Number(data.get('lowStockLimit')||5);
    const description=String(data.get('description')||'').trim();
    if(!name)return alert('اكتب اسم المنتج');
    if(!Number.isFinite(unitPrice)||unitPrice<0)return alert('سعر المفرد غير صحيح');
    if(previousPrice&&(!Number.isFinite(previousPrice)||previousPrice<=unitPrice))return alert('السعر السابق يجب أن يكون أعلى من سعر المفرد');
    if((packPrice===null)!=(packSize===null))return alert('أدخل سعر الباكيت وعدد القطع معاً أو اتركهما فارغين');
    if(packPrice!==null&&(!Number.isFinite(packPrice)||packPrice<=0))return alert('سعر الباكيت غير صحيح');
    if(packSize!==null&&(!Number.isInteger(packSize)||packSize<2))return alert('عدد قطع الباكيت يجب أن يكون 2 أو أكثر');
    if(!Number.isFinite(stock)||stock<0)return alert('المخزون غير صحيح');
    try{
      const removed=new Set(data.getAll('removeImage').map(value=>String(value||'').trim()).filter(Boolean));
      const kept=normalizeImages(existing||{}).filter(path=>!removed.has(path));
      const files=Array.from(form.querySelector('input[name="images"]')?.files||[]).slice(0,Math.max(0,8-kept.length));
      const uploaded=[];
      for(const file of files){const path=await uploadImage(file);if(path)uploaded.push(String(path))}
      const images=[...kept,...uploaded].filter(Boolean).slice(0,8);
      const payload={
        name,title:name,type,category,category_id:categoryRow?.id||null,subcategory_id:subcategoryRow?.id||null,
        unit_price:unitPrice,pack_price:packPrice,pack_size:packSize,
        price:previousPrice>unitPrice?previousPrice:unitPrice,
        sale_price:previousPrice>unitPrice?unitPrice:null,stock,
        low_stock_limit:Math.max(0,lowStockLimit||0),description,details:description,
        images,image_path:images[0]||null,
        status:existing?.status||'published',updated_at:new Date().toISOString()
      };
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
    const currentPrice=Number(item.unit_price??item.sale_price??item.deal_price??item.price??0),previousPrice=currentPrice<Number(item.price||0)?Number(item.price||0):0;
    const packPrice=Number(item.pack_price||0),packSize=Number(item.pack_size||0);
    return `<article class="admin-product-v129-card">
      <div class="admin-product-v129-image">${image?`<img src="${escv(image)}" alt="${escv(item.name||'منتج')}">`:`<span>${normalizeType(item.type)==='gift'?'🎁':'✏️'}</span>`}<em class="status ${escv(status)}">${statusLabel(status)}</em></div>
      <div class="admin-product-v129-body">
        <div class="admin-product-v129-title"><div><small>${typeLabel(item.type)} • ${escv(item.category||'عام')}${item.subcategory_id&&subcategoryById(item.subcategory_id)?` • ${escv(subcategoryById(item.subcategory_id).name)}`:''}</small><h3>${escv(item.name||item.title||'منتج')}</h3></div><div class="admin-product-price-pair"><strong>مفرد: ${moneyv(currentPrice)} د.ع</strong>${packPrice>0&&packSize>=2?`<small>باكيت (${moneyv(packSize)}): ${moneyv(packPrice)} د.ع</small>`:''}${previousPrice?`<del>${moneyv(previousPrice)} د.ع</del>`:''}</div></div>
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
    refreshProductSubcategories();
  }

  function refreshProductSubcategories(){
    const type=document.getElementById('alinProductType')?.value||'stationery';
    const category=document.getElementById('alinProductCategory')?.value||'';
    const select=document.getElementById('alinProductSubcategory');
    if(!select)return;
    const previous=select.value;
    select.innerHTML=subcategoryOptions(type,category,previous);
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
    </section>${subcategoryAdminHtml()}`;
  }

  function productCategoryChoices(){
    return categories().filter(item=>['stationery','gift'].includes(normalizeType(item.type))&&String(item.status||'active')==='active').sort((a,b)=>Number(a.sort_order||0)-Number(b.sort_order||0)||String(a.name||'').localeCompare(String(b.name||''),'ar'));
  }

  function subcategoryAdminHtml(){
    const parentRows=productCategoryChoices();
    const rows=[...subcategories()].sort((a,b)=>String(a.parent_category_id||'').localeCompare(String(b.parent_category_id||''))||Number(a.sort_order||0)-Number(b.sort_order||0)||String(a.name||'').localeCompare(String(b.name||''),'ar'));
    const parentName=id=>categories().find(item=>String(item.id)===String(id))?.name||'قسم غير معروف';
    return `<section class="admin-subcategories-v1"><header><div><h2>شُعب المنتجات</h2><p>مثلاً: أقلام، دفاتر، ألوان. كل شعبة تظهر كرف مستقل داخل القسم مع زر «عرض المزيد».</p></div></header>
      <form id="alinSubcategoryForm" class="form-grid admin-subcategory-create">
        <select name="parentCategoryId" required>${parentRows.map(item=>`<option value="${escv(item.id)}">${escv(item.name)}</option>`).join('')}</select>
        <input name="name" placeholder="اسم الشعبة، مثال: أقلام" required>
        <input name="sortOrder" type="number" min="0" value="10" placeholder="ترتيب الظهور">
        <button type="button" data-alin-click="addProductSubcategory">إضافة الشعبة</button>
      </form>
      <div class="admin-subcategory-list">${rows.length?rows.map(item=>`<article class="admin-subcategory-card ${String(item.status||'active')==='active'?'':'is-hidden'}"><div><b>${escv(item.name)}</b><small>${escv(parentName(item.parent_category_id))} • ترتيب ${Number(item.sort_order||0)}</small></div><div class="row-actions"><button type="button" class="secondary" data-alin-click="editProductSubcategory" data-alin-click-arg0="${escv(item.id)}">تعديل</button><button type="button" data-alin-click="toggleProductSubcategory" data-alin-click-arg0="${escv(item.id)}">${String(item.status||'active')==='active'?'إخفاء':'إظهار'}</button><button type="button" class="danger" data-alin-click="deleteProductSubcategory" data-alin-click-arg0="${escv(item.id)}">حذف</button></div></article>`).join(''):'<div class="empty">لا توجد شعب بعد.</div>'}</div>
    </section>`;
  }

  async function addProductSubcategory(){
    const form=document.getElementById('alinSubcategoryForm');if(!form)return;
    const data=new FormData(form),parentCategoryId=String(data.get('parentCategoryId')||''),name=String(data.get('name')||'').trim(),sortOrder=Math.max(0,Number(data.get('sortOrder')||10));
    if(!parentCategoryId||!name)return alert('اختر القسم واكتب اسم الشعبة');
    if(subcategories().some(item=>String(item.parent_category_id)===parentCategoryId&&String(item.name||'').trim().toLowerCase()===name.toLowerCase()))return alert('هذه الشعبة موجودة مسبقاً داخل القسم');
    try{await window.insert('product_subcategories',{parent_category_id:parentCategoryId,name,status:'active',sort_order:sortOrder,created_at:new Date().toISOString(),updated_at:new Date().toISOString()});await reloadAndRender(renderCategoriesAdmin);window.renderStore?.();window.toast?.('تمت إضافة الشعبة');}catch(error){alert(error?.message||'تعذر إضافة الشعبة')}
  }

  async function editProductSubcategory(id){
    const item=subcategoryById(id);if(!item)return;
    const name=prompt('اسم الشعبة',item.name||'');if(name===null)return;const clean=String(name).trim();if(!clean)return alert('اكتب اسم الشعبة');
    const orderText=prompt('ترتيب الظهور',String(item.sort_order||10));if(orderText===null)return;const sortOrder=Math.max(0,Number(orderText||0));
    try{await window.update('product_subcategories',{name:clean,sort_order:sortOrder,updated_at:new Date().toISOString()},{id:item.id});await reloadAndRender(renderCategoriesAdmin);window.renderStore?.();window.toast?.('تم تعديل الشعبة');}catch(error){alert(error?.message||'تعذر تعديل الشعبة')}
  }

  async function toggleProductSubcategory(id){
    const item=subcategoryById(id);if(!item)return;const status=String(item.status||'active')==='active'?'inactive':'active';
    try{await window.update('product_subcategories',{status,updated_at:new Date().toISOString()},{id:item.id});await reloadAndRender(renderCategoriesAdmin);window.renderStore?.();window.toast?.(status==='active'?'تم إظهار الشعبة':'تم إخفاء الشعبة');}catch(error){alert(error?.message||'تعذر تغيير حالة الشعبة')}
  }

  async function deleteProductSubcategory(id){
    const item=subcategoryById(id);if(!item)return;const linked=products().filter(product=>String(product.subcategory_id||'')===String(item.id));
    if(linked.length)return alert(`لا يمكن حذف الشعبة لأنها مرتبطة بـ ${linked.length} منتج. انقل المنتجات أو أخفِ الشعبة.`);
    if(!confirm(`حذف شعبة ${item.name||''}؟`))return;
    try{await window.removeRow('product_subcategories',{id:item.id});await reloadAndRender(renderCategoriesAdmin);window.renderStore?.();window.toast?.('تم حذف الشعبة');}catch(error){alert(error?.message||'تعذر حذف الشعبة')}
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
  window.refreshProductSubcategories=refreshProductSubcategories;
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
  window.addProductSubcategory=addProductSubcategory;
  window.editProductSubcategory=editProductSubcategory;
  window.toggleProductSubcategory=toggleProductSubcategory;
  window.deleteProductSubcategory=deleteProductSubcategory;
  // Compatibility aliases point to the same implementation, not wrappers.
  window.alinV73AddProduct=window.addProduct;
  window.alinV73EditProduct=window.editProduct;
  window.alinV73DeleteProduct=window.deleteProduct;
  window.alinV79ToggleProduct=id=>{const item=products().find(row=>String(row.id)===String(id));return item?setProductStatus(id,String(item.status||'published')==='published'?'hidden':'published'):undefined};
  window.AlinAdminModules?.register?.('products',renderProductsAdmin);
  window.AlinAdminModules?.register?.('categories',renderCategoriesAdmin);
})();
