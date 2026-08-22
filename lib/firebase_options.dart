// ملف مؤقت (placeholder) — يجب استبداله فعلياً!
//
// هذا الملف يُفترض أن يُولَّد تلقائياً بواسطة أمر:
//   flutterfire configure
// بعد إنشاء مشروع Firebase المركزي الخاص بالتراخيص وربطه بهذا المشروع.
// راجع قسم "إعداد Firebase" في README.md لمعرفة الخطوات كاملة.
//
// القيم أدناه وهمية بالكامل ولن تعمل قبل استبدالها.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions لم يتم إعدادها لهذه المنصة — '
      'هذا التطبيق مخصص للويب فقط. شغّل flutterfire configure لتوليد الإعدادات الصحيحة.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_WEB_API_KEY',
    appId: 'REPLACE_WITH_YOUR_WEB_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    authDomain: 'REPLACE_WITH_YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.appspot.com',
  );
}
