import 'dart:developer';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/utils/apk_manifest_parser.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/web_error_unwrap.dart';
import '../../data/app_versions_repository.dart';
import '../../models/app_version.dart';

/// نموذج إضافة/تعديل إصدار تطبيق. عند تمرير [existingVersion] يعمل بوضع
/// التعديل (اسم الحزمة غير قابل للتغيير حينها، لأنه معرّف المستند).
///
/// اسم الحزمة (Package Name) **لا يُكتب يدوياً إطلاقاً**: يُستخرج تلقائياً
/// من ملف الـ APK المختار فور اختياره (عبر قراءة AndroidManifest.xml
/// الثنائي داخل الملف وتحليل سمة `package`)، ويُعرض للإدمن كحقل للقراءة
/// فقط للتأكيد قبل الحفظ — راجع [extractPackageNameFromApk]. فشل
/// الاستخراج يمنع الحفظ كلياً ولا يوجد أي رجوع لإدخال يدوي.
///
/// رمز الإصدار (versionCode) واسم الإصدار (versionName) حقول يدوية بالكامل
/// — لا يوجد أي استخراج تلقائي لهما من ملف الـ APK عمداً، حتى يبقى القرار
/// بيد الإدمن بالكامل.
class AppVersionFormDialog extends StatefulWidget {
  const AppVersionFormDialog({
    super.key,
    this.existingVersion,
    required this.allVersions,
  });

  final AppVersion? existingVersion;

  /// كل إصدارات التطبيقات الحالية — تُستخدم لإيجاد القيمة الحالية المنشورة
  /// عند التحقق من تراجع رمز الإصدار (وربط رابط APK الحالي عند عدم اختيار
  /// ملف جديد بوضع التعديل).
  final List<AppVersion> allVersions;

  bool get isEditMode => existingVersion != null;

  @override
  State<AppVersionFormDialog> createState() => _AppVersionFormDialogState();
}

