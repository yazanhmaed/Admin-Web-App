import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/code_generator.dart';
import '../models/company.dart';
import '../models/company_firebase_config.dart';

/// نتيجة عملية استيراد شركات من JSON.
class ImportResult {
  ImportResult({required this.imported, required this.errors});

  final List<String> imported;
  final List<String> errors;

  int get successCount => imported.length;
  int get errorCount => errors.length;
}

/// طبقة الوصول لمجموعة `companies` في Firestore.
///
/// معرّف كل مستند هو نفس قيمة حقل `code` — راجع نموذج البيانات بالمخطط.
class CompaniesRepository {
  CompaniesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _companiesRef =>
      _firestore.collection('companies');

  /// مستند العدّاد المستخدم لتوليد أكواد الشركات التسلسلية (شارك بين كل
  /// البادئات، مثال: ACM-001 ثم XYZ-002 ثم ACM-003...).
  DocumentReference<Map<String, dynamic>> get _companyCodeCounterRef =>
      _firestore.collection('meta').doc('companyCodeCounter');

  /// معاينة الرقم التسلسلي التالي المتوقّع (لعرضه بالنموذج فور فتحه
  /// وأثناء الكتابة). قراءة غير ذرّية — للعرض فقط، وليست المصدر النهائي.
  Future<int> previewNextNumber() async {
    final snap = await _companyCodeCounterRef.get();
    final last = snap.data()?['lastNumber'];
    return (last is int ? last : 0) + 1;
  }

  /// ينشئ شركة جديدة بكود فريد يُولَّد ذرّياً (atomically) داخل معاملة
  /// Firestore، لتفادي تعارض الأكواد عند الحفظ المتزامن من أكثر من
  /// مستخدم بنفس اللحظة. البادئة تُشتق من [companyName]، والرقم التسلسلي
  /// من عدّاد مشترك. يستدعي [buildCompany] بالكود النهائي بعد توليده،
  /// ويُرجع الكود المُستخدم فعلياً.
  Future<String> createCompanyWithAutoCode(
    String companyName,
    Company Function(String code) buildCompany,
  ) async {
    final prefix = CompanyCodeFormat.abbreviate(companyName);
    // ملاحظة: على الويب، runTransaction<T> لا يُرجع قيمة الإغلاق فعلياً
    // (يُرجع null دائماً بسبب قيد بمكتبة cloud_firestore_web)، لذا نلتقط
    // الكود بمتغيّر بالنطاق الخارجي بدلاً من الاعتماد على قيمة الإرجاع.
    late final String resultCode;
    await _firestore.runTransaction<void>((tx) async {
      final counterSnap = await tx.get(_companyCodeCounterRef);
      var next = ((counterSnap.data()?['lastNumber'] as int?) ?? 0) + 1;
      var code = CompanyCodeFormat.format(prefix, next);
      var docRef = _companiesRef.doc(code);
      var docSnap = await tx.get(docRef);
      // احتياط دفاعي: لو كان هناك مستند بنفس الكود بالفعل (مثلاً بسبب
      // إنشاء يدوي سابق)، انتقل للرقم التالي حتى نجد كوداً غير مستخدم.
      while (docSnap.exists) {
        next += 1;
        code = CompanyCodeFormat.format(prefix, next);
        docRef = _companiesRef.doc(code);
        docSnap = await tx.get(docRef);
      }

      final company = buildCompany(code);
      tx.set(docRef, company.toCreateMap());
      tx.set(_companyCodeCounterRef, {'lastNumber': next});
      resultCode = code;
    });
    return resultCode;
  }

  /// تدفّق لحظي بكل الشركات (يُستخدم لتحديث القائمة تلقائياً).
  Stream<List<Company>> watchAll() {
    return _companiesRef.orderBy('name').snapshots().map(
          (snapshot) =>
              snapshot.docs.map(Company.fromFirestore).toList(growable: false),
        );
  }

  Future<bool> codeExists(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    final doc = await _companiesRef.doc(trimmed).get();
    return doc.exists;
  }

  Future<void> createCompany(Company company) {
    return _companiesRef.doc(company.code.trim()).set(company.toCreateMap());
  }

  /// تحديث بيانات شركة موجودة (الكود لا يتغيّر بهذه العملية).
  Future<void> updateCompany(Company company) {
    return _companiesRef.doc(company.code.trim()).update(company.toUpdateMap());
  }

  /// تغيير كود شركة: ينشئ مستنداً جديداً بالكود الجديد ويحذف القديم معاً (batch).
  Future<void> changeCompanyCode({
    required String oldCode,
    required Company companyWithNewCode,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _companiesRef.doc(companyWithNewCode.code.trim()),
      companyWithNewCode.toCreateMap(),
    );
    batch.delete(_companiesRef.doc(oldCode.trim()));
    await batch.commit();
  }

  Future<void> setActive(String code, bool isActive) {
    return _companiesRef.doc(code.trim()).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renewSubscription(String code, DateTime newExpiryDate) {
    return _companiesRef.doc(code.trim()).update({
      'expiryDate': Timestamp.fromDate(newExpiryDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCompany(String code) {
    return _companiesRef.doc(code.trim()).delete();
  }

  /// يستورد قائمة شركات من بيانات JSON (قائمة من كائنات `Map`).
  ///
  /// يتجاهل أي حقل لا يطابق المخطط (مثل `companyKeyOld`)، ويستبدل
  /// `expiryDate` بقيمة [fallbackExpiry] عندما يتعذّر تفسير القيمة
  /// الموجودة بالـ JSON (placeholder).
  Future<ImportResult> importFromJsonList(
    List<dynamic> rawList, {
    required DateTime fallbackExpiry,
  }) async {
    final imported = <String>[];
    final errors = <String>[];

    for (final rawItem in rawList) {
      if (rawItem is! Map) {
        errors.add('عنصر غير صالح (ليس كائن JSON).');
        continue;
      }
      final map = Map<String, dynamic>.from(rawItem);
      final code = (map['code'] as String?)?.trim() ?? '';
      final name = (map['name'] as String?)?.trim() ?? '';
      if (code.isEmpty || name.isEmpty) {
        errors.add('عنصر بدون code أو name صالحين، تم تجاهله.');
        continue;
      }

      final firebaseMap = map['firebase'] as Map<String, dynamic>?;
      final company = Company(
        code: code,
        name: name,
        email: (map['email'] as String?)?.trim() ?? '',
        isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
        expiryDate: _parseDate(map['expiryDate']) ?? fallbackExpiry,
        createdAt: null,
        updatedAt: null,
        android: AndroidFirebaseConfig.fromMap(
          firebaseMap?['android'] as Map<String, dynamic>?,
        ),
        ios: IosFirebaseConfig.fromMap(
          firebaseMap?['ios'] as Map<String, dynamic>?,
        ),
      );

      try {
        await _companiesRef.doc(code).set(company.toCreateMap());
        imported.add(code);
      } catch (e) {
        errors.add('فشل استيراد "$code": $e');
      }
    }

    return ImportResult(imported: imported, errors: errors);
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      // افتراض أنه milliseconds since epoch.
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
