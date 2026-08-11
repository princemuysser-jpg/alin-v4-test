'use strict';
(()=>{
  const EVENTS=['click','change','input','submit','keydown','keyup','contextmenu'];
  const MAX_ARGS=12;

  function attrName(event,suffix=''){
    return `data-alin-${event}${suffix?`-${suffix}`:''}`;
  }

  function actionElement(target,event){
    if(!(target instanceof Element)) return null;
    return target.closest(`[${attrName(event)}]`);
  }

  function readArg(element,event,index){
    const base=`${attrName(event)}-arg${index}`;
    const source=element.getAttribute(`${base}-source`);
    if(source==='self') return element;
    if(source==='event') return window.event;
    if(source==='value') return 'value' in element ? element.value : '';
    if(source==='checked') return 'checked' in element ? Boolean(element.checked) : false;
    if(source==='file0') return element.files?.[0] ?? null;

    if(!element.hasAttribute(base) && !element.hasAttribute(`${base}-type`)) return undefined;
    const value=element.getAttribute(base) ?? '';
    const type=element.getAttribute(`${base}-type`) || 'string';
    if(type==='number') return Number(value);
    if(type==='boolean') return value==='true';
    if(type==='null') return null;
    return value;
  }

  function argsFor(element,event,eventObject){
    const args=[];
    for(let i=0;i<MAX_ARGS;i++){
      const base=`${attrName(event)}-arg${i}`;
      const source=element.getAttribute(`${base}-source`);
      if(source==='event'){args.push(eventObject);continue;}
      if(!source&&!element.hasAttribute(base)&&!element.hasAttribute(`${base}-type`)) break;
      args.push(readArg(element,event,i));
    }
    return args;
  }

  function resolve(path){
    const clean=String(path||'').replace(/^window\./,'').trim();
    if(!clean||clean.startsWith('@')) return null;
    const parts=clean.split('.').filter(Boolean);
    let owner=window;
    let value=window;
    for(let i=0;i<parts.length;i++){
      owner=value;
      value=value?.[parts[i]];
      if(value==null) return null;
    }
    return typeof value==='function'?{fn:value,owner}:null;
  }

  function builtin(action,element,eventObject,event){
    if(action==='@prevent'){
      eventObject.preventDefault();
      eventObject.stopPropagation();
      return true;
    }
    if(action==='@sanitize-phone'){
      if('value' in element) element.value=String(element.value||'').replace(/[^0-9+]/g,'');
      return true;
    }
    if(action==='@close-checkout-scroll-store'){
      window.closeCheckout?.();
      document.getElementById('storeGrid')?.scrollIntoView({behavior:'smooth'});
      return true;
    }
    if(action==='@frame-print'){
      const id=element.getAttribute(`${attrName(event)}-target`)||'';
      document.getElementById(id)?.contentWindow?.print?.();
      return true;
    }
    if(action==='@hide-by-id'){
      const id=element.getAttribute(`${attrName(event)}-target`)||'';
      document.getElementById(id)?.classList.add('hidden');
      return true;
    }
    if(action==='@desktop-options-account'){
      window.alinToggleDesktopOptions?.(false);
      window.alinOpenRealAccount?.();
      return true;
    }
    if(action==='@desktop-options-about'){
      window.alinToggleDesktopOptions?.(false);
      window.alinAboutPlatform?.();
      return true;
    }
    if(action==='@desktop-options-contact'){
      window.alinToggleDesktopOptions?.(false);
      window.alinContactUs?.();
      return true;
    }
    return false;
  }

  async function dispatch(eventObject,event){
    const element=actionElement(eventObject.target,event);
    if(!element) return;
    const action=element.getAttribute(attrName(event))||'';

    if(event==='submit') eventObject.preventDefault();
    if(builtin(action,element,eventObject,event)) return;

    const resolved=resolve(action);
    if(!resolved){
      console.error(`[ALIN UI] action not found: ${action}`);
      return;
    }

    try{
      const result=resolved.fn.apply(resolved.owner,argsFor(element,event,eventObject));
      const settled=result&&typeof result.then==='function'?await result:result;
      if(settled===false){
        eventObject.preventDefault();
        eventObject.stopPropagation();
      }
    }catch(error){
      console.error(`[ALIN UI] action failed: ${action}`,error);
      window.toast?.('تعذر تنفيذ العملية. حاول مرة أخرى.');
    }
  }

  EVENTS.forEach(event=>document.addEventListener(event,eventObject=>{void dispatch(eventObject,event);},false));
  window.AlinUiActions=Object.freeze({version:'4.2.0-rc.13',resolve});
})();
