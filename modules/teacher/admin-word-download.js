(function(){
  'use strict';

  const originalOpen=window.openTeacherRequestSource;
  if(typeof originalOpen!=='function')return;

  async function downloadTeacherRequestSource(id){
    try{
      const cur=typeof current!=='undefined'?current:(window.current||{});
      if(String(cur.role||'')!=='admin')throw new Error('تنزيل الملف متاح للمدير فقط');

      const database=typeof db!=='undefined'?db:(window.db||{});
      const rows=database.teacherRequests||database.teacher_requests||[];
      const request=rows.find(x=>String(x.id)===String(id));

      if(!request?.source_file_path)throw new Error('لا يوجد ملف Word مرفوع');
      if(typeof alinResolveStoredFile!=='function')throw new Error('خدمة الملفات غير جاهزة');

      const resolved=await alinResolveStoredFile(request.source_file_path,'teacher-requests');
      if(!resolved?.url)throw new Error('تعذر تجهيز رابط الملف');

      const response=await fetch(resolved.url,{cache:'no-store'});
      if(!response.ok)throw new Error('تعذر تنزيل ملف Word');

      const blob=await response.blob();
      const objectUrl=URL.createObjectURL(blob);
      const link=document.createElement('a');

      link.href=objectUrl;
      link.download=request.source_file_name||`${request.title||'ملزمة المدرس'}.docx`;
      document.body.appendChild(link);
      link.click();
      link.remove();

      setTimeout(()=>URL.revokeObjectURL(objectUrl),1500);

      if(typeof audit==='function'){
        await audit('teacher_request','تنزيل ملف Word للتصميم: '+(request.title||request.id));
      }
    }catch(error){
      alert(error.message||'تعذر تنزيل الملف');
    }
  }

  window.downloadTeacherRequestSource=downloadTeacherRequestSource;

  window.openTeacherRequestSource=async function(id){
    const result=await originalOpen(id);
    const cur=typeof current!=='undefined'?current:(window.current||=async function(id){
    const result=await originalOpen(id);
    const cur=typeof current!=='undefined'?current:(window.current||{});

    if(String(cur.role||'')==='admin'){
      const actions=document.querySelector('#checkoutBox .teacher-word-viewer .row-actions');

      if(actions&&!actions.querySelector('[data-admin-word-download]')){
        const button=document.createElement('button');
        button.type='button';
        button.dataset.adminWordDownload='1';
        button.textContent='تنزيل ملف Word للتصميم';
        button.onclick=()=>downloadTeacherRequestSource(id);
        actions.prepend(button);
      }
    }

    return result;
  };

  if(window.AlinTeacherModules){
    window.AlinTeacherModules.openTeacherRequestSource=window.openTeacherRequestSource;
  }
})();