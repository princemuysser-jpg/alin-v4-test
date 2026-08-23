// === admin/delivery-pricing.js ===
/* ALIN v4.3.0 — independent student delivery charge / courier fee controls. */
(function(){
  'use strict';
  const core=window.AlinCourierCore;
  if(!core)return;
  const {escv,notify,now,allCouriers,areasOf,areaRows}=core;
  const arr=v=>Array.isArray(v)?v:[];
  const db=()=>window.db||{};
  const money=v=>Math.max(0,Number(v)||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const settings=()=>db().settings||{};
  const defaultStudentFee=()=>Math.max(0,Number(settings().delivery_fee)||2000);
  const defaultCourierFee=()=>Math.max(0,Number(settings().courier_fee)||Math.round(defaultStudentFee()*(Math.max(0,Math.min(100,Number(settings().delegate_profit_percent)||75))/100)));
  const client=()=>window.ALINAuthRuntime?.client?.()||window.sb||window.AlinCloud?.client?.()||null;

  function readAmount(message,initial){
    const raw=prompt(message,String(Math.max(0,Number(initial)||0)));
    if(raw===null)return null;
    const value=Number(String(raw).replace(/,/g,'').trim());
    if(!Number.isFinite(value)||value<0){alert('اكتب مبلغ صحيح صفر أو أكثر');return undefined}
    return Math.round(value);
  }

  function renderAreas(){
    const rows=areaRows();
    if(!window.adminContent)return false;
    window.activeAdminTab='courierAreas';
    adminContent.innerHTML=`<section class="v161-admin"><header class="v161-title"><div><small>مناطق التوصيل</small><h2>إدارة المناطق والأسعار</h2><p>سعر الطالب وأجرة المندوب مستقلان. تگدر تخلي سعر الطالب صفر ويبقى حق المندوب محفوظ.</p></div><button data-alin-click="alinV430AddArea">+ إضافة منطقة</button></header><div class="v161-area-admin">${rows.map(a=>{const count=allCouriers().filter(c=>areasOf(c).includes(a.name)).length;return `<article><div><h3>${escv(a.name)}</h3><p>مرتبطة بـ ${count} مندوب</p><p><b>على الطالب:</b> ${money(a.delivery_fee)} د.ع &nbsp; • &nbsp; <b>أجرة المندوب:</b> ${money(a.courier_fee??defaultCourierFee())} د.ع</p></div><div><button data-alin-click="alinV430EditArea" data-alin-click-arg0="${escv(a.id)}">تعديل الأسعار</button><button class="danger" data-alin-click="alinV161DeleteArea" data-alin-click-arg0="${escv(a.id)}" data-alin-click-arg1="${escv(a.name)}">حذف</button></div></article>`}).join('')}</div></section>`;
    return true;
  }

  window.alinV430AddArea=async function(){
    const name=(prompt('اسم المنطقة الجديدة')||'').trim();if(!name)return;
    const deliveryFee=readAmount('كلفة التوصيل على الطالب',defaultStudentFee());if(deliveryFee==null||deliveryFee===undefined)return;
    const courierFee=readAmount('أجرة المندوب المستقلة',defaultCourierFee());if(courierFee==null||courierFee===undefined)return;
    try{
      await insert('delivery_areas',{id:typeof uid==='function'?uid('A'):`A${Date.now()}`,name,city:'كركوك',status:'active',active:true,delivery_fee:deliveryFee,courier_fee:courierFee,sort_order:areaRows().length+1});
      if(typeof load==='function')await load();renderAreas();notify('تمت إضافة المنطقة والأسعار');
    }catch(error){alert(error?.message||'تعذر إضافة المنطقة')}
  };

  window.alinV430EditArea=async function(id){
    const row=areaRows().find(x=>String(x.id)===String(id));if(!row)return alert('المنطقة غير موجودة');
    const name=(prompt('اسم المنطقة',row.name)||'').trim();if(!name)return;
    const deliveryFee=readAmount('كلفة التوصيل على الطالب\n0 = مجاني افتراضياً لهذه المنطقة',row.delivery_fee??defaultStudentFee());if(deliveryFee==null||deliveryFee===undefined)return;
    const courierFee=readAmount('أجرة المندوب المستقلة',row.courier_fee??defaultCourierFee());if(courierFee==null||courierFee===undefined)return;
    try{
      await update('delivery_areas',{name,delivery_fee:deliveryFee,courier_fee:courierFee,updated_at:now()},{id});
      if(name!==row.name){
        for(const c of allCouriers()){
          const areas=areasOf(c);
          if(areas.includes(row.name))await update('couriers',{areas:areas.map(x=>x===row.name?name:x),area:c.area===row.name?name:c.area,updated_at:now()},{id:c.id});
        }
      }
      if(typeof load==='function')await load();renderAreas();notify('تم حفظ أسعار المنطقة');
    }catch(error){alert(error?.message||'تعذر تعديل المنطقة')}
  };

  async function setPricing(orderId,mode,deliveryFee=null,courierFee=null){
    const c=client();if(!c?.rpc)return alert('خدمة Supabase غير جاهزة');
    try{
      const {data,error}=await c.rpc('alin_admin_set_order_delivery_pricing',{
        p_order_id:String(orderId),p_mode:String(mode),p_delivery_fee:deliveryFee,p_courier_fee:courierFee
      });
      if(error)throw error;if(!data?.ok)throw new Error(data?.error||'تعذر حفظ التسعير');
      if(typeof load==='function')await load({force:true,reason:'delivery-pricing-v430'});
      notify(mode==='free'?'تم جعل التوصيل مجانياً للطالب مع حفظ أجرة المندوب':'تم تحديث كلفة التوصيل');
      if(window.activeAdminTab==='deliveryOrders'&&typeof window.renderDeliveryOrdersAdmin==='function')window.renderDeliveryOrdersAdmin();
      else if(typeof window.adminOrderDetails==='function')window.adminOrderDetails(orderId);
      return true;
    }catch(error){alert(error?.message||'تعذر تعديل كلفة التوصيل');return false}
  }

  window.alinV430AreaPricing=id=>setPricing(id,'area');
  window.alinV430FreePricing=id=>setPricing(id,'free');
  window.alinV430CustomPricing=function(id){
    const order=arr(db().orders).find(x=>String(x.id)===String(id));if(!order)return alert('الطلب غير موجود');
    const student=readAmount('المبلغ الذي يدفعه الطالب للتوصيل',order.delivery_fee||0);if(student==null||student===undefined)return;
    const courier=readAmount('أجرة المندوب لهذا الطلب',order.courier_fee??defaultCourierFee());if(courier==null||courier===undefined)return;
    return setPricing(id,'custom',student,courier);
  };

  function decorateOrder(id){
    const box=document.getElementById('adminOrderDetailsBox');if(!box||box.querySelector('.alin-v430-pricing'))return;
    const o=arr(db().orders).find(x=>String(x.id)===String(id));if(!o)return;
    const home=['home_delivery','delivery','courier'].includes(String(o.fulfillment_type||o.delivery_type||''));if(!home)return;
    const locked=['completed','delivered','cancelled','rejected'].includes(String(o.status||''))||Boolean(o.settlement_done);
    const mode=String(o.delivery_pricing_mode||'area');
    const labels={area:'سعر المنطقة',free:'مجاني للطالب',custom:'مبلغ خاص'};
    const section=document.createElement('section');section.className='v126-assign alin-v430-pricing';
    section.innerHTML=`<h3>تسعير التوصيل</h3><div class="v126-detail-grid"><div><small>الوضع</small><b>${escv(labels[mode]||mode)}</b></div><div><small>على الطالب</small><b>${money(o.delivery_fee)} د.ع</b></div><div><small>أجرة المندوب</small><b>${money(o.courier_fee??0)} د.ع</b></div></div>${locked?'<small>الحساب مقفول بعد إكمال/إلغاء الطلب.</small>':`<div class="v126-detail-actions"><button data-alin-click="alinV430AreaPricing" data-alin-click-arg0="${escv(o.id)}">سعر المنطقة</button><button data-alin-click="alinV430FreePricing" data-alin-click-arg0="${escv(o.id)}">توصيل مجاني</button><button class="secondary" data-alin-click="alinV430CustomPricing" data-alin-click-arg0="${escv(o.id)}">مبلغ خاص</button></div>`}`;
    const assign=box.querySelector('.v126-assign');
    if(assign)assign.before(section);else box.appendChild(section);
  }

  function installOrderDecorator(){
    const old=window.adminOrderDetails;
    if(typeof old!=='function'||old.__alinV430)return false;
    const wrapped=function(id){const result=old.apply(this,arguments);setTimeout(()=>decorateOrder(id),0);return result};
    wrapped.__alinV430=true;window.adminOrderDetails=wrapped;return true;
  }

  window.renderCourierAreasAdmin=renderAreas;
  window.AlinAdminModules?.register?.('courierAreas',renderAreas);
  installOrderDecorator();
  setTimeout(installOrderDecorator,500);
})();
