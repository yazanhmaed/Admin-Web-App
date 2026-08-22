# لوحة إدارة الشركات (Admin Web App)

تطبيق Flutter Web مستقل لإدارة "الشركات" التي تستخدم تطبيق المخزن (`warehouse_app`).
يتصل هذا التطبيق فقط بمشروع **Firebase مركزي واحد** مخصص للتراخيص والإعدادات
(Firestore + Authentication) — لا علاقة له ببيانات المخزون/الفواتير الخاصة بأي شركة.

لاحقاً، تطبيق المخزن الرئيسي سيقرأ من نفس مشروع Firebase هذا (مجموعة `companies`)
ليعرف بيانات الاتصال الخاصة بكل شركة بناءً على كود يدخله المستخدم.

## المتطلبات

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (قناة stable، أحدث إصدار) مع تفعيل دعم الويب:
  ```bash
  flutter config --enable-web
  ```
* [Firebase CLI](https://firebase.google.com/docs/cli) و [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup):
  ```bash
  npm install -g firebase-tools
  dart pub global activate flutterfire_cli
  ```

## التشغيل محلياً

```bash
flutter pub get
flutter run -d chrome
```

للبناء للإنتاج:

```bash
flutter build web
```

## إعداد Firebase (خطوات يدوية — مرة واحدة فقط)

هذا التطبيق **لا** يُنشئ مشروع Firebase تلقائياً. يجب تنفيذ الخطوات التالية يدوياً:

1. **أنشئ مشروع Firebase جديد مخصص** (مثلاً باسم `warehouse-central-license`) من
   [Firebase Console](https://console.firebase.google.com/). هذا المشروع منفصل تماماً
   عن أي مشروع Firebase خاص بأي شركة على حدة.

2. **فعّل الخدمات التالية** داخل المشروع الجديد:
   * **Firestore Database** (اختر Native mode، وليس Datastore mode).
   * **Authentication** → فعّل طريقة تسجيل الدخول **Email/Password**.

3. **اربط هذا المشروع بمشروع Firebase** عبر تشغيل الأمر التالي من جذر هذا
   المستودع (يتطلب تسجيل دخول مسبق بـ `firebase login`):
   ```bash
   flutterfire configure
   ```
   اختر مشروع Firebase الذي أنشأته بالخطوة 1، واختر منصة **web** فقط (هذا تطبيق
   ويب فقط). سيقوم الأمر بإعادة توليد ملف `lib/firebase_options.dart` تلقائياً
   بالقيم الصحيحة — **استبدل الملف الحالي (فيه قيم وهمية placeholder فقط)**.

4. **أنشئ حساب إدمن يدوياً** من Firebase Console:
   Authentication → Users → Add user → أدخل إيميل وكلمة مرور. هذا الحساب هو
   ما ستستخدمه لتسجيل الدخول لهذا التطبيق. لا يوجد تسجيل حساب جديد من داخل
   التطبيق نفسه — الحسابات تُنشأ من Console فقط، وحساب واحد بصلاحيات كاملة
   يكفي حالياً (لا يوجد نظام صلاحيات متعدد المستويات).

5. **انشر قواعد أمان Firestore** الموجودة بملف [`firestore.rules`](./firestore.rules):
   ```bash
   firebase deploy --only firestore:rules
   ```
   أو الصق محتوى الملف يدوياً من Firebase Console → Firestore Database → Rules.

   منطق القواعد:
   * قراءة مستند شركة واحدة بمعرفة الكود بالضبط (`get`): مسموحة للجميع (يحتاجها
     تطبيق المخزن قبل تسجيل الدخول).
   * القراءة الجماعية لكل الشركات (`list`): ممنوعة لغير المسجّلين دخول (لمنع
     استخراج قائمة كل الأكواد).
   * الكتابة (إنشاء/تعديل/حذف): فقط للمستخدم المسجّل دخول (الإدمن).

## نموذج البيانات (Firestore Schema)

**Collection:** `companies` — **معرّف المستند = قيمة حقل `code`** (وليس معرّفاً
تلقائياً)، لضمان عدم تكرار الأكواد بنيوياً.

```json
{
  "name": "string",
  "code": "string",
  "email": "string",
  "isActive": true,
  "expiryDate": "Timestamp",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "firebase": {
    "android": {
      "apiKey": "string",
      "appId": "string",
      "messagingSenderId": "string",
      "projectId": "string",
      "storageBucket": "string"
    },
    "ios": {
      "apiKey": "string",
      "appId": "string",
      "messagingSenderId": "string",
      "projectId": "string",
      "storageBucket": "string",
      "iosBundleId": "string"
    }
  }
}
```

قسم `firebase.ios` اختياري بالكامل — يمكن تركه فارغاً إذا لم يكن لدى الشركة
نسخة iOS بعد.

## الميزات

* تسجيل دخول بإيميل/كلمة مرور (بدون تسجيل حساب جديد من داخل التطبيق).
* قائمة الشركات مع تحديث لحظي (`snapshots()`)، بحث بالاسم/الكود، تلوين تحذيري
  لتاريخ الانتهاء (برتقالي خلال 7 أيام، أحمر عند الانتهاء).
* تبديل حالة التفعيل مباشرة من القائمة.
* إضافة/تعديل شركة مع فحص لحظي (debounced) لتوفر الكود قبل الحفظ.
* تجديد الاشتراك (+30 / +90 / +365 يوم أو تاريخ مخصص).
* حذف مع تأكيد.
* استيراد شركات من نص JSON (أداة لمرة واحدة، أعلى شاشة القائمة) — تتجاهل أي
  حقل لا يطابق المخطط، وتستبدل قيم `expiryDate` الوهمية بتاريخ افتراضي (سنة
  من اليوم).

## ملاحظات

* هذا مشروع منفصل تماماً عن `warehouse_app` — لا تعديل عليه إطلاقاً.
* لا يوجد إرسال بريد إلكتروني تلقائي (Cloud Functions) بهذه المرحلة — حقل
  `email` موجود بالمخطط فقط جاهزاً لاستخدام مستقبلي.
