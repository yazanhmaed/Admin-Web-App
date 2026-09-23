class Validators {
  Validators._();

  static final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String value) => _emailRegExp.hasMatch(value.trim());

  static String? requiredField(String? value, {String label = 'هذا الحقل'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label مطلوب';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = requiredField(value, label: 'البريد الإلكتروني');
    if (requiredError != null) return requiredError;
    if (!isValidEmail(value!)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    return null;
  }

  /// صيغة الكود المقترحة: WH-XXX-0000 (حروف/أرقام، شرطات مسموحة).
  static final RegExp _codeRegExp = RegExp(r'^[A-Za-z0-9\-]{3,}$');

  static String? code(String? value) {
    final requiredError = requiredField(value, label: 'كود الشركة');
    if (requiredError != null) return requiredError;
    if (!_codeRegExp.hasMatch(value!.trim())) {
      return 'الكود يجب أن يحتوي أحرف/أرقام/شرطات فقط (3 أحرف على الأقل)';
    }
    return null;
  }

  /// صيغة اسم حزمة أندرويد (applicationId)، مثال: com.example.app.
  static final RegExp _packageNameRegExp =
      RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$');

  static String? packageName(String? value) {
    final requiredError = requiredField(value, label: 'اسم الحزمة');
    if (requiredError != null) return requiredError;
    if (!_packageNameRegExp.hasMatch(value!.trim())) {
      return 'صيغة اسم الحزمة غير صحيحة (مثال: com.example.app)';
    }
    return null;
  }

  static String? positiveInteger(String? value, {String label = 'القيمة'}) {
    final requiredError = requiredField(value, label: label);
    if (requiredError != null) return requiredError;
    final n = int.tryParse(value!.trim());
    if (n == null || n <= 0) {
      return '$label يجب أن يكون رقماً صحيحاً موجباً';
    }
    return null;
  }
}
