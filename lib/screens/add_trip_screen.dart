import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../services/api_service.dart';

class AddTripScreen extends StatefulWidget {
  final ApiService api;
  final DateTime date;

  const AddTripScreen({super.key, required this.api, required this.date});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _start;
  late DateTime _end;
  final _amountCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  String _payment = 'card';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final d = widget.date;
    _start = DateTime(d.year, d.month, d.day, 9, 0);
    _end = DateTime(d.year, d.month, d.day, 9, 30);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
    });
  }

  void _onAmountChanged(String raw) {
    final amount = double.tryParse(raw);
    if (amount != null && amount > 0) {
      _commissionCtrl.text = (amount * 0.15).round().toString();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Время окончания должно быть позже начала'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final trip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      start: _start,
      end: _end,
      amount: double.parse(_amountCtrl.text),
      payment: _payment,
      commission: double.parse(_commissionCtrl.text),
    );

    setState(() => _submitting = true);
    try {
      await widget.api.addTrip(trip);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dtFmt = DateFormat('dd.MM.yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая поездка'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DateTimeTile(
              label: 'Начало',
              value: dtFmt.format(_start),
              onTap: () => _pickDateTime(isStart: true),
            ),
            const SizedBox(height: 8),
            _DateTimeTile(
              label: 'Конец',
              value: dtFmt.format(_end),
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Сумма (₸)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: _onAmountChanged,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Введите сумму больше 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _payment,
              decoration: const InputDecoration(
                labelText: 'Способ оплаты',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'card', child: Text('Карта')),
                DropdownMenuItem(value: 'cash', child: Text('Наличные')),
              ],
              onChanged: (v) => setState(() => _payment = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _commissionCtrl,
              decoration: const InputDecoration(
                labelText: 'Комиссия (₸)',
                border: OutlineInputBorder(),
                helperText: 'Авто: 15% от суммы',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0) return 'Введите корректную комиссию';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Добавить поездку'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.access_time),
      onTap: onTap,
    );
  }
}
