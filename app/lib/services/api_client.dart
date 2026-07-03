import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient, TokenStorage? tokenStorage})
    : _httpClient = httpClient ?? http.Client(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _httpClient;
  final TokenStorage _tokenStorage;
  final String baseUrl = AppConstants.apiBaseUrl;

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _send('POST', path, body: body);
  }

  Future<dynamic> put(String path, {Object? body, bool isFormData = false}) async {
    return _send('PUT', path, body: body, isFormData: isFormData);
  }

  Future<dynamic> delete(String path) async {
    return _send('DELETE', path);
  }

  Future<dynamic> multipartPost(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required String filePath,
    String method = 'POST',
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final token = await _tokenStorage.readToken();
    final request = http.MultipartRequest(method, uri)
      ..fields.addAll(fields)
      ..files.add(await http.MultipartFile.fromPath(fileField, filePath));

    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw ApiException(
        detail?.toString() ?? 'Upload failed',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool isFormData = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final token = await _tokenStorage.readToken();
    final headers = {
      'Accept': 'application/json',
      if (!isFormData) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = switch (method) {
      'GET' => await _httpClient.get(uri, headers: headers),
      'POST' => await _httpClient.post(
        uri,
        headers: headers,
        body: body == null
            ? null
            : isFormData
                ? body
                : jsonEncode(body),
      ),
      'PUT' => await _httpClient.put(
        uri,
        headers: headers,
        body: body == null
            ? null
            : isFormData
                ? body
                : jsonEncode(body),
      ),
      'DELETE' => await _httpClient.delete(uri, headers: headers),
      _ => throw UnsupportedError(method),
    };

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw ApiException(
        detail?.toString() ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}
