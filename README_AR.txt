إصلاح ظهور تسعير التوصيل في لوحة المدير — 2026-08-23

السبب:
ملف modules/admin/delivery-pricing.js موجود في المصدر وموجود في module-order.json،
لكن ملف dist/alin-role-runtime.v4.js الحالي لا يحتويه، لذلك الواجهة لا تظهر.

الإصلاح:
1) alin-config.js
   - رفع assetVersion إلى:
     4.2.0-delivery-pricing-ui-20260823-1121
   - إضافة bridge صغير ينتظر تحميل role runtime ثم يحمل:
     ./modules/admin/delivery-pricing.js
   - إذا أصبح الـ dist مستقبلاً يحتوي الموديول، الـ bridge يتوقف تلقائياً ولا يكرر التحميل.

2) modules/admin/delivery-pricing.js
   - نسخة مطابقة تماماً للملف الحالي في GitHub (Git blob SHA: 62552b13a44cae3aa9848d303863077071a1b419)
   - مرفقة فقط لضمان وجود الملف عند الرفع.

طريقة الرفع:
- ارفع محتويات هذا ZIP إلى جذر المستودع مع الحفاظ على المسارات.
- استبدل alin-config.js الموجود.
- استبدل modules/admin/delivery-pricing.js أو اتركه إذا كان نفس النسخة الحالية.
- لا تحتاج لتغيير dist/alin-role-runtime.v4.js.

بعد النشر:
- أغلق صفحة آلين وافتحها من جديد أو Ctrl+F5.
- لوحة المدير > المندوبين > مناطق التوصيل:
  يجب أن يظهر لكل منطقة "على الطالب" و"أجرة المندوب" وزر "تعديل الأسعار".
- داخل تفاصيل طلب توصيل غير مكتمل:
  يجب أن يظهر قسم "تسعير التوصيل" مع:
  سعر المنطقة / توصيل مجاني / مبلغ خاص.

التحقق المنفذ:
- node --check نجح على alin-config.js.
- node --check نجح على modules/admin/delivery-pricing.js.
- ملف delivery-pricing.js المرفق مطابق SHA للنسخة الحالية على GitHub.

ملاحظة:
محاولة الرفع المباشر من ربط GitHub داخل ChatGPT رُفضت بصلاحية 403، لذلك هذا الملف لم يُرفع أو يُنشر تلقائياً.
