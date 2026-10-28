/// تعريف ميزة واحدة يمكن تفعيلها/تعطيلها لكل شركة على حدة.
///
/// تُخزَّن القيم بمستند الشركة تحت الحقل `features.<key>` (قيم bool فقط).
/// غياب الحقل أو المفتاح = معطّلة.
class FeatureDef {
  const FeatureDef({
    required this.key,
    required this.label,
    required this.description,
  });

  /// المفتاح كما يُخزَّن بـ Firestore ويقرأه تطبيق المخزن.
  final String key;
  final String label;
  final String description;
}

/// سجلّ الميزات (المصدر الوحيد). لإضافة ميزة جديدة أضف سطراً هنا فقط —
/// نموذج الإضافة/التعديل وقائمة الشركات يُولَّدان من هذه القائمة تلقائياً.
const kCompanyFeatures = <FeatureDef>[
  FeatureDef(
    key: 'itemImages',
    label: 'صور الأصناف',
    description: 'إضافة صورة لكل صنف (يتطلب Firebase Blaze لدى الشركة)',
  ),
  FeatureDef(
    key: 'parcelsCount',
    label: 'عدد الطرود',
    description: 'حقل عدد الطرود عند إغلاق فاتورة البيع',
  ),
  FeatureDef(
    key: 'scanStep',
    label: 'عدد القطع عند البيع',
    description: 'حقل في كل صنف يحدد عدد القطع التي تُضاف للفاتورة مع كل مسح',
  ),
];

/// يقرأ خريطة الميزات بشكل متسامح: أي قيمة غير bool تُتجاهل، وأي نوع غير
/// خريطة يُعامل كخريطة فارغة. المفاتيح غير الموجودة بالسجلّ تُحفظ كما هي.
Map<String, bool> parseFeaturesMap(dynamic raw) {
  if (raw is! Map) return const {};
  final result = <String, bool>{};
  raw.forEach((key, value) {
    if (key is String && value is bool) result[key] = value;
  });
  return Map.unmodifiable(result);
}
