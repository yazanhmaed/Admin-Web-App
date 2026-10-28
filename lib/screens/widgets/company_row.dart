import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/company_features.dart';
import '../../core/theme.dart';
import '../../data/companies_repository.dart';
import '../../models/company.dart';

const kCompanyRowColumns = <String, double>{
  'name': 260,
  'email': 220,
  'status': 110,
  'expiry': 150,
  'projectId': 180,
  'features': 240,
  'actions': 230,
};

double get kCompanyRowTotalWidth =>
    kCompanyRowColumns.values.fold(0.0, (a, b) => a + b) + 32;

class CompanyRowHeader extends StatelessWidget {
  const CompanyRowHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
              width: kCompanyRowColumns['name'],
              child: Text('اسم الشركة', style: style)),
          SizedBox(
              width: kCompanyRowColumns['email'],
              child: Text('البريد الإلكتروني', style: style)),
          SizedBox(
              width: kCompanyRowColumns['status'],
              child: Text('مفعّلة', style: style)),
          SizedBox(
              width: kCompanyRowColumns['expiry'],
              child: Text('تاريخ الانتهاء', style: style)),
          SizedBox(
              width: kCompanyRowColumns['projectId'],
              child: Text('Project ID (Android)', style: style)),
          SizedBox(
              width: kCompanyRowColumns['features'],
              child: Text('الميزات', style: style)),
          SizedBox(
              width: kCompanyRowColumns['actions'],
              child: Text('إجراءات', style: style)),
        ],
      ),
    );
  }
}

class CompanyRow extends StatelessWidget {
  const CompanyRow({
    super.key,
    required this.company,
    required this.onToggleActive,
    required this.onToggleFeature,
    required this.onEdit,
    required this.onRenew,
    required this.onDelete,
    required this.onDetails,
  });

  final Company company;
  final ValueChanged<bool> onToggleActive;
  final void Function(String key, bool enabled) onToggleFeature;
  final VoidCallback onEdit;
  final VoidCallback onRenew;
  final VoidCallback onDelete;
  final VoidCallback onDetails;

  Color? _expiryColor() {
    if (company.isExpired) return AppTheme.danger;
    if (company.isExpiringSoon) return AppTheme.warning;
    return null;
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: company.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ الكود "${company.code}"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final expiryColor = _expiryColor();

    return InkWell(
      onTap: onDetails,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: kCompanyRowColumns['name'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    company.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Tooltip(
                    message: 'انقر لنسخ الكود',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _copyCode(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            company.code,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: kCompanyRowColumns['email'],
              child: Text(company.email, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: kCompanyRowColumns['status'],
              child: Switch(
                value: company.isActive,
                onChanged: onToggleActive,
              ),
            ),
            SizedBox(
              width: kCompanyRowColumns['expiry'],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (expiryColor != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        company.isExpired
                            ? Icons.error_rounded
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: expiryColor,
                      ),
                    ),
                  Text(
                    dateFormat.format(company.expiryDate),
                    style: TextStyle(
                      color: expiryColor,
                      fontWeight: expiryColor != null ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: kCompanyRowColumns['projectId'],
              child: Text(
                company.android.projectId.isEmpty
                    ? '—'
                    : company.android.projectId,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            SizedBox(
              width: kCompanyRowColumns['features'],
              child: _FeaturesCell(
                company: company,
                onToggleFeature: onToggleFeature,
              ),
            ),
            SizedBox(
              width: kCompanyRowColumns['actions'],
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'تجديد الاشتراك',
                    icon: const Icon(Icons.autorenew_rounded, size: 20),
                    onPressed: onRenew,
                  ),
                  IconButton(
                    tooltip: 'تعديل',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: AppTheme.danger),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شارات (chips) للميزات المفعّلة + قائمة منبثقة لتبديل أي ميزة فوراً.
class _FeaturesCell extends StatelessWidget {
  const _FeaturesCell({required this.company, required this.onToggleFeature});

  final Company company;
  final void Function(String key, bool enabled) onToggleFeature;

  @override
  Widget build(BuildContext context) {
    final enabled =
        kCompanyFeatures.where((f) => company.isFeatureEnabled(f.key));
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final f in enabled)
                Tooltip(
                  message: f.description,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      f.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'تبديل الميزات',
          icon: Icon(Icons.tune_rounded, size: 18, color: Colors.grey.shade600),
          onSelected: (key) =>
              onToggleFeature(key, !company.isFeatureEnabled(key)),
          itemBuilder: (_) => [
            for (final f in kCompanyFeatures)
              CheckedPopupMenuItem<String>(
                value: f.key,
                checked: company.isFeatureEnabled(f.key),
                child: Text(f.label),
              ),
          ],
        ),
      ],
    );
  }
}

class ImportedResultSnackHelper {
  static void show(BuildContext context, ImportResult result) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'تم استيراد ${result.successCount} شركة'
          '${result.errorCount > 0 ? '، وفشل ${result.errorCount}' : ''}.',
        ),
        backgroundColor:
            result.errorCount > 0 ? AppTheme.warning : AppTheme.success,
      ),
    );
  }
}
