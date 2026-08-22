import 'dart:math';

/// يولّد كود شركة مبدئي بصيغة WH-XXX-0000 يمكن للمستخدم تعديله لاحقاً.
class CodeGenerator {
  CodeGenerator._();

  static final Random _random = Random();

  static String suggestCode(String companyName) {
    final letters = companyName
        .toUpperCase()
        .split('')
        .where((c) => RegExp(r'[A-Z]').hasMatch(c))
        .take(3)
        .join();

    final prefix = letters.padRight(3, 'X').substring(0, 3);
    final digits = (_random.nextInt(9000) + 1000).toString();
    return 'WH-$prefix-$digits';
  }
}
