/* ALIN unified staff shell v2 — teacher + library + courier. Frontend only. */
(function(){
  'use strict';
  if(window.__ALIN_ROLE_SHELL_V2__)return;
  window.__ALIN_ROLE_SHELL_V2__=true;

  const VERSION=String(window.ALIN_CONFIG?.assetVersion||'4.2.0-unified-staff-shell-v2');
  const text=v=>String(v??'').trim();
  const normalizeRole=v=>{const r=text(v).toLowerCase();return r==='delegate'?'courier':r};
  const context=()=>{const c=window.current||{};return {role:normalizeRole(c.role),name:text(c.name||c.username),area:text(c.area),landmark:text(c.landmark)}};
  const roleMeta={
    teacher:{label:'لوحة المدرس',fallback:'المدرس',subtitle:'إدارة الملازم والطلبات والأرباح والنشر من مكان واحد'},
    library:{label:'لوحة إدارة المكتبة',fallback:'المكتبة',subtitle:'إدارة الطلبات والطباعة والتسليم من مكان واحد'},
    courier:{label:'صفحة المندوب',fallback:'المندوب',subtitle:'إدارة طلبات التوصيل والمتابعة والحسابات من مكان واحد'}
  };
  const pageFor=role=>document.getElementById(`${role}Page`);
  const sourceHeader=(role,page)=>role==='teacher'?page?.querySelector(':scope > h2'):role==='library'?page?.querySelector('.library-v116-header'):page?.querySelector('.courier-v161-hero');
  const tabsFor=(role,page)=>role==='teacher'?page?.querySelector(':scope > .teacher-tabs'):role==='library'?page?.querySelector(':scope > .library-v116-tabs'):page?.querySelector(':scope > .courier-v161-tabs');
  const contentFor=role=>document.getElementById(role==='teacher'?'teacherContent':role==='library'?'libraryV116Content':'courierV161Content');

  function loadCss(){
    if(document.getElementById('alinRoleShellV2Css'))return;
    const link=document.createElement('link');
    link.id='alinRoleShellV2Css';link.rel='stylesheet';
    link.href=`./styles/alin-role-shell-v2.css?v=${encodeURIComponent(VERSION)}`;
    document.head.appendChild(link);
  }

  function roleInfo(role){
    const c=context(),meta=roleMeta[role];
    if(role==='teacher')return {name:c.role==='teacher'&&c.name?c.name:meta.fallback,subtitle:meta.subtitle};
    if(role==='library'){
      const name=text(document.getElementById('libraryV116Name')?.textContent)||((c.role==='library'&&c.name)?c.name:meta.fallback);
      const location=text(document.getElementById('libraryV116Location')?.textContent);
      return {name,subtitle:location||meta.subtitle};
    }
    const name=text(document.getElementById('courierV161Name')?.textContent)||((c.role==='courier'&&c.name)?c.name:meta.fallback);
    const areas=text(document.getElementById('courierV161Areas')?.textContent);
    return {name,subtitle:areas&&areas!=='—'?`مناطق العمل: ${areas}`:meta.subtitle};
  }
  function setText(node,value){if(node&&node.textContent!==value)node.textContent=value}

  function ensureHero(role,page){
    const source=sourceHeader(role,page);
    if(source){source.classList.remove('alin-role-unified-hero','alin-role-library-hero','alin-role-courier-hero');source.classList.add('alin-role-source-header')}
    let hero=page.querySelector(`:scope > [data-alin-role-hero="${role}"]`);
    if(!hero){
      hero=document.createElement('header');
      hero.className='alin-role-unified-hero';
      hero.dataset.alinRoleHero=role;
      hero.innerHTML='<div class="alin-role-hero-main"><div class="alin-role-avatar" aria-hidden="true"></div><div class="alin-role-hero-copy"><small></small><h1></h1><p></p></div></div><div class="alin-role-platform-badge">منصة آلين</div>';
      page.prepend(hero);
    }
    const info=roleInfo(role),meta=roleMeta[role];
    setText(hero.querySelector('.alin-role-avatar'),(info.name||meta.fallback).slice(0,1));
    setText(hero.querySelector('.alin-role-hero-copy small'),meta.label);
    setText(hero.querySelector('.alin-role-hero-copy h1'),info.name||meta.fallback);
    setText(hero.querySelector('.alin-role-hero-copy p'),info.subtitle||meta.subtitle);
    return hero;
  }

  function preserveLibraryStatus(page,hero){
    const status=document.getElementById('libraryV116Status');
    if(!status)return;
    let strip=page.querySelector(':scope > .alin-role-library-status-strip');
    if(!strip){strip=document.createElement('section');strip.className='alin-role-library-status-strip';hero.insertAdjacentElement('afterend',strip)}
    if(status.parentElement!==strip)strip.appendChild(status);
  }

  function decorateTabs(role,page){
    const tabs=tabsFor(role,page);if(!tabs)return;
    tabs.classList.add('alin-role-tabs');
    [...tabs.children].forEach(button=>button.classList.add('alin-role-tab'));
    if(role==='teacher'){
      const stats=document.getElementById('teacherStats');
      if(stats&&tabs.nextElementSibling!==stats)tabs.insertAdjacentElement('afterend',stats);
    }
  }

  function decorateStats(page){
    page.querySelectorAll('#teacherStats,.teacher-v155-stats,.teacher-dashboard-stats,.teacher-stats,.library-v116-stats,.library-v120-finance-cards,.v174-metrics,.v164-finance-grid').forEach(root=>{
      root.classList.add('alin-role-stats');
      [...root.children].forEach(child=>child.classList.add('alin-role-stat'));
    });
  }

  function decorateCards(page){
    page.querySelectorAll('#teacherContent > section,#teacherContent .teacher-v155-card,.library-v116-panel,.library-v116-order,.v174-panel,.v174-order,.v164-table-card,.v164-profile,.v164-notifications > article').forEach(node=>node.classList.add('alin-role-card'));
  }

  function install(){
    for(const role of ['teacher','library','courier']){
      const page=pageFor(role);if(!page)continue;
      page.classList.add('alin-role-shell');page.dataset.alinRoleShell=role;
      const hero=ensureHero(role,page);
      if(role==='library')preserveLibraryStatus(page,hero);
      decorateTabs(role,page);
      const content=contentFor(role);content?.classList.add('alin-role-content');
      decorateStats(page);decorateCards(page);
    }
  }

  let scheduled=false;
  function schedule(){if(scheduled)return;scheduled=true;requestAnimationFrame(()=>{scheduled=false;install()})}
  const observer=new MutationObserver(schedule);
  function start(){loadCss();install();observer.observe(document.body,{subtree:true,childList:true,characterData:true});}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
  ['alin:role-runtime-ready','alin:auth-login','alin:auth-restored','alin:data-refreshed','alin:page-open','alin:teacher-rendered','alin:notifications-updated'].forEach(type=>window.addEventListener(type,schedule));
  window.AlinRoleShellV2=Object.freeze({install,schedule,version:'2.0.1'});
})();
