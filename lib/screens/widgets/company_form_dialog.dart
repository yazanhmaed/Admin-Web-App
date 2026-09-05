import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/utils/code_generator.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/web_error_unwrap.dart';
import '../../data/companies_repository.dart';
import '../../models/company.dart';
import '../../models/company_firebase_config.dart';
import 'firebase_config_import.dart';

/// نموذج إضافة/تعديل شركة. عند تمرير [existingCompany] يعمل بوضع التعديل
/// (الكود غير قابل للتغيير حينها).
///
/// كود الشركة يُولَّد بالكامل تلقائياً (بادئة من اسم الشركة + رقم تسلسلي،
/// مثال: ACM-001) ولا يمكن إدخاله أو تعديله يدوياً — راجع
/// [CompaniesRepository.createCompanyWithAutoCode].
class CompanyFormDialog extends StatefulWidget {
  const CompanyFormDialog({super.key, this.existingCompany});

  final Company? existingCompany;

  bool get isEditMode => existingCompany != null;

  @override
  State<CompanyFormDialog> createState() => _CompanyFormDialogState();
}

class _CompanyFormDialogState extends State<CompanyFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  late final TextEditingController _androidApiKey;
  late final TextEditingController _androidAppId;
  late final TextEditingController _androidSenderId;
  late final TextEditingController _androidProjectId;
  late final TextEditingController _androidStorageBucket;

  late final TextEditingController _iosApiKey;
  late final TextEditingController _iosAppId;
  late final TextEditingController _iosSenderId;
  late final TextEditingController _iosProjectId;
  late final TextEditingController _iosStorageBucket;
  late final TextEditingController _iosBundleId;

  late DateTime _expiryDate;
  late bool _isActive;

  /// كود الشركة: بوضع التعديل هو كود الشركة الحالي (ثابت). بوضع الإضافة
  /// نعرض معاينة حيّة تتحدّث مع كل تغيير باسم الشركة (البادئة تُشتق من
  /// الاسم فوراً محلياً)، بينما الرقم التسلسلي [_previewNextNumber] يُجلب
  /// مرة واحدة عند فتح النموذج. المصدر النهائي الحقيقي للكود يُولَّد
  /// ذرّياً داخل معاملة Firestore عند الحفظ الفعلي.
  int? _previewNextNumber;
  bool _isLoadingPreviewCode = false;
  String? get _fixedCode => _isEditMode ? widget.existingCompany!.code : null;

  String? get _previewCode {
    if (_isEditMode) return _fixedCode;
    if (_previewNextNumber == null) return null;
    final prefix = CompanyCodeFormat.abbreviate(_nameController.text);
    return CompanyCodeFormat.format(prefix, _previewNextNumber!);
  }

  bool _isSaving = false;
  String? _saveError;

  bool get _isEditMode => widget.isEditMode;

  @override
  void initState() {
    super.initState();
    final company = widget.existingCompany;

    _nameController = TextEditingController(text: company?.name ?? '');
    _emailController = TextEditingController(text: company?.email ?? '');

    _androidApiKey = TextEditingController(text: company?.android.apiKey ?? '');
    _androidAppId = TextEditingController(text: company?.android.appId ?? '');
    _androidSenderId =
        TextEditingController(text: company?.android.messagingSenderId ?? '');
    _androidProjectId =
        TextEditingController(text: company?.android.projectId ?? '');
    _androidStorageBucket =
        TextEditingController(text: company?.android.storageBucket ?? '');

    _iosApiKey = TextEditingController(text: company?.ios.apiKey ?? '');
    _iosAppId = TextEditingController(text: company?.ios.appId ?? '');
    _iosSenderId =
        TextEditingController(text: company?.ios.messagingSenderId ?? '');
    _iosProjectId = TextEditingController(text: company?.ios.projectId ?? '');
    _iosStorageBucket =
        TextEditingController(text: company?.ios.storageBucket ?? '');
    _iosBundleId = TextEditingController(text: company?.ios.iosBundleId ?? '');

    _expiryDate =
        company?.expiryDate ?? DateTime.now().add(const Duration(days: 365));
    _isActive = company?.isActive ?? true;

    if (!_isEditMode) {
      // البادئة تتحدّث تلقائياً مع كل تغيير بالاسم (معاينة محلية فورية).
      _nameController.addListener(_onNameChangedForPreview);
      _loadPreviewNumber();
    }
  }

  void _onNameChangedForPreview() => setState(() {});

  Future<void> _loadPreviewNumber() async {
    setState(() => _isLoadingPreviewCode = true);
    try {
      final repo = context.read<CompaniesRepository>();
      final next = await repo.previewNextNumber();
      if (!mounted) return;
      setState(() {
        _previewNextNumber = next;
        _isLoadingPreviewCode = false;
      });
    } catch (e) {
      log('previewNextNumber failed: ${unwrapWebError(e)}');
      if (!mounted) return;
      setState(() => _isLoadingPreviewCode = false);
    }
  }

  @override
  void dispose() {
    if (!_isEditMode) {
      _nameController.removeListener(_onNameChangedForPreview);
    }
    _nameController.dispose();
    _emailController.dispose();
    _androidApiKey.dispose();
    _androidAppId.dispose();
    _androidSenderId.dispose();
    _androidProjectId.dispose();
    _androidStorageBucket.dispose();
    _iosApiKey.dispose();
    _iosAppId.dispose();
    _iosSenderId.dispose();
    _iosProjectId.dispose();
    _iosStorageBucket.dispose();
    _iosBundleId.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  void _applyAndroidExtracted(Map<String, String> fields) {
    setState(() {
      _androidApiKey.text = fields['apiKey'] ?? '';
      _androidAppId.text = fields['appId'] ?? '';
      _androidSenderId.text = fields['messagingSenderId'] ?? '';
      _androidProjectId.text = fields['projectId'] ?? '';
      _androidStorageBucket.text = fields['storageBucket'] ?? '';
    });
  }

  void _applyIosExtracted(Map<String, String> fields) {
    setState(() {
      _iosApiKey.text = fields['apiKey'] ?? '';
      _iosAppId.text = fields['appId'] ?? '';
      _iosSenderId.text = fields['messagingSenderId'] ?? '';
      _iosProjectId.text = fields['projectId'] ?? '';
      _iosStorageBucket.text = fields['storageBucket'] ?? '';
      _iosBundleId.text = fields['iosBundleId'] ?? '';
    });
  }

  bool get _iosSectionTouched =>
      _iosApiKey.text.trim().isNotEmpty ||
      _iosAppId.text.trim().isNotEmpty ||
      _iosSenderId.text.trim().isNotEmpty ||
      _iosProjectId.text.trim().isNotEmpty ||
      _iosStorageBucket.text.trim().isNotEmpty ||
      _iosBundleId.text.trim().isNotEmpty;

  String? _iosConditionalValidator(String? value, String label) {
    if (!_iosSectionTouched) return null;
    if ((value ?? '').trim().isEmpty) {
      return '$label مطلوب عند تعبئة أي حقل بقسم iOS';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _saveError = null);
    if (!_formKey.currentState!.validate()) return;

    if (!_isEditMode && _isLoadingPreviewCode) {
      setState(() => _saveError = 'الرجاء الانتظار حتى يتم توليد الكود.');
      return;
    }

    setState(() => _isSaving = true);

    final android = AndroidFirebaseConfig(
      apiKey: _androidApiKey.text,
      appId: _androidAppId.text,
      messagingSenderId: _androidSenderId.text,
      projectId: _androidProjectId.text,
      storageBucket: _androidStorageBucket.text,
    );

    final ios = _iosSectionTouched
        ? IosFirebaseConfig(
            apiKey: _iosApiKey.text,
            appId: _iosAppId.text,
            messagingSenderId: _iosSenderId.text,
            projectId: _iosProjectId.text,
            storageBucket: _iosStorageBucket.text,
            iosBundleId: _iosBundleId.text,
          )
        : IosFirebaseConfig.empty;

    final repo = context.read<CompaniesRepository>();
    try {
      if (_isEditMode) {
        final company = Company(
          code: widget.existingCompany!.code,
          name: _nameController.text,
          email: _emailController.text,
          isActive: _isActive,
          expiryDate: _expiryDate,
          createdAt: widget.existingCompany?.createdAt,
          updatedAt: widget.existingCompany?.updatedAt,
          android: android,
          ios: ios,
        );
        await repo.updateCompany(company);
      } else {
        await repo.createCompanyWithAutoCode(
          _nameController.text,
          (code) => Company(
            code: code,
            name: _nameController.text,
            email: _emailController.text,
            isActive: _isActive,
            expiryDate: _expiryDate,
            createdAt: null,
            updatedAt: null,
            android: android,
            ios: ios,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      final realError = unwrapWebError(e);
      log('save failed: $realError');
      setState(() {
        _isSaving = false;
        _saveError = 'تعذّر الحفظ: $realError';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

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
                  _isEditMode ? 'تعديل بيانات الشركة' : 'إضافة شركة جديدة',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration:
                              const InputDecoration(labelText: 'اسم الشركة *'),
                          validator: (v) =>
                              Validators.requiredField(v, label: 'اسم الشركة'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                              labelText: 'إيميل الشركة *'),
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 14),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'الكود (يُولَّد تلقائياً)',
                            helperText: _isEditMode
                                ? 'كود ثابت لا يمكن تعديله. لتغييره، أنشئ شركة جديدة واحذف هذه.'
                                : 'بادئة من اسم الشركة + رقم تسلسلي. يتحدّث مع الاسم، ويتولّد نهائياً عند الحفظ.',
                            helperMaxLines: 2,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                          child: Row(
                            children: [
                              if (_isLoadingPreviewCode) ...[
                                const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 10),
                                const Text('جارِ توليد الكود...'),
                              ] else
                                Text(
                                  _previewCode ?? '—',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: _pickExpiryDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'تاريخ الانتهاء *'),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(dateFormat.format(_expiryDate)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('مفعّلة'),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                        const SizedBox(height: 20),
                        _SectionTitle('بيانات Firebase - Android'),
                        const SizedBox(height: 10),
                        FirebaseConfigFilePicker(
                          buttonLabel: 'استيراد من ملف google-services.json',
                          allowedExtensions: const ['json'],
                          parse: parseGoogleServicesJson,
                          onExtracted: _applyAndroidExtracted,
                        ),
                        const SizedBox(height: 12),
                        _buildFieldGrid([
                          TextFormField(
                            controller: _androidApiKey,
                            decoration:
                                const InputDecoration(labelText: 'apiKey *'),
                            validator: (v) =>
                                Validators.requiredField(v, label: 'apiKey'),
                          ),
                          TextFormField(
                            controller: _androidAppId,
                            decoration:
                                const InputDecoration(labelText: 'appId *'),
                            validator: (v) =>
                                Validators.requiredField(v, label: 'appId'),
                          ),
                          TextFormField(
                            controller: _androidSenderId,
                            decoration: const InputDecoration(
                                labelText: 'messagingSenderId *'),
                            validator: (v) => Validators.requiredField(v,
                                label: 'messagingSenderId'),
                          ),
                          TextFormField(
                            controller: _androidProjectId,
                            decoration:
                                const InputDecoration(labelText: 'projectId *'),
                            validator: (v) =>
                                Validators.requiredField(v, label: 'projectId'),
                          ),
                          TextFormField(
                            controller: _androidStorageBucket,
                            decoration: const InputDecoration(
                                labelText: 'storageBucket *'),
                            validator: (v) => Validators.requiredField(v,
                                label: 'storageBucket'),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _SectionTitle('بيانات Firebase - iOS (اختياري)'),
                        const SizedBox(height: 10),
                        FirebaseConfigFilePicker(
                          buttonLabel:
                              'استيراد من ملف GoogleService-Info.plist',
                          allowedExtensions: const ['plist'],
                          parse: parseGoogleServiceInfoPlist,
                          onExtracted: _applyIosExtracted,
                        ),
                        const SizedBox(height: 12),
                        _buildFieldGrid([
                          TextFormField(
                            controller: _iosApiKey,
                            onChanged: (_) => setState(() {}),
                            decoration:
                                const InputDecoration(labelText: 'apiKey'),
                            validator: (v) =>
                                _iosConditionalValidator(v, 'apiKey'),
                          ),
                          TextFormField(
                            controller: _iosAppId,
                            onChanged: (_) => setState(() {}),
                            decoration:
                                const InputDecoration(labelText: 'appId'),
                            validator: (v) =>
                                _iosConditionalValidator(v, 'appId'),
                          ),
                          TextFormField(
                            controller: _iosSenderId,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                                labelText: 'messagingSenderId'),
                            validator: (v) => _iosConditionalValidator(
                                v, 'messagingSenderId'),
                          ),
                          TextFormField(
                            controller: _iosProjectId,
                            onChanged: (_) => setState(() {}),
                            decoration:
                                const InputDecoration(labelText: 'projectId'),
                            validator: (v) =>
                                _iosConditionalValidator(v, 'projectId'),
                          ),
                          TextFormField(
                            controller: _iosStorageBucket,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                                labelText: 'storageBucket'),
                            validator: (v) =>
                                _iosConditionalValidator(v, 'storageBucket'),
                          ),
                          TextFormField(
                            controller: _iosBundleId,
                            onChanged: (_) => setState(() {}),
                            decoration:
                                const InputDecoration(labelText: 'iosBundleId'),
                            validator: (v) =>
                                _iosConditionalValidator(v, 'iosBundleId'),
                          ),
                        ]),
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

  Widget _buildFieldGrid(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 480;
        if (!isWide) {
          return Column(
            children: [
              for (final f in fields)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: f),
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final f in fields)
              SizedBox(width: (constraints.maxWidth - 12) / 2, child: f),
          ],
        );
      },
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
