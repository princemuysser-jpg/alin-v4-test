// === store/discovery-catalog.js ===
// Store catalog rendering, filters, categories, rails and public statistics.
(()=>{
  'use strict';
  const ctx=window.AlinStoreDiscovery;
  if(!ctx)throw new Error('AlinStoreDiscovery core must load before catalog');
  const {$,$$,esc,num,fmt,imageUrl,state,canonicalItems,activeDeal,effectivePrice,badges,isFavorite,statusVisible,isDesktop,isMobile,studentProfile,updateDesktopHeader,updateMobileHeader}=ctx;

  const CATEGORY_ICON_PREFIX='store_category_icon_';
  const SECTION_VISIBLE_PREFIX='store_section_visible_';
  const BUILTIN_SECTIONS=[
    {key:'booklet',name:'ملازم',subtitle:'جميع المواد والمراحل',type:'booklet',order:1,iconClass:'cat-book'},
    {key:'stationery',name:'قرطاسية',subtitle:'أدوات الدراسة والكتب',type:'stationery',order:2,iconClass:'cat-pen'},
    {key:'gift',name:'هدايا',subtitle:'هدايا راقية ومميزة',type:'gift',order:3,iconClass:'cat-gift'},
    {key:'deal',name:'عروض',subtitle:'خصومات وعروض حصرية',type:'deal',order:4,iconClass:'cat-deal'}
  ];
  const settings=()=>window.db?.settings||{};
  const normalizeCategoryType=value=>{
    const type=String(value||'').trim().toLowerCase();
    if(['gift','gifts'].includes(type))return 'gift';
    if(['stationery','stationary'].includes(type))return 'stationery';
    if(['booklet','booklets'].includes(type))return 'booklet';
    if(['deal','deals','offer','offers'].includes(type))return 'deal';
    return type||'stationery';
  };
  const settingBool=(key,fallback=true)=>{
    const value=settings()[key];
    if(value===undefined||value===null||value==='')return fallback;
    return !['false','0','no','off','inactive','hidden'].includes(String(value).trim().toLowerCase());
  };
  const categoryRows=()=>Array.isArray(window.db?.categories)?window.db.categories:[];
  const productSubcategoryRows=()=>Array.isArray(window.db?.productSubcategories)?window.db.productSubcategories:[];
  const isBuiltinRow=row=>BUILTIN_SECTIONS.some(section=>section.key!=='deal'&&normalizeCategoryType(row?.type)===section.key&&String(row?.name||'').trim()===section.name);
  const categoryIconKey=section=>`${CATEGORY_ICON_PREFIX}${section.key}`;
  const categoryIcon=section=>String(settings()[categoryIconKey(section)]||'').trim();

  function storefrontSections(){
    const rows=categoryRows();
    const builtins=BUILTIN_SECTIONS.filter(section=>settingBool(`${SECTION_VISIBLE_PREFIX}${section.key}`,true)).map(section=>{
      const row=rows.find(item=>isBuiltinRow(item)&&normalizeCategoryType(item.type)===section.key);
      return {...section,order:Number(row?.sort_order||settings()[`store_section_order_${section.key}`]||section.order),rowId:row?.id||'',custom:false};
    });
    const customs=rows.filter(row=>!isBuiltinRow(row)&&String(row.status||'active')==='active').map((row,index)=>({
      key:`category:${row.id}`,
      rowId:String(row.id||''),
      name:String(row.name||'قسم'),
      subtitle:normalizeCategoryType(row.type)==='booklet'?'ملازم ضمن هذا القسم':normalizeCategoryType(row.type)==='gift'?'هدايا مختارة':'منتجات مختارة',
      type:normalizeCategoryType(row.type),
      order:Number(row.sort_order||50+index),
      iconClass:'cat-custom',
      custom:true
    })).filter(section=>settingBool(`${SECTION_VISIBLE_PREFIX}${section.key}`,true));
    return [...builtins,...customs].sort((a,b)=>a.order-b.order||a.name.localeCompare(b.name,'ar'));
  }

  function defaultCategorySvg(section){
    const type=normalizeCategoryType(section?.type||section?.key);
    if(type==='booklet')return `<svg viewBox="0 0 96 96" aria-hidden="true" focusable="false"><rect x="20" y="20" width="54" height="60" rx="10" class="cat-svg-fill-1"/><rect x="28" y="14" width="50" height="58" rx="10" class="cat-svg-fill-2"/><path d="M37 29h27M37 39h23M37 49h18" class="cat-svg-line"/><path d="M32 15v57" class="cat-svg-line soft"/></svg>`;
    if(type==='gift')return `<svg viewBox="0 0 96 96" aria-hidden="true" focusable="false"><rect x="18" y="39" width="60" height="40" rx="9" class="cat-svg-fill-1"/><rect x="14" y="31" width="68" height="19" rx="8" class="cat-svg-fill-2"/><path d="M48 31v48M25 49h46" class="cat-svg-line"/><path d="M47 31c-13-2-19-10-14-17 6-8 15 4 15 17Zm2 0c13-2 19-10 14-17-6-8-15 4-14 17Z" class="cat-svg-ribbon"/></svg>`;
    if(type==='deal')return `<svg viewBox="0 0 96 96" aria-hidden="true" focusable="false"><path d="M24 28h48l6 51H18l6-51Z" class="cat-svg-fill-1"/><path d="M34 32c0-11 5-18 14-18s14 7 14 18" class="cat-svg-line"/><path d="M33 56h30" class="cat-svg-line soft"/><circle cx="37" cy="50" r="5" class="cat-svg-dot"/><circle cx="59" cy="65" r="5" class="cat-svg-dot"/><path d="M38 68 58 47" class="cat-svg-line"/></svg>`;
    if(type==='stationery')return `<svg viewBox="0 0 96 96" aria-hidden="true" focusable="false"><path d="M26 45h45l-5 35H31l-5-35Z" class="cat-svg-fill-1"/><path d="M37 46 31 15l9-2 6 33M52 46l5-33 9 2-5 31" class="cat-svg-pencil"/><path d="M48 46V16" class="cat-svg-line"/><circle cx="48" cy="12" r="5" class="cat-svg-dot"/></svg>`;
    return `<svg viewBox="0 0 96 96" aria-hidden="true" focusable="false"><rect x="18" y="18" width="60" height="60" rx="18" class="cat-svg-fill-1"/><path d="M30 49h36M48 31v36" class="cat-svg-line"/></svg>`;
  }

  function categoryIconMarkup(section){
    const icon=categoryIcon(section);
    if(icon)return `<span class="cat-icon cat-image"><img src="${esc(imageUrl(icon))}" alt="" loading="lazy"></span>`;
    return `<span class="cat-icon cat-default-icon ${esc(section.iconClass||'cat-custom')}">${defaultCategorySvg(section)}</span>`;
  }

  function ensureCategoryShowcase(root){
    if(!root||root.closest('.alin-category-showcase'))return;
    const parent=root.parentElement;
    if(!parent)return;
    const showcase=document.createElement('section');
    showcase.className='alin-category-showcase';
    showcase.setAttribute('aria-label','تسوّق حسب الأقسام');
    showcase.innerHTML=`<header class="alin-category-heading"><div><span>اكتشف متجر آلين</span><h2>تسوّق حسب الأقسام</h2></div></header><div class="alin-category-slider"><button class="alin-category-slide alin-category-slide-right" type="button" data-alin-category-slide="right" aria-label="تحريك الأقسام إلى اليمين"><span aria-hidden="true">›</span></button><div class="alin-category-track-slot"></div><button class="alin-category-slide alin-category-slide-left" type="button" data-alin-category-slide="left" aria-label="تحريك الأقسام إلى اليسار"><span aria-hidden="true">‹</span></button></div>`;
    parent.insertBefore(showcase,root);
    showcase.querySelector('.alin-category-track-slot')?.appendChild(root);
    const slide=direction=>{
      const buttons=[...root.querySelectorAll('[data-v99-category]')];
      if(!buttons.length)return;
      const rootRect=root.getBoundingClientRect();
      const center=rootRect.left+rootRect.width/2;
      const visual=buttons.slice().sort((a,b)=>a.getBoundingClientRect().left-b.getBoundingClientRect().left);
      let index=0,best=Infinity;
      visual.forEach((button,i)=>{const rect=button.getBoundingClientRect();const distance=Math.abs((rect.left+rect.width/2)-center);if(distance<best){best=distance;index=i}});
      const next=Math.max(0,Math.min(visual.length-1,index+(direction==='right'?1:-1)));
      visual[next]?.scrollIntoView({behavior:'smooth',block:'nearest',inline:'center'});
    };
    showcase.querySelector('[data-alin-category-slide="right"]')?.addEventListener('click',()=>slide('right'));
    showcase.querySelector('[data-alin-category-slide="left"]')?.addEventListener('click',()=>slide('left'));
  }

  function renderStoreCategories(){
    const root=$('#alinStoreCategories');
    if(!root)return;
    ensureCategoryShowcase(root);
    const sections=storefrontSections();
    root.innerHTML=sections.map(section=>`<button aria-pressed="false" data-v99-category="${esc(section.key)}" type="button">${categoryIconMarkup(section)}<span class="cat-copy"><strong>${esc(section.name)}</strong><small>${esc(section.subtitle)}</small></span></button>`).join('');
    const showcase=root.closest('.alin-category-showcase');
    if(showcase)showcase.hidden=!sections.length;
  }

  function selectedCustomCategory(){
    const key=String(state.categoryKey||'');
    if(!key.startsWith('category:'))return null;
    const id=key.slice('category:'.length);
    return categoryRows().find(row=>String(row.id)===id)||null;
  }

  function customCategoryMatches(item){
    const row=selectedCustomCategory();
    if(!row)return true;
    const type=normalizeCategoryType(row.type);
    const itemType=normalizeCategoryType(item.kind);
    const typeMatch=type==='deal'?activeDeal(item):itemType===type;
    if(!typeMatch)return false;
    const name=String(row.name||'').trim().toLowerCase();
    if(!name)return true;
    const values=[item.category,item.subject,item.raw?.category,item.raw?.category_id].map(value=>String(value||'').trim().toLowerCase());
    return values.includes(name)||values.some(value=>value&&value.includes(name));
  }

  function applyStoreView(){
    const home=$('#alinStoreHomeView'),catalog=$('#alinStoreCatalogView');
    const isCatalog=state.storeView==='catalog';
    if(home)home.hidden=isCatalog;
    if(catalog)catalog.hidden=!isCatalog;
    document.body.classList.toggle('alin-store-catalog-mode',isCatalog);
  }

  function card(item){
    const out=item.stock!==null&&item.stock<=0;
    const price=effectivePrice(item);
    return `<article class="v99-product-card" data-v99-item="${esc(ctx.stableKey(item.kind,item.id))}">
      <button class="v99-fav" type="button" data-v99-action="favorite" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}" aria-label="المفضلة">${isFavorite(item)?'♥':'♡'}</button>
      <button class="v99-product-media" type="button" data-v99-action="details" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}" aria-label="عرض تفاصيل ${esc(item.title)}"${item.image?` style='--alin-media-image:url("${esc(imageUrl(item.image))}")'`:''}>${item.image?`<img class="alin-product-image-fit" src="${esc(imageUrl(item.image))}" alt="" loading="lazy" style="width:100%!important;height:100%!important;object-fit:contain!important;object-position:center!important;padding:0!important;margin:0!important;position:relative!important;z-index:2!important;">`:'<span class="v99-placeholder" aria-hidden="true">آ</span>'}</button>
      <div class="v99-product-body"><div class="v99-badges">${badges(item).map(label=>`<span class="v99-badge ${label==='كمية محدودة'?'stock':''}">${esc(label)}</span>`).join('')}</div>
        <h3><button class="v99-title-button" type="button" data-v99-action="details" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">${esc(item.title)}</button></h3>
        <p>${esc([item.teacher,item.subject,item.grade].filter(Boolean).join(' • '))}</p>
        <div class="v99-card-meta"><span class="v99-stock ${out?'out':''}">${item.stock===null?'متاح':out?'نافد':`متوفر: ${fmt(item.stock)}`}</span>${item.prep?`<span>تجهيز ${fmt(item.prep)} د</span>`:''}</div>
        <div class="v99-card-price"><span>مفرد: ${fmt(price)} د.ع ${activeDeal(item)?`<del>${fmt(item.price)}</del>`:''}</span>${item.packPrice>0&&item.packSize>=2?`<small>باكيت ${fmt(item.packSize)} قطع: ${fmt(item.packPrice)} د.ع</small>`:''}</div>
        <div class="v99-actions"><button class="${out?'v99-alert-action':''}" data-v99-action="cart" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">${out?'أبلغني':'أضف للسلة'}</button><button class="v99-secondary" data-v99-action="details" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">التفاصيل</button></div>
      </div></article>`;
  }

  function matches(item){
    const filters=state.filters;
    const query=String($('#searchInput')?.value||'').trim().toLowerCase();
    const categoryQuery=String(state.categoryQuery||'').trim().toLowerCase();
    const haystack=[item.title,item.teacher,item.subject,item.grade,item.category,item.description].join(' ').toLowerCase();
    return (!query||haystack.includes(query))
      &&(!categoryQuery||haystack.includes(categoryQuery))
      &&customCategoryMatches(item)
      &&(!state.subcategoryId||String(item.subcategoryId||'')===String(state.subcategoryId))
      &&(!filters.kind||normalizeCategoryType(item.kind)===normalizeCategoryType(filters.kind)||String(item.category||'')===String(filters.kind))
      &&(!filters.grade||item.grade===filters.grade)
      &&(!filters.subject||item.subject===filters.subject)
      &&(!filters.teacher||String(item.teacherId)===filters.teacher)
      &&(!filters.min||effectivePrice(item)>=num(filters.min))
      &&(!filters.max||effectivePrice(item)<=num(filters.max))
      &&(!filters.available||(filters.available==='yes'?(item.stock===null||item.stock>0):item.stock===0))
      &&(!filters.badge||(filters.badge==='deal'?(activeDeal(item)||normalizeCategoryType(item.kind)==='deal'):badges(item).includes(filters.badge)));
  }

  function sorted(rows){
    const mode=state.filters.sort;
    return rows.sort((a,b)=>mode==='newest'?String(b.created).localeCompare(String(a.created))
      :mode==='best'?b.sold-a.sold
      :mode==='priceAsc'?effectivePrice(a)-effectivePrice(b)
      :mode==='priceDesc'?effectivePrice(b)-effectivePrice(a)
      :(Number(activeDeal(b))-Number(activeDeal(a)))||(b.sold-a.sold));
  }

  function options(rows,key,label,value=item=>item[key]){
    const values=[...new Map(rows.map(item=>[String(value(item)||''),String(value(item)||'')])).values()].filter(Boolean).sort();
    return `<option value="">${label}</option>${values.map(item=>`<option value="${esc(item)}">${esc(item)}</option>`).join('')}`;
  }

  function renderFilters(){
    const root=$('#v99DiscoveryTools');
    if(!root)return;
    const rows=canonicalItems();
    const teachers=(window.db?.accounts?.teachers||[]).filter(row=>row.status==='active'||!row.status);
    const desktop=isDesktop(),mobile=isMobile();
    if(desktop||mobile){root.setAttribute('role','dialog');root.setAttribute('aria-modal','true');root.setAttribute('tabindex','-1')}
    if(desktop)root.setAttribute('aria-labelledby','v99FilterDrawerTitle');
    if(mobile)root.setAttribute('aria-labelledby','v99MobileFilterDrawerTitle');
    const drawerHead=desktop
      ?'<div class="v99-drawer-head"><h2 id="v99FilterDrawerTitle">فلترة المنتجات</h2><button type="button" class="v99-drawer-close" data-v99-action="closeDesktopFilters" aria-label="إغلاق لوحة الفلاتر">×</button></div>'
      :mobile
        ?'<div class="v99-mobile-drawer-head"><h2 id="v99MobileFilterDrawerTitle">فلترة المنتجات</h2><button type="button" class="v99-mobile-drawer-close" data-v99-action="closeMobileFilters" aria-label="إغلاق لوحة الفلاتر">×</button></div>'
        :'<button class="v99-filter-toggle" type="button" data-v99-action="toggleFilters" aria-expanded="false"><span>تصفية وفرز المنتجات</span><span class="v99-toggle-mark" aria-hidden="true">+</span></button>';
    root.innerHTML=`${drawerHead}<div id="v99ActiveFilters" class="v99-active-filters" aria-live="polite"></div><div class="v99-filters" aria-label="عوامل التصفية">
      <label><span>النوع أو القسم</span><select data-filter="kind">${options(rows,'kind','الكل',item=>item.kind)}</select></label>
      <label><span>المرحلة الدراسية</span><select data-filter="grade">${options(rows,'grade','كل المراحل')}</select></label>
      <label><span>المادة</span><select data-filter="subject">${options(rows,'subject','كل المواد')}</select></label>
      <label><span>المدرس</span><select data-filter="teacher"><option value="">كل المدرسين</option>${teachers.map(teacher=>`<option value="${esc(teacher.id)}">${esc(teacher.name)}</option>`).join('')}</select></label>
      <fieldset class="v99-price-range"><legend>نطاق السعر</legend><label><span>من</span><input data-filter="min" type="number" min="0" inputmode="numeric" placeholder="0"></label><label><span>إلى</span><input data-filter="max" type="number" min="0" inputmode="numeric" placeholder="بدون حد"></label></fieldset>
      <label><span>حالة التوفر</span><select data-filter="available"><option value="">الكل</option><option value="yes">متوفر</option><option value="no">نافد</option></select></label>
      <label><span>الشارة أو العرض</span><select data-filter="badge"><option value="">الكل</option><option value="deal">عرض اليوم</option><option>جديد</option><option>الأكثر طلباً</option><option>كمية محدودة</option></select></label>
      <label class="v99-sort-control"><span>ترتيب النتائج</span><select data-filter="sort"><option value="recommended">افتراضي</option><option value="newest">الأحدث</option><option value="best">الأكثر مبيعاً</option><option value="priceAsc">السعر من الأقل إلى الأعلى</option><option value="priceDesc">السعر من الأعلى إلى الأقل</option></select></label>
      </div><div class="v99-filter-actions"><span class="v99-filter-summary" id="v99FilterSummary"></span><button type="button" class="v99-secondary" data-v99-action="clearFilters">مسح الكل</button></div>`;
    syncFilterControls();
    renderFilterChips();
  }

  function syncFilterControls(){
    $$('[data-filter]').forEach(element=>{element.value=state.filters[element.dataset.filter]||''});
  }

  function renderFilterChips(){
    const root=$('#v99ActiveFilters');
    const activeRows=Object.entries(state.filters).filter(([key,value])=>value&&!(key==='sort'&&value==='recommended'));
    if(root){
      const labels={kind:'النوع',grade:'المرحلة',subject:'المادة',teacher:'المدرس',min:'من',max:'إلى',available:'التوفر',badge:'العرض',sort:'الترتيب'};
      const visible=(key,value)=>{
        if(key==='min'||key==='max')return `${fmt(value)} د.ع`;
        const control=$(`[data-filter="${key}"]`);
        const option=[...(control?.options||[])].find(row=>row.value===String(value));
        return option?.textContent?.trim()||String(value);
      };
      root.innerHTML=activeRows.map(([key,value])=>`<button type="button" data-v99-action="removeFilter" data-filter-key="${esc(key)}" aria-label="إزالة فلتر ${esc(labels[key])}">${esc(labels[key])}: ${esc(visible(key,value))} <span aria-hidden="true">×</span></button>`).join('');
      root.hidden=!activeRows.length;
    }
    for(const id of ['v99DesktopFilterCount','v99MobileFilterCount']){
      const count=$(`#${id}`);
      if(count){count.textContent=fmt(activeRows.length);count.hidden=!activeRows.length}
    }
  }

  function miniCard(item){
    const current=effectivePrice(item),hasPrevious=activeDeal(item)&&item.price>current;
    return `<article class="v99-mini-card"><div class="v99-mini-media"${item.image?` style='--alin-media-image:url("${esc(imageUrl(item.image))}")'`:''}>${item.image?`<img class="alin-product-image-fit" src="${esc(imageUrl(item.image))}" alt="" style="width:100%!important;height:100%!important;object-fit:contain!important;object-position:center!important;padding:0!important;margin:0!important;position:relative!important;z-index:2!important;">`:'<span class="v99-placeholder">آ</span>'}</div><div class="v99-mini-body"><div class="v99-badges">${badges(item).slice(0,2).map(label=>`<span class="v99-badge">${esc(label)}</span>`).join('')}</div><h3>${esc(item.title)}</h3><p>${esc([item.teacher,item.subject,item.grade].filter(Boolean).join(' • '))}</p><div class="v99-card-price"><strong>${fmt(current)} د.ع</strong>${hasPrevious?`<del>${fmt(item.price)} د.ع</del>`:''}</div><button data-v99-action="details" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">عرض</button></div></article>`;
  }

  function rail(rootSelector,title,subtitle,rows){
    const root=$(rootSelector);
    if(!root)return;
    if(!rows.length){root.innerHTML='';return}
    root.innerHTML=`<div class="v99-section-head"><div><h2>${esc(title)}</h2><small>${esc(subtitle)}</small></div></div><div class="v99-rail">${rows.map(miniCard).join('')}</div>`;
  }

  function renderStage(){
    const root=$('#v99Personalized');
    if(!root)return;
    if(isMobile()){root.replaceChildren();root.hidden=true;return}
    root.hidden=false;
    const profile=studentProfile();
    const grades=[...new Set(canonicalItems().map(item=>item.grade).filter(Boolean))];
    root.innerHTML=`<div class="v99-stage-strip"><div><h2>مواد تناسب مرحلتك</h2><p>${profile.grade?`نعرض لك اختيارات ${esc(profile.grade)} أولاً.`:'اختر مرحلتك لتحصل على اقتراحات أقرب لدراستك.'}</p></div><select id="v99GradeSelect" aria-label="المرحلة الدراسية"><option value="">كل المراحل</option>${grades.map(grade=>`<option ${grade===profile.grade?'selected':''}>${esc(grade)}</option>`).join('')}</select></div><div id="v99PersonalizedItems" class="v99-rail-root"></div>`;
  }

  function updateCountdowns(){
    $$('[data-deal-end]').forEach(element=>{
      const end=Date.parse(element.dataset.dealEnd);
      if(!end){element.textContent='لفترة محدودة';return}
      const remaining=Math.max(0,end-ctx.now());
      const hours=Math.floor(remaining/36e5),minutes=Math.floor((remaining%36e5)/6e4),seconds=Math.floor((remaining%6e4)/1000);
      element.textContent=remaining?`ينتهي خلال ${fmt(hours)}:${String(minutes).padStart(2,'0')}:${String(seconds).padStart(2,'0')}`:'انتهى العرض';
    });
  }

  function renderDeal(){
    const root=$('#v99DailyDeals');
    if(!root)return;
    const item=canonicalItems().filter(activeDeal).sort((a,b)=>(b.price-b.dealPrice)-(a.price-a.dealPrice))[0];
    if(!item){root.innerHTML='';return}
    root.innerHTML=`<article class="v99-deal-feature"><div class="v99-deal-media">${item.image?`<img src="${esc(imageUrl(item.image))}" alt="${esc(item.title)}">`:'<span class="v99-placeholder">ALIN</span>'}</div><div class="v99-deal-copy"><span class="v99-kicker">عرض اليوم</span><h2>${esc(item.title)}</h2><p>${esc([item.teacher,item.subject,item.grade].filter(Boolean).join(' • '))}</p><div class="v99-price">${fmt(item.dealPrice)} د.ع <del>${fmt(item.price)}</del></div><div class="v99-countdown" data-deal-end="${esc(item.dealEnd||'')}"></div><div class="v99-actions"><button data-v99-action="cart" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">أضف للسلة</button><button class="v99-secondary" data-v99-action="share" data-kind="${esc(item.kind)}" data-id="${esc(item.id)}">مشاركة</button></div></div></article>`;
    updateCountdowns();
  }

  function publicTeachers(){
    return (window.db?.accounts?.teachers||[]).filter(teacher=>teacher.public_profile===false?false:(teacher.status==='active'||teacher.status==='approved'||!teacher.status));
  }

  function renderTeachers(){
    const root=$('#v99TeacherRail'),rows=publicTeachers();
    if(!root)return;
    if(isDesktop()||isMobile()){root.innerHTML='';root.hidden=true;return}
    if(!rows.length){root.innerHTML='';return}
    root.innerHTML=`<div class="v99-section-head"><div><h2>مدرسون مميزون</h2><small>تعرّف على المدرس وملزماته</small></div></div><div class="v99-rail">${rows.slice(0,10).map(teacher=>`<article class="v99-teacher-card" data-v99-action="teacher" data-id="${esc(teacher.id)}"><span class="v99-avatar">${teacher.avatar_path||teacher.image_path?`<img src="${esc(imageUrl(teacher.avatar_path||teacher.image_path))}" alt="">`:esc((teacher.name||'آ').slice(0,1))}</span><span><b>${esc(teacher.name)}</b><small>${esc(teacher.specialty||teacher.subject||'مدرس معتمد')}</small></span></article>`).join('')}</div>`;
  }

  function renderBundles(){
    const root=$('#v99Bundles');
    if(!root)return;
    const bundles=state.tables.bundles||[],items=state.tables.bundle_items||[];
    const active=bundles.filter(bundle=>bundle.active!==false&&statusVisible(bundle.status));
    if(!active.length){root.innerHTML='';return}
    root.innerHTML=`<div class="v99-section-head"><div><h2>حزم أوفر</h2><small>مجموعة مواد بسعر واحد</small></div></div><div class="v99-rail">${active.map(bundle=>{const count=items.filter(item=>String(item.bundle_id)===String(bundle.id)).length;return `<article class="v99-mini-card"><div class="v99-mini-body"><span class="v99-kicker">حزمة ${fmt(count)} مواد</span><h3>${esc(bundle.name||bundle.title)}</h3><p>${esc(bundle.description||'اختيار متكامل بسعر مخفّض')}</p><div class="v99-card-price">${fmt(bundle.bundle_price||bundle.price)} د.ع</div><button data-v99-action="bundle" data-id="${esc(bundle.id)}">عرض الحزمة</button></div></article>`}).join('')}</div>`;
  }

  function featuredRows(rows){
    const productsOnly=rows.filter(item=>['stationery','gift','product'].includes(normalizeCategoryType(item.kind)));
    const base=productsOnly.length?productsOnly:rows;
    const explicit=base.filter(item=>{
      const raw=item.raw||{};
      const featured=raw.featured===true||raw.is_featured===true||String(raw.featured||raw.is_featured||'').toLowerCase()==='true';
      return featured||String(item.badge||'').trim()==='مميز';
    });
    if(explicit.length)return explicit.slice(0,8);
    return [...base].sort((a,b)=>(b.sold-a.sold)||String(b.created||'').localeCompare(String(a.created||''))).slice(0,8);
  }

  function renderRails(){
    const rows=canonicalItems();
    const newest=[...rows].filter(item=>item.created).sort((a,b)=>String(b.created).localeCompare(String(a.created))).slice(0,8);
    const topTen=[...rows].sort((a,b)=>(b.sold-a.sold)||String(b.created||'').localeCompare(String(a.created||''))).slice(0,10);
    rail('#v99NewArrivals','وصل حديثاً','أحدث المواد والمنتجات المضافة',newest);
    rail('#v99Featured','منتجات مميزة','اختيارات بارزة من متجر آلين',featuredRows(rows));
    rail('#v99TopTen','أفضل 10','الأكثر طلباً في المتجر',topTen);
    const oldDeal=$('#v99DailyDeals');if(oldDeal)oldDeal.innerHTML='';
    const oldBundles=$('#v99Bundles');if(oldBundles)oldBundles.innerHTML='';
    const oldTeachers=$('#v99TeacherRail');if(oldTeachers){oldTeachers.innerHTML='';oldTeachers.hidden=true}
  }

  function visibleAccount(row){
    if(!row||row.deleted_at)return false;
    return !['inactive','disabled','suspended','rejected','deleted','archived'].includes(String(row.status||'active').trim().toLowerCase());
  }
  function uniqueVisibleCount(rows){
    const seen=new Set();
    for(const row of rows||[]){
      if(!visibleAccount(row))continue;
      const key=String(row.id||row.auth_user_id||row.username||row.phone||row.name||'').trim();
      if(key)seen.add(key);
    }
    return seen.size;
  }
  function renderStoreStats(){
    const booklets=(window.db?.booklets||[]).filter(row=>statusVisible(row.status)&&!row.deleted_at).length;
    const teachers=uniqueVisibleCount(window.db?.accounts?.teachers||[]);
    const libraries=uniqueVisibleCount(window.db?.accounts?.libraries||[]);
    const values={alinStatBooklets:booklets,alinStatTeachers:teachers,alinStatLibraries:libraries};
    for(const [id,value] of Object.entries(values)){const node=document.getElementById(id);if(node)node.textContent=fmt(value)}
    return values;
  }

  function renderCategoryTools(resultCount=0){
    const root=$('#storeProducts');
    if(!root)return;
    const isCatalog=state.storeView==='catalog';
    root.hidden=!isCatalog;
    if(!isCatalog){root.innerHTML='';return}
    const key=String(state.categoryKey||(state.searchCatalog?'search':'all'));
    if(root.dataset.categoryKey!==key||!root.querySelector('#v99CategorySearch')){
      root.dataset.categoryKey=key;
      root.innerHTML=`<div class="v99-category-tools">
        <label class="v99-category-search" for="v99CategorySearch"><span class="v99-category-search-icon" aria-hidden="true"></span><input id="v99CategorySearch" type="search" autocomplete="off" placeholder="ابحث داخل هذا القسم..." value="${esc(state.categoryQuery||'')}" aria-label="البحث داخل القسم"></label>
        <label class="v99-category-sort"><span>ترتيب</span><select id="v99CategorySort" aria-label="ترتيب منتجات القسم"><option value="recommended">افتراضي</option><option value="newest">الأحدث</option><option value="priceAsc">السعر من الأقل إلى الأعلى</option><option value="priceDesc">السعر من الأعلى إلى الأقل</option></select></label>
        <span class="v99-category-result-count" id="v99CategoryResultCount" aria-live="polite"></span>
      </div>`;
    }
    const search=root.querySelector('#v99CategorySearch');
    if(search&&document.activeElement!==search)search.value=state.categoryQuery||'';
    const sort=root.querySelector('#v99CategorySort');
    if(sort)sort.value=['recommended','newest','priceAsc','priceDesc'].includes(state.filters.sort)?state.filters.sort:'recommended';
    const count=root.querySelector('#v99CategoryResultCount');
    if(count)count.textContent=`${fmt(resultCount)} منتج`;
  }

  function categoryCopy(){
    const key=String(state.categoryKey||'');
    const custom=storefrontSections().find(section=>section.key===key);
    if(state.subcategoryId){const sub=productSubcategoryRows().find(item=>String(item.id)===String(state.subcategoryId));if(sub)return [sub.name,custom?`كل منتجات شعبة ${sub.name}`:'منتجات الشعبة'];}
    if(custom)return [custom.name,custom.custom?'منتجات هذا القسم':custom.subtitle];
    if(state.searchCatalog)return ['نتائج البحث','النتائج المطابقة لعبارة البحث'];
    return ['كل المنتجات','الكتالوج الكامل'];
  }

  function syncCategoryUI(prefix){
    const active=String(state.categoryKey||'');
    const copy=categoryCopy();
    $$('[data-v99-category]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.v99Category===active)));
    const title=$(`#${prefix}CatalogTitle`),kicker=$(`#${prefix}CatalogKicker`);
    if(title)title.textContent=copy[0];
    if(kicker)kicker.textContent=copy[1];
  }
  const syncDesktopCategoryUI=()=>{if(isDesktop())syncCategoryUI('v99')};
  const syncMobileCategoryUI=()=>{if(isMobile())syncCategoryUI('v99Mobile')};

  function resetCatalogSelection(){
    state.categoryKey='';
    state.subcategoryId='';
    state.categoryQuery='';
    state.searchCatalog=false;
    state.filters={kind:'',grade:'',subject:'',teacher:'',min:'',max:'',available:'',badge:'',sort:'recommended'};
  }

  function openStoreHome(){
    resetCatalogSelection();
    state.storeView='home';
    const search=$('#searchInput');if(search)search.value='';
    syncFilterControls();
    return renderStore();
  }

  function openStoreCategory(key){
    const section=storefrontSections().find(item=>item.key===String(key||''));
    if(!section)return openStoreHome();
    state.storeView='catalog';
    state.categoryKey=section.key;
    state.subcategoryId='';
    state.categoryQuery='';
    state.searchCatalog=false;
    state.filters={kind:'',grade:'',subject:'',teacher:'',min:'',max:'',available:'',badge:'',sort:'recommended'};
    state.filters.badge=section.key==='deal'?'deal':'';
    state.filters.kind=section.custom?(section.type==='deal'?'':section.type):(section.key==='deal'?'':section.type);
    syncFilterControls();
    return renderStore();
  }

  function selectedParentCategoryId(){
    const section=storefrontSections().find(item=>item.key===String(state.categoryKey||''));
    if(!section||!['stationery','gift'].includes(normalizeCategoryType(section.type)))return '';
    if(section.rowId)return String(section.rowId);
    const row=categoryRows().find(item=>isBuiltinRow(item)&&normalizeCategoryType(item.type)===normalizeCategoryType(section.type));
    return String(row?.id||'');
  }

  function shelfModeActive(){
    if(state.storeView!=='catalog'||state.searchCatalog||state.subcategoryId||String(state.categoryQuery||'').trim())return false;
    const section=storefrontSections().find(item=>item.key===String(state.categoryKey||''));
    if(!section||!['stationery','gift'].includes(normalizeCategoryType(section.type)))return false;
    const f=state.filters||{};
    return !f.grade&&!f.subject&&!f.teacher&&!f.min&&!f.max&&!f.available&&!f.badge&&(!f.sort||f.sort==='recommended');
  }

  function shelfRows(allRows){
    const parentId=selectedParentCategoryId();if(!parentId)return [];
    const subcats=productSubcategoryRows().filter(item=>String(item.parent_category_id)===parentId&&String(item.status||'active')==='active').sort((a,b)=>Number(a.sort_order||0)-Number(b.sort_order||0)||String(a.name||'').localeCompare(String(b.name||''),'ar'));
    const rows=subcats.map(subcategory=>({subcategory,items:allRows.filter(item=>String(item.subcategoryId||'')===String(subcategory.id))})).filter(row=>row.items.length);
    const unassigned=allRows.filter(item=>!String(item.subcategoryId||''));
    if(unassigned.length)rows.push({subcategory:{id:'__other__',name:'منتجات أخرى'},items:unassigned,other:true});
    return rows;
  }

  function renderProductShelves(rows){
    const shelves=shelfRows(rows);if(!shelves.length)return false;
    const limit=isMobile()?4:5;
    const grid=$('#storeGrid');if(!grid)return false;
    grid.classList.add('alin-product-shelves');
    grid.innerHTML=shelves.map(row=>`<section class="alin-product-shelf"><header><div><h2>${esc(row.subcategory.name)}</h2><small>${fmt(row.items.length)} منتج</small></div>${!row.other?`<button type="button" class="alin-shelf-more" data-v99-action="subcategoryMore" data-subcategory-id="${esc(row.subcategory.id)}">عرض المزيد</button>`:''}</header><div class="alin-product-shelf-rail">${row.items.slice(0,limit).map(card).join('')}</div></section>`).join('');
    return true;
  }

  function openProductSubcategory(id){
    if(id==='__other__')state.subcategoryId='';else state.subcategoryId=String(id||'');
    state.categoryQuery='';state.filters.sort='recommended';
    return renderStore();
  }

  function renderEffectiveStore(){
    const grid=$('#storeGrid');
    if(!grid)return [];
    const rows=sorted(canonicalItems().filter(matches));
    grid.classList.remove('alin-product-shelves');
    const shelfBaseRows=sorted(canonicalItems().filter(item=>{const old=state.subcategoryId;state.subcategoryId='';const ok=matches(item);state.subcategoryId=old;return ok}));
    const shelvesRendered=shelfModeActive()&&renderProductShelves(shelfBaseRows);
    if(!shelvesRendered)grid.innerHTML=rows.map(card).join('')||'<div class="v99-empty"><b>لا توجد منتجات في هذا القسم حالياً</b><p>يمكنك الرجوع للرئيسية واختيار قسم آخر.</p></div>';
    const summary=$('#v99FilterSummary');
    if(summary)summary.textContent=`${fmt(rows.length)} نتيجة`;
    renderFilterChips();
    renderStoreCategories();
    renderCategoryTools(rows.length);
    syncDesktopCategoryUI();
    syncMobileCategoryUI();
    renderRails();
    applyStoreView();
    updateDesktopHeader();
    updateMobileHeader();
    renderStoreStats();
    document.dispatchEvent(new CustomEvent('alin:store-rendered',{detail:{count:rows.length,source:'store-discovery',view:state.storeView||'home',category:state.categoryKey||''}}));
    return rows;
  }

  function normalizedStoreType(type){
    return normalizeCategoryType(type);
  }
  function currentStoreItems(){
    const type=normalizedStoreType(window.db?.settings?.storeType||'');
    const rows=canonicalItems();
    if(!type)return rows;
    return rows.filter(item=>normalizedStoreType(item.kind)===type||normalizedStoreType(item.category)===type);
  }
  function renderStore(){
    const signature=`${(window.db?.booklets||[]).length}:${(window.db?.products||[]).length}:${(window.db?.accounts?.teachers||[]).length}:${(window.db?.categories||[]).length}:${(window.db?.productSubcategories||[]).length}`;
    if(state.catalogSignature!==signature){state.catalogSignature=signature;renderFilters();renderStage()}
    const query=String($('#searchInput')?.value||'').trim();
    if(query){state.storeView='catalog';state.searchCatalog=true;if(!state.categoryKey){state.filters.kind='';state.filters.badge=''}}
    else if(state.searchCatalog){state.searchCatalog=false;if(!state.categoryKey)state.storeView='home'}
    if(!state.storeView)state.storeView='home';
    ctx.renderStudentHub?.();
    return renderEffectiveStore();
  }
  function setStoreType(type,button){
    const value=normalizedStoreType(type)||'booklet';
    window.db.settings=window.db.settings||{};
    window.db.settings.storeType=value;
    if(button){document.querySelectorAll('[data-v99-category],.store-nav button').forEach(node=>node.classList.remove('active'));button.classList.add('active')}
    return openStoreCategory(value);
  }

  Object.assign(ctx,{card,matches,sorted,renderFilters,syncFilterControls,renderFilterChips,miniCard,rail,renderStage,renderDeal,renderRails,renderStoreStats,storefrontSections,renderStoreCategories,renderCategoryTools,openStoreHome,openStoreCategory,applyStoreView,syncDesktopCategoryUI,syncMobileCategoryUI,renderEffectiveStore,openProductSubcategory,normalizedStoreType,currentStoreItems,renderStore,setStoreType,publicTeachers,renderTeachers,renderBundles,updateCountdowns});
  window.storeItems=currentStoreItems;
  window.renderStore=renderStore;
  window.setStoreType=setStoreType;
  window.AlinStorefront=Object.freeze({render:renderStore,items:canonicalItems,currentItems:currentStoreItems,setType:setStoreType,stats:renderStoreStats,openDetails:(kind,id)=>window.v99OpenDetails?.(kind,id)});
})();
