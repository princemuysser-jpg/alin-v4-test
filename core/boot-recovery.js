/* ALIN recovery — tracking + options actions — 2026-08-01 */
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
      try{
        window.alinCloseMobileSheets();
      }catch(error){
        console.warn('ALIN sheet close error', error);
      }
    }

    ['alinAccountSheet','alinTrackingSheet'].forEach(function(id){
      var element = byId(id);
      if(element) element.hidden = true;
    });

    var backdrop = byId('alinSheetBackdrop');
    if(backdrop) backdrop.hidden = true;

    var desktopModal = byId('alinDesktopOptionsModal');
    if(desktopModal) desktopModal.classList.add('hidden');

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

  function optionRoots(){
    return document.querySelectorAll('#alinAccountSheet, #alinDesktopOptionsModal');
  }

  function updateOptionStates(){
    var currentLanguage =
      (window.AlinI18n && typeof window.AlinI18n.current === 'function'
        ? window.AlinI18n.current()
        : document.documentElement.dataset.alinLanguage) || 'ar';

    optionRoots().forEach(function(root){
      root.querySelectorAll('[data-lang]').forEach(function(button){
        var active = button.getAttribute('data-lang') === currentLanguage;
        button.classList.toggle('active', active);
        button.classList.toggle('is-active', active);
        button.setAttribute('aria-pressed', active ? 'true' : 'false');
      });
    });

    var currentTheme = document.documentElement.dataset.alinTheme === 'dark' ? 'dark' : 'light';
    optionRoots().forEach(function(root){
      root.querySelectorAll('[data-theme]').forEach(function(button){
        var active = button.getAttribute('data-theme') === currentTheme;
        button.classList.toggle('active', active);
        button.classList.toggle('is-active', active);
        button.setAttribute('aria-pressed', active ? 'true' : 'false');
      });
    });
  }

  function ensureDesktopOptionsStyle(){
    if(byId('alinDesktopOptionsStyle')) return;

    var style = document.createElement('style');
    style.id = 'alinDesktopOptionsStyle';
    style.textContent =
      'body.store-desktop .desktop-options-icon{display:grid;place-items:center;width:25px;height:25px}' +
      'body.store-desktop .desktop-options-icon svg{width:23px;height:23px;fill:none;stroke:currentColor;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}' +
      '#alinDesktopOptionsModal .alin-desktop-options-card{width:min(760px,calc(100vw - 40px));max-width:760px;padding:24px;border-radius:24px}' +
      '#alinDesktopOptionsModal .alin-desktop-options-head{display:flex;align-items:flex-start;justify-content:space-between;gap:18px;margin-bottom:18px;padding-left:40px}' +
      '#alinDesktopOptionsModal .alin-desktop-options-head h2{margin:0 0 5px;color:#0b3158;font-size:26px}' +
      '#alinDesktopOptionsModal .alin-desktop-options-head p{margin:0;color:#66778a}' +
      '#alinDesktopOptionsModal .alin-desktop-options-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}' +
      '#alinDesktopOptionsModal .alin-desktop-option{display:grid;gap:11px;min-width:0;padding:17px;border:1px solid #dfe6ee;border-radius:18px;background:#fff;color:#14365b;text-align:right;box-shadow:0 8px 24px rgba(15,48,81,.06)}' +
      '#alinDesktopOptionsModal button.alin-desktop-option{cursor:pointer}' +
      '#alinDesktopOptionsModal .alin-desktop-option strong{font-size:17px}' +
      '#alinDesktopOptionsModal .alin-desktop-option small{color:#6b7b8d;line-height:1.6}' +
      '#alinDesktopOptionsModal .alin-desktop-option-title{display:flex;align-items:center;gap:10px}' +
      '#alinDesktopOptionsModal .alin-desktop-option-icon{display:grid;place-items:center;width:38px;height:38px;border-radius:12px;background:#edf5fc;font-size:20px}' +
      '#alinDesktopOptionsModal .alin-desktop-choice-group{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px}' +
      '#alinDesktopOptionsModal .alin-desktop-choice-group.theme{grid-template-columns:repeat(2,minmax(0,1fr))}' +
      '#alinDesktopOptionsModal .alin-choice{min-height:42px;border:1px solid #d6e0ea;border-radius:12px;background:#f5f8fb;color:#173b61;font-weight:800;cursor:pointer}' +
      '#alinDesktopOptionsModal .alin-choice.active,#alinDesktopOptionsModal .alin-choice.is-active,#alinDesktopOptionsModal .alin-choice[aria-pressed="true"]{border-color:#0c416f;background:#0c416f;color:#fff}' +
      'html[data-alin-theme="dark"] #alinDesktopOptionsModal .alin-desktop-options-card{background:#0a2239;color:#eaf4ff}' +
      'html[data-alin-theme="dark"] #alinDesktopOptionsModal .alin-desktop-options-head h2,html[data-alin-theme="dark"] #alinDesktopOptionsModal .alin-desktop-option strong{color:#eaf4ff}' +
      'html[data-alin-theme="dark"] #alinDesktopOptionsModal .alin-desktop-options-head p,html[data-alin-theme="dark"] #alinDesktopOptionsModal .alin-desktop-option small{color:#a9bdd1}' +
      'html[data-alin-theme="dark"] #alinDesktopOptionsModal .alin-desktop-option{border-color:#29445f;background:#102d48;color:#eaf4ff}' +
      'html[data-alin-theme="dark"] #alinDesktopOptionsModal .alin-desktop-option-icon,html[data-alin-theme="dark"] #alinDesktopOptionsModal .alin-choice{border-color:#34516c;background:#173753;color:#eaf4ff}' +
      '@media(max-width:760px){#alinDesktopOptionsModal .alin-desktop-options-grid{grid-template-columns:1fr}}';

    document.head.appendChild(style);
  }

  function ensureDesktopOptionsUi(){
    if(!document.body || !document.body.classList.contains('store-desktop')) return;

    ensureDesktopOptionsStyle();

    var actions = document.querySelector('.desktop-store-actions');
    if(actions && !byId('alinDesktopOptionsButton')){
      var button = document.createElement('button');
      button.id = 'alinDesktopOptionsButton';
      button.type = 'button';
      button.className = 'desktop-action desktop-options';
      button.setAttribute('aria-label', 'خيارات');
      button.innerHTML =
        '<span class="desktop-options-icon" aria-hidden="true">' +
          '<svg viewBox="0 0 24 24"><path d="M4 7h10"/><path d="M18 7h2"/><circle cx="16" cy="7" r="2"/><path d="M4 17h2"/><path d="M10 17h10"/><circle cx="8" cy="17" r="2"/></svg>' +
        '</span><small>خيارات</small>';

      var exitButton = actions.querySelector('[data-desktop-control="exit"]');
      actions.insertBefore(button, exitButton || null);

      button.addEventListener('click', function(){
        if(typeof window.alinOpenDesktopOptions === 'function'){
          window.alinOpenDesktopOptions();
        }
      });
    }

    var modal = byId('alinDesktopOptionsModal');
    if(!modal){
      modal = document.createElement('div');
      modal.id = 'alinDesktopOptionsModal';
      modal.className = 'modal hidden';
      modal.setAttribute('role', 'dialog');
      modal.setAttribute('aria-modal', 'true');
      modal.setAttribute('aria-label', 'خيارات');
      modal.innerHTML =
        '<div class="modal-card alin-desktop-options-card">' +
          '<button type="button" class="x" data-desktop-options-close aria-label="إغلاق">×</button>' +
          '<div class="alin-desktop-options-head"><div><h2>خيارات</h2><p>الحساب واللغة ومظهر المنصة</p></div></div>' +
          '<div class="alin-desktop-options-grid">' +
            '<button type="button" class="alin-desktop-option" data-desktop-option-action="account">' +
              '<span class="alin-desktop-option-title"><span class="alin-desktop-option-icon">👤</span><strong>حسابي</strong></span>' +
              '<small>تسجيل الدخول وإدارة حساب الطالب</small>' +
            '</button>' +
            '<section class="alin-desktop-option">' +
              '<span class="alin-desktop-option-title"><span class="alin-desktop-option-icon">🌐</span><strong>اللغة</strong></span>' +
              '<small>اختر لغة واجهة المنصة</small>' +
              '<div class="alin-desktop-choice-group">' +
                '<button type="button" class="alin-choice" data-lang="ar">العربية</button>' +
                '<button type="button" class="alin-choice" data-lang="ku">کوردی</button>' +
                '<button type="button" class="alin-choice" data-lang="en">English</button>' +
              '</div>' +
            '</section>' +
            '<section class="alin-desktop-option">' +
              '<span class="alin-desktop-option-title"><span class="alin-desktop-option-icon">◐</span><strong>المظهر</strong></span>' +
              '<small>الوضع النهاري أو الليلي</small>' +
              '<div class="alin-desktop-choice-group theme">' +
                '<button type="button" class="alin-choice" data-theme="light">نهاري</button>' +
                '<button type="button" class="alin-choice" data-theme="dark">ليلي</button>' +
              '</div>' +
            '</section>' +
            '<button type="button" class="alin-desktop-option" data-desktop-option-action="contact">' +
              '<span class="alin-desktop-option-title"><span class="alin-desktop-option-icon">💬</span><strong>تواصل معنا</strong></span>' +
              '<small>للاستفسار والدعم</small>' +
            '</button>' +
            '<button type="button" class="alin-desktop-option" data-desktop-option-action="about">' +
              '<span class="alin-desktop-option-title"><span class="alin-desktop-option-icon">ⓘ</span><strong>حول منصة آلين</strong></span>' +
              '<small>معلومات عن المنصة وخدماتها</small>' +
            '</button>' +
          '</div>' +
        '</div>';

      document.body.appendChild(modal);

      modal.addEventListener('click', function(event){
        if(event.target === modal || event.target.closest('[data-desktop-options-close]')){
          closeMobileSheets();
          return;
        }

        var languageButton = event.target.closest('[data-lang]');
        if(languageButton && typeof window.alinSetLanguage === 'function'){
          window.alinSetLanguage(languageButton.getAttribute('data-lang'));
          return;
        }

        var themeButton = event.target.closest('[data-theme]');
        if(themeButton && typeof window.alinSetTheme === 'function'){
          window.alinSetTheme(themeButton.getAttribute('data-theme'));
          return;
        }

        var actionButton = event.target.closest('[data-desktop-option-action]');
        if(!actionButton) return;

        var action = actionButton.getAttribute('data-desktop-option-action');
        if(action === 'account' && typeof window.alinOpenRealAccount === 'function'){
          window.alinOpenRealAccount();
        }else if(action === 'contact' && typeof window.alinContactUs === 'function'){
          window.alinContactUs();
        }else if(action === 'about' && typeof window.alinAboutPlatform === 'function'){
          window.alinAboutPlatform();
        }
      });
    }
  }

  function installOptionActions(){
    if(!document.body) return;

    var isMobile = document.body.classList.contains('store-mobile');
    var isDesktop = document.body.classList.contains('store-desktop');
    if(!isMobile && !isDesktop) return;

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

    window.alinOpenDesktopOptions = function(){
      ensureDesktopOptionsUi();
      var modal = byId('alinDesktopOptionsModal');
      if(!modal) return false;
      modal.classList.remove('hidden');
      updateOptionStates();
      return true;
    };

    window.alinCloseDesktopOptions = function(){
      closeMobileSheets();
    };

    ensureDesktopOptionsUi();
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
