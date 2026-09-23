import 'dart:developer';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/web_error_unwrap.dart';
import '../../data/app_versions_repository.dart';
import '../../models/app_version.dart';

/// نموذج إضافة/تعديل إصدار تطبيق. عند تمرير [existingVersion] يعمل بوضع
/// التعديل (اسم الحزمة غير قابل للتغيير حينها، لأنه معرّف المستند).
///
/// رمز الإصدار (versionCode) واسم الإصدار (versionName) حقول يدوية بالكامل
/// — لا يوجد أي استخراج تلقائي من ملف الـ APK عمداً، حتى يبقى القرار
/// بيد الإدمن بالكامل.
class AppVersionFormDialog extends StatefulWidget {
  const AppVersionFormDialog({
    super.key,
    this.existingVersion,
    required this.allVersions,
  });

  final AppVersion? existingVersion;

  /// كل إصدارات التطبيقات الحالية — تُستخدم لاقتراحات اسم الحزمة ولإيجاد
  /// القيمة الحالية المنشورة عند التحقق من تراجع رمز الإصدار.
  final List<AppVersion> allVersions;

  bool get isEditMode => existingVersion != null;

  @override
  State<AppVersionFormDialog> createState() => _AppVersionFormDialogState();
}

class _AppVersionFormDialogState extends State<AppVersionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _packageNameController;
  final _packageNameFocusNode = FocusNode();
  late final TextEditingController _versionCodeController;
  late final TextEditingController _versionNameController;
  late final TextEditingController _releaseNotesController;

  PlatformFile? _pickedFile;
  Uint8List? _pickedFileBytes;

  bool _isSaving = false;
  double? _uploadProgress;
  String? _saveError;
  String? _fileError;

  bool get _isEditMode => widget.isEditMode;

  @override
  void initState() {
    super.initState();
    final v = widget.existingVersion;
    _packageNameController = TextEditingController(text: v?.packageName ?? '');
    _versionCodeController =
        TextEditingController(text: v != null ? '${v.latestVersionCode}' : '');
    _versionNameController = TextEditingController(text: v?.latestVersionName ?? '');
    _releaseNotesController = TextEditingController(text: v?.releaseNotes ?? '');
  }

  @override
  void dispose() {
    _packageNameController.dispose();
    _packageNameFocusNode.dispose();
    _versionCodeController.dispose();
    _versionNameController.dispose();
    _releaseNotesController.dispose();
    super.dispose();
  }

  List<String> get _knownPackageNames =>
      widget.allVersions.map((v) => v.packageName).toSet().toList()..sort();

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
    if (file.bytes == null) {
      setState(() => _fileError = 'تعذّر قراءة الملف المحدد.');
      return;
    }
    setState(() {
      _pickedFile = file;
      _pickedFileBytes = file.bytes;
      _fileError = null;
    });
  }

  void _clearPickedFile() {
    setState(() {
      _pickedFile = null;
      _pickedFileBytes = null;
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
    setState(() {
      _saveError = null;
      _fileError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final packageName = _packageNameController.text.trim();
    final existingForPackage = _findExisting(packageName);
    final apkUrlFallback = existingForPackage?.apkDownloadUrl;

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
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
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
                        _buildPackageNameField(),
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 20),
                        _buildApkPicker(),
                        if (_fileError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _fileError!,
                            style: const TextStyle(
                                color: AppTheme.danger, fontSize: 12),
                          ),
                        ],
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
                      onPressed: _isSaving ? null : _submit,
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

  Widget _buildPackageNameField() {
    if (_isEditMode) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'اسم الحزمة (Package Name)',
          helperText: 'لا يمكن تعديله — هو معرّف المستند بقاعدة البيانات.',
          helperMaxLines: 2,
          filled: true,
          fillColor: Color(0xFFF1F5F9),
        ),
        child: Text(
          widget.existingVersion!.packageName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    return RawAutocomplete<String>(
      textEditingController: _packageNameController,
      focusNode: _packageNameFocusNode,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return _knownPackageNames;
        return _knownPackageNames
            .where((p) => p.toLowerCase().contains(query));
      },
      onSelected: (selection) => _packageNameController.text = selection,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'اسم الحزمة (Package Name) *',
            helperText:
                'مثال: com.example.warehouse — يمكن اختيار حزمة سابقة من القائمة أو كتابة واحدة جديدة.',
            helperMaxLines: 2,
          ),
          validator: Validators.packageName,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 592),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildApkPicker() {
    final existingUrl = widget.existingVersion?.apkDownloadUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('ملف الـ APK'),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isSaving ? null : _pickApk,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(
              _pickedFile == null ? 'اختيار ملف APK' : 'استبدال الملف المحدد'),
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
