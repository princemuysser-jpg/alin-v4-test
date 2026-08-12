// === core/config.js ===
/* ALIN v4.1.0 Courier Rebuilt — ضع بيانات مشروع Supabase الجديد فقط. */
window.ALIN_CONFIG=window.ALIN_CONFIG||Object.freeze({
  version:'4.2.0-rc.21',
  desktopPage:'./store-desktop.html',
  mobilePage:'./store-mobile.html',
  currency:'د.ع',
  locale:'ar-IQ',
  locales:{ar:'ar-IQ',ku:'ckb-IQ',en:'en-IQ'},
  authEnabled:true,
  authEmailDomain:'users.alin.local',
  supabaseUrl:'PASTE_NEW_SUPABASE_URL_HERE',
  supabaseAnonKey:'PASTE_NEW_SUPABASE_ANON_KEY_HERE'
});
window.Alin=window.Alin||{};
window.Alin.helpers={
  byId:id=>document.getElementById(id),
  one:(selector,root=document)=>root.querySelector(selector),
  all:(selector,root=document)=>[...root.querySelectorAll(selector)],
  money:value=>Number(value||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')+' د.ع'
};

;
