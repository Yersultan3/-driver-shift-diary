import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import 'add_trip_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService api;
  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _date = DateTime.now();
  List<Trip> _trips = [];
  DaySummary? _summary;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await widget.api.getTrips(_date);
      final summary = await widget.api.getSummary(_date);
      setState(() {
        _trips = trips;
        _summary = summary;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _prevDay() {
    setState(() => _date = _date.subtract(const Duration(days: 1)));
    _fetch();
  }

  void _nextDay() {
    setState(() => _date = _date.add(const Duration(days: 1)));
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневник смен'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          _DateNav(date: _date, onPrev: _prevDay, onNext: _nextDay),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Ошибка: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_summary != null) _SummaryCard(summary: _summary!),
          Expanded(
            child: _trips.isEmpty && !_loading
                ? const Center(
                    child: Text(
                      'Нет поездок за этот день',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView.separated(
                      itemCount: _trips.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (_, i) => _TripTile(trip: _trips[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddTripScreen(api: widget.api, date: _date),
            ),
          );
          if (added == true) _fetch();
        },
        tooltip: 'Добавить поездку',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DateNav extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DateNav({required this.date, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEE, d MMM yyyy', 'ru').format(date);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DaySummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.##', 'ru_RU');
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сводка за день',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Row('Поездок', '${summary.tripsCount}'),
            _Row('Выручка', '₸ ${fmt.format(summary.totalAmount)}'),
            _Row(
              'Комиссия',
              '₸ ${fmt.format(summary.totalCommission)}',
              valueColor: Colors.red,
            ),
            _Row(
              'На руки',
              '₸ ${fmt.format(summary.netIncome)}',
              bold: true,
            ),
            const Divider(height: 16),
            _Row('Наличные', '₸ ${fmt.format(summary.cash)}'),
            _Row('Карта', '₸ ${fmt.format(summary.card)}'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _Row(this.label, this.value, {this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: bold ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final Trip trip;
  const _TripTile({required this.trip});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final moneyFmt = NumberFormat('#,##0.##', 'ru_RU');
    final isCash = trip.payment == 'cash';

    return ListTile(
      leading: SizedBox(
        width: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              timeFmt.format(trip.start),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Icon(Icons.arrow_downward, size: 10, color: Colors.grey),
            Text(timeFmt.format(trip.end), style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
      title: Text(
        '₸ ${moneyFmt.format(trip.amount)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('Комиссия: ₸ ${moneyFmt.format(trip.commission)}'),
      trailing: Chip(
        label: Text(
          isCash ? 'Нал' : 'Карта',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: isCash ? Colors.green.shade600 : Colors.indigo,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
