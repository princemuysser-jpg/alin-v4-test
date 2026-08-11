(function(){
  'use strict';
  function panel(){return document.getElementById('alinDesktopOptionsPanel')}
  function trigger(){return document.getElementById('alinDesktopOptionsButton')}
  function sync(){
    var lang=(window.AlinI18n&&typeof window.AlinI18n.current==='function'?window.AlinI18n.current():document.documentElement.dataset.alinLanguage)||'ar';
    var theme=document.documentElement.dataset.alinTheme==='dark'?'dark':'light';
    document.querySelectorAll('#alinDesktopOptionsPanel [data-lang]').forEach(function(b){var on=b.dataset.lang===lang;b.classList.toggle('active',on);b.setAttribute('aria-pressed',on?'true':'false')});
    document.querySelectorAll('#alinDesktopOptionsPanel [data-theme]').forEach(function(b){var on=b.dataset.theme===theme;b.classList.toggle('active',on);b.setAttribute('aria-pressed',on?'true':'false')});
  }
  window.alinToggleDesktopOptions=function(force){
    var box=panel(),btn=trigger();if(!box)return;
    var open=typeof force==='boolean'?force:box.hidden;
    box.hidden=!open;if(btn)btn.setAttribute('aria-expanded',open?'true':'false');
    if(open){sync();requestAnimationFrame(function(){box.querySelector('button')?.focus()})}
  };
  document.addEventListener('click',function(e){
    var box=panel(),btn=trigger();if(!box||box.hidden)return;
    if(box.contains(e.target)||btn&&btn.contains(e.target))return;
    window.alinToggleDesktopOptions(false);
  });
  document.addEventListener('keydown',function(e){if(e.key==='Escape')window.alinToggleDesktopOptions(false)});
  window.addEventListener('alin:language-applied',sync);
  window.addEventListener('alin:theme-changed',sync);
  window.addEventListener('load',sync,{once:true});
})();
