/* ALIN — Safe editor for printer accounts. Prevents the legacy advanced editor
 * from silently changing a printer into another role. */
(function(){
  'use strict';
  if(window.__ALIN_PRINTER_ACCOUNT_EDITOR__)return;
  window.__ALIN_PRINTER_ACCOUNT_EDITOR__=true;

  const arr=v=>Array.isArray(v)?v:[];
  const printers=()=>arr(window.db?.accounts?.all).filter(x=>String(x.role||'').toLowerCase()==='printer'&&!x.deleted_at);
  let baseOpen=null;

  async function editPrinter(id){
    const x=printers().find(a=>String(a.id)===String(id));
    if(!x)return alert('تعذر العثور على حساب المطبعة');
    const name=prompt('اسم المطبعة',x.name||'');if(name===null)return;
    const username=prompt('اسم الدخول',x.username||'');if(username===null)return;
    const phone=prompt('رقم الهاتف',x.phone||'');if(phone===null)return;
    const area=prompt('المنطقة',x.area||'');if(area===null)return;
    const landmark=prompt('أقرب نقطة دالة',x.landmark||'');if(landmark===null)return;
    try{
      if(!window.ALINAuth?.updateAccountFromAdmin)throw new Error('خدمة تعديل الحساب غير جاهزة');
      await window.ALINAuth.updateAccountFromAdmin({
        account_id:String(id),role:'printer',name:String(name).trim(),username:String(username).trim(),
        status:x.status||'active',phone:String(phone).trim(),area:String(area).trim(),
        landmark:String(landmark).trim(),notes:x.notes||''
      });
      await window.load?.({force:true,reason:'printer-account-edit'});
      window.renderAccountsAdmin?.();window.toast?.('تم حفظ حساب المطبعة');
    }catch(e){alert(e?.message||'تعذر حفظ حساب المطبعة')}
  }

  function install(){
    if(typeof window.v132OpenAccountEditor!=='function')return false;
    if(window.v132OpenAccountEditor.__alinPrinterSafe)return true;
    baseOpen=window.v132OpenAccountEditor;
    const wrapped=function(id){
      const isPrinter=printers().some(x=>String(x.id)===String(id));
      return isPrinter?editPrinter(id):baseOpen(id);
    };
    wrapped.__alinPrinterSafe=true;
    window.v132OpenAccountEditor=wrapped;
    return true;
  }

  window.addEventListener('alin:role-runtime-ready',()=>setTimeout(install,0));
  window.addEventListener('alin:page-open',()=>setTimeout(install,0));
  window.addEventListener('alin:data-refreshed',()=>setTimeout(install,0));
  setTimeout(install,100);
})();
