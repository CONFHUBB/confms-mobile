import 'dart:convert';

import 'package:confms_mobile/models/auth_user.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession extends ChangeNotifier {
  AuthSession();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  String? _token;
  AuthUser? _user;

  String? get token => _token;
  AuthUser? get user => _user;
  bool get isAuthenticated => (_token ?? '').isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = _normalizeToken(prefs.getString(_tokenKey));

    final userJson = prefs.getString(_userKey);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(userJson);
        if (decoded is Map<String, dynamic>) {
          _user = AuthUser.fromJson(decoded);
        }
      } catch (_) {
        _user = null;
      }
    }

    notifyListeners();
  }

  Future<void> saveSession({
    required String token,
    required AuthUser user,
  }) async {
    _token = _normalizeToken(token);
    _user = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));

    notifyListeners();
  }

  Future<void> clearSession() async {
    _token = null;
    _user = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);

    notifyListeners();
  }

  String _normalizeToken(String? token) {
    final value = (token ?? '').trim();
    if (value.toLowerCase().startsWith('bearer ')) {
      return value.substring(7).trim();
    }
    return value;
  }
}
