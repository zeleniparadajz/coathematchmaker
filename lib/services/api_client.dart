import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.baseUrl = 'http://localhost:4000'});

  final String baseUrl;
  String? token;

  Uri uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  String imageUrl(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.startsWith('http')) return value;
    return '$baseUrl$value';
  }

  Future<Map<String, dynamic>> getJson(String path,
      [Map<String, String>? query]) async {
    final response = await http.get(uri(path, query), headers: headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(String path,
      [Map<String, dynamic>? body]) async {
    final response = await http.post(
      uri(path),
      headers: headers,
      body: jsonEncode(body ?? <String, dynamic>{}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(
      String path, Map<String, dynamic> body) async {
    final response =
        await http.patch(uri(path), headers: headers, body: jsonEncode(body));
    return _decode(response);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await http.delete(uri(path), headers: headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> uploadProfileImage(XFile file) async {
    final request =
        http.MultipartRequest('POST', uri('/api/players/me/profile-image'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      await http.MultipartFile.fromPath('profileImage', file.path),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(
        decoded['message']?.toString() ?? 'API request failed',
        response.statusCode,
      );
    }

    return decoded;
  }
}
