import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme.dart';
import '../../data/companies_repository.dart';
import 'company_row.dart';

/// أداة استيراد لمرة واحدة: يلصق المستخدم نص JSON (قائمة شركات) فيتم
/// إنشاء مستند `companies/{code}` لكل عنصر، مع تجاهل أي حقل غير معروف
/// واستبدال `expiryDate` الوهمي بتاريخ حقيقي (سنة من الآن افتراضياً).
class ImportJsonDialog extends StatefulWidget {
  const ImportJsonDialog({super.key});

  @override
  State<ImportJsonDialog> createState() => _ImportJsonDialogState();
}

class _ImportJsonDialogState extends State<ImportJsonDialog> {
  final _textController = TextEditingController();
  bool _isImporting = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() => _error = null);
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'الصق نص JSON أولاً.');
      return;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (e) {
      setState(() => _error = 'نص JSON غير صالح: $e');
      return;
    }

    List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded['companies'] is List) {
      list = decoded['companies'] as List;
    } else {
      setState(() => _error = 'يجب أن يكون JSON عبارة عن قائمة شركات.');
      return;
    }

    setState(() => _isImporting = true);
    final repo = context.read<CompaniesRepository>();
    final result = await repo.importFromJsonList(
      list,
      fallbackExpiry: DateTime.now().add(const Duration(days: 365)),
    );

    if (!mounted) return;
    setState(() => _isImporting = false);
    Navigator.of(context).pop();
    ImportedResultSnackHelper.show(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('استيراد شركات من JSON',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'الصق قائمة JSON بنفس شكل مخطط الشركات. سيتم تجاهل أي حقل غير معروف، '
                'واستبدال قيم expiryDate الوهمية بتاريخ افتراضي (سنة من اليوم).',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: '[ { "name": "...", "code": "...", ... } ]',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.danger)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isImporting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isImporting ? null : _import,
                    child: _isImporting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Text('استيراد'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
