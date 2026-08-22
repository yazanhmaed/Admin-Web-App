import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'company_firebase_config.dart';

/// نموذج بيانات "الشركة" كما يُخزَّن بمجموعة (collection) `companies`.
///
/// معرّف المستند (document id) هو نفس قيمة [code] دائماً — لا يُستخدم
/// معرّف تلقائي من Firestore، حتى نضمن عدم تكرار الأكواد بنيوياً.
class Company extends Equatable {
  const Company({
    required this.code,
    required this.name,
    required this.email,
    required this.isActive,
    required this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
    required this.android,
    required this.ios,
  });

  final String code;
  final String name;
  final String email;
  final bool isActive;
  final DateTime expiryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final AndroidFirebaseConfig android;
  final IosFirebaseConfig ios;

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  /// هل الاشتراك سينتهي خلال 7 أيام أو أقل (وما زال غير منتهٍ فعلياً)؟
  bool get isExpiringSoon {
    if (isExpired) return false;
    final diff = expiryDate.difference(DateTime.now());
    return diff.inHours <= 24 * 7;
  }

  factory Company.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Company.fromMap(doc.id, data);
  }

  factory Company.fromMap(String code, Map<String, dynamic> data) {
    final firebaseMap = data['firebase'] as Map<String, dynamic>?;
    return Company(
      code: code,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      isActive: (data['isActive'] ?? true) as bool,
      expiryDate: _toDate(data['expiryDate']) ?? DateTime.now(),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
      android: AndroidFirebaseConfig.fromMap(
        firebaseMap?['android'] as Map<String, dynamic>?,
      ),
      ios: IosFirebaseConfig.fromMap(
        firebaseMap?['ios'] as Map<String, dynamic>?,
      ),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// يبني الخريطة التي تُكتب إلى Firestore عند الإنشاء (create).
  Map<String, dynamic> toCreateMap() => {
        'name': name.trim(),
        'code': code.trim(),
        'email': email.trim(),
        'isActive': isActive,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'firebase': {
          'android': android.toMap(),
          'ios': ios.toMap(),
        },
      };

  /// يبني الخريطة التي تُكتب إلى Firestore عند التعديل (update) — يحافظ على createdAt.
  Map<String, dynamic> toUpdateMap() => {
        'name': name.trim(),
        'code': code.trim(),
        'email': email.trim(),
        'isActive': isActive,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'updatedAt': FieldValue.serverTimestamp(),
        'firebase': {
          'android': android.toMap(),
          'ios': ios.toMap(),
        },
      };

  Company copyWith({
    String? code,
    String? name,
    String? email,
    bool? isActive,
    DateTime? expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    AndroidFirebaseConfig? android,
    IosFirebaseConfig? ios,
  }) {
    return Company(
      code: code ?? this.code,
      name: name ?? this.name,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      android: android ?? this.android,
      ios: ios ?? this.ios,
    );
  }

  @override
  List<Object?> get props => [
        code,
        name,
        email,
        isActive,
        expiryDate,
        createdAt,
        updatedAt,
        android,
        ios,
      ];
}
