/* ALIN — Books supplier UI: platform or printer account only. */
(function(){
  'use strict';
  if(window.__ALIN_BOOKS_PRINTER_ONLY__)return;
  window.__ALIN_BOOKS_PRINTER_ONLY__=true;

  const arr=v=>Array.isArray(v)?v:[];
  const esc=v=>typeof window.esc==='function'?window.esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const printers=()=>arr(window.db?.accounts?.all).filter(x=>String(x.role||'').toLowerCase()==='printer'&&String(x.status||'active')==='active'&&!x.deleted_at);
  const books=()=>arr(window.db?.products).filter(x=>String(x.type||'').toLowerCase()==='book');
  let baseOpen=null;

  function decorateEditor(){
    const form=document.getElementById('alinBookForm');if(!form)return;
    const type=document.getElementById('alinBookSupplierType');if(!type)return;
    const current=type.value==='printer'?'printer':'platform';
    type.innerHTML=`<option value="platform">مخزون منصة آلين</option><option value="printer">مطبعة</option>`;
    type.value=current;
    const lib=document.getElementById('alinBookLibraryField');if(lib)lib.remove();
    const printer=document.getElementById('alinBookPrinterField');
    if(printer){
      const selected=form.dataset.printerAccountId||books().find(x=>String(x.id)===String(form.dataset.id))?.supplier_account_id||'';
      printer.innerHTML=`<span>حساب المطبعة الموردة</span><select name="supplierAccountId"><option value="">اختر المطبعة</option>${printers().map(x=>`<option value="${esc(x.id)}" ${String(x.id)===String(selected)?'selected':''}>${esc(x.name||x.username||x.id)}</option>`).join('')}</select>`;
    }
    const sync=()=>{
      const isPlatform=type.value==='platform';
      if(printer)printer.hidden=isPlatform;
      const p=document.getElementById('alinBookPlatformShare'),s=document.getElementById('alinBookSupplierShare');
      if(isPlatform){if(p){p.value='100';p.readOnly=true}if(s){s.value='0';s.readOnly=true}}
      else{if(p)p.readOnly=false;if(s)s.readOnly=false}
    };
    type.onchange=sync;sync();
  }

  async function save(event){
    const form=event.target;if(!(form instanceof HTMLFormElement)||form.id!=='alinBookForm')return;
    event.preventDefault();event.stopImmediatePropagation();
    const d=new FormData(form),id=String(form.dataset.id||''),existing=id?books().find(x=>String(x.id)===id):null;
    const name=String(d.get('name')||'').trim(),price=Number(d.get('price')||0),stock=Number(d.get('stock')||0),low=Number(d.get('lowStockLimit')||5);
    const supplierType=String(d.get('supplierType')||'platform'),platformShare=Number(d.get('platformShare')||0),supplierShare=Number(d.get('supplierShare')||0);
    const supplierAccountId=supplierType==='printer'?String(d.get('supplierAccountId')||'').trim():'';
    const printer=printers().find(x=>String(x.id)===supplierAccountId);
    if(!name)return alert('اكتب اسم الكتاب');
    if(!Number.isFinite(price)||price<0)return alert('سعر الكتاب غير صحيح');
    if(!Number.isFinite(stock)||stock<0)return alert('المخزون غير صحيح');
    if(!['platform','printer'].includes(supplierType))return alert('مورد الكتاب يجب أن يكون منصة آلين أو مطبعة');
    if(platformShare<0||platformShare>100||supplierShare<0||supplierShare>100||platformShare+supplierShare!==100)return alert('مجموع حصة المنصة والمطبعة يجب أن يساوي 100%');
    if(supplierType==='platform'&&(platformShare!==100||supplierShare!==0))return alert('مخزون المنصة يكون 100% للمنصة');
    if(supplierType==='printer'&&!printer)return alert('اختر حساب المطبعة الموردة');
    try{
      let imagePath=existing?.image_path||'';
      const file=form.querySelector('input[name="image"]')?.files?.[0];
      if(file?.name){const uploader=window.uploadFileV52||window.uploadFile;if(typeof uploader!=='function')throw new Error('خدمة رفع الصور غير متاحة');imagePath=await uploader('products',file,{type:'image'})}
      const payload={name,title:name,type:'book',category:'كتب',category_id:'CAT-BOOKS',unit_price:price,price,sale_price:null,stock,low_stock_limit:Math.max(0,low||0),description:String(d.get('description')||'').trim(),details:String(d.get('description')||'').trim(),image_path:imagePath||null,images:imagePath?[imagePath]:[],platform_share_percent:supplierType==='platform'?100:platformShare,supplier_share_percent:supplierType==='platform'?0:supplierShare,supplier_type:supplierType,supplier_account_id:supplierType==='printer'?printer.id:null,supplier_name:supplierType==='printer'?printer.name:'منصة آلين',supplier_pickup_enabled:false,status:existing?.status||'published',updated_at:new Date().toISOString()};
      if(existing)await window.update('products',payload,{id});
      else await window.insert('products',{id:typeof window.uid==='function'?window.uid('BK'):`BK-${Date.now()}`,...payload,created_at:new Date().toISOString()});
      await window.audit?.('book',`${existing?'تعديل':'إضافة'} كتاب ${name}`);
      window.alinCloseBookEditor?.();await window.load?.({force:true,reason:'book-printer-save'});window.renderBooksAdmin?.();window.renderStore?.();window.toast?.(existing?'تم تعديل الكتاب':'تمت إضافة الكتاب');
    }catch(e){console.error('[ALIN printer book save]',e);alert(e?.message||'تعذر حفظ الكتاب')}
  }

  function install(){
    if(!baseOpen&&typeof window.alinOpenBookEditor==='function')baseOpen=window.alinOpenBookEditor;
    if(baseOpen&&!window.alinOpenBookEditor?.__printerOnly){
      const wrapped=function(id=''){const result=baseOpen(id);setTimeout(decorateEditor,0);return result};wrapped.__printerOnly=true;window.alinOpenBookEditor=wrapped;
    }
  }

  document.addEventListener('submit',save,true);
  window.addEventListener('alin:admin-tab',e=>{if(e.detail?.tab==='books')setTimeout(install,0)});
  window.addEventListener('alin:role-runtime-ready',()=>setTimeout(install,0));
  setTimeout(install,100);
})();
