import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    return 'http://localhost:8080';
  }

  static const String _tokenKey = 'jwt_token';

  // ─── Token storage ──────────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Map<String, String> _jsonHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _parseResponse(http.Response response) {
    final body = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final message =
        (body is Map && body['error'] != null) ? body['error'] : 'Request failed';
    throw ApiException(message as String, statusCode: response.statusCode);
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/register'),
          headers: _jsonHeaders(),
          body: json.encode({'name': name, 'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    final data = _parseResponse(response);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/login'),
          headers: _jsonHeaders(),
          body: json.encode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    final data = _parseResponse(response);
    final token = data['token'] as String;
    await saveToken(token);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'current_user',
      jsonEncode(data['user']),
    );

  return token;
  }

  Future<void> logout() async {
    await clearToken();
  }

  // ─── Users (protected) ───────────────────────────────────────────────────

  Future<List<User>> getUsers() async {
    final token = await getToken();
    if (token == null) throw const ApiException('Not authenticated');

    final response = await http
        .get(
          Uri.parse('$_baseUrl/users'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 15));

    final data = _parseResponse(response);
    final list = data['users'] as List<dynamic>;
    return list.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<User> getUserById(int id) async {
    final token = await getToken();
    if (token == null) throw const ApiException('Not authenticated');

    final response = await http
        .get(
          Uri.parse('$_baseUrl/users/$id'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 15));

    final data = _parseResponse(response);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> updateUser(int id, {String? name, String? email, String? password}) async {
    final token = await getToken();
    if (token == null) throw const ApiException('Not authenticated');

    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (password != null) 'password': password,
    };

    final response = await http
        .put(
          Uri.parse('$_baseUrl/users/$id'),
          headers: _jsonHeaders(token: token),
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 15));

    final data = _parseResponse(response);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> deleteUser(int id) async {
    final token = await getToken();
    if (token == null) throw const ApiException('Not authenticated');

    final response = await http
        .delete(
          Uri.parse('$_baseUrl/users/$id'),
          headers: _jsonHeaders(token: token),
        )
        .timeout(const Duration(seconds: 15));

    _parseResponse(response);
  }
}
