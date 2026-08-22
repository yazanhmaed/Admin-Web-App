import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/companies_repository.dart';
import '../../models/company.dart';

const kCompanyRowColumns = <String, double>{
  'name': 200,
  'email': 220,
  'status': 110,
  'expiry': 150,
  'projectId': 180,
  'code': 150,
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
          SizedBox(width: kCompanyRowColumns['name'], child: Text('اسم الشركة', style: style)),
          SizedBox(width: kCompanyRowColumns['email'], child: Text('البريد الإلكتروني', style: style)),
          SizedBox(width: kCompanyRowColumns['status'], child: Text('مفعّلة', style: style)),
          SizedBox(width: kCompanyRowColumns['expiry'], child: Text('تاريخ الانتهاء', style: style)),
          SizedBox(width: kCompanyRowColumns['projectId'], child: Text('Project ID (Android)', style: style)),
          SizedBox(width: kCompanyRowColumns['code'], child: Text('الكود', style: style)),
          SizedBox(width: kCompanyRowColumns['actions'], child: Text('إجراءات', style: style)),
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
    required this.onEdit,
    required this.onRenew,
    required this.onDelete,
    required this.onDetails,
  });

  final Company company;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onRenew;
  final VoidCallback onDelete;
  final VoidCallback onDetails;

  Color? _expiryColor() {
    if (company.isExpired) return AppTheme.danger;
    if (company.isExpiringSoon) return AppTheme.warning;
    return null;
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
              child: Text(
                company.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
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
                      fontWeight:
                          expiryColor != null ? FontWeight.w700 : null,
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
              width: kCompanyRowColumns['code'],
              child: SelectableText(company.code),
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
