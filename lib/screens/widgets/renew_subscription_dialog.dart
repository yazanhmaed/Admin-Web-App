import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../data/companies_repository.dart';
import '../../models/company.dart';

class RenewSubscriptionDialog extends StatefulWidget {
  const RenewSubscriptionDialog({super.key, required this.company});

  final Company company;

  @override
  State<RenewSubscriptionDialog> createState() =>
      _RenewSubscriptionDialogState();
}

enum _RenewOption { days30, days90, days365, custom }

class _RenewSubscriptionDialogState extends State<RenewSubscriptionDialog> {
  _RenewOption _selected = _RenewOption.days30;
  late DateTime _customDate;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final base = widget.company.expiryDate.isAfter(DateTime.now())
        ? widget.company.expiryDate
        : DateTime.now();
    _customDate = base.add(const Duration(days: 30));
  }

  DateTime get _baseDate {
    final current = widget.company.expiryDate;
    return current.isAfter(DateTime.now()) ? current : DateTime.now();
  }

  DateTime get _resultDate {
    switch (_selected) {
      case _RenewOption.days30:
        return _baseDate.add(const Duration(days: 30));
      case _RenewOption.days90:
        return _baseDate.add(const Duration(days: 90));
      case _RenewOption.days365:
        return _baseDate.add(const Duration(days: 365));
      case _RenewOption.custom:
        return _customDate;
    }
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _customDate = picked;
        _selected = _RenewOption.custom;
      });
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await context
          .read<CompaniesRepository>()
          .renewSubscription(widget.company.code, _resultDate);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = 'تعذّر تجديد الاشتراك: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return AlertDialog(
      title: Text('تجديد اشتراك "${widget.company.name}"'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('تاريخ الانتهاء الحالي: ${dateFormat.format(widget.company.expiryDate)}'),
            const SizedBox(height: 12),
            RadioGroup<_RenewOption>(
              groupValue: _selected,
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selected = v);
                if (v == _RenewOption.custom) _pickCustomDate();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RadioListTile<_RenewOption>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('+30 يوم'),
                    value: _RenewOption.days30,
                  ),
                  const RadioListTile<_RenewOption>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('+90 يوم'),
                    value: _RenewOption.days90,
                  ),
                  const RadioListTile<_RenewOption>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('+365 يوم'),
                    value: _RenewOption.days365,
                  ),
                  RadioListTile<_RenewOption>(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        const Text('تاريخ مخصص: '),
                        TextButton(
                          onPressed: _pickCustomDate,
                          child: Text(dateFormat.format(_customDate)),
                        ),
                      ],
                    ),
                    value: _RenewOption.custom,
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Text(
              'تاريخ الانتهاء الجديد: ${dateFormat.format(_resultDate)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _confirm,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('تجديد'),
        ),
      ],
    );
  }
}
