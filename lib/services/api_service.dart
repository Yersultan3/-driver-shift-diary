import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trip.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({
    this.baseUrl = 'http://localhost:8000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Trip>> getTrips(DateTime date) async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/trips?date=${_fmtDate(date)}'),
    );
    if (resp.statusCode != 200) throw ApiException(resp.statusCode, resp.body);
    final list = jsonDecode(resp.body) as List;
    return list.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DaySummary> getSummary(DateTime date) async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/summary?date=${_fmtDate(date)}'),
    );
    if (resp.statusCode != 200) throw ApiException(resp.statusCode, resp.body);
    return DaySummary.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Trip> addTrip(Trip trip) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/trips'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(trip.toJson()),
    );
    if (resp.statusCode == 409) {
      throw const ApiException(409, 'Поездка с таким ID уже существует');
    }
    if (resp.statusCode != 201) throw ApiException(resp.statusCode, resp.body);
    return Trip.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}
