import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';
import 'app_logger.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// Thin HTTP client for the Raspberry Pi FastAPI backend. Reads the
/// server address from SettingsService on every call, so changing the
/// server IP in Settings takes effect immediately without restarting
/// the app.
///
/// NOTE: endpoint paths here match the backend as documented in this
/// project's history (/api/auth/login, /api/scan, /api/processes,
/// /api/job-cards, /api/insquares). If your backend's routes differ,
/// adjust the paths below to match.
class ApiService {
  final SettingsService _settings = SettingsService();

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (withAuth) {
      final token = await _settings.getAuthToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<Uri> _uri(String path, [Map<String, String>? query]) async {
    final base = await _settings.getBaseUrl();
    if (base.isEmpty) {
      throw ApiException('Server address not set. Go to Settings first.');
    }
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<dynamic> _handle(http.Response resp) async {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      return jsonDecode(resp.body);
    }
    String message = 'Request failed (${resp.statusCode})';
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {
      // body wasn't JSON; keep generic message
    }
    throw ApiException(message, resp.statusCode);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final uri = await _uri('/api/auth/login');
    AppLogger.instance.log('POST $uri (login as $username)');
    final resp = await http
        .post(uri,
            headers: await _headers(withAuth: false),
            body: jsonEncode({'username': username, 'password': password}))
        .timeout(const Duration(seconds: 15));
    final data = await _handle(resp);
    if (data is Map<String, dynamic>) {
      final token = data['access_token'] ?? data['token'];
      if (token != null) {
        await _settings.setAuthToken(token.toString());
        await _settings.setUsername(username);
      }
      return data;
    }
    throw ApiException('Unexpected login response');
  }

  Future<List<dynamic>> getProcesses() async {
    final uri = await _uri('/api/processes');
    AppLogger.instance.log('GET $uri');
    final resp =
        await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 15));
    final data = await _handle(resp);
    return (data is List) ? data : [];
  }

  Future<List<dynamic>> searchInsquares(String query) async {
    final uri = await _uri('/api/insquares', {'q': query});
    AppLogger.instance.log('GET $uri');
    final resp =
        await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 15));
    final data = await _handle(resp);
    return (data is List) ? data : [];
  }

  Future<Map<String, dynamic>> createJobCard({
    required int insquareId,
    int? productTypeId,
    String? notes,
  }) async {
    final uri = await _uri('/api/job-cards');
    final body = {
      'insquare_id': insquareId,
      if (productTypeId != null) 'product_type_id': productTypeId,
      if (notes != null) 'notes': notes,
    };
    AppLogger.instance.log('POST $uri body=$body');
    final resp = await http
        .post(uri, headers: await _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    final data = await _handle(resp);
    return (data is Map<String, dynamic>) ? data : {};
  }

  /// Sends one handheld scan to the backend's process_scan pipeline.
  /// [processCode] identifies which process this scan represents
  /// (e.g. "PPC_OUT", "PRODUCTION_IN", "ISOLATE_IN") and [tagValue] is
  /// the RFID tag read, from either the XR2 or the uTouch2.
  Future<Map<String, dynamic>> submitScan({
    required String processCode,
    required String tagValue,
  }) async {
    final uri = await _uri('/api/scan');
    final body = {'process_code': processCode, 'tag_epc': tagValue};
    AppLogger.instance.log('POST $uri body=$body');
    final resp = await http
        .post(uri, headers: await _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    final data = await _handle(resp);
    return (data is Map<String, dynamic>) ? data : {};
  }

  Future<bool> ping() async {
    try {
      final uri = await _uri('/api/health');
      final resp = await http.get(uri, headers: await _headers(withAuth: false))
          .timeout(const Duration(seconds: 6));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      AppLogger.instance.log('ping failed: $e');
      return false;
    }
  }
}
