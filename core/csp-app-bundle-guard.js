'use strict';
(()=>{
  const script=document.getElementById('alinAppBundleScript');
  if(script){
    script.addEventListener('load',()=>window.alinAppBundleLoaded?.(),{once:true});
    script.addEventListener('error',()=>window.alinAppBundleFailed?.(),{once:true});
  }

  // Libraries must never receive book-supplier earnings.
  window.__ALIN_LIBRARY_BOOK_SUPPLIER_PROFIT__=true;

  const version=window.ALIN_CONFIG?.assetVersion||window.ALIN_CONFIG?.version||'4.2.0';
  const load=(id,src)=>{
    if(document.getElementById(id))return;
    const s=document.createElement('script');s.id=id;s.src=`${src}?v=${encodeURIComponent(version)}`;s.async=false;document.head.appendChild(s);
  };

  load('alinPrinterRoleBridgeScript','./core/printer-role-bridge.js');
  load('alinPrinterAwareAccountsScript','./modules/admin/accounts.js');
  load('alinPrinterAccountEditorScript','./modules/admin/printer-account-editor.js');
  load('alinBooksPrinterOnlyScript','./modules/admin/books-printer-only.js');
  load('alinAdminPrinterFinanceScript','./modules/admin/printer-finance.js');
})();
