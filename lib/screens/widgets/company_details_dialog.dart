import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/company.dart';

class CompanyDetailsDialog extends StatelessWidget {
  const CompanyDetailsDialog({super.key, required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd  HH:mm');

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      company.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (company.isActive
                              ? AppTheme.success
                              : Colors.grey)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      company.isActive ? 'مفعّلة' : 'غير مفعّلة',
                      style: TextStyle(
                        color:
                            company.isActive ? AppTheme.success : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoRow('الكود', company.code),
                      _InfoRow('البريد الإلكتروني', company.email),
                      _InfoRow(
                        'تاريخ الانتهاء',
                        DateFormat('yyyy-MM-dd').format(company.expiryDate),
                        valueColor: company.isExpired
                            ? AppTheme.danger
                            : (company.isExpiringSoon
                                ? AppTheme.warning
                                : null),
                      ),
                      if (company.createdAt != null)
                        _InfoRow('تاريخ الإنشاء', dateFormat.format(company.createdAt!)),
                      if (company.updatedAt != null)
                        _InfoRow('آخر تعديل', dateFormat.format(company.updatedAt!)),
                      const SizedBox(height: 16),
                      _SectionTitle('بيانات Firebase - Android'),
                      const SizedBox(height: 8),
                      _FirebaseConfigTable(entries: {
                        'apiKey': company.android.apiKey,
                        'appId': company.android.appId,
                        'messagingSenderId': company.android.messagingSenderId,
                        'projectId': company.android.projectId,
                        'storageBucket': company.android.storageBucket,
                      }),
                      const SizedBox(height: 16),
                      _SectionTitle('بيانات Firebase - iOS'),
                      const SizedBox(height: 8),
                      company.ios.isFullyEmpty
                          ? Text('لا توجد بيانات iOS بعد.',
                              style: TextStyle(color: Colors.grey.shade600))
                          : _FirebaseConfigTable(entries: {
                              'apiKey': company.ios.apiKey,
                              'appId': company.ios.appId,
                              'messagingSenderId':
                                  company.ios.messagingSenderId,
                              'projectId': company.ios.projectId,
                              'storageBucket': company.ios.storageBucket,
                              'iosBundleId': company.ios.iosBundleId,
                            }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
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

class _FirebaseConfigTable extends StatelessWidget {
  const _FirebaseConfigTable({required this.entries});
  final Map<String, String> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (final entry in entries.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: Text(entry.key,
                        style: const TextStyle(fontFamily: 'monospace')),
                  ),
                  Expanded(
                    child: SelectableText(
                      entry.value.isEmpty ? '—' : entry.value,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
