import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // هذا تطبيق ويب فقط — لا يوجد Keychain/Keystore هنا (تلك واجهات
  // مخصّصة للمنصّات الأصلية Android/iOS). البقاء مسجّلاً دخول على الويب
  // يعتمد على جلسة المتصفح التي يديرها Firebase Auth SDK نفسه (تُخزَّن
  // بمتصفح المستخدم عبر IndexedDB). نجعل هذا صريحاً هنا (LOCAL بدل
  // الاعتماد على الافتراضي الضمني) لضمان بقاء الجلسة بعد إغلاق المتصفح
  // وإعادة فتحه، وليس فقط أثناء التبويب الحالي.
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  runApp(const AdminApp());
}
