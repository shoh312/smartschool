import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

/// Thrown whenever the request never reached the server at all (refused
/// connection, DNS failure, timeout, ...). Kept free of the raw OS/socket
/// text -- callers map this to a localized, human-readable message instead
/// of showing `SocketException`/`ClientException` details to the user.
class NetworkException implements Exception {
  const NetworkException();
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    TokenStorage? tokenStorage,
    String Function()? baseUrlResolver,
  }) : _httpClient = httpClient ?? http.Client(),
       _tokenStorage = tokenStorage ?? TokenStorage(),
       _baseUrlResolver = baseUrlResolver ?? (() => AppConstants.apiBaseUrl);

  final http.Client _httpClient;
  final TokenStorage _tokenStorage;
  final String Function() _baseUrlResolver;
  String get baseUrl => _baseUrlResolver();

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _send('POST', path, body: body);
  }

  Future<dynamic> put(String path, {Object? body, bool isFormData = false}) async {
    return _send('PUT', path, body: body, isFormData: isFormData);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _send('PATCH', path, body: body);
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

    http.Response response;
    try {
      final streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }
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

    http.Response response;
    try {
      response = switch (method) {
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
        'PATCH' => await _httpClient.patch(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        'DELETE' => await _httpClient.delete(uri, headers: headers),
        _ => throw UnsupportedError(method),
      };
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      throw ApiException(
        detail?.toString() ??
            (response.body.isNotEmpty ? response.body : 'Request failed'),
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }
}
