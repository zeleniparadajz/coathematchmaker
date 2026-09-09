import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/env.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  //ApiClient({this.baseUrl = 'http://localhost:4000'});

  ApiClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? Env.apiUrl,
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final Map<String, Future<Map<String, dynamic>>> _requests = {};
  String? token;

  void close() => _client.close();

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send,
  ) async {
    try {
      return _decode(await send().timeout(const Duration(seconds: 20)));
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Server ne odgovara. Pokušaj ponovo.');
    } on SocketException {
      throw ApiException('Nema internet veze. Pokušaj ponovo.');
    } on http.ClientException {
      throw ApiException('Veza sa serverom nije dostupna.');
    } on FormatException {
      throw ApiException('Server je vratio neispravan odgovor.');
    }
  }

  Uri uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  String imageUrl(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.startsWith('http')) {
      final uri = Uri.tryParse(value);
      if (uri != null &&
          uri.path.startsWith('/uploads') &&
          (uri.host == '161.97.74.146' ||
              uri.host == 'coabackapi.zeleniparadajz.me' ||
              uri.host == 'localhost')) {
        return '$baseUrl${uri.path}';
      }
      return value;
    }
    final normalized = value.startsWith('/') ? value : '/$value';
    return '$baseUrl$normalized';
  }

  Future<Map<String, dynamic>> getJson(
    String path, [
    Map<String, String>? query,
  ]) async {
    final url = uri(path, query);
    final key = '$token:$url';
    final existing = _requests[key];
    if (existing != null) return existing;
    final request = _request(() => _client.get(url, headers: headers));
    _requests[key] = request;
    try {
      return await request;
    } finally {
      _requests.remove(key);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    return _request(
      () => _client.post(
        uri(path),
        headers: headers,
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _request(
      () => _client.patch(uri(path), headers: headers, body: jsonEncode(body)),
    );
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    return _request(() => _client.delete(uri(path), headers: headers));
  }

  Future<Map<String, dynamic>> uploadProfileImage(XFile file) async {
    return uploadImage(
      '/api/players/me/profile-image',
      file,
      fieldName: 'profileImage',
    );
  }

  Future<Map<String, dynamic>> uploadImage(
    String path,
    XFile file, {
    String fieldName = 'image',
  }) async {
    final request = http.MultipartRequest('POST', uri(path));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));

    return _request(() async {
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      final value = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      decoded = value;
    } on FormatException {
      throw ApiException(
        'Server trenutno nije dostupan. Pokušaj ponovo.',
        response.statusCode,
      );
    }

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(
        decoded['message']?.toString() ?? 'API request failed',
        response.statusCode,
      );
    }

    return decoded;
  }
}
