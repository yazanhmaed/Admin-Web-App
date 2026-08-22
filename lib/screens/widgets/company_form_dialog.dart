import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/utils/code_generator.dart';
import '../../core/utils/validators.dart';
import '../../data/companies_repository.dart';
import '../../models/company.dart';
import '../../models/company_firebase_config.dart';

enum _CodeCheckStatus { idle, checking, available, taken }

/// نموذج إضافة/تعديل شركة. عند تمرير [existingCompany] يعمل بوضع التعديل
/// (الكود غير قابل للتغيير حينها).
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
  late final TextEditingController _codeController;

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

  bool _codeManuallyEdited = false;
  Timer? _debounce;
  _CodeCheckStatus _codeCheckStatus = _CodeCheckStatus.idle;
  bool _isSaving = false;
  String? _saveError;

  bool get _isEditMode => widget.isEditMode;

  @override
  void initState() {
    super.initState();
    final company = widget.existingCompany;

    _nameController = TextEditingController(text: company?.name ?? '');
    _emailController = TextEditingController(text: company?.email ?? '');
    _codeController = TextEditingController(text: company?.code ?? '');

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

    if (_isEditMode) {
      _codeCheckStatus = _CodeCheckStatus.idle;
    } else {
      _nameController.addListener(_onNameChanged);
      _codeController.addListener(_onCodeChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
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

  void _onNameChanged() {
    if (_codeManuallyEdited || _isEditMode) return;
    final suggested = CodeGenerator.suggestCode(_nameController.text);
    _codeController.removeListener(_onCodeChanged);
    _codeController.text = suggested;
    _codeController.addListener(_onCodeChanged);
    _scheduleCodeCheck();
  }

  void _onCodeChanged() {
    _codeManuallyEdited = true;
    _scheduleCodeCheck();
  }

  void _scheduleCodeCheck() {
    _debounce?.cancel();
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeCheckStatus = _CodeCheckStatus.idle);
      return;
    }
    setState(() => _codeCheckStatus = _CodeCheckStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final repo = context.read<CompaniesRepository>();
      final exists = await repo.codeExists(code);
      if (!mounted || _codeController.text.trim() != code) return;
      setState(() {
        _codeCheckStatus =
            exists ? _CodeCheckStatus.taken : _CodeCheckStatus.available;
      });
    });
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

    final code = _codeController.text.trim();

    if (!_isEditMode) {
      if (_codeCheckStatus == _CodeCheckStatus.checking) {
        setState(() => _saveError = 'الرجاء الانتظار حتى ينتهي فحص الكود.');
        return;
      }
      setState(() => _codeCheckStatus = _CodeCheckStatus.checking);
      final repo = context.read<CompaniesRepository>();
      final exists = await repo.codeExists(code);
      if (exists) {
        setState(() {
          _codeCheckStatus = _CodeCheckStatus.taken;
          _saveError = 'هذا الكود مستخدم بالفعل، الرجاء اختيار كود آخر.';
        });
        return;
      }
      if (!mounted) return;
      setState(() => _codeCheckStatus = _CodeCheckStatus.available);
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

    final company = Company(
      code: code,
      name: _nameController.text,
      email: _emailController.text,
      isActive: _isActive,
      expiryDate: _expiryDate,
      createdAt: widget.existingCompany?.createdAt,
      updatedAt: widget.existingCompany?.updatedAt,
      android: android,
      ios: ios,
    );

    final repo = context.read<CompaniesRepository>();
    try {
      if (_isEditMode) {
        await repo.updateCompany(company);
      } else {
        await repo.createCompany(company);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isSaving = false;
        _saveError = 'تعذّر الحفظ: $e';
      });
    }
  }

  Widget _codeSuffixIcon() {
    switch (_codeCheckStatus) {
      case _CodeCheckStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _CodeCheckStatus.available:
        return const Icon(Icons.check_circle_rounded, color: AppTheme.success);
      case _CodeCheckStatus.taken:
        return const Icon(Icons.cancel_rounded, color: AppTheme.danger);
      case _CodeCheckStatus.idle:
        return const SizedBox.shrink();
    }
  }

  String? _codeHelperText() {
    switch (_codeCheckStatus) {
      case _CodeCheckStatus.available:
        return 'الكود متاح ✅';
      case _CodeCheckStatus.taken:
        return 'الكود مستخدم بالفعل ❌';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
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
                        TextFormField(
                          controller: _codeController,
                          enabled: !_isEditMode,
                          decoration: InputDecoration(
                            labelText: 'الكود *',
                            helperText: _isEditMode
                                ? 'لا يمكن تعديل الكود بعد الإنشاء. لتغييره، أنشئ شركة جديدة واحذف هذه.'
                                : (_codeHelperText() ??
                                    'صيغة مقترحة: WH-XXX-0000'),
                            helperMaxLines: 2,
                            suffixIcon:
                                _isEditMode ? null : _codeSuffixIcon(),
                          ),
                          validator: Validators.code,
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: _pickExpiryDate,
                          child: InputDecorator(
                            decoration:
                                const InputDecoration(labelText: 'تاريخ الانتهاء *'),
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
                        const SizedBox(height: 12),
                        _SectionTitle('بيانات Firebase - Android'),
                        const SizedBox(height: 10),
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
                            decoration: const InputDecoration(
                                labelText: 'projectId *'),
                            validator: (v) => Validators.requiredField(v,
                                label: 'projectId'),
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
                            decoration: const InputDecoration(
                                labelText: 'projectId'),
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
                            decoration: const InputDecoration(
                                labelText: 'iosBundleId'),
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
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
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
