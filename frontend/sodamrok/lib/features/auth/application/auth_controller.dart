import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/dio_client.dart';
import '../data/services/auth_service.dart';
import '../data/storage/token_storage.dart';
import '../domain/models/auth_tokens.dart';
import '../domain/models/auth_user.dart';

enum AuthStatus {
  initializing,
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthService authService,
    required TokenStorage tokenStorage,
    required DioClient dioClient,
  })  : _authService = authService,
        _tokenStorage = tokenStorage,
        _dioClient = dioClient;

  final AuthService _authService;
  final TokenStorage _tokenStorage;
  final DioClient _dioClient;

  AuthStatus _status = AuthStatus.initializing;
  AuthUser? _user;
  AuthTokens? _tokens;
  String? _error;
  Completer<bool>? _refreshCompleter;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get error => _error;
  AuthTokens? get tokens => _tokens;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get hasRefreshToken => (_tokens?.refreshToken.isNotEmpty ?? false);

  Future<void> initialize() async {
    final stored = _tokenStorage.read();
    if (stored == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _applyTokens(stored);

    try {
      _status = AuthStatus.authenticating;
      notifyListeners();

      final profile = await _authService.fetchProfile();
      _user = profile;
      _status = AuthStatus.authenticated;
      _error = null;
    } catch (_) {
      await logout(clearStorageOnly: true);
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(email: email, password: password);
      final tokens = result.$1;
      final user = result.$2;

      _applyTokens(tokens);
      await _tokenStorage.save(tokens);

      _user = user;
      _status = AuthStatus.authenticated;
      _error = null;
    } on DioException catch (error) {
      _handleLoginError(error);
    } catch (_) {
      _status = AuthStatus.error;
      _error = '로그인에 실패했어요. 잠시 후 다시 시도해 주세요.';
    }

    notifyListeners();
  }

  Future<String?> register({
    required String email,
    required String password,
    String? displayName,
    String? nickname,
  }) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
        nickname: nickname,
      );
      await login(email: email, password: password);
      return null;
    } on DioException catch (error) {
      final message = _extractErrorMessage(error.response?.data) ?? '회원가입 중 오류가 발생했어요.';
      _status = AuthStatus.error;
      _error = message;
      notifyListeners();
      return message;
    } catch (_) {
      _status = AuthStatus.error;
      _error = '회원가입에 실패했어요. 잠시 후 다시 시도해 주세요.';
      notifyListeners();
      return _error;
    }
  }

  Future<String?> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      await _authService.resetPassword(email: email, newPassword: newPassword);
      return null;
    } on DioException catch (error) {
      return _extractErrorMessage(error.response?.data) ?? '비밀번호를 재설정하지 못했어요.';
    } catch (_) {
      return '비밀번호 재설정에 실패했어요. 잠시 후 다시 시도해 주세요.';
    }
  }

  Future<bool> refreshTokens() {
    if (!hasRefreshToken) {
      return Future.value(false);
    }
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    () async {
      try {
        final refreshed = await _authService.refresh(_tokens!.refreshToken);
        _applyTokens(refreshed);
        await _tokenStorage.save(refreshed);
        completer.complete(true);
      } catch (_) {
        await logout();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      } finally {
        _refreshCompleter = null;
      }
    }();

    return completer.future;
  }

  Future<void> logout({bool clearStorageOnly = false}) async {
    _user = null;
    _tokens = null;
    _error = null;
    _dioClient.setAuthToken(null);
    await _tokenStorage.clear();
    if (!clearStorageOnly) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  void _applyTokens(AuthTokens tokens) {
    _tokens = tokens;
    _dioClient.setAuthToken(tokens.accessToken);
  }

  void _handleLoginError(DioException error) {
    final statusCode = error.response?.statusCode ?? 0;
    if (statusCode == 401) {
      _status = AuthStatus.error;
      _error = '이메일 또는 비밀번호가 올바르지 않아요.';
      return;
    }

    _status = AuthStatus.error;
    _error = _extractErrorMessage(error.response?.data) ?? '로그인 중 알 수 없는 오류가 발생했어요.';
  }

  String? _extractErrorMessage(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is String && data.isNotEmpty) {
      return data;
    }
    if (data is Map) {
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String && first.isNotEmpty) {
            return first;
          }
        } else if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }
}
