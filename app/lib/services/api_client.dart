import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/constants.dart';
import 'token_storage.dart';

/// `http.MultipartFile.fromPath` doesn't reliably infer a MIME type on
/// every platform (on Windows, files picked via image_picker often come
/// back with no recognizable extension in their temp path, so it falls
/// back to `application/octet-stream`) -- and a photo endpoint like the
/// journal scanner rejects that outright since the receiving API only
/// accepts a real image MIME type. Guessing from the extension when
/// present covers every photo this app ever uploads (face registration,
/// journal scans), so there's no need for a full MIME-sniffing library.
/// Every call site uploads a photo (face registration or a journal scan),
/// never an arbitrary file, so an unrecognized/missing extension still
/// defaults to JPEG rather than leaving it to `http`'s own fallback (which
/// is `application/octet-stream` -- rejected outright by the journal-scan
/// endpoint's image-only API).
MediaType _guessImageMediaType(String filePath) {
  final lower = filePath.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  if (lower.endsWith('.heic')) return MediaType('image', 'heic');
  if (lower.endsWith('.heif')) return MediaType('image', 'heif');
  return MediaType('image', 'jpeg');
}

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

  /// [filePath] is optional: some form endpoints take a photo only
  /// sometimes (the AI material builder can start from a topic, a pasted
  /// text, *or* a textbook photo), and they still need multipart because
  /// their other fields are form fields.
  Future<dynamic> multipartPost(
    String path, {
    required Map<String, String> fields,
    String fileField = 'file',
    String? filePath,
    String method = 'POST',
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final token = await _tokenStorage.readToken();
    final request = http.MultipartRequest(method, uri)..fields.addAll(fields);
    if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          filePath,
          contentType: _guessImageMediaType(filePath),
        ),
      );
    }

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