class _AppVersionFormDialogState extends State<AppVersionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _versionCodeController;
  late final TextEditingController _versionNameController;
  late final TextEditingController _releaseNotesController;

  PlatformFile? _pickedFile;
  Uint8List? _pickedFileBytes;

  /// اسم الحزمة المُستخرَج تلقائياً من آخر ملف APK تم اختياره بنجاح.
  String? _detectedPackageName;

  bool _isParsingFile = false;
  bool _isSaving = false;
  double? _uploadProgress;
  String? _saveError;
  String? _fileError;

  bool get _isEditMode => widget.isEditMode;

  /// هل الملف المختار حالياً (إن وُجد) يطابق حزمة المستند قيد التعديل؟
  /// بوضع الإضافة لا يوجد "تعارض" أصلاً — اسم الحزمة يُشتق من الملف مباشرة.
  bool get _hasPackageMismatch =>
      _isEditMode &&
      _detectedPackageName != null &&
      _detectedPackageName != widget.existingVersion!.packageName;

  @override
  void initState() {
    super.initState();
    final v = widget.existingVersion;
    _versionCodeController =
        TextEditingController(text: v != null ? '${v.latestVersionCode}' : '');
    _versionNameController = TextEditingController(text: v?.latestVersionName ?? '');
    _releaseNotesController = TextEditingController(text: v?.releaseNotes ?? '');
  }

  @override
  void dispose() {
    _versionCodeController.dispose();
    _versionNameController.dispose();
    _releaseNotesController.dispose();
    super.dispose();
  }

  AppVersion? _findExisting(String packageName) {
    final trimmed = packageName.trim();
    for (final v in widget.allVersions) {
      if (v.packageName == trimmed) return v;
    }
    return null;
  }

  Future<void> _pickApk() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['apk'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    setState(() {
      _fileError = null;
      _isParsingFile = true;
    });

    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _isParsingFile = false;
        _fileError = 'تعذّر قراءة الملف المحدد.';
      });
      return;
    }

    try {
      // فك الضغط وتحليل AndroidManifest.xml الثنائي عملية سريعة بالذاكرة
      // (لا تحتاج isolate منفصل)، لكنها قد تستغرق لحظة لملفات كبيرة.
      final detected = extractPackageNameFromApk(bytes);
      if (!mounted) return;
      setState(() {
        _pickedFile = file;
        _pickedFileBytes = bytes;
        _detectedPackageName = detected;
        _isParsingFile = false;
      });
    } on ApkManifestParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isParsingFile = false;
        _pickedFile = null;
        _pickedFileBytes = null;
        _detectedPackageName = null;
        _fileError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isParsingFile = false;
        _pickedFile = null;
        _pickedFileBytes = null;
        _detectedPackageName = null;
        _fileError = 'تعذّر تحليل ملف الـ APK: $e';
      });
    }
  }

  void _clearPickedFile() {
    setState(() {
      _pickedFile = null;
      _pickedFileBytes = null;
      _detectedPackageName = null;
      _fileError = null;
    });
  }

  String _formatSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<bool> _confirmDowngradeIfNeeded(String packageName, int newCode) async {
    final existing = _findExisting(packageName);
    if (existing == null || newCode > existing.latestVersionCode) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تنبيه: رمز إصدار غير تصاعدي'),
        content: Text(
          'رمز الإصدار الجديد ($newCode) أقل من أو يساوي رمز الإصدار '
          'المنشور حالياً لهذه الحزمة (${existing.latestVersionCode}).\n'
          'هل أنت متأكد أنك تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('متابعة رغم ذلك'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _submit() async {
    setState(() => _saveError = null);
    if (!_formKey.currentState!.validate()) return;

    if (_hasPackageMismatch) {
      setState(() => _fileError =
          'اسم الحزمة المستخرج من الملف المختار لا يطابق حزمة هذا الإصدار — لا يمكن الحفظ بهذا الملف.');
      return;
    }

    final packageName = _isEditMode
        ? widget.existingVersion!.packageName
        : _detectedPackageName;

    if (packageName == null || packageName.isEmpty) {
      setState(() => _fileError =
          'الرجاء اختيار ملف APK صالح ليتم تحديد اسم الحزمة تلقائياً.');
      return;
    }

    final apkUrlFallback = _findExisting(packageName)?.apkDownloadUrl;
    if (_pickedFileBytes == null &&
        (apkUrlFallback == null || apkUrlFallback.isEmpty)) {
      setState(() => _fileError = 'الرجاء اختيار ملف APK.');
      return;
    }

    final versionCode = int.parse(_versionCodeController.text.trim());

    final proceed = await _confirmDowngradeIfNeeded(packageName, versionCode);
    if (!proceed) return;
    if (!mounted) return;

    setState(() => _isSaving = true);

    final repo = context.read<AppVersionsRepository>();
    try {
      String apkUrl;
      if (_pickedFileBytes != null) {
        setState(() => _uploadProgress = 0);
        apkUrl = await repo.uploadApk(
          packageName: packageName,
          versionCode: versionCode,
          bytes: _pickedFileBytes!,
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _uploadProgress = p);
          },
        );
      } else {
        apkUrl = apkUrlFallback!;
      }

      final version = AppVersion(
        packageName: packageName,
        latestVersionCode: versionCode,
        latestVersionName: _versionNameController.text.trim(),
        apkDownloadUrl: apkUrl,
        releaseNotes: _releaseNotesController.text,
        updatedAt: null,
      );
      await repo.saveVersion(version);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      final realError = unwrapWebError(e);
      log('save failed: $realError');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _uploadProgress = null;
        _saveError = 'تعذّر الحفظ: $realError';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditMode ? 'تعديل إصدار تطبيق' : 'إضافة إصدار جديد',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildApkPicker(),
                        const SizedBox(height: 14),
                        _buildPackageNameDisplay(),
                        if (_fileError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _fileError!,
                            style: const TextStyle(
                                color: AppTheme.danger, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _versionCodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'رمز الإصدار (versionCode) *',
                            helperText: 'رقم صحيح، يفضَّل أن يكون أكبر من السابق. مثال: 15',
                          ),
                          validator: (v) =>
                              Validators.positiveInteger(v, label: 'رمز الإصدار'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _versionNameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الإصدار (versionName) *',
                            helperText: 'مثال: 1.5.0',
                          ),
                          validator: (v) =>
                              Validators.requiredField(v, label: 'اسم الإصدار'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _releaseNotesController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات الإصدار (اختياري)',
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (_saveError != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _saveError!,
                              style: const TextStyle(color: AppTheme.danger),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed:
                          (_isSaving || _isParsingFile || _hasPackageMismatch)
                              ? null
                              : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Text('حفظ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// حقل عرض اسم الحزمة — للقراءة فقط دائماً. بوضع التعديل يعرض حزمة
  /// المستند الثابتة، وبوضع الإضافة يعرض القيمة المُستخرَجة من آخر ملف APK
  /// ناجح (أو تلميحاً بانتظار اختيار ملف).
  Widget _buildPackageNameDisplay() {
    final packageName =
        _isEditMode ? widget.existingVersion!.packageName : _detectedPackageName;
    final mismatch = _hasPackageMismatch;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'اسم الحزمة (Package Name)',
        helperText: _isEditMode
            ? 'لا يمكن تعديله — هو معرّف المستند بقاعدة البيانات.'
            : 'يُستخرج تلقائياً من ملف الـ APK فور اختياره — لا يمكن كتابته يدوياً.',
        helperMaxLines: 2,
        filled: true,
        fillColor: mismatch
            ? AppTheme.danger.withValues(alpha: 0.06)
            : const Color(0xFFF1F5F9),
      ),
      child: Row(
        children: [
          Icon(
            mismatch
                ? Icons.error_outline_rounded
                : (packageName != null
                    ? Icons.check_circle_outline_rounded
                    : Icons.hourglass_empty_rounded),
            size: 16,
            color: mismatch
                ? AppTheme.danger
                : (packageName != null ? AppTheme.success : Colors.grey.shade500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              packageName ?? 'بانتظار اختيار ملف APK...',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: packageName == null ? Colors.grey.shade500 : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApkPicker() {
    final existingUrl = widget.existingVersion?.apkDownloadUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('ملف الـ APK'),
        const SizedBox(height: 6),
        Text(
          _isEditMode
              ? 'استبدال الملف اختياري — إن اخترت ملفاً جديداً يجب أن يكون لنفس الحزمة.'
              : 'اختر ملف الـ APK أولاً — سيُستخرج منه اسم الحزمة تلقائياً.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: (_isSaving || _isParsingFile) ? null : _pickApk,
          icon: _isParsingFile
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(
            _isParsingFile
                ? 'جارِ تحليل الملف...'
                : (_pickedFile == null
                    ? 'اختيار ملف APK'
                    : 'استبدال الملف المحدد'),
          ),
        ),
        const SizedBox(height: 8),
        if (_pickedFile != null)
          Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_pickedFile!.name} (${_formatSize(_pickedFile!.size)})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'إلغاء الاختيار',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: _isSaving ? null : _clearPickedFile,
              ),
            ],
          )
        else if (existingUrl != null && existingUrl.isNotEmpty)
          Text(
            'لن يتغيّر ملف الـ APK الحالي إذا لم تختر ملفاً جديداً.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          )
        else
          Text(
            'لم يتم اختيار ملف بعد.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        if (_uploadProgress != null) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
              value: _uploadProgress == 0 ? null : _uploadProgress),
          const SizedBox(height: 4),
          Text(
            'جارِ الرفع... ${((_uploadProgress ?? 0) * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
