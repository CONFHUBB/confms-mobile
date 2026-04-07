import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  ApiService({http.Client? client, this.tokenProvider})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Future<String?> Function()? tokenProvider;

  // Fixed domain — no VPN needed.
  // Override with --dart-define=API_BASE_URL=... for local dev.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://confhub.io.vn/api/v1',
  );

  Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _client.get(
      _buildUri(path),
      headers: await _buildHeaders(),
    );
    return _decodeObjectResponse(response);
  }

  Future<dynamic> getAny(String path) async {
    final response = await _client.get(
      _buildUri(path),
      headers: await _buildHeaders(),
    );
    return _decodeAnyResponse(response);
  }

  Future<http.Response> getRaw(String path) async {
    return _client.get(_buildUri(path), headers: await _buildHeaders());
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.post(
      _buildUri(path),
      headers: await _buildHeaders(),
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decodeObjectResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.put(
      _buildUri(path),
      headers: await _buildHeaders(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeObjectResponse(response);
  }

  Map<String, String> get _jsonHeaders => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, String>> _buildHeaders() async {
    final headers = Map<String, String>.from(_jsonHeaders);
    final rawToken = await tokenProvider?.call();
    final token = _normalizeToken(rawToken);
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  String _normalizeToken(String? rawToken) {
    final value = (rawToken ?? '').trim();
    if (value.isEmpty) return '';

    if (value.toLowerCase().startsWith('bearer ')) {
      return value.substring(7).trim();
    }
    return value;
  }

  Map<String, dynamic> _decodeObjectResponse(http.Response response) {
    final decoded = _decodeAnyResponse(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException(
      message: 'Unexpected response format from server.',
    );
  }

  dynamic _decodeAnyResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: _extractErrorMessage(response),
        statusCode: response.statusCode,
      );
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    return decoded;
  }

  String _extractErrorMessage(http.Response response) {
    if (response.statusCode == 401) {
      return 'Unauthorized. Please sign in again.';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message =
            decoded['message'] ?? decoded['detail'] ?? decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fall through to generic message.
    }
    return 'Request failed with status ${response.statusCode}.';
  }
}

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
