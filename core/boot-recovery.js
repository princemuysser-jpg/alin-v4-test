/* ALIN mobile tracking recovery — 2026-07-31 */
(function(){
  'use strict';

  function escapeHtml(value){
    return String(value == null ? '' : value).replace(/[&<>"']/g,function(char){
      return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char];
    });
  }

  function installMobileTrackingFix(){
    if(!document.body || !document.body.classList.contains('store-mobile')) return;

    window.alinSubmitMobileTracking = async function(){
      var source = document.getElementById('alinMobileTrackingInput');
      var target = document.getElementById('trackOrderInput');
      var result = document.getElementById('alinMobileTrackingResult');
      var code = String(source && source.value || '').trim();

      if(!code){
        if(result) result.innerHTML = '<div class="notice">اكتب رقم الطلب أولاً.</div>';
        return false;
      }

      if(target) target.value = code;
      if(result) result.innerHTML = '<div class="notice">جارٍ التحقق من حالة الطلب...</div>';

      try{
        if(typeof window.trackOrder !== 'function'){
          throw new Error('خدمة التتبع غير متاحة');
        }

        var timer;
        var timeout = new Promise(function(_, reject){
          timer = setTimeout(function(){
            reject(new Error('تعذر الوصول إلى خدمة التتبع خلال 15 ثانية.'));
          }, 15000);
        });

        try{
          await Promise.race([Promise.resolve(window.trackOrder()), timeout]);
        } finally {
          clearTimeout(timer);
        }

        var original = document.getElementById('trackOrderResult');
        var finalHtml = String(original && original.innerHTML || '').trim();

        if(result){
          result.innerHTML = finalHtml || '<div class="notice">لم تصل نتيجة من خدمة التتبع.</div>';
        }
        if(source && target && target.value){
          source.value = target.value;
        }
        return true;
      }catch(error){
        console.warn('ALIN mobile tracking error', error);
        if(result){
          result.innerHTML =
            '<div class="notice">' +
            escapeHtml(error && error.message || 'تعذر التحقق من الطلب حالياً.') +
            '</div>';
        }
        return false;
      }
    };
  }

  window.addEventListener('load', installMobileTrackingFix, {once:true});
  setTimeout(installMobileTrackingFix, 4000);
})();
