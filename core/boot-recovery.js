/* ALIN mobile recovery — tracking + options actions — 2026-07-31 */
(function(){
  'use strict';

  function byId(id){
    return document.getElementById(id);
  }

  function escapeHtml(value){
    return String(value == null ? '' : value).replace(/[&<>"']/g,function(char){
      return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char];
    });
  }

  function closeMobileSheets(){
    if(typeof window.alinCloseMobileSheets === 'function'){
      window.alinCloseMobileSheets();
      return;
    }
    ['alinAccountSheet','alinTrackingSheet'].forEach(function(id){
      var element = byId(id);
      if(element) element.hidden = true;
    });
    var backdrop = byId('alinSheetBackdrop');
    if(backdrop) backdrop.hidden = true;
    if(document.body) document.body.style.overflow = '';
  }

  function settingValue(key, fallback){
    var settings = window.db && window.db.settings;

    if(Array.isArray(settings)){
      var row = settings.find(function(item){
        return item && String(item.key || item.name || item.setting_key || '') === key;
      });
      if(row){
        var value = row.value;
        if(value == null) value = row.setting_value;
        if(value == null) value = row.text;
        if(value != null && String(value).trim() !== '') return value;
      }
    }else if(settings && typeof settings === 'object'){
      var direct = settings[key];
      if(direct != null && String(direct).trim() !== '') return direct;
    }

    return fallback;
  }

  function normalizeWhatsapp(value){
    var digits = String(value || '').replace(/[^0-9]/g,'');
    if(!digits) return '';
    if(digits.indexOf('00') === 0) digits = digits.slice(2);
    if(digits.indexOf('0') === 0) digits = '964' + digits.slice(1);
    if(digits.indexOf('964') !== 0 && digits.length === 10) digits = '964' + digits;
    return digits;
  }

  function ensureInfoModal(){
    var modal = byId('alinOptionsInfoModal');
    if(modal) return modal;

    modal = document.createElement('div');
    modal.id = 'alinOptionsInfoModal';
    modal.className = 'modal hidden';
    modal.innerHTML =
      '<div class="modal-card" style="max-width:520px">' +
        '<button type="button" class="x" id="alinOptionsInfoClose" aria-label="إغلاق">×</button>' +
        '<div id="alinOptionsInfoContent"></div>' +
      '</div>';

    document.body.appendChild(modal);

    byId('alinOptionsInfoClose').addEventListener('click', function(){
      modal.classList.add('hidden');
    });

    modal.addEventListener('click', function(event){
      if(event.target === modal) modal.classList.add('hidden');
    });

    return modal;
  }

  function showInfo(title, text, whatsapp){
    closeMobileSheets();

    var modal = ensureInfoModal();
    var contentBox = byId('alinOptionsInfoContent');
    var phone = normalizeWhatsapp(whatsapp);

    contentBox.innerHTML =
      '<section dir="rtl" style="padding:8px 2px;text-align:right">' +
        '<h2 style="margin:0 0 12px;color:#0b3158">' + escapeHtml(title) + '</h2>' +
        '<p style="margin:0;line-height:1.9;color:#4d5f73;white-space:pre-wrap">' + escapeHtml(text) + '</p>' +
        (phone
          ? '<button type="button" id="alinOptionsWhatsappButton" style="width:100%;margin-top:18px;min-height:48px;border:0;border-radius:14px;background:#168b4d;color:#fff;font-weight:900;font-size:15px">فتح واتساب</button>'
          : '') +
      '</section>';

    modal.classList.remove('hidden');

    var whatsappButton = byId('alinOptionsWhatsappButton');
    if(whatsappButton){
      whatsappButton.addEventListener('click', function(){
        window.open('https://wa.me/' + phone, '_blank', 'noopener,noreferrer');
      }, {once:true});
    }
  }

  function updateOptionStates(){
    var currentLanguage =
      (window.AlinI18n && typeof window.AlinI18n.current === 'function'
        ? window.AlinI18n.current()
        : document.documentElement.dataset.alinLanguage) || 'ar';

    document.querySelectorAll('#alinAccountSheet [data-lang]').forEach(function(button){
      var active = button.getAttribute('data-lang') === currentLanguage;
      button.classList.toggle('active', active);
      button.classList.toggle('is-active', active);
      button.setAttribute('aria-pressed', active ? 'true' : 'false');
    });

    var currentTheme = document.documentElement.dataset.alinTheme === 'dark' ? 'dark' : 'light';
    document.querySelectorAll('#alinAccountSheet [data-theme]').forEach(function(button){
      var active = button.getAttribute('data-theme') === currentTheme;
      button.classList.toggle('active', active);
      button.classList.toggle('is-active', active);
      button.setAttribute('aria-pressed', active ? 'true' : 'false');
    });
  }

  function installOptionActions(){
    if(!document.body || !document.body.classList.contains('store-mobile')) return;

    window.alinOpenRealAccount = function(){
      closeMobileSheets();

      window.setTimeout(function(){
        if(window.AlinStudentAuth && typeof window.AlinStudentAuth.open === 'function'){
          window.AlinStudentAuth.open('login');
          return;
        }
        if(typeof window.openStudentAuth === 'function'){
          window.openStudentAuth('login');
          return;
        }
        var button = byId('studentAuthBtn');
        if(button) button.click();
        else window.alert('خدمة حساب الطالب غير متاحة حالياً.');
      }, 30);
    };

    window.alinSetLanguage = function(language){
      var allowed = ['ar','ku','en'];
      var next = allowed.indexOf(language) >= 0 ? language : 'ar';

      try{
        if(window.AlinI18n && typeof window.AlinI18n.setLanguage === 'function'){
          window.AlinI18n.setLanguage(next, {announce:true});
        }else{
          window.dispatchEvent(new CustomEvent('alin:language-changed', {
            detail:{language:next}
          }));
        }
      }catch(error){
        console.warn('ALIN language change error', error);
        window.alert('تعذر تغيير اللغة حالياً.');
        return false;
      }

      window.setTimeout(updateOptionStates, 20);
      return true;
    };

    window.alinSetTheme = function(theme){
      var next = theme === 'dark' ? 'dark' : 'light';

      try{
        localStorage.setItem('alin_theme_v234', next);
      }catch(_){}

      document.documentElement.dataset.alinTheme = next;
      document.documentElement.dataset.alinThemeMode = next;

      if(document.body){
        document.body.classList.toggle('alin-dark', next === 'dark');
        document.body.classList.toggle('alin-light', next === 'light');
      }

      var themeColor = document.querySelector('meta[name="theme-color"]');
      if(themeColor){
        themeColor.setAttribute('content', next === 'dark' ? '#071a2e' : '#f8f3e8');
      }

      try{
        if(typeof window.applyBrand === 'function') window.applyBrand();
        window.dispatchEvent(new CustomEvent('alin:theme-changed', {
          detail:{theme:next}
        }));
      }catch(error){
        console.warn('ALIN theme change error', error);
      }

      updateOptionStates();
      if(typeof window.toast === 'function'){
        window.toast(next === 'dark' ? 'تم تفعيل الوضع الليلي' : 'تم تفعيل الوضع النهاري');
      }
      return true;
    };

    window.alinContactUs = function(){
      var title = settingValue('contact_title', 'تواصل معنا');
      var text = settingValue(
        'contact_text',
        'للاستفسار أو الدعم، تواصل مع إدارة منصة آلين.'
      );
      var whatsapp = settingValue(
        'whatsapp',
        settingValue('platform_phone', '')
      );

      showInfo(title, text, whatsapp);
    };

    window.alinAboutPlatform = function(){
      var title = settingValue('about_title', 'حول منصة آلين');
      var text = settingValue(
        'about_text',
        'منصة آلين تجمع الملازم والقرطاسية والهدايا في مكان واحد، وتربط الطالب بالمدرس والمكتبة وخدمة التوصيل.'
      );

      showInfo(title, text, '');
    };

    updateOptionStates();
  }

  function installMobileTrackingFix(){
    if(!document.body || !document.body.classList.contains('store-mobile')) return;

    window.alinSubmitMobileTracking = async function(){
      var source = byId('alinMobileTrackingInput');
      var target = byId('trackOrderInput');
      var result = byId('alinMobileTrackingResult');
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
        }finally{
          clearTimeout(timer);
        }

        var original = byId('trackOrderResult');
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

  function installAll(){
    installOptionActions();
    installMobileTrackingFix();
  }

  if(document.readyState === 'complete'){
    installAll();
  }else{
    window.addEventListener('load', installAll, {once:true});
  }

  setTimeout(installAll, 4000);
})();
