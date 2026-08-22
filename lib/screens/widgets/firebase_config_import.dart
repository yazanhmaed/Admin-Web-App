import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../core/theme.dart';

/// خطأ تحليل ملف إعدادات Firebase (JSON أو plist) برسالة عربية واضحة.
class FirebaseConfigParseException implements Exception {
  FirebaseConfigParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

const int kFirebaseConfigMaxFileSizeBytes = 2 * 1024 * 1024; // 2MB

/// يحلّل ملف `google-services.json` (Android) ويستخرج الحقول المطلوبة:
/// apiKey, appId, messagingSenderId, projectId, storageBucket.
///
/// يأخذ أول عنصر بمصفوفة `client` — وهو الشائع لمعظم المشاريع (تطبيق
/// أندرويد واحد لكل مشروع Firebase).
Map<String, String> parseGoogleServicesJson(String content) {
  dynamic decoded;
  try {
    decoded = jsonDecode(content);
  } catch (_) {
    throw FirebaseConfigParseException('الملف تالف أو ليس بصيغة JSON صحيحة.');
  }
  if (decoded is! Map) {
    throw FirebaseConfigParseException(
        'شكل الملف غير متوافق مع google-services.json.');
  }
  final map = Map<String, dynamic>.from(decoded);
  final projectInfo = map['project_info'];
  final clients = map['client'];
  if (projectInfo is! Map || clients is! List || clients.isEmpty) {
    throw FirebaseConfigParseException(
        'الملف لا يحتوي على project_info أو client — تأكد أنه ملف google-services.json صحيح.');
  }
  final firstClient = clients.first;
  if (firstClient is! Map) {
    throw FirebaseConfigParseException('بنية client داخل الملف غير صحيحة.');
  }

  final clientInfo = firstClient['client_info'];
  final apiKeyList = firstClient['api_key'];
  final appId =
      clientInfo is Map ? clientInfo['mobilesdk_app_id']?.toString() : null;
  final apiKey = (apiKeyList is List &&
          apiKeyList.isNotEmpty &&
          apiKeyList.first is Map)
      ? (apiKeyList.first as Map)['current_key']?.toString()
      : null;

  final result = <String, String>{
    'apiKey': apiKey ?? '',
    'appId': appId ?? '',
    'messagingSenderId': projectInfo['project_number']?.toString() ?? '',
    'projectId': projectInfo['project_id']?.toString() ?? '',
    'storageBucket': projectInfo['storage_bucket']?.toString() ?? '',
  };

  _throwIfMissing(result);
  return result;
}

/// يحلّل ملف `GoogleService-Info.plist` (iOS، صيغة XML) ويستخرج الحقول
/// المطلوبة: apiKey, appId, messagingSenderId, projectId, storageBucket,
/// iosBundleId.
Map<String, String> parseGoogleServiceInfoPlist(String content) {
  XmlDocument doc;
  try {
    doc = XmlDocument.parse(content);
  } catch (_) {
    throw FirebaseConfigParseException('الملف تالف أو ليس بصيغة XML/plist صحيحة.');
  }

  final dictElements = doc.findAllElements('dict');
  if (dictElements.isEmpty) {
    throw FirebaseConfigParseException(
        'شكل الملف غير متوافق مع GoogleService-Info.plist.');
  }

  final entries = <String, String>{};
  final children = dictElements.first.childElements.toList();
  for (var i = 0; i < children.length - 1; i++) {
    if (children[i].name.local != 'key') continue;
    final keyName = children[i].innerText.trim();
    final valueEl = children[i + 1];
    entries[keyName] = valueEl.name.local == 'true'
        ? 'true'
        : valueEl.name.local == 'false'
            ? 'false'
            : valueEl.innerText.trim();
  }

  final result = <String, String>{
    'apiKey': entries['API_KEY'] ?? '',
    'appId': entries['GOOGLE_APP_ID'] ?? '',
    'messagingSenderId': entries['GCM_SENDER_ID'] ?? '',
    'projectId': entries['PROJECT_ID'] ?? '',
    'storageBucket': entries['STORAGE_BUCKET'] ?? '',
    'iosBundleId': entries['BUNDLE_ID'] ?? '',
  };

  _throwIfMissing(result);
  return result;
}

void _throwIfMissing(Map<String, String> result) {
  final missing =
      result.entries.where((e) => e.value.isEmpty).map((e) => e.key).toList();
  if (missing.isNotEmpty) {
    throw FirebaseConfigParseException('حقول ناقصة بالملف: ${missing.join('، ')}.');
  }
}

/// زر استعراض لملف إعدادات Firebase (google-services.json أو
/// GoogleService-Info.plist)، يقرأ الملف ويحلّله ويستخرج الحقول تلقائياً
/// دون أي إدخال يدوي، مع إمكانية مراجعة/تعديل القيم بعدها بحقول النموذج.
class FirebaseConfigFilePicker extends StatefulWidget {
  const FirebaseConfigFilePicker({
    super.key,
    required this.buttonLabel,
    required this.allowedExtensions,
    required this.parse,
    required this.onExtracted,
  });

  final String buttonLabel;
  final List<String> allowedExtensions;
  final Map<String, String> Function(String content) parse;
  final ValueChanged<Map<String, String>> onExtracted;

  @override
  State<FirebaseConfigFilePicker> createState() =>
      _FirebaseConfigFilePickerState();
}

class _FirebaseConfigFilePickerState extends State<FirebaseConfigFilePicker> {
  bool _isLoading = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      _fail('تعذّر قراءة الملف المحدد.');
      return;
    }
    if (bytes.lengthInBytes > kFirebaseConfigMaxFileSizeBytes) {
      _fail('حجم الملف كبير جداً (الحد الأقصى 2MB).');
      return;
    }

    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      _fail('تعذّرت قراءة الملف — الترميز غير مدعوم.');
      return;
    }

    try {
      final extracted = widget.parse(text);
      widget.onExtracted(extracted);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusIsError = false;
        _statusMessage = 'تم استيراد الملف "${file.name}" بنجاح.';
      });
    } on FirebaseConfigParseException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('حدث خطأ غير متوقع أثناء معالجة الملف: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _statusIsError = true;
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _pick,
          icon: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_open_outlined, size: 18),
          label: Text(_isLoading ? 'جارٍ المعالجة...' : widget.buttonLabel),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _statusIsError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 15,
                color: _statusIsError ? AppTheme.danger : AppTheme.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusIsError ? AppTheme.danger : AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
