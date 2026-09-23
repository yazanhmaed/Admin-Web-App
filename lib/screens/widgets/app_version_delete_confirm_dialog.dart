import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/app_version.dart';

class AppVersionDeleteConfirmDialog extends StatelessWidget {
  const AppVersionDeleteConfirmDialog({super.key, required this.version});

  final AppVersion version;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: Text(
        'هل أنت متأكد من حذف إصدار حزمة "${version.packageName}" '
        '(v${version.latestVersionName} / ${version.latestVersionCode})؟\n'
        'لا يمكن التراجع عن هذا الإجراء.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('حذف'),
        ),
      ],
    );
  }
}
