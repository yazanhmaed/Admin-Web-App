import 'dart:convert';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/company_firebase_config.dart';

/// نتيجة استيراد ناجحة: إعدادات Android (مطلوبة إن وُجدت بالملف) وiOS
/// (اختيارية) المستخرجة من ملف JSON.
class FirebaseImportData {
  const FirebaseImportData({this.android, this.ios});

  final AndroidFirebaseConfig? android;
  final IosFirebaseConfig? ios;
}

/// منطقة سحب وإفلات (أو استعراض) لملف JSON يحوي بيانات اتصال Firebase
/// الخاصة بشركة، لتعبئة حقول النموذج تلقائياً بدل الإدخال اليدوي.
///
/// شكل الملف المتوقع:
/// ```json
/// {
///   "android": {
///     "apiKey": "...", "appId": "...", "messagingSenderId": "...",
///     "projectId": "...", "storageBucket": "..."
///   },
///   "ios": {
///     "apiKey": "...", "appId": "...", "messagingSenderId": "...",
///     "projectId": "...", "storageBucket": "...", "iosBundleId": "..."
///   }
/// }
/// ```
/// قسم `ios` اختياري بالكامل. أي حقل إضافي غير معروف يُتجاهل.
class FirebaseImportDropZone extends StatefulWidget {
  const FirebaseImportDropZone({super.key, required this.onImported});

  final ValueChanged<FirebaseImportData> onImported;

  static const int maxFileSizeBytes = 2 * 1024 * 1024; // 2MB

  @override
  State<FirebaseImportDropZone> createState() =>
      _FirebaseImportDropZoneState();
}

class _FirebaseImportDropZoneState extends State<FirebaseImportDropZone> {
  bool _isDragging = false;
  bool _isLoading = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _handleBytes(String fileName, Uint8List bytes) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    if (!fileName.toLowerCase().endsWith('.json')) {
      _fail('صيغة الملف غير مدعومة. الرجاء رفع ملف JSON فقط.');
      return;
    }
    if (bytes.lengthInBytes > FirebaseImportDropZone.maxFileSizeBytes) {
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

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      _fail('الملف تالف أو ليس بصيغة JSON صحيحة.');
      return;
    }

    if (decoded is! Map) {
      _fail('شكل الملف غير متوافق: يجب أن يكون كائن JSON يحوي android/ios.');
      return;
    }

    final map = Map<String, dynamic>.from(decoded);
    final androidMap = map['android'];
    final iosMap = map['ios'];

    if (androidMap == null && iosMap == null) {
      _fail('الملف لا يحوي أي بيانات android أو ios معروفة.');
      return;
    }

    AndroidFirebaseConfig? android;
    if (androidMap is Map) {
      final config =
          AndroidFirebaseConfig.fromMap(Map<String, dynamic>.from(androidMap));
      if (!config.isComplete) {
        _fail('بيانات android بالملف ناقصة (يجب توفر كل الحقول الخمسة).');
        return;
      }
      android = config;
    } else if (androidMap != null) {
      _fail('حقل android بالملف يجب أن يكون كائناً وليس نصاً/قائمة.');
      return;
    }

    IosFirebaseConfig? ios;
    if (iosMap is Map) {
      final config =
          IosFirebaseConfig.fromMap(Map<String, dynamic>.from(iosMap));
      if (!config.isFullyEmpty && !config.isComplete) {
        _fail('بيانات ios بالملف ناقصة (يجب توفر كل الحقول الستة أو تركها فارغة).');
        return;
      }
      if (!config.isFullyEmpty) ios = config;
    } else if (iosMap != null) {
      _fail('حقل ios بالملف يجب أن يكون كائناً وليس نصاً/قائمة.');
      return;
    }

    widget.onImported(FirebaseImportData(android: android, ios: ios));
    setState(() {
      _isLoading = false;
      _statusIsError = false;
      _statusMessage = 'تم استيراد بيانات Firebase بنجاح من "$fileName". '
          'يمكنك مراجعة الحقول أدناه وتعديلها قبل الحفظ.';
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _statusIsError = true;
      _statusMessage = message;
    });
  }

  Future<void> _browse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _fail('تعذّر قراءة الملف المحدد.');
      return;
    }
    await _handleBytes(file.name, bytes);
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) return;
    final file = details.files.first;
    setState(() => _isDragging = false);
    final bytes = await file.readAsBytes();
    await _handleBytes(file.name, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _isDragging ? AppTheme.primary : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: _handleDrop,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: _isDragging
                  ? AppTheme.primary.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.4),
            ),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  )
                : Column(
                    children: [
                      Icon(Icons.upload_file_rounded,
                          size: 28, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text(
                        'اسحب ملف بيانات Firebase (JSON) هنا وأفلته',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _browse,
                        icon: const Icon(Icons.folder_open_outlined, size: 18),
                        label: const Text('استعراض ملف'),
                      ),
                    ],
                  ),
          ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _statusIsError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: _statusIsError ? AppTheme.danger : AppTheme.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _statusIsError ? AppTheme.danger : AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'شكل الملف المتوقع: كائن JSON بحقل "android" (مطلوب: apiKey, appId, '
          'messagingSenderId, projectId, storageBucket) وحقل "ios" اختياري '
          '(نفس الحقول + iosBundleId).',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
