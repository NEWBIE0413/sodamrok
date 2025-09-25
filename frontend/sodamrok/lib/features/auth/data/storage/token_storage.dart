import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/auth_tokens.dart';

class TokenStorage {
  TokenStorage(this._preferences);

  static const String _key = 'auth_tokens';

  final SharedPreferences _preferences;

  Future<bool> save(AuthTokens tokens) async {
    final encoded = jsonEncode(tokens.toJson());
    return _preferences.setString(_key, encoded);
  }

  AuthTokens? read() {
    final stored = _preferences.getString(_key);
    if (stored == null || stored.isEmpty) {
      return null;
    }
    final Map<String, dynamic> json = jsonDecode(stored) as Map<String, dynamic>;
    return AuthTokens.fromJson(json);
  }

  Future<bool> clear() => _preferences.remove(_key);
}
