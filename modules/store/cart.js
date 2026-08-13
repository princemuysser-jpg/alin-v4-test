// === modules/store/cart.js ===
/* ALIN v2.1.8 — authoritative cart module. Delivery uses area + landmark + GPS only. */
(function(){
  'use strict';

  const STORAGE_BASE='ALIN_CART';
  const storageKey=()=>window.AlinStudentIsolation?.key?.(STORAGE_BASE)||STORAGE_BASE;
  const aliases={booklet:'booklet',booklets:'booklet','ملزمة':'booklet','ملازم':'booklet',product:'product',products:'product',stationery:'product',stationary:'product',gift:'product',gifts:'product',deal:'product',booklet_product:'product'};
  const $=id=>document.getElementById(id);
  const num=value=>Number(value||0);
  const escText=value=>typeof window.esc==='function'?window.esc(value):String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const formatMoney=value=>typeof window.money==='function'?window.money(value):num(value).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const same=(a,b)=>String(a??'')===String(b??'');

  function readStoredCart(){
    try{
      const rows=JSON.parse(localStorage.getItem(storageKey())||'[]');
      return Array.isArray(rows)?rows:[];
    }catch(_){return []}
  }

  if(!Array.isArray(window.cart))window.cart=readStoredCart();

  function rows(){return Array.isArray(window.cart)?window.cart:(window.cart=[])}
  function booklets(){return Array.isArray(window.db?.booklets)?window.db.booklets:[]}
  function products(){return Array.isArray(window.db?.products)?window.db.products:[]}
  function findBooklet(id){return booklets().find(item=>same(item.id,id))||null}
  function findProduct(id){return products().find(item=>same(item.id,id))||null}
  function itemCurrentPrice(item,purchaseType='unit'){
    if(purchaseType==='pack'&&num(item?.pack_price)>0&&num(item?.pack_size)>=2)return num(item.pack_price);
    const base=num(item?.unit_price??item?.price);
    const sale=num(item?.sale_price??item?.deal_price);
    const start=item?.deal_start?Date.parse(item.deal_start):0;
    const end=item?.deal_end?Date.parse(item.deal_end):0;
    const now=Date.now();
    const validWindow=(!start||start<=now)&&(!end||end>=now);
    return sale>0&&sale<base&&validWindow?sale:base;
  }

  function normalizeKindAndId(kind,id){
    let rawKind=String(kind??'').trim().toLowerCase();
    let rawId=String(id??'').trim();
    let booklet=findBooklet(rawId),product=findProduct(rawId);
    if(!booklet&&!product&&rawKind){
      const swappedBooklet=findBooklet(rawKind),swappedProduct=findProduct(rawKind);
      if(swappedBooklet||swappedProduct){rawId=rawKind;rawKind=String(id??'').trim().toLowerCase();booklet=swappedBooklet;product=swappedProduct}
    }
    return {kind:booklet?'booklet':product?'product':aliases[rawKind]||'',id:rawId,item:booklet||product};
  }

  function normalizeLine(line,index=0){
    const normalized=normalizeKindAndId(line?.kind,line?.id);
    if(!normalized.kind||!normalized.id)return null;
    const source=normalized.item;
    const purchaseType=normalized.kind==='product'&&String(line?.purchase_type||line?.purchaseType||'unit')==='pack'&&num(source?.pack_price)>0&&num(source?.pack_size)>=2?'pack':'unit';
    const packSize=purchaseType==='pack'?Math.floor(num(source?.pack_size)||0):null;
    return {
      kind:normalized.kind,
      id:normalized.id,
      title:String(source?.title||source?.name||line?.title||`العنصر ${index+1}`),
      price:source?itemCurrentPrice(source,purchaseType):num(line?.price),
      qty:Math.max(1,Math.min(100,Math.floor(num(line?.qty)||1))),
      purchase_type:purchaseType,
      pack_size:packSize
    };
  }

  function normalizeCart(){
    const normalized=rows().map(normalizeLine).filter(Boolean);
    window.cart=normalized;
    return normalized;
  }

  function imageFor(item){
    const path=item?.cover_path||item?.image_path||item?.image||item?.image_url||item?.cover_url||item?.thumbnail||'';
    if(!path)return '';
    try{return typeof window.mediaUrl==='function'?window.mediaUrl(path):path}catch(_){return path}
  }

  function cartCount(){return rows().reduce((sum,line)=>sum+Math.max(1,num(line.qty)),0)}
  function cartTotal(){return rows().reduce((sum,line)=>sum+num(line.price)*Math.max(1,num(line.qty)),0)}
  function appliedCoupon(){return window.AlinCoupons?.getApplied?.()||null}
  function cartPricing(){
    const subtotal=cartTotal();
    const coupon=appliedCoupon();
    const discount=typeof window.AlinCoupons?.calculateCartDiscount==='function'
      ? window.AlinCoupons.calculateCartDiscount(coupon,rows())
      : rows().reduce((sum,line)=>sum+(typeof window.calculateCouponDiscount==='function'?window.calculateCouponDiscount(coupon,num(line.price)*Math.max(1,num(line.qty))):0),0);
    return {subtotal,discount:Math.min(subtotal,Math.max(0,num(discount))),total:Math.max(0,subtotal-Math.max(0,num(discount))),coupon};
  }
  function hasProducts(){return rows().some(line=>line.kind!=='booklet')}
  function activeLibraries(){
    return (window.db?.accounts?.libraries||[]).filter(item=>{
      const status=String(item?.status||'active').toLowerCase();
      return !item?.deleted_at&&!['inactive','disabled','rejected','deleted'].includes(status);
    });
  }
  function libraryKey(library){
    return String(library?.id||library?.library_id||library?.account_id||library?.user_id||library?.username||'').trim();
  }
  function libraryDisplayName(library,fallback='مكتبة'){
    const candidates=[library?.name,library?.library_name,library?.display_name,library?.full_name,library?.business_name,library?.store_name,library?.shop_name,library?.title,library?.account_name,library?.public_name,library?.username,fallback];
    const value=candidates.find(item=>String(item??'').trim());
    return String(value||fallback).trim()||fallback;
  }
  function libraryByKey(value){
    const wanted=String(value||'').trim();
    return activeLibraries().find(item=>[item?.id,item?.library_id,item?.account_id,item?.user_id,item?.username].some(candidate=>same(candidate,wanted)))||null;
  }
  function selectedOptionLibraryName(option){
    const raw=String(option?.dataset?.libraryName||option?.label||option?.textContent||'').trim();
    return raw.replace(/\s*(?:—|-)\s*(?:مفتوح|مغلق).*$/u,'').trim();
  }
  function libraryOpen(library){
    try{return typeof window.libIsOpen==='function'?!!window.libIsOpen(library):!(library?.is_open===false||String(library?.is_open)==='false'||String(library?.open_status||'').toLowerCase()==='closed')}catch(_){return true}
  }
  function libraryOptions(){
    return activeLibraries().map(library=>{
      const id=libraryKey(library),name=libraryDisplayName(library);
      if(!id)return '';
      const open=libraryOpen(library);
      return `<option value="${escText(id)}" data-library-name="${escText(name)}" ${open?'':'disabled'}>${escText(name)} — ${open?'مفتوح':'مغلق'}${library.area?` — ${escText(library.area)}`:''}</option>`;
    }).join('');
  }
  function courierOptions(){
    try{
      const list=typeof window.activeCouriers==='function'?window.activeCouriers():[];
      return (Array.isArray(list)?list:[]).map(courier=>`<option value="${escText(courier.id)}">${escText(courier.name||'مندوب')}${courier.area?` — ${escText(courier.area)}`:''}</option>`).join('');
    }catch(_){return ''}
  }

  function deliveryAreaNames(){
    const cloud=window.db?.deliveryAreas||window.db?.delivery_areas||[];
    const fallback=Array.isArray(window.ALIN_KIRKUK_AREAS)?window.ALIN_KIRKUK_AREAS:[];
    return [...new Set((cloud.length?cloud.map(row=>row?.name):fallback).map(name=>String(name||'').trim()).filter(Boolean))];
  }
  function deliveryAreaOptions(){
    return `<option value="">اختر منطقة التوصيل</option>`+deliveryAreaNames().map(name=>`<option value="${escText(name)}">${escText(name)}</option>`).join('');
  }

  function dispatch(name,detail={}){document.dispatchEvent(new CustomEvent(name,{detail}))}

  function renderCartBadge(){
    const count=cartCount(),pricing=cartPricing();
    const ids=['cartCount','cartCountFab','desktopCartCount','mobileCartCount','mobileBottomCartCount'];
    ids.forEach(id=>{const element=$(id);if(!element)return;element.textContent=String(count);if('hidden'in element)element.hidden=!count});
    const summary=$('cartSummary');if(summary)summary.textContent=count?`${count} مادة في السلة`:'';
    dispatch('alin:cart-changed',{count,total:pricing.total,subtotal:pricing.subtotal,discount:pricing.discount,items:rows().map(item=>({...item}))});
    return count;
  }

  function cartSave(){
    normalizeCart();
    localStorage.setItem(storageKey(),JSON.stringify(rows()));
    if(!rows().length&&window.AlinCoupons?.getAppliedCode?.())window.AlinCoupons.clear();
    renderCartBadge();
  }

  function addToCart(kind,id,qty=1,purchaseType='unit'){
    const normalized=normalizeKindAndId(kind,id);
    if(!normalized.item){
      if(typeof window.toast==='function')window.toast('تعذر العثور على المادة في المتجر');
      return false;
    }
    const amount=Math.max(1,Math.min(100,Math.floor(num(qty)||1)));
    const type=normalized.kind==='product'&&purchaseType==='pack'&&num(normalized.item.pack_price)>0&&num(normalized.item.pack_size)>=2?'pack':'unit';
    const packSize=type==='pack'?Math.floor(num(normalized.item.pack_size)):null;
    const unitsPerQty=type==='pack'?packSize:1;
    if(normalized.kind==='product'&&num(normalized.item.stock)<=0){alert('المنتج نافد');return false}
    const current=rows().find(line=>line.kind===normalized.kind&&same(line.id,normalized.id)&&String(line.purchase_type||'unit')===type);
    const nextQty=(current?.qty||0)+amount;
    if(normalized.kind==='product'&&num(normalized.item.stock)<nextQty*unitsPerQty){alert('الكمية المطلوبة غير متوفرة');return false}
    const price=itemCurrentPrice(normalized.item,type);
    if(current){current.qty=nextQty;current.title=normalized.item.title||normalized.item.name||current.title;current.price=price;current.purchase_type=type;current.pack_size=packSize}
    else rows().push({kind:normalized.kind,id:normalized.id,title:normalized.item.title||normalized.item.name||'مادة',price,qty:amount,purchase_type:type,pack_size:packSize});
    cartSave();
    if(typeof window.toast==='function')window.toast(type==='pack'?'تمت إضافة الباكيت إلى السلة':'تمت الإضافة إلى السلة');
    return true;
  }

  function cartQty(index,delta){
    const line=rows()[index];if(!line)return;
    const next=Math.max(1,Math.min(100,num(line.qty)+num(delta)));
    const source=line.kind==='booklet'?findBooklet(line.id):findProduct(line.id);
    const unitsPerQty=line.purchase_type==='pack'?Math.max(2,num(line.pack_size||source?.pack_size)):1;
    if(line.kind==='product'&&source&&num(source.stock)<next*unitsPerQty){alert('الكمية المطلوبة غير متوفرة');return}
    line.qty=next;cartSave();openCart({kind:line.kind,id:line.id});
  }

  function cartRemove(index){
    if(!rows()[index])return;
    rows().splice(index,1);cartSave();openCart();
  }

  function checkoutGpsHtml(){
    return `<section class="v162-gps-box" id="v162GpsBox">
      <div class="v162-gps-head"><div><b>نقطة موقع التوصيل GPS</b><small>تساعد الإدارة والمندوب على الوصول لنقطة التسليم بدقة.</small></div><span id="v162GpsStatus" class="v162-gps-status">غير محدد</span></div>
      <div class="v162-gps-actions">
        <button type="button" class="v162-gps-primary" data-alin-click="alinV162UseCurrentLocation"><span aria-hidden="true">⌖</span> استخدام موقعي الحالي</button>
        <button type="button" id="v162OpenMapBtn" class="secondary" data-alin-click="alinV162OpenSelectedMap" disabled>فتح الموقع على الخريطة</button>
        <button type="button" id="v162ClearGpsBtn" class="secondary" data-alin-click="alinV162ClearGps" hidden>مسح الموقع</button>
      </div>
      <div id="v162GpsDetails" class="v162-gps-details" hidden></div>
      <input type="hidden" id="deliveryLatitude"><input type="hidden" id="deliveryLongitude"><input type="hidden" id="deliveryLocationUrl"><input type="hidden" id="deliveryLocationAccuracy">
      <p class="v162-gps-note">حدد موقع التوصيل أو اكتب أقرب نقطة دالة، وبعد تأكيد الطلب تتولى الإدارة تعيين المندوب.</p>
    </section>`;
  }

  function fulfillmentHtml(){
    if(hasProducts()){
      return `<section class="alin-fulfillment"><h4>طريقة الاستلام والدفع</h4><div class="alin-delivery-options"><label class="selected"><input type="radio" name="fulfillment" value="home_delivery" checked><span><b>توصيل للبيت</b><small>القرطاسية والهدايا تُسلّم عن طريق المندوب</small></span></label></div><div id="deliveryFields" class="alin-delivery-fields"><div class="form-grid"><select id="deliveryArea" required>${deliveryAreaOptions()}</select><input id="deliveryLandmark" placeholder="أقرب نقطة دالة" required></div>${checkoutGpsHtml()}</div></section>`;
    }
    return `<section class="alin-fulfillment"><h4>طريقة الاستلام والدفع</h4><div class="alin-delivery-options"><label class="selected"><input type="radio" name="fulfillment" value="pickup" checked data-alin-change="toggleDeliveryFields"><span><b>استلام من المكتبة</b><small>الدفع عند الاستلام</small></span></label><label><input type="radio" name="fulfillment" value="home_delivery" data-alin-change="toggleDeliveryFields"><span><b>توصيل للبيت</b><small>الدفع للمندوب</small></span></label></div><div id="pickupFields" class="alin-pickup-fields"><select id="libSelect" data-alin-change="showLibInfo"><option value="">اختر مكتبة الاستلام</option>${libraryOptions()}</select><div id="libInfo"></div></div><div id="deliveryFields" class="alin-delivery-fields hidden"><div class="form-grid"><select id="deliveryArea" required>${deliveryAreaOptions()}</select><input id="deliveryLandmark" placeholder="أقرب نقطة دالة" required></div>${checkoutGpsHtml()}</div></section>`;
  }

  function ensureCartLibrarySummary(){
    const rowsBox=document.querySelector('#checkoutBox .alin-summary-rows');
    if(!rowsBox)return null;
    let row=document.getElementById('cartPickupLibraryRow');
    if(!row){
      row=document.createElement('div');
      row.id='cartPickupLibraryRow';
      row.className='alin-cart-library-summary';
      row.innerHTML='<span>مكتبة الاستلام</span><b id="cartPickupLibraryName">غير محددة</b>';
      rowsBox.appendChild(row);
    }
    return row;
  }

  function showLibInfo(){
    const select=$('libSelect'),box=$('libInfo');
    const summaryRow=ensureCartLibrarySummary();
    const summaryName=document.getElementById('cartPickupLibraryName');
    if(!select||!box){if(summaryRow)summaryRow.hidden=true;return}
    if(summaryRow)summaryRow.hidden=false;
    const selectedId=String(select.value||'').trim();
    if(!selectedId){box.replaceChildren();delete select.dataset.selectedLibraryName;if(summaryName)summaryName.textContent='غير محددة';return}
    const option=select.options?.[select.selectedIndex]||null;
    const library=libraryByKey(selectedId);
    const optionName=selectedOptionLibraryName(option);
    const name=optionName||libraryDisplayName(library,'مكتبة الاستلام');
    const details=[library?.area,library?.landmark].map(value=>String(value||'').trim()).filter(Boolean).join(' — ')||'مكتبة الاستلام المختارة';
    const open=library?libraryOpen(library):!option?.disabled;
    select.dataset.selectedLibraryName=name;
    box.dataset.libraryName=name;
    box.innerHTML=`<div class="alin-library-status" role="status" aria-live="polite"><div><small>المكتبة المختارة</small><b>${escText(name)}</b><small>${escText(details)}</small></div><span class="${open?'is-open':'is-closed'}">${open?'مفتوح':'مغلق'}</span></div>`;
    if(summaryName)summaryName.textContent=name;
  }

  function toggleDeliveryFields(){
    const fulfillment=document.querySelector('#checkoutBox input[name="fulfillment"]:checked')?.value||(hasProducts()?'home_delivery':'pickup');
    const pickup=$('pickupFields'),delivery=$('deliveryFields');
    if(pickup)pickup.classList.toggle('hidden',fulfillment!=='pickup');
    if(delivery)delivery.classList.toggle('hidden',fulfillment!=='home_delivery');
    document.querySelectorAll('#checkoutBox .alin-delivery-options label').forEach(label=>label.classList.toggle('selected',!!label.querySelector('input:checked')));
    dispatch('alin:fulfillment-changed',{fulfillment});
  }

  function itemIcon(kind){return kind==='booklet'?'📘':'🛍️'}

  function renderCartPricing(){
    const pricing=cartPricing();
    const subtotalElement=$('cartSubtotalValue');
    const discountElement=$('cartDiscountValue');
    const discountRow=$('cartDiscountRow');
    const finalElement=$('cartFinalValue');
    const input=$('couponInput');
    const message=$('couponMsg');
    if(subtotalElement)subtotalElement.textContent=`${formatMoney(pricing.subtotal)} د.ع`;
    if(discountElement)discountElement.textContent=`− ${formatMoney(pricing.discount)} د.ع`;
    if(discountRow)discountRow.hidden=pricing.discount<=0;
    if(finalElement)finalElement.textContent=`${formatMoney(pricing.total)} د.ع`;
    if(input&&pricing.coupon&&!input.value)input.value=pricing.coupon.code||'';
    if(message&&pricing.coupon&&pricing.discount>0&&!message.textContent){
      message.textContent=`تم تطبيق كوبون ${pricing.coupon.code} — الخصم ${formatMoney(pricing.discount)} د.ع`;
    }
    dispatch('alin:cart-pricing',{subtotal:pricing.subtotal,discount:pricing.discount,total:pricing.total,coupon:pricing.coupon});
    return pricing;
  }

  function openCart(context={}){
    normalizeCart();
    const box=window.checkoutBox||$('checkoutBox'),modal=window.checkoutModal||$('checkoutModal');
    if(!box||!modal)return;
    window.checkoutItem={kind:'cart'};
    const list=rows(),count=cartCount(),pricing=cartPricing(),total=pricing.subtotal;
    if(!list.length){
      box.innerHTML='<div class="alin-cart-shell"><div class="alin-cart-main"><div class="alin-cart-empty"><div class="alin-empty-icon">🛒</div><h3>السلة فارغة حالياً</h3><p>أضف ملازم أو قرطاسية أو هدايا ثم ارجع لإتمام الطلب.</p><button type="button" data-alin-click="@close-checkout-scroll-store">تصفح المتجر</button></div></div><aside class="alin-cart-side"><h3>ملخص الطلب</h3><div class="alin-summary-card"><div class="alin-summary-rows"><div><span>عدد المواد</span><b>0</b></div><div><span>الإجمالي</span><b>0 د.ع</b></div></div></div></aside></div>';
    }else{
      const itemsHtml=list.map((line,index)=>{
        const source=line.kind==='booklet'?findBooklet(line.id):findProduct(line.id),image=imageFor(source),lineTotal=num(line.price)*num(line.qty);
        return `<article class="alin-cart-item"><div class="alin-cart-thumb">${image?`<img src="${escText(image)}" alt="${escText(line.title)}">`:`<span>${itemIcon(line.kind)}</span>`}</div><div class="alin-cart-info"><h3 class="alin-cart-title">${escText(line.title)}</h3><div class="alin-cart-meta"><span class="alin-cart-chip">${line.kind==='booklet'?'ملزمة':line.purchase_type==='pack'?`باكيت ${formatMoney(line.pack_size)} قطع`:'مفرد'}</span><span class="alin-cart-chip">السعر: ${formatMoney(line.price)} د.ع</span></div><div class="alin-cart-price">${formatMoney(lineTotal)} د.ع</div></div><div class="alin-cart-controls"><div class="alin-qty-box"><button type="button" aria-label="تقليل الكمية" data-alin-click="cartQty" data-alin-click-arg0="${index}" data-alin-click-arg1="-1" data-alin-click-arg1-type="number">−</button><b>${line.qty}</b><button type="button" aria-label="زيادة الكمية" data-alin-click="cartQty" data-alin-click-arg0="${index}" data-alin-click-arg1="1" data-alin-click-arg1-type="number">+</button></div><button type="button" class="alin-remove-btn" data-alin-click="cartRemove" data-alin-click-arg0="${index}">حذف من السلة</button></div></article>`;
      }).join('');
      box.innerHTML=`<div class="alin-cart-shell"><section class="alin-cart-main"><div class="alin-cart-head"><div><h2>سلة آلين</h2><p>راجع المواد والكميات قبل تأكيد الطلب.</p></div><span class="alin-cart-badge">${count}</span></div><div class="alin-cart-list">${itemsHtml}</div></section><aside class="alin-cart-side"><h3>ملخص الطلب</h3><div class="alin-cart-side-content"><div class="alin-summary-card"><div class="alin-summary-rows"><div><span>عدد المواد</span><b>${count}</b></div><div><span>المجموع الفرعي</span><b id="cartSubtotalValue">${formatMoney(pricing.subtotal)} د.ع</b></div><div id="cartDiscountRow" ${pricing.discount>0?'':'hidden'}><span>خصم الكوبون</span><b id="cartDiscountValue">− ${formatMoney(pricing.discount)} د.ع</b></div></div><div class="alin-summary-total"><div>الإجمالي النهائي</div><b id="cartFinalValue">${formatMoney(pricing.total)} د.ع</b></div><div class="coupon-box"><input id="couponInput" value="${escText(pricing.coupon?.code||'')}" placeholder="أدخل كود الخصم"><button type="button" data-alin-click="checkCoupon">تطبيق</button></div><div id="couponMsg">${pricing.coupon&&pricing.discount>0?`تم تطبيق كوبون ${escText(pricing.coupon.code)} — الخصم ${formatMoney(pricing.discount)} د.ع`:''}</div><div class="alin-cart-form"><h4>بيانات الطالب والاستلام</h4><div class="form-grid"><input id="studentName" placeholder="اسم الطالب الكامل"><input id="studentPhone" placeholder="رقم الهاتف"></div><textarea id="orderNotes" rows="2" maxlength="1000" placeholder="ملاحظات على الطلب (اختياري)"></textarea>${fulfillmentHtml()}</div></div><button type="button" class="alin-cart-submit" data-alin-click="confirmCartCheckout">تأكيد الطلب الآن</button></aside></div>`;
    }
    modal.classList.remove('hidden');
    document.body?.classList.add('alin-cart-open');
    const close=modal.querySelector('.x');if(close){close.textContent='إغلاق';close.setAttribute('aria-label','إغلاق السلة')}
    setTimeout(()=>{toggleDeliveryFields();showLibInfo();window.setTimeout(showLibInfo,120);renderCartPricing();dispatch('alin:cart-rendered',{kind:context.kind||'',id:context.id||'',count,subtotal:pricing.subtotal,discount:pricing.discount,total:pricing.total})},0);
  }

  function openCheckout(kind,id){
    const normalized=normalizeKindAndId(kind,id);
    if(!normalized.item)return alert('المادة غير موجودة');
    const pause=String(window.db?.settings?.order_pause_scope||'');
    const itemScope=String(normalized.item.type||normalized.item.category||'');
    if(pause&&(pause==='all'||pause===normalized.kind||pause===itemScope))return alert(window.db?.settings?.order_pause_reason||'الطلبات متوقفة مؤقتاً');
    if(addToCart(normalized.kind,normalized.id))openCart({kind:normalized.kind,id:normalized.id});
  }

  function closeCheckout(){
    const modal=window.checkoutModal||$('checkoutModal');if(modal)modal.classList.add('hidden');
    document.body?.classList.remove('alin-cart-open');
    window.checkoutItem=null;
    const close=modal?.querySelector('.x');if(close){close.textContent='×';close.setAttribute('aria-label','إغلاق')}
    dispatch('alin:cart-closed');
  }

  function updateTotal(){return renderCartPricing().total}

  function switchCartScope(){
    window.cart=readStoredCart().map(normalizeLine).filter(Boolean);
    try{window.AlinCoupons?.clear?.()}catch(_){}
    const modal=document.getElementById('checkoutModal');
    if(modal&&!modal.classList.contains('hidden')){try{closeCheckout()}catch(_){modal.classList.add('hidden')}}
    renderCartBadge();
    document.dispatchEvent(new CustomEvent('alin:cart-scope-changed',{detail:{items:rows().map(item=>({...item}))}}));
  }
  document.addEventListener('alin:storage-scope-changed',switchCartScope);
  document.addEventListener('change',event=>{if(event.target?.id==='libSelect')showLibInfo()});
  document.addEventListener('input',event=>{if(event.target?.id==='libSelect')showLibInfo()});
  document.addEventListener('alin:data-refreshed',()=>{if(document.getElementById('libSelect'))showLibInfo()});

  Object.assign(window,{cartSave,renderCartBadge,renderCartPricing,cartPricing,addToCart,cartQty,cartRemove,openCart,openCheckout,closeCheckout,showLibInfo,toggleDeliveryFields,updateTotal,alinCartQty:cartQty,alinCartRemove:cartRemove,alinApplyCoupon:()=>window.checkCoupon?.()});

  document.addEventListener('alin:coupon-changed',()=>renderCartPricing());

  function install(){normalizeCart();cartSave()}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
})();
