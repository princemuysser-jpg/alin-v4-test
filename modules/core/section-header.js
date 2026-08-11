/* ALIN v4.1.5 prepublish 1f — style the existing section header only; never insert a second header. */
(()=>{
  'use strict';
  if(window.__ALIN_EXISTING_SECTION_HEADER__)return;
  window.__ALIN_EXISTING_SECTION_HEADER__=true;

  const roles={
    admin:{page:'adminPage',host:'adminContent',nav:'.admin-tabs'},
    teacher:{page:'teacherPage',host:'teacherContent',nav:'.teacher-tabs'},
    library:{page:'libraryPage',host:'libraryV116Content',nav:'.library-v116-tabs',pageHeader:'.library-v116-header'},
    courier:{page:'courierPage',host:'courierV161Content',nav:'.courier-v161-tabs',pageHeader:'.courier-v161-hero'}
  };

  function findExistingHeader(host){
    if(!host)return null;
    const selectors=[
      ':scope > .alin415r-heading',
      ':scope > section:first-child > .alin415r-heading:first-child',
      ':scope > header:first-child',
      ':scope > section:first-child > header:first-child',
      ':scope > [class*="-head"]:first-child',
      ':scope > section:first-child > [class*="-head"]:first-child',
      ':scope > *:first-child > [class*="-head"]:first-child',
      ':scope > [class*="-hero"]:first-child',
      ':scope > section:first-child > [class*="-hero"]:first-child',
      ':scope > [class*="-welcome"]:first-child',
      ':scope > section:first-child > [class*="-welcome"]:first-child'
    ];
    for(const selector of selectors){
      try{const node=host.querySelector(selector);if(node)return node}catch(_){ }
    }
    return null;
  }

  function decorate(role){
    const cfg=roles[role],page=document.getElementById(cfg?.page),host=document.getElementById(cfg?.host);
    if(!cfg||!page||!host)return;
    page.querySelectorAll('.alin-existing-section-header').forEach(node=>node.classList.remove('alin-existing-section-header'));
    const fixedHeader=cfg.pageHeader?page.querySelector(cfg.pageHeader):null;
    const header=fixedHeader||findExistingHeader(host);
    if(header)header.classList.add('alin-existing-section-header');
  }

  function decorateAll(){Object.keys(roles).forEach(decorate)}

  function wrapNavigation(name,role){
    const original=window[name];
    if(typeof original!=='function'||original.__alinExistingHeaderWrapped)return;
    function wrapped(tab,...args){
      if(String(tab||'')!=='receipts')try{window.AlinReceiptsNavigationGuard?.leave?.()}catch(_){ }
      const result=original.call(this,tab,...args);
      requestAnimationFrame(()=>decorate(role));
      setTimeout(()=>decorate(role),80);
      return result;
    }
    Object.defineProperty(wrapped,'__alinExistingHeaderWrapped',{value:true});
    Object.defineProperty(wrapped,'__alinReceiptsGuarded',{value:true});
    window[name]=wrapped;
  }

  function install(){
    wrapNavigation('adminTab','admin');
    wrapNavigation('teacherTab','teacher');
    wrapNavigation('renderCourierDashboard','courier');
    decorateAll();
  }

  document.addEventListener('click',event=>{
    const button=event.target.closest?.('#adminPage .admin-tabs button,#teacherPage .teacher-tabs button,#libraryPage .library-v116-tabs button,#courierPage .courier-v161-tabs button');
    if(!button)return;
    const role=button.closest('#adminPage')?'admin':button.closest('#teacherPage')?'teacher':button.closest('#libraryPage')?'library':button.closest('#courierPage')?'courier':'';
    if(role){requestAnimationFrame(()=>decorate(role));setTimeout(()=>decorate(role),100)}
  },true);

  const start=()=>{
    install();
    [120,500,1100,2200].forEach(delay=>setTimeout(install,delay));
    const observer=new MutationObserver(records=>{
      if(records.some(record=>record.type==='childList'))requestAnimationFrame(decorateAll);
    });
    observer.observe(document.body,{subtree:true,childList:true});
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
  window.AlinExistingSectionHeader=Object.freeze({refresh:decorateAll});
})();
