class Trip {
  final String id;
  final DateTime start;
  final DateTime end;
  final double amount;
  final String payment;
  final double commission;

  const Trip({
    required this.id,
    required this.start,
    required this.end,
    required this.amount,
    required this.payment,
    required this.commission,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        amount: (json['amount'] as num).toDouble(),
        payment: json['payment'] as String,
        commission: (json['commission'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'amount': amount,
        'payment': payment,
        'commission': commission,
      };
}

class DaySummary {
  final String date;
  final int tripsCount;
  final double totalAmount;
  final double totalCommission;
  final double netIncome;
  final double cash;
  final double card;

  const DaySummary({
    required this.date,
    required this.tripsCount,
    required this.totalAmount,
    required this.totalCommission,
    required this.netIncome,
    required this.cash,
    required this.card,
  });

  factory DaySummary.fromJson(Map<String, dynamic> json) => DaySummary(
        date: json['date'] as String,
        tripsCount: json['trips_count'] as int,
        totalAmount: (json['total_amount'] as num).toDouble(),
        totalCommission: (json['total_commission'] as num).toDouble(),
        netIncome: (json['net_income'] as num).toDouble(),
        cash: (json['cash'] as num).toDouble(),
        card: (json['card'] as num).toDouble(),
      );

  factory DaySummary.fromTrips(List<Trip> trips, String date) {
    double total = 0, commission = 0, cash = 0, card = 0;
    for (final t in trips) {
      total += t.amount;
      commission += t.commission;
      if (t.payment == 'cash') {
        cash += t.amount;
      } else {
        card += t.amount;
      }
    }
    return DaySummary(
      date: date,
      tripsCount: trips.length,
      totalAmount: total,
      totalCommission: commission,
      netIncome: total - commission,
      cash: cash,
      card: card,
    );
  }

  static DaySummary empty(String date) => DaySummary(
        date: date,
        tripsCount: 0,
        totalAmount: 0,
        totalCommission: 0,
        netIncome: 0,
        cash: 0,
        card: 0,
      );
}
