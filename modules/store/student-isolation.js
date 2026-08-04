// === store/student-isolation.js ===
/* ALIN v4.1.5 — per-student and per-guest browser storage isolation. */
(function(){
  'use strict';
  if(window.AlinStudentIsolation)return;
  const STUDENT_SESSION_KEY='alin_student_secure_session_v3';
  const GUEST_SCOPE_KEY='alin_guest_scope_v1';
  const safe=value=>String(value??'').replace(/[^a-zA-Z0-9_-]/g,'_').slice(0,120)||'unknown';
  function randomId(){
    try{return crypto.randomUUID?.()||`${Date.now()}-${Math.random().toString(36).slice(2)}`}catch(_){return `${Date.now()}-${Math.random().toString(36).slice(2)}`}
  }
  function studentId(){
    try{
      const state=JSON.parse(sessionStorage.getItem(STUDENT_SESSION_KEY)||'null');
      return state?.student?.id?String(state.student.id):'';
    }catch(_){return ''}
  }
  function guestId(){
    try{
      let value=sessionStorage.getItem(GUEST_SCOPE_KEY);
      if(!value){value=randomId();sessionStorage.setItem(GUEST_SCOPE_KEY,value)}
      return value;
    }catch(_){return'guest-session'}
  }
  function scope(){const id=studentId();return id?`student_${safe(id)}`:`guest_${safe(guestId())}`}
  function key(base){return `${String(base||'ALIN_DATA')}__${scope()}`}
  let active=scope();
  function refresh(reason='session'){
    const previous=active,next=scope();active=next;
    if(previous!==next)document.dispatchEvent(new CustomEvent('alin:storage-scope-changed',{detail:{previous,next,reason}}));
    return next;
  }
  function rotateGuest(reason='logout'){
    try{sessionStorage.setItem(GUEST_SCOPE_KEY,randomId())}catch(_){}
    return refresh(reason);
  }
  function readJson(base,fallback=[],storage=localStorage){try{const value=JSON.parse(storage.getItem(key(base))||'null');return value??fallback}catch(_){return fallback}}
  function writeJson(base,value,storage=localStorage){try{storage.setItem(key(base),JSON.stringify(value));return true}catch(_){return false}}
  function remove(base,storage=localStorage){try{storage.removeItem(key(base));return true}catch(_){return false}}
  document.addEventListener('alin:student-session',()=>queueMicrotask(()=>refresh('student-session')));
  window.AlinStudentIsolation=Object.freeze({scope,key,studentId,guestId,refresh,rotateGuest,readJson,writeJson,remove});
})();

;
