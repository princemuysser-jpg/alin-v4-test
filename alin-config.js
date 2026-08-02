// منصة آلين v4.1.8.0 — تحسين السرعة وفصل جلسات الطلبة وإصلاح فتح الصفحات.
window.ALIN_CONFIG=Object.freeze({
  version:'4.1.8.0-unified-receipts',
  desktopPage:'./store-desktop.html',
  mobilePage:'./store-mobile.html',
  currency:'د.ع',
  locale:'ar-IQ',
  locales:{ar:'ar-IQ',ku:'ckb-IQ',en:'en-IQ'},
  authEnabled:true,
  authEmailDomain:'users.alin.local',
  supabaseUrl:'https://dgaikazhbtyjmswpyvrl.supabase.co',
  supabaseAnonKey:'sb_publishable_HjVoise8mRYVeMeBaM9pxw_oxf_mLp3'
});

// تحميل طبقة الأداء من ملف مستقل حتى تبقى الصيانة واضحة.
(function loadAlinPerformanceLayer(){
  if(document.querySelector('script[data-alin-performance="4.1.7"]'))return;
  const script=document.createElement('script');
  script.src='./alin-performance-v4.1.7.js?v=4.1.8.0';
  script.defer=true;
  script.dataset.alinPerformance='4.1.7';
  script.onerror=()=>console.warn('ALIN: تعذر تحميل طبقة تحسين الأداء؛ سيستمر النظام بالوضع الاعتيادي.');
  document.head.appendChild(script);
})();
