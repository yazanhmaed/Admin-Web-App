import 'package:flutter_test/flutter_test.dart';

import 'package:admin_web_app/core/utils/validators.dart';
import 'package:admin_web_app/core/utils/code_generator.dart';
import 'package:admin_web_app/models/company_firebase_config.dart';
import 'package:admin_web_app/screens/widgets/firebase_config_import.dart';

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

  group('CompanyCodeFormat.abbreviate', () {
    test('takes initials of the first 3 words for multi-word names', () {
      expect(CompanyCodeFormat.abbreviate('Acme Trading Co'), 'ATC');
    });

    test('takes the first 3 letters of a single-word name', () {
      expect(CompanyCodeFormat.abbreviate('Acme'), 'ACM');
    });

    test('pads a short single-word name to 3 letters', () {
      expect(CompanyCodeFormat.abbreviate('Ab'), 'ABX');
    });

    test('falls back to CMP for names with no latin letters', () {
      expect(CompanyCodeFormat.abbreviate('شركة الأمل'), 'CMP');
    });

    test('falls back to CMP for an empty name', () {
      expect(CompanyCodeFormat.abbreviate(''), 'CMP');
    });
  });

  group('CompanyCodeFormat.format', () {
    test('pads sequence numbers to 3 digits', () {
      expect(CompanyCodeFormat.format('ACM', 1), 'ACM-001');
      expect(CompanyCodeFormat.format('ACM', 23), 'ACM-023');
    });

    test('does not truncate numbers wider than the padding', () {
      expect(CompanyCodeFormat.format('ACM', 1234), 'ACM-1234');
    });
  });

  group('AndroidFirebaseConfig.fromMap (file import parsing)', () {
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

  group('IosFirebaseConfig.fromMap (file import parsing)', () {
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

  group('parseGoogleServicesJson', () {
    const validJson = '''
    {
      "project_info": {
        "project_number": "618182289733",
        "project_id": "admin-warehouse-app",
        "storage_bucket": "admin-warehouse-app.appspot.com"
      },
      "client": [
        {
          "client_info": {
            "mobilesdk_app_id": "1:618182289733:android:abcdef123456",
            "android_client_info": { "package_name": "com.example.app" }
          },
          "api_key": [ { "current_key": "AIzaSyTestKey" } ]
        }
      ]
    }
    ''';

    test('extracts all five Android fields from a valid file', () {
      final result = parseGoogleServicesJson(validJson);
      expect(result['apiKey'], 'AIzaSyTestKey');
      expect(result['appId'], '1:618182289733:android:abcdef123456');
      expect(result['messagingSenderId'], '618182289733');
      expect(result['projectId'], 'admin-warehouse-app');
      expect(result['storageBucket'], 'admin-warehouse-app.appspot.com');
    });

    test('throws for corrupted (non-JSON) content', () {
      expect(() => parseGoogleServicesJson('not json'),
          throwsA(isA<FirebaseConfigParseException>()));
    });

    test('throws when project_info/client are missing', () {
      expect(() => parseGoogleServicesJson('{}'),
          throwsA(isA<FirebaseConfigParseException>()));
    });

    test('throws when required fields are missing', () {
      const missingApiKey = '''
      {
        "project_info": {
          "project_number": "1",
          "project_id": "p",
          "storage_bucket": "b"
        },
        "client": [ { "client_info": { "mobilesdk_app_id": "a" } } ]
      }
      ''';
      expect(() => parseGoogleServicesJson(missingApiKey),
          throwsA(isA<FirebaseConfigParseException>()));
    });
  });

  group('parseGoogleServiceInfoPlist', () {
    const validPlist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>AIzaSyTestKey</string>
	<key>GCM_SENDER_ID</key>
	<string>618182289733</string>
	<key>BUNDLE_ID</key>
	<string>com.example.app</string>
	<key>PROJECT_ID</key>
	<string>admin-warehouse-app</string>
	<key>STORAGE_BUCKET</key>
	<string>admin-warehouse-app.appspot.com</string>
	<key>GOOGLE_APP_ID</key>
	<string>1:618182289733:ios:abcdef123456</string>
	<key>IS_SIGNIN_ENABLED</key>
	<true/>
</dict>
</plist>''';

    test('extracts all six iOS fields from a valid file', () {
      final result = parseGoogleServiceInfoPlist(validPlist);
      expect(result['apiKey'], 'AIzaSyTestKey');
      expect(result['appId'], '1:618182289733:ios:abcdef123456');
      expect(result['messagingSenderId'], '618182289733');
      expect(result['projectId'], 'admin-warehouse-app');
      expect(result['storageBucket'], 'admin-warehouse-app.appspot.com');
      expect(result['iosBundleId'], 'com.example.app');
    });

    test('throws for corrupted (non-XML) content', () {
      expect(() => parseGoogleServiceInfoPlist('not xml'),
          throwsA(isA<FirebaseConfigParseException>()));
    });

    test('throws when required keys are missing', () {
      const missingKeys = '''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
	<key>API_KEY</key>
	<string>only-this-one</string>
</dict></plist>''';
      expect(() => parseGoogleServiceInfoPlist(missingKeys),
          throwsA(isA<FirebaseConfigParseException>()));
    });
  });
}
