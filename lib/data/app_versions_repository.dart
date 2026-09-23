import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_version.dart';

/// طبقة الوصول لمجموعة `appVersions` في Firestore، بالإضافة لرفع ملفات الـ
/// APK إلى Firebase Storage بنفس المشروع المركزي.
///
/// معرّف كل مستند هو نفس قيمة [AppVersion.packageName] — راجع نموذج
/// البيانات بالمخطط.
class AppVersionsRepository {
  AppVersionsRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _versionsRef =>
      _firestore.collection('appVersions');

  /// تدفّق لحظي بكل إصدارات التطبيقات المنشورة (يُستخدم لتحديث القائمة
  /// تلقائياً).
  Stream<List<AppVersion>> watchAll() {
    return _versionsRef.orderBy(FieldPath.documentId).snapshots().map(
          (snapshot) => snapshot.docs
              .map(AppVersion.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<AppVersion?> getByPackageName(String packageName) async {
    final doc = await _versionsRef.doc(packageName.trim()).get();
    if (!doc.exists) return null;
    return AppVersion.fromFirestore(doc);
  }

  /// يرفع ملف الـ APK إلى المسار `app-releases/{packageName}/{versionCode}.apk`
  /// ويُعيد رابط تنزيل عام له. [onProgress] يُستدعى بنسبة الرفع (0..1).
  Future<String> uploadApk({
    required String packageName,
    required int versionCode,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref('app-releases/${packageName.trim()}/$versionCode.apk');
    final task = ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/vnd.android.package-archive'),
    );

    final subscription = task.snapshotEvents.listen((snapshot) {
      if (onProgress == null || snapshot.totalBytes <= 0) return;
      onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
    });

    try {
      await task;
    } finally {
      await subscription.cancel();
    }

    return ref.getDownloadURL();
  }

  /// ينشئ أو يستبدل مستند إصدار تطبيق كاملاً (Document id = packageName).
  Future<void> saveVersion(AppVersion version) {
    return _versionsRef.doc(version.packageName.trim()).set(version.toMap());
  }

  Future<void> deleteVersion(String packageName) {
    return _versionsRef.doc(packageName.trim()).delete();
  }

  /// يحذف ملف الـ APK المرتبط من Storage (تنظيف اختياري بعد حذف المستند).
  /// تجاهل الفشل هنا آمن: ملف Storage يتيم لا يترتب عليه أي مشكلة وظيفية.
  Future<void> deleteApkFile({
    required String packageName,
    required int versionCode,
  }) async {
    try {
      await _storage
          .ref('app-releases/${packageName.trim()}/$versionCode.apk')
          .delete();
    } catch (_) {
      // تجاهل: الملف قد يكون غير موجود أو المسار مختلف.
    }
  }
}
