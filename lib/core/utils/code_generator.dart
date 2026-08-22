/// صيغة كود الشركة التسلسلي الثابتة: CMP-0001, CMP-0002, ...
///
/// الكود الفعلي يُولَّد ذرّياً (atomically) داخل معاملة Firestore عند
/// الحفظ — راجع `CompaniesRepository.createCompanyWithAutoCode` — هذه
/// الدالة هنا هي فقط منطق التنسيق المشترك بين المعاينة بالواجهة وبين
/// التوليد الفعلي، لضمان تطابق الصيغة.
class CompanyCodeFormat {
  CompanyCodeFormat._();

  static const String prefix = 'CMP';
  static const int digits = 4;

  static String format(int sequenceNumber) =>
      '$prefix-${sequenceNumber.toString().padLeft(digits, '0')}';
}
