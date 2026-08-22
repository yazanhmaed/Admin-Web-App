import 'package:equatable/equatable.dart';

/// بيانات اتصال Firebase الخاصة بمنصة Android لشركة معيّنة.
class AndroidFirebaseConfig extends Equatable {
  const AndroidFirebaseConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.storageBucket,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String storageBucket;

  static const empty = AndroidFirebaseConfig(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
  );

  bool get isEmpty => this == empty;

  bool get isComplete =>
      apiKey.trim().isNotEmpty &&
      appId.trim().isNotEmpty &&
      messagingSenderId.trim().isNotEmpty &&
      projectId.trim().isNotEmpty &&
      storageBucket.trim().isNotEmpty;

  factory AndroidFirebaseConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return empty;
    return AndroidFirebaseConfig(
      apiKey: (map['apiKey'] ?? '') as String,
      appId: (map['appId'] ?? '') as String,
      messagingSenderId: (map['messagingSenderId'] ?? '') as String,
      projectId: (map['projectId'] ?? '') as String,
      storageBucket: (map['storageBucket'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'apiKey': apiKey.trim(),
        'appId': appId.trim(),
        'messagingSenderId': messagingSenderId.trim(),
        'projectId': projectId.trim(),
        'storageBucket': storageBucket.trim(),
      };

  AndroidFirebaseConfig copyWith({
    String? apiKey,
    String? appId,
    String? messagingSenderId,
    String? projectId,
    String? storageBucket,
  }) {
    return AndroidFirebaseConfig(
      apiKey: apiKey ?? this.apiKey,
      appId: appId ?? this.appId,
      messagingSenderId: messagingSenderId ?? this.messagingSenderId,
      projectId: projectId ?? this.projectId,
      storageBucket: storageBucket ?? this.storageBucket,
    );
  }

  @override
  List<Object?> get props =>
      [apiKey, appId, messagingSenderId, projectId, storageBucket];
}

/// بيانات اتصال Firebase الخاصة بمنصة iOS لشركة معيّنة (اختيارية بالكامل).
class IosFirebaseConfig extends Equatable {
  const IosFirebaseConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.storageBucket,
    required this.iosBundleId,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String storageBucket;
  final String iosBundleId;

  static const empty = IosFirebaseConfig(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
    iosBundleId: '',
  );

  bool get isEmpty => this == empty;

  /// هل كل الحقول فارغة؟ (يعني القسم لم يُعبَّأ إطلاقاً)
  bool get isFullyEmpty =>
      apiKey.trim().isEmpty &&
      appId.trim().isEmpty &&
      messagingSenderId.trim().isEmpty &&
      projectId.trim().isEmpty &&
      storageBucket.trim().isEmpty &&
      iosBundleId.trim().isEmpty;

  bool get isComplete =>
      apiKey.trim().isNotEmpty &&
      appId.trim().isNotEmpty &&
      messagingSenderId.trim().isNotEmpty &&
      projectId.trim().isNotEmpty &&
      storageBucket.trim().isNotEmpty &&
      iosBundleId.trim().isNotEmpty;

  factory IosFirebaseConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return empty;
    return IosFirebaseConfig(
      apiKey: (map['apiKey'] ?? '') as String,
      appId: (map['appId'] ?? '') as String,
      messagingSenderId: (map['messagingSenderId'] ?? '') as String,
      projectId: (map['projectId'] ?? '') as String,
      storageBucket: (map['storageBucket'] ?? '') as String,
      iosBundleId: (map['iosBundleId'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'apiKey': apiKey.trim(),
        'appId': appId.trim(),
        'messagingSenderId': messagingSenderId.trim(),
        'projectId': projectId.trim(),
        'storageBucket': storageBucket.trim(),
        'iosBundleId': iosBundleId.trim(),
      };

  IosFirebaseConfig copyWith({
    String? apiKey,
    String? appId,
    String? messagingSenderId,
    String? projectId,
    String? storageBucket,
    String? iosBundleId,
  }) {
    return IosFirebaseConfig(
      apiKey: apiKey ?? this.apiKey,
      appId: appId ?? this.appId,
      messagingSenderId: messagingSenderId ?? this.messagingSenderId,
      projectId: projectId ?? this.projectId,
      storageBucket: storageBucket ?? this.storageBucket,
      iosBundleId: iosBundleId ?? this.iosBundleId,
    );
  }

  @override
  List<Object?> get props => [
        apiKey,
        appId,
        messagingSenderId,
        projectId,
        storageBucket,
        iosBundleId,
      ];
}
