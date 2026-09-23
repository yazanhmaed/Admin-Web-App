import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// نموذج بيانات "إصدار التطبيق" كما يُخزَّن بمجموعة (collection) `appVersions`.
///
/// معرّف المستند (document id) هو نفس قيمة [packageName] دائماً — تطبيق
/// المخزن يقرأ هذا المستند مباشرة باسم الحزمة (applicationId) للتحقق من
/// وجود تحديث جديد.
class AppVersion extends Equatable {
  const AppVersion({
    required this.packageName,
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.apkDownloadUrl,
    required this.releaseNotes,
    required this.updatedAt,
  });

  final String packageName;
  final int latestVersionCode;
  final String latestVersionName;
  final String apkDownloadUrl;
  final String releaseNotes;
  final DateTime? updatedAt;

  factory AppVersion.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppVersion.fromMap(doc.id, data);
  }

  factory AppVersion.fromMap(String packageName, Map<String, dynamic> data) {
    return AppVersion(
      packageName: packageName,
      latestVersionCode: (data['latestVersionCode'] as num?)?.toInt() ?? 0,
      latestVersionName: (data['latestVersionName'] ?? '') as String,
      apkDownloadUrl: (data['apkDownloadUrl'] ?? '') as String,
      releaseNotes: (data['releaseNotes'] ?? '') as String,
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// يبني الخريطة التي تُكتب إلى Firestore (إنشاء أو استبدال كامل للمستند).
  Map<String, dynamic> toMap() => {
        'latestVersionCode': latestVersionCode,
        'latestVersionName': latestVersionName.trim(),
        'apkDownloadUrl': apkDownloadUrl,
        'releaseNotes': releaseNotes.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  AppVersion copyWith({
    String? packageName,
    int? latestVersionCode,
    String? latestVersionName,
    String? apkDownloadUrl,
    String? releaseNotes,
    DateTime? updatedAt,
  }) {
    return AppVersion(
      packageName: packageName ?? this.packageName,
      latestVersionCode: latestVersionCode ?? this.latestVersionCode,
      latestVersionName: latestVersionName ?? this.latestVersionName,
      apkDownloadUrl: apkDownloadUrl ?? this.apkDownloadUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        packageName,
        latestVersionCode,
        latestVersionName,
        apkDownloadUrl,
        releaseNotes,
        updatedAt,
      ];
}
