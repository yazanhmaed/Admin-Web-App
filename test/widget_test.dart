import 'package:flutter_test/flutter_test.dart';

import 'package:admin_web_app/core/utils/validators.dart';
import 'package:admin_web_app/core/utils/code_generator.dart';

void main() {
  group('Validators', () {
    test('accepts a valid email', () {
      expect(Validators.isValidEmail('test@example.com'), isTrue);
    });

    test('rejects an invalid email', () {
      expect(Validators.isValidEmail('not-an-email'), isFalse);
    });

    test('email() returns error message for empty input', () {
      expect(Validators.email(''), isNotNull);
    });

    test('email() returns null for a valid email', () {
      expect(Validators.email('admin@warehouse.app'), isNull);
    });
  });

  group('CodeGenerator', () {
    test('suggestCode produces WH-XXX-#### format', () {
      final code = CodeGenerator.suggestCode('Acme Trading');
      expect(code, matches(RegExp(r'^WH-[A-Z]{3}-\d{4}$')));
    });

    test('suggestCode pads short/non-english names', () {
      final code = CodeGenerator.suggestCode('شركة');
      expect(code, matches(RegExp(r'^WH-[A-Z]{3}-\d{4}$')));
    });
  });
}
