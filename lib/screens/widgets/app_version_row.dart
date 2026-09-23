import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/app_version.dart';

const kAppVersionRowColumns = <String, double>{
  'packageName': 280,
  'versionName': 110,
  'versionCode': 110,
  'notes': 130,
  'updatedAt': 150,
  'actions': 110,
};

double get kAppVersionRowTotalWidth =>
    kAppVersionRowColumns.values.fold(0.0, (a, b) => a + b) + 32;

class AppVersionRowHeader extends StatelessWidget {
  const AppVersionRowHeader({super.key});

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
          SizedBox(width: kAppVersionRowColumns['packageName'], child: Text('اسم الحزمة (Package Name)', style: style)),
          SizedBox(width: kAppVersionRowColumns['versionName'], child: Text('الإصدار', style: style)),
          SizedBox(width: kAppVersionRowColumns['versionCode'], child: Text('رمز الإصدار', style: style)),
          SizedBox(width: kAppVersionRowColumns['notes'], child: Text('ملاحظات الإصدار', style: style)),
          SizedBox(width: kAppVersionRowColumns['updatedAt'], child: Text('آخر تحديث', style: style)),
          SizedBox(width: kAppVersionRowColumns['actions'], child: Text('إجراءات', style: style)),
        ],
      ),
    );
  }
}

class AppVersionRow extends StatelessWidget {
  const AppVersionRow({
    super.key,
    required this.version,
    required this.onEdit,
    required this.onDelete,
  });

  final AppVersion version;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final hasNotes = version.releaseNotes.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: kAppVersionRowColumns['packageName'],
            child: Text(
              version.packageName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: kAppVersionRowColumns['versionName'],
            child: Text(version.latestVersionName),
          ),
          SizedBox(
            width: kAppVersionRowColumns['versionCode'],
            child: Text('${version.latestVersionCode}'),
          ),
          SizedBox(
            width: kAppVersionRowColumns['notes'],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasNotes
                      ? Icons.check_circle_outline_rounded
                      : Icons.remove_circle_outline_rounded,
                  size: 16,
                  color: hasNotes ? AppTheme.success : Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Text(hasNotes ? 'محدّدة' : 'بدون'),
              ],
            ),
          ),
          SizedBox(
            width: kAppVersionRowColumns['updatedAt'],
            child: Text(
              version.updatedAt != null
                  ? dateFormat.format(version.updatedAt!)
                  : '—',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          SizedBox(
            width: kAppVersionRowColumns['actions'],
            child: Row(
              children: [
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
    );
  }
}
