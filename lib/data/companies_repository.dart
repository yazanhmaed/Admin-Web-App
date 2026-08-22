import 'package:cloud_firestore/cloud_firestore.dart';

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
