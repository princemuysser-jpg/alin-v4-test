// === store/discovery-details.js ===
// Product details, related items, sharing, stock alerts, reviews and bundles.
(()=>{
  'use strict';
  const ctx=window.AlinStoreDiscovery;
  if(!ctx)throw new Error('AlinStoreDiscovery core must load before details');
  const {$,esc,num,fmt,imageUrl,state,canonicalItems,activeDeal,effectivePrice,comparisonPrice,badges,findItem,isFavorite,openModal,hasSb,stableKey}=ctx;

  const reviewsFor=item=>(state.tables.product_reviews||[]).filter(row=>row.kind===item.kind&&String(row.item_id)===item.id&&['approved','published'].includes(row.status||'approved'));
  const clampRating=value=>Math.max(0,Math.min(5,num(value)));
  const starText=value=>{
    const rounded=Math.round(clampRating(value));
    return `${'★'.repeat(rounded)}${'☆'.repeat(5-rounded)}`;
  };
  function ratingBreakdown(reviews){
    const total=reviews.length||0;
    return [5,4,3,2,1].map(star=>{
      const count=reviews.filter(row=>Math.round(clampRating(row.rating))===star).length;
      const width=total?Math.round((count/total)*100):0;
      return `<div class="v99-rating-bar"><span>${fmt(star)} ★</span><i><b style="width:${width}%"></b></i><small>${fmt(count)}</small></div>`;
    }).join('');
  }
  function relatedItems(item){
    return canonicalItems().filter(candidate=>stableKey(candidate.kind,candidate.id)!==stableKey(item.kind,item.id)).map(candidate=>({
      item:candidate,
      score:(candidate.subject&&candidate.subject===item.subject?5:0)
        +(candidate.grade&&candidate.grade===item.grade?4:0)
        +(candidate.teacherId&&String(candidate.teacherId)===String(item.teacherId)?3:0)
        +(candidate.category&&candidate.category===item.category?2:0)
    })).filter(row=>row.score>0).sort((a,b)=>b.score-a.score).slice(0,6).map(row=>row.item);
  }
  function relatedDetailHtml(item){
    const rows=relatedItems(item);
    return rows.length?`<section class="v99-related"><div class="v99-section-head"><div><h2>مواد مرتبطة</h2><small>اقتراحات من نفس المادة أو المرحلة</small></div></div><div class="v99-rail">${rows.map(ctx.miniCard).join('')}</div></section>`:'';
  }

  function openDetails(kind,id){
    const item=findItem(kind,id);
    if(!item)return;
    const reviews=reviewsFor(item);
    const average=reviews.length?reviews.reduce((sum,row)=>sum+clampRating(row.rating),0)/reviews.length:0;
    const variants=Array.isArray(item.variants)?item.variants:[];
    const out=item.stock!==null&&item.stock<=0;
    const current=effectivePrice(item),previous=comparisonPrice(item),hasPrevious=activeDeal(item)&&previous>current;
    const discount=hasPrevious?Math.max(1,Math.round((1-current/previous)*100)):0;
    const reviewRows=reviews.slice(0,8).map(review=>`<article class="v99-review-card"><div class="v99-review-stars" aria-label="تقييم ${fmt(review.rating)} من 5">${starText(review.rating)}</div><p>${esc(review.comment||'تقييم بدون تعليق')}</p><small>تقييم موثّق في منصة آلين</small></article>`).join('');
    const gallery=[...(item.images||[]),item.image,...variants.map(row=>row.image)].map(String).filter(Boolean).filter((value,index,array)=>array.indexOf(value)===index);
    const galleryHtml=gallery.length?`<div class="alin-product-gallery"><div class="v99-detail-media"><img id="alinProductMainImage" src="${esc(imageUrl(gallery[0]))}" alt="${esc(item.title)}">${discount?`<span class="v99-detail-discount">خصم ${fmt(discount)}%</span>`:''}</div>${gallery.length>1?`<div class="alin-product-thumbs">${gallery.map((path,index)=>`<button type="button" class="${index===0?'active':''}" data-v99-action="imageThumb" data-src="${esc(imageUrl(path))}" aria-label="الصورة ${index+1}"><img src="${esc(imageUrl(path))}" alt=""></button>`).join('')}</div>`:''}</div>`:'<div class="v99-detail-media"><span class="v99-placeholder">ALIN</span></div>';
    const variantSelector=variants.length?`<section class="alin-product-model-picker"><div class="alin-product-model-picker__head"><div><h3>اختر التصميم</h3><small>اختيار التصميم مطلوب حتى يوصل الطلب للمخزن بصورة واضحة.</small></div><span>${fmt(variants.length)} موديل</span></div><div class="alin-product-model-list">${variants.map(variant=>{const variantOut=num(variant.stock)<=0;const image=variant.image?imageUrl(variant.image):'';return `<label class="alin-product-model ${variantOut?'is-out':''}"><input type="radio" name="v99Variant" value="${esc(variant.id)}" data-code="${esc(variant.code)}" data-name="${esc(variant.name)}" data-stock="${fmt(variant.stock)}" data-image="${esc(image)}" ${variantOut?'disabled':''}><span class="alin-product-model__image">${image?`<img src="${esc(image)}" alt="${esc(variant.name)}">`:'<i>آ</i>'}</span><span class="alin-product-model__copy"><b>${esc(variant.code||'—')}</b><strong>${esc(variant.name||'تصميم')}</strong><small>${variantOut?'نافد':`متوفر ${fmt(variant.stock)} قطعة`}</small></span>${variantOut?'<em>نافد</em>':''}</label>`}).join('')}</div><p id="v99VariantHint" class="alin-product-model-hint">اختر أحد التصاميم أعلاه قبل الإضافة للسلة.</p></section>`:'';
    openModal(`<section class="v99-detail-premium">
      <div class="v99-detail-main">
        ${galleryHtml}
        <div class="v99-detail-copy">
          <div class="v99-badges">${badges(item).map(label=>`<span class="v99-badge">${esc(label)}</span>`).join('')}</div>
          <h2>${esc(item.title)}</h2>
          <p class="v99-detail-meta-line">${esc([item.teacher,item.subject,item.grade,item.category].filter(Boolean).join(' • '))}</p>
          <div class="v99-detail-rating-summary"><span class="v99-rating-stars" aria-label="متوسط التقييم ${average.toFixed(1)} من 5">${starText(average)}</span><b>${reviews.length?average.toFixed(1):'جديد'}</b><small>${reviews.length?`${fmt(reviews.length)} تقييم`:'لا توجد تقييمات منشورة بعد'}</small></div>
          ${item.description?`<p class="v99-detail-description">${esc(item.description)}</p>`:''}
          <div class="v99-detail-price"><strong>سعر المفرد: ${fmt(current)} د.ع</strong>${hasPrevious?`<del>${fmt(previous)} د.ع</del><span>وفّر ${fmt(previous-current)} د.ع</span>`:''}${item.packPrice>0&&item.packSize>=2?`<strong class="alin-pack-price">سعر الباكيت: ${fmt(item.packPrice)} د.ع <small>(${fmt(item.packSize)} قطع)</small></strong>`:''}</div>
          <div class="v99-detail-facts v99-detail-facts-stock-only"><span>${out?'غير متوفر حالياً':item.stock===null?'متاح للطلب':`المخزون الكلي: ${fmt(item.stock)} قطعة`}</span></div>
          ${variantSelector}
          ${item.kind!=='booklet'&&item.packPrice>0&&item.packSize>=2?`<div class="alin-purchase-type"><label><input type="radio" name="v99PurchaseType" value="unit" checked> <span>مفرد — ${fmt(current)} د.ع</span></label><label><input type="radio" name="v99PurchaseType" value="pack"> <span>باكيت ${fmt(item.packSize)} قطع — ${fmt(item.packPrice)} د.ع</span></label></div>`:''}
          <div class="v99-qty"><label for="v99DetailQty">الكمية</label><input id="v99DetailQty" type="number" min="1" max="99" value="1"></div>
          <div class="v99-actions">${out?`<button data-v99-action="stockForm" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">أبلغني عند التوفر</button>`:`<button data-v99-action="cartQty" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">أضف للسلة</button>`}<button class="v99-ghost" data-v99-action="favorite" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">${isFavorite(item)?'إزالة من المفضلة':'حفظ بالمفضلة'}</button><button class="v99-ghost" data-v99-action="share" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">مشاركة</button></div>
        </div>
      </div>
      <section class="v99-reviews v99-reviews-premium"><div class="v99-reviews-head"><div><span>آراء العملاء</span><h3>التقييمات بالنجوم</h3></div><button data-v99-action="reviewForm" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">أضف تقييمك</button></div>
        <div class="v99-rating-overview"><div class="v99-rating-score"><strong>${reviews.length?average.toFixed(1):'—'}</strong><span class="v99-rating-stars">${starText(average)}</span><small>${reviews.length?`${fmt(reviews.length)} تقييم منشور`:'كن أول من يقيّم هذا المنتج'}</small></div><div class="v99-rating-bars">${ratingBreakdown(reviews)}</div></div>
        <div class="v99-review-list">${reviewRows||'<div class="v99-review-empty"><b>لا توجد تقييمات منشورة بعد</b><p>يمكنك إضافة تقييمك وسيظهر بعد مراجعته.</p></div>'}</div>
      </section>
      ${relatedDetailHtml(item)}
    </section>`);
  }

  async function shareItem(item){
    const url=new URL(location.href);
    url.hash='';
    url.searchParams.set('item',stableKey(item.kind,item.id));
    const data={title:item.title,text:`${item.title} — ${fmt(effectivePrice(item))} د.ع`,url:url.toString()};
    try{
      if(navigator.share)await navigator.share(data);
      else{await navigator.clipboard.writeText(`${data.text}\n${data.url}`);if(typeof window.toast==='function')window.toast('تم نسخ رابط المنتج')}
    }catch(error){if(error.name!=='AbortError')alert('تعذر نسخ الرابط')}
  }

  function stockForm(item){
    openModal(`<h2>أبلغني عند التوفر</h2><p>سنحفظ طلب التنبيه في النظام فقط إذا كانت الخدمة مفعلة.</p><div class="v99-form"><input id="v99StockContact" placeholder="رقم الهاتف"><button data-v99-action="stockSubmit" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">حفظ التنبيه</button><div id="v99FormMsg"></div></div>`);
  }
  async function publicSubmission(action,payload){
    const client=window.sb;
    if(!client?.functions?.invoke)throw new Error('خدمة الإرسال غير متاحة حالياً');
    const {data,error}=await client.functions.invoke('public-submission',{body:{action,...payload}});
    if(error){
      let detail=null;
      try{if(error.context&&typeof error.context.json==='function')detail=await error.context.json()}catch(_){}
      throw new Error(detail?.message||error.message||'تعذر إرسال الطلب حالياً');
    }
    if(!data?.ok)throw new Error(data?.message||'تعذر إرسال الطلب حالياً');
    return data;
  }
  async function stockSubmit(item){
    const contact=$('#v99StockContact')?.value.trim(),message=$('#v99FormMsg');
    if(!contact){if(message)message.innerHTML='<div class="v99-notice error">اكتب رقم الهاتف.</div>';return}
    if(!state.schema.stock_alerts||!hasSb()){if(message)message.innerHTML='<div class="v99-notice error">خدمة التنبيه غير مفعلة على قاعدة البيانات.</div>';return}
    try{
      const result=await publicSubmission('stock_alert',{kind:item.kind,item_id:item.id,contact});
      if(message)message.innerHTML=`<div class="v99-notice success">${esc(result.message||'تم تسجيل طلب التنبيه.')}</div>`;
    }catch(error){if(message)message.innerHTML=`<div class="v99-notice error">${esc(error.message||'تعذر تسجيل التنبيه حالياً')}</div>`}
  }

  function reviewForm(item){
    openModal(`<section class="v99-review-form"><span class="v99-kicker">شارك تجربتك</span><h2>قيّم ${esc(item.title)}</h2><p>اختر عدد النجوم واكتب رأيك. التقييم يظهر بعد مراجعة الإدارة.</p><div class="v99-form"><input id="v99ReviewContact" placeholder="رقم الهاتف"><label class="v99-rating-select"><span>التقييم</span><select id="v99ReviewRating"><option value="5">★★★★★ — ممتاز</option><option value="4">★★★★☆ — جيد جداً</option><option value="3">★★★☆☆ — جيد</option><option value="2">★★☆☆☆ — مقبول</option><option value="1">★☆☆☆☆ — ضعيف</option></select></label><textarea id="v99ReviewComment" placeholder="اكتب رأيك عن المنتج"></textarea><button data-v99-action="reviewSubmit" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">إرسال التقييم</button><div id="v99FormMsg"></div></div></section>`);
  }
  async function reviewSubmit(item){
    const message=$('#v99FormMsg'),contact=$('#v99ReviewContact')?.value.trim(),rating=num($('#v99ReviewRating')?.value),comment=$('#v99ReviewComment')?.value.trim();
    if(!contact||!comment){if(message)message.innerHTML='<div class="v99-notice error">أكمل رقم الهاتف والتعليق.</div>';return}
    if(!state.schema.product_reviews||!hasSb()){if(message)message.innerHTML='<div class="v99-notice error">خدمة التقييمات غير مفعلة.</div>';return}
    try{
      const result=await publicSubmission('review',{kind:item.kind,item_id:item.id,contact,rating,comment});
      if(message)message.innerHTML=`<div class="v99-notice success">${esc(result.message||'تم إرسال تقييمك للمراجعة قبل النشر.')}</div>`;
    }catch(error){if(message)message.innerHTML=`<div class="v99-notice error">${esc(error.message||'تعذر إرسال التقييم حالياً')}</div>`}
  }

  function teacherModal(id){
    const teacher=ctx.publicTeachers?.().find(row=>String(row.id)===String(id));
    if(!teacher)return;
    const books=canonicalItems().filter(item=>item.kind==='booklet'&&String(item.teacherId)===String(id));
    openModal(`<div class="v99-detail"><div><span class="v99-avatar">${teacher.avatar_path||teacher.image_path?`<img src="${esc(imageUrl(teacher.avatar_path||teacher.image_path))}" alt="">`:esc((teacher.name||'آ').slice(0,1))}</span></div><div class="v99-detail-copy"><span class="v99-kicker">ملف المدرس</span><h2>${esc(teacher.name)}</h2><p><b>${esc(teacher.specialty||'مدرس معتمد')}</b></p><p>${esc(teacher.bio||'مدرس معتمد في منصة آلين.')}</p></div></div><div class="v99-rail">${books.map(ctx.miniCard).join('')||'<div class="v99-empty">لا توجد ملازم منشورة حالياً.</div>'}</div>`);
  }

  function bundleModal(id){
    const bundle=(state.tables.bundles||[]).find(row=>String(row.id)===String(id));
    if(!bundle)return;
    const lines=(state.tables.bundle_items||[]).filter(row=>String(row.bundle_id)===String(id));
    const mapped=lines.map(line=>({...line,item:findItem(line.kind,String(line.item_id))})).filter(row=>row.item);
    openModal(`<h2>${esc(bundle.name||bundle.title)}</h2><p>${esc(bundle.description||'')}</p><div>${mapped.map(row=>`<div class="row"><div><b>${esc(row.item.title)}</b><small>الكمية ${fmt(row.quantity||1)}</small></div><span>${fmt(effectivePrice(row.item))} د.ع</span></div>`).join('')||'<div class="v99-empty">لا توجد عناصر متاحة في هذه الحزمة.</div>'}</div><div class="v99-price">سعر الحزمة: ${fmt(bundle.bundle_price||bundle.price)} د.ع</div><button data-v99-action="bundleAdd" data-id="${esc(id)}" ${mapped.length?'':'disabled'}>أضف الحزمة للسلة</button>`);
  }

  function addBundle(id){
    const lines=(state.tables.bundle_items||[]).filter(row=>String(row.bundle_id)===String(id));
    for(const line of lines){for(let index=0;index<Math.max(1,num(line.quantity));index++)window.addToCart?.(line.kind,String(line.item_id))}
    ctx.updateDesktopHeader();
    ctx.updateMobileHeader();
    if(typeof window.toast==='function')window.toast('أضيفت عناصر الحزمة المتاحة إلى السلة');
  }

  Object.assign(ctx,{reviewsFor,relatedItems,relatedDetailHtml,openDetails,shareItem,stockForm,stockSubmit,reviewForm,reviewSubmit,teacherModal,bundleModal,addBundle});
  window.v99OpenDetails=openDetails;
})();
