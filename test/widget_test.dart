import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:arqa_project/models/trip.dart';
import 'package:arqa_project/services/api_service.dart';

// ── In-memory mock HTTP client ────────────────────────────────────────────────

class _MockClient extends http.BaseClient {
  final Map<String, String> _store = {};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' && request.url.path == '/trips') {
      final body = (request as http.Request).body;
      final trip = jsonDecode(body) as Map<String, dynamic>;
      final id = trip['id'] as String;
      if (_store.containsKey(id)) {
        return _resp(409, jsonEncode({'detail': 'duplicate trip id'}));
      }
      _store[id] = body;
      return _resp(201, body);
    }
    return _resp(404, '{}');
  }

  http.StreamedResponse _resp(int code, String body) => http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        code,
        headers: {'content-type': 'application/json'},
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Trip _trip(String id, {String payment = 'card'}) => Trip(
      id: id,
      start: DateTime(2026, 10, 1, 8, 10),
      end: DateTime(2026, 10, 1, 8, 32),
      amount: 2400,
      payment: payment,
      commission: 360,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('DaySummary.fromTrips — summary calculation', () {
    final trips = [
      _trip('t1', payment: 'card'),
      Trip(
        id: 't2',
        start: DateTime(2026, 10, 1, 9, 5),
        end: DateTime(2026, 10, 1, 9, 20),
        amount: 1500,
        payment: 'cash',
        commission: 225,
      ),
    ];

    test('trips count', () {
      expect(DaySummary.fromTrips(trips, '2026-10-01').tripsCount, 2);
    });

    test('total amount', () {
      expect(DaySummary.fromTrips(trips, '2026-10-01').totalAmount, 3900);
    });

    test('total commission', () {
      expect(DaySummary.fromTrips(trips, '2026-10-01').totalCommission, 585);
    });

    test('net income = total − commission', () {
      expect(DaySummary.fromTrips(trips, '2026-10-01').netIncome, 3315);
    });

    test('cash breakdown', () {
      expect(DaySummary.fromTrips(trips, '2026-10-01').cash, 1500);
    });

    test('card breakdown', () {
      expect(DaySummary.fromTrips(trips, '2026-10-01').card, 2400);
    });

    test('empty list → all zeros', () {
      final s = DaySummary.fromTrips([], '2026-10-01');
      expect(s.tripsCount, 0);
      expect(s.netIncome, 0);
    });
  });

  group('Duplicate protection via ApiService (mock)', () {
    late ApiService api;

    setUp(() {
      api = ApiService(baseUrl: 'http://test', client: _MockClient());
    });

    test('first add succeeds', () async {
      final result = await api.addTrip(_trip('t1'));
      expect(result.id, 't1');
    });

    test('same id a second time throws ApiException 409', () async {
      await api.addTrip(_trip('t1'));
      expect(
        () => api.addTrip(_trip('t1')),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('different id is allowed', () async {
      await api.addTrip(_trip('t1'));
      final result = await api.addTrip(_trip('t2'));
      expect(result.id, 't2');
    });
  });

  group('Trip JSON round-trip', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 't1',
        'start': '2026-10-01T08:10:00.000',
        'end': '2026-10-01T08:32:00.000',
        'amount': 2400.0,
        'payment': 'card',
        'commission': 360.0,
      };
      final trip = Trip.fromJson(json);
      expect(trip.id, 't1');
      expect(trip.amount, 2400.0);
      expect(trip.payment, 'card');
      expect(trip.commission, 360.0);
    });
  });
}
