import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  final String? baseUrl = dotenv.env['BACKEND_BASE_URL'];

  bool get enabled => baseUrl != null && baseUrl!.isNotEmpty;

  Future<http.Response> post(String path, {Map<String, String>? headers, Object? body}) {
    if (!enabled) throw StateError('Backend API not configured');
    final uri = Uri.parse(_buildUrl(path));
    final h = {'Content-Type': 'application/json', ...?headers};
    return http.post(uri, headers: h, body: jsonEncode(body));
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) {
    if (!enabled) throw StateError('Backend API not configured');
    final uri = Uri.parse(_buildUrl(path));
    return http.get(uri, headers: headers);
  }

  String _buildUrl(String path) {
    final prefix = baseUrl!.endsWith('/') ? baseUrl!.substring(0, baseUrl!.length - 1) : baseUrl!;
    final suffix = path.startsWith('/') ? path : '/$path';
    return '$prefix$suffix';
  }
}

final apiClient = ApiClient();
