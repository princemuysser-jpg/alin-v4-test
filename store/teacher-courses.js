(function(){
  const config = window.ALIN_CONFIG || {};
  const forceOff = String(localStorage.getItem('alin_feature_teacher_courses') || '').toLowerCase() === 'off';
  if (config.teacherCoursesEnabled === false || forceOff) return;

  const courses = [
    {
      id:'phy-6th-2026',
      subject:'الفيزياء',
      level:'السادس العلمي',
      title:'دورة الفيزياء الشاملة',
      teacher:'أ. أحمد محمد',
      starts:'1 / 9 / 2026',
      days:'السبت - الاثنين - الأربعاء',
      mode:'حضوري',
      location:'معهد آلين التعليمي',
      price:'75,000',
      currency:'د.ع',
      status:'open',
      statusLabel:'التسجيل مفتوح',
      cta:'احجز قريباً',
      gradient:['#173d72','#0b74bd'],
      teacherInitial:'أ'
    },
    {
      id:'chem-6th-2026',
      subject:'الكيمياء',
      level:'السادس العلمي',
      title:'دورة الكيمياء العضوية',
      teacher:'أ. سيف العزاوي',
      starts:'10 / 9 / 2026',
      days:'الأحد - الثلاثاء - الخميس',
      mode:'أونلاين',
      location:'Google Meet',
      price:'60,000',
      currency:'د.ع',
      status:'soon',
      statusLabel:'تبدأ قريباً',
      cta:'عرض التفاصيل',
      gradient:['#8e5822','#d18d19'],
      teacherInitial:'س'
    },
    {
      id:'math-4th-2026',
      subject:'الرياضيات',
      level:'الرابع العلمي',
      title:'دورة التفاضل المتكامل',
      teacher:'أ. علي حسين',
      starts:'25 / 8 / 2026',
      days:'السبت - الثلاثاء - الخميس',
      mode:'حضوري',
      location:'معهد آلين التعليمي',
      price:'75,000',
      currency:'د.ع',
      status:'open',
      statusLabel:'التسجيل مفتوح',
      cta:'احجز قريباً',
      gradient:['#1f6b4d','#14a56a'],
      teacherInitial:'ع'
    },
    {
      id:'eng-rules-2026',
      subject:'الإنكليزي',
      level:'المتوسطة والثانوية',
      title:'دورة القواعد الشاملة',
      teacher:'أ. محمد السعدي',
      starts:'5 / 9 / 2026',
      days:'الأحد - الثلاثاء - الخميس',
      mode:'حضوري',
      location:'معهد آلين التعليمي',
      price:'65,000',
      currency:'د.ع',
      status:'full',
      statusLabel:'اكتمل العدد',
      cta:'عرض التفاصيل',
      gradient:['#4f4d7d','#7568c7'],
      teacherInitial:'م'
    }
  ];

  const esc = (value)=>String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
  const q = (sel, root=document)=>root.querySelector(sel);
  const qa = (sel, root=document)=>Array.from(root.querySelectorAll(sel));

  function cardMarkup(course){
    const statusClass = course.status === 'soon' ? ' is-soon' : course.status === 'full' ? ' is-full' : '';
    return `
      <article class="alin-course-card" style="--course-grad-a:${esc(course.gradient[0])};--course-grad-b:${esc(course.gradient[1])}" data-course-id="${esc(course.id)}">
        <div class="alin-course-card__hero">
          <span class="alin-course-card__status${statusClass}">${esc(course.statusLabel)}</span>
          <div class="alin-course-card__subject"><small>${esc(course.level)}</small><h3>${esc(course.subject)}</h3></div>
          <div class="alin-course-card__avatar" aria-hidden="true">${esc(course.teacherInitial)}</div>
        </div>
        <div class="alin-course-card__body">
          <h3 class="alin-course-card__name">${esc(course.title)}</h3>
          <p class="alin-course-card__teacher">${esc(course.teacher)}</p>
          <div class="alin-course-card__meta">
            <span><b>◔</b><span>تبدأ: ${esc(course.starts)}</span></span>
            <span><b>⌚</b><span>${esc(course.days)}</span></span>
            <span><b>⌂</b><span>${esc(course.location)} — ${esc(course.mode)}</span></span>
          </div>
          <div class="alin-course-card__price"><div><small>الاشتراك</small><strong>${esc(course.price)}</strong></div><small>${esc(course.currency)}</small></div>
          <div class="alin-course-card__actions">
            <button class="alin-course-card__details" type="button" data-course-action="details" data-course-id="${esc(course.id)}">عرض التفاصيل</button>
            <button class="alin-course-card__reserve" type="button" data-course-action="details" data-course-id="${esc(course.id)}">${esc(course.cta)}</button>
          </div>
        </div>
      </article>`;
  }

  function sectionMarkup(){
    return `
      <div class="alin-teacher-courses__head">
        <div class="alin-teacher-courses__title">
          <small>اكتشف دورات آلين</small>
          <h2>دورات المدرسين</h2>
        </div>
        <button type="button" data-course-action="all">عرض الكل</button>
      </div>
      <div class="alin-teacher-courses__viewport">${courses.map(cardMarkup).join('')}</div>`;
  }

  function modalMarkup(){
    return `
      <div class="alin-teacher-courses-modal__panel" role="dialog" aria-modal="true" aria-labelledby="alinTeacherCoursesModalTitle">
        <div class="alin-teacher-courses-modal__head">
          <div><h3 id="alinTeacherCoursesModalTitle">دورات المدرسين</h3><p>قسم مستقل داخل المتجر، وإذا ما عجبك ينگدر ينشال بدون ما يأثر على باقي الأقسام.</p></div>
          <button class="alin-teacher-courses-modal__close" type="button" aria-label="إغلاق">×</button>
        </div>
        <div class="alin-teacher-courses-modal__grid">${courses.map(cardMarkup).join('')}</div>
      </div>`;
  }

  function ensureModal(){
    let modal = document.getElementById('alinTeacherCoursesModal');
    if (modal) return modal;
    modal = document.createElement('div');
    modal.id = 'alinTeacherCoursesModal';
    modal.className = 'alin-teacher-courses-modal';
    modal.hidden = true;
    modal.innerHTML = modalMarkup();
    document.body.appendChild(modal);
    modal.addEventListener('click', (event)=>{
      if (event.target === modal || event.target.closest('.alin-teacher-courses-modal__close')) closeModal();
    });
    modal.addEventListener('keydown', (event)=>{ if (event.key === 'Escape') closeModal(); });
    return modal;
  }

  function openModal(focusCourseId){
    const modal = ensureModal();
    modal.hidden = false;
    document.body.style.overflow = 'hidden';
    const button = modal.querySelector('.alin-teacher-courses-modal__close');
    button && button.focus({preventScroll:true});
    if (focusCourseId){
      const target = qa('[data-course-id]', modal).find((node)=>node.getAttribute('data-course-id') === focusCourseId);
      target && target.scrollIntoView({behavior:'smooth', block:'center', inline:'nearest'});
    }
  }

  function closeModal(){
    const modal = document.getElementById('alinTeacherCoursesModal');
    if (!modal) return;
    modal.hidden = true;
    document.body.style.overflow = '';
  }

  function bind(root){
    qa('[data-course-action]', root).forEach((button)=>{
      button.addEventListener('click', ()=>{
        const action = button.getAttribute('data-course-action');
        const courseId = button.getAttribute('data-course-id');
        if (action === 'all') return openModal();
        openModal(courseId || undefined);
      });
    });
  }

  function render(){
    qa('#alinTeacherCoursesSection').forEach((mount)=>{
      mount.innerHTML = sectionMarkup();
      mount.hidden = false;
      bind(mount);
    });
    ensureModal();
    bind(document.getElementById('alinTeacherCoursesModal'));
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', render, {once:true});
  } else {
    render();
  }
})();
