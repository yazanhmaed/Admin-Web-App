import 'package:flutter_test/flutter_test.dart';

import 'package:admin_web_app/core/utils/validators.dart';
import 'package:admin_web_app/core/utils/code_generator.dart';
import 'package:admin_web_app/models/company_firebase_config.dart';

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

  group('CompanyCodeFormat', () {
    test('pads sequence numbers to 4 digits with CMP- prefix', () {
      expect(CompanyCodeFormat.format(1), 'CMP-0001');
      expect(CompanyCodeFormat.format(23), 'CMP-0023');
      expect(CompanyCodeFormat.format(4567), 'CMP-4567');
    });

    test('does not truncate numbers wider than the padding', () {
      expect(CompanyCodeFormat.format(12345), 'CMP-12345');
    });
  });

  group('AndroidFirebaseConfig.fromMap (drag & drop import parsing)', () {
    test('parses a complete map as complete', () {
      final config = AndroidFirebaseConfig.fromMap({
        'apiKey': 'a',
        'appId': 'b',
        'messagingSenderId': 'c',
        'projectId': 'd',
        'storageBucket': 'e',
      });
      expect(config.isComplete, isTrue);
    });

    test('flags a partial map as incomplete', () {
      final config = AndroidFirebaseConfig.fromMap({'apiKey': 'a'});
      expect(config.isComplete, isFalse);
    });
  });

  group('IosFirebaseConfig.fromMap (drag & drop import parsing)', () {
    test('an empty map is fully empty, not incomplete', () {
      final config = IosFirebaseConfig.fromMap(null);
      expect(config.isFullyEmpty, isTrue);
      expect(config.isComplete, isFalse);
    });

    test('a partial map is neither fully empty nor complete', () {
      final config = IosFirebaseConfig.fromMap({'apiKey': 'a'});
      expect(config.isFullyEmpty, isFalse);
      expect(config.isComplete, isFalse);
    });
  });
}
