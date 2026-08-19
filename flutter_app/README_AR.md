# منصة آلين — Flutter Production 5.2

هذا هو مشروع تطبيق الطالب الرسمي بـFlutter، مربوط مباشرة بمشروع Supabase الإنتاجي الحالي لمنصة آلين. لا يوجد Local Server ولا قاعدة بيانات ثانية.

## هوية الإصدار
- Android Package ID: `com.alin.platform`
- Version Name: `5.2.0`
- Version Code: `4`
- Android compileSdk: 36
- Android targetSdk: 36
- Android minSdk: 24
- الاتصال بالخادم: HTTPS إلى Supabase الإنتاجي.

## الموجود فعلياً
- متجر الملازم والقرطاسية والهدايا من `alin_public_store_bootstrap`.
- أقسام وشعب، بحث وترتيب، منتجات وملازم، صور ومخزون.
- تفاصيل المنتج واختيار التصميم/Variant وشراء مفرد/باكيت.
- مواد مرتبطة بنفس منطق الويب: المادة ثم المرحلة ثم المدرس ثم القسم.
- تقييمات منشورة + معدل ونجوم وتوزيع 1–5 + إرسال تقييم جديد للمراجعة عبر نفس public-submission.
- خصم ظاهر على البطاقات والتفاصيل: نسبة الخصم + السعر السابق مشطوب + السعر الجديد + مبلغ التوفير.
- مفضلة وسلة محفوظتان على الجهاز.
- Checkout حقيقي عبر `alin_create_store_orders_guarded` مع حماية تكرار الطلب من السيرفر.
- القرطاسية والهدايا تتحول إلى التوصيل فقط كما يفرض السيرفر.
- المكتبات ومناطق التوصيل ورسوم المنطقة من نفس قاعدة آلين.
- حساب الطالب: إنشاء/دخول/خروج، وترحيب بالاسم.
- رمز جلسة الطالب محفوظ في Secure Storage المشفر على الجهاز، والجلسة تبقى حتى تسجيل الخروج.
- طلباتي، العروض الخاصة، وتجهيز كود العرض مباشرة للـCheckout.
- تتبع الطلب.
- مركز الإشعارات العامة داخل التطبيق وتحديث عند الرجوع للتطبيق وكل 45 ثانية أثناء التشغيل.
- تصميم Flutter مستقل للموبايل وTablet/iPad؛ لا WebView ولا CSS/PWA.
- Android Native Splash وأيقونة آلين.
- Android Release Signing جاهز لقراءة `android/key.properties` بدون وضع الأسرار داخل Source ZIP.
- ملفات Google Play: Icon 512 + Feature Graphic + نصوص المتجر + مسودة سياسة الخصوصية/Data Safety.

## التوقيع
حزمة التوقيع السرية منفصلة عن Source ZIP. انسخ منها:
- `key.properties` → إلى `android/key.properties`
- مجلد `keystore` → إلى `android/keystore`

لا ترفع حزمة التوقيع إلى GitHub ولا تشاركها.

## إخراج ملف Google Play
على Windows بعد تثبيت Flutter وAndroid Studio/SDK 36:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tool\build_play_release.ps1
```

السكريبت يشغل `pub get` ثم `analyze` ثم `test` ثم يبني AAB وAPK Release.

ملف Google Play الناتج:
`build/app/outputs/bundle/release/app-release.aab`

## ملاحظة الإشعارات الخارجية
مركز الإشعارات داخل التطبيق كامل ومربوط بـSupabase. الإشعار Native الفوري عندما يكون التطبيق مغلقاً يحتاج Firebase Cloud Messaging/Apple APNs وملف مشروع Firebase الخاص بالتطبيق؛ لم يتم تضمين مفتاح أو مشروع Firebase وهمي لأن هذه بيانات اعتماد خارجية لا يجوز اختلاقها. هذا لا يمنع بناء أو رفع الإصدار الحالي إلى Google Play.

## الأمان
داخل Flutter يوجد Supabase Publishable Key فقط. لا يوجد Service Role Key ولا VAPID Private Key ولا مفتاح إدارة داخل التطبيق.
