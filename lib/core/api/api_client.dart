/// lib/core/api/api_client.dart
///
/// Client HTTP centralisé — point d'entrée unique vers FastAPI.
///
/// Responsabilités :
///   • Attacher automatiquement le Bearer token JWT
///   • Rafraîchir le token (401 → refresh → retry)
///   • Décoder UTF-8 de façon uniforme
///   • Gérer les erreurs réseau
///
/// Règle : TOUS les services feature-based passent par ApiClient.
/// Personne n'instancie http.Client directement sauf ici.
library api_client;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';

/// Réponse normalisée retournée par ApiClient.
class ApiResponse {
  final int statusCode;
  final Map<String, dynamic> body;
  final bool isSuccess;
  final String? error;

  const ApiResponse._({
    required this.statusCode,
    required this.body,
    required this.isSuccess,
    this.error,
  });

  factory ApiResponse.success(int code, Map<String, dynamic> body) =>
      ApiResponse._(statusCode: code, body: body, isSuccess: true);

  factory ApiResponse.failure(int code, String error, [Map<String, dynamic>? body]) =>
      ApiResponse._(statusCode: code, body: body ?? {}, isSuccess: false, error: error);
}

class ApiClient {
  // Singleton
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  final http.Client _http = http.Client();
  static const Duration _timeout = Duration(seconds: 20);

  // ── Token Management ────────────────────────────────────────────────────────

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refresh_token', token);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('refresh_token');
  }

  /// Headers JSON + Bearer token (si disponible).
  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Tente de renouveler le token via /token/refresh.
  Future<bool> _tryRefresh() async {
    final refresh = await _getRefreshToken();
    if (refresh == null) return false;
    try {
      final response = await _http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/token/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await saveToken(data['access_token'] as String);
        if (data['refresh_token'] != null) {
          await saveRefreshToken(data['refresh_token'] as String);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── HTTP Verbs ───────────────────────────────────────────────────────────────

  /// GET authentifié avec retry 401.
  Future<ApiResponse> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path')
        .replace(queryParameters: query);
    try {
      var headers = await _headers();
      var response = await _http.get(uri, headers: headers).timeout(_timeout);

      if (response.statusCode == 401) {
        if (await _tryRefresh()) {
          headers = await _headers();
          response = await _http.get(uri, headers: headers).timeout(_timeout);
        }
      }
      return _parse(response);
    } catch (e) {
      return ApiResponse.failure(0, 'Erreur réseau : $e');
    }
  }

  /// POST JSON.
  Future<ApiResponse> post(String path, {Map<String, dynamic>? body, bool requireAuth = true}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    try {
      var headers = await _headers();
      if (!requireAuth) headers.remove('Authorization');
      final response = await _http
          .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);
      return _parse(response);
    } catch (e) {
      return ApiResponse.failure(0, 'Erreur réseau : $e');
    }
  }

  /// POST form-urlencoded (login JWT).
  Future<ApiResponse> postForm(String path, Map<String, String> fields) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    try {
      final response = await _http
          .post(uri,
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: fields)
          .timeout(_timeout);
      return _parse(response);
    } catch (e) {
      return ApiResponse.failure(0, 'Erreur réseau : $e');
    }
  }

  /// PUT JSON.
  Future<ApiResponse> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    try {
      final headers = await _headers();
      final response = await _http
          .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);
      return _parse(response);
    } catch (e) {
      return ApiResponse.failure(0, 'Erreur réseau : $e');
    }
  }

  /// PATCH JSON.
  Future<ApiResponse> patch(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    try {
      final headers = await _headers();
      final response = await _http
          .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
          .timeout(_timeout);
      return _parse(response);
    } catch (e) {
      return ApiResponse.failure(0, 'Erreur réseau : $e');
    }
  }

  /// DELETE.
  Future<ApiResponse> delete(String path) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    try {
      final headers = await _headers(json: false);
      final response = await _http.delete(uri, headers: headers).timeout(_timeout);
      return _parse(response);
    } catch (e) {
      return ApiResponse.failure(0, 'Erreur réseau : $e');
    }
  }

  /// Multipart upload (images, PDF, vidéos).
  Future<ApiResponse> upload(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    String contentType = 'application/octet-stream',
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    try {
      final token = await getToken();
      final request = http.MultipartRequest('POST', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        fieldName, bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ));
      if (fields != null) request.fields.addAll(fields);
      final streamed = await request.send().timeout(_timeout);
      final body = await streamed.stream.bytesToString();
      final parsed = _tryDecode(body);
      return streamed.statusCode >= 200 && streamed.statusCode < 300
          ? ApiResponse.success(streamed.statusCode, parsed)
          : ApiResponse.failure(streamed.statusCode,
              parsed['detail'] as String? ?? 'Erreur upload', parsed);
    } catch (e) {
      return ApiResponse.failure(0, 'Erreur réseau upload : $e');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  ApiResponse _parse(http.Response response) {
    final body = _tryDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponse.success(response.statusCode, body);
    }
    final error = body['detail'] as String? ??
        body['message'] as String? ??
        'Erreur HTTP ${response.statusCode}';
    return ApiResponse.failure(response.statusCode, error, body);
  }

  Map<String, dynamic> _tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      // Si c'est une liste, on l'encapsule
      if (decoded is List) return {'items': decoded};
      return {'value': decoded};
    } catch (_) {
      return {'raw': raw};
    }
  }
}
