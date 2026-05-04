import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  AuthService(this.api);

  static const _tokenKey = 'jwt_token';

  final ApiClient api;
  Player? currentPlayer;
  bool loading = true;

  bool get isLoggedIn => api.token != null && currentPlayer != null;
  bool get isAdmin => currentPlayer?.isAdmin ?? false;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString(_tokenKey);

    if (api.token != null) {
      try {
        final data = await api.getJson('/api/auth/me');
        currentPlayer = Player.fromJson(data['player']);
      } catch (_) {
        await prefs.remove(_tokenKey);
        api.token = null;
      }
    }

    loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await api.postJson('/api/auth/login', {
      'email': email,
      'password': password,
    });
    await _saveSession(data);
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    final data = await api.postJson('/api/auth/register', payload);
    if (data['token'] != null) {
      await _saveSession(data);
    }
    return data;
  }

  Future<void> resendVerification(String email) async {
    await api.postJson('/api/auth/resend-verification', {'email': email});
  }

  Future<void> refreshMe() async {
    final data = await api.getJson('/api/auth/me');
    currentPlayer = Player.fromJson(data['player']);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    api.token = null;
    currentPlayer = null;
    notifyListeners();
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    api.token = data['token'];
    currentPlayer = Player.fromJson(data['player']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, api.token!);
    notifyListeners();
  }
}
