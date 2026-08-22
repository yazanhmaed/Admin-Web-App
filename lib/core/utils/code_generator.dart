/// منطق توليد كود الشركة: بادئة مشتقة من اسم الشركة + رقم تسلسلي مشترك.
///
/// مثال: "Acme Trading" → `ACM-001`. الرقم التسلسلي ذاته يُولَّد ذرّياً
/// (atomically) داخل معاملة Firestore عند الحفظ الفعلي — راجع
/// `CompaniesRepository.createCompanyWithAutoCode` — أما الدوال هنا فهي
/// منطق التنسيق/الاشتقاق المشترك بين المعاينة الفورية بالواجهة (أثناء
/// الكتابة) وبين التوليد النهائي، لضمان تطابق الصيغة.
class CompanyCodeFormat {
  CompanyCodeFormat._();

  /// البادئة الاحتياطية إن تعذّر اشتقاق أي حرف لاتيني من اسم الشركة
  /// (مثلاً اسم بالعربية بالكامل).
  static const String fallbackPrefix = 'CMP';

  static const int digits = 3;

  /// يشتق بادئة من 3 أحرف من اسم الشركة: الأحرف الأولى من كل كلمة إن كان
  /// الاسم أكثر من كلمة، أو أول 3 أحرف من الكلمة الوحيدة إن كانت كلمة واحدة.
  static String abbreviate(String companyName) {
    final words = companyName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return fallbackPrefix;

    final raw = words.length >= 2
        ? words.take(3).map((w) => w[0]).join()
        : words.first;

    final lettersOnly = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (lettersOnly.isEmpty) return fallbackPrefix;
    return lettersOnly.length >= 3
        ? lettersOnly.substring(0, 3)
        : lettersOnly.padRight(3, 'X');
  }

  static String format(String prefix, int sequenceNumber) =>
      '$prefix-${sequenceNumber.toString().padLeft(digits, '0')}';
}
