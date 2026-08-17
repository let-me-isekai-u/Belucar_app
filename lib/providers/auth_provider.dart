import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import '../models/provider_result.dart';
import '../services/api_service.dart';
import '../services/login_credential_storage.dart';
import '../services/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required TokenStorage tokenStorage})
    : _tokenStorage = tokenStorage;

  final TokenStorage _tokenStorage;
  AuthTokens? _tokens;
  Future<bool>? _refreshOperation;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _tokens?.accessToken.isNotEmpty == true;
  String? get accessToken => _tokens?.accessToken;

  Future<AuthRestoreStatus> restoreSession() async {
    _setLoading(true);
    try {
      _tokens = await _tokenStorage.migrateLegacyTokens();
      final token = _tokens?.accessToken ?? '';
      if (token.isEmpty) {
        if (await _refreshAccessToken()) {
          return AuthRestoreStatus.authenticated;
        }
        await clearSession();
        return AuthRestoreStatus.unauthenticated;
      }

      final profileResponse = await ApiService.getCustomerProfile(
        accessToken: token,
      );
      if (profileResponse.statusCode == 200) {
        await _markEventBannerVisible();
        return AuthRestoreStatus.authenticated;
      }

      if (await _refreshAccessToken()) {
        await _markEventBannerVisible();
        return AuthRestoreStatus.authenticated;
      }

      await clearSession();
      return AuthRestoreStatus.unauthenticated;
    } catch (_) {
      // Keep the old startup behavior: an unverifiable session is signed out.
      await clearSession();
      return AuthRestoreStatus.unauthenticated;
    } finally {
      _setLoading(false);
    }
  }

  Future<ProviderResult<LoginSession>> login({
    required String phone,
    required String password,
    required String deviceToken,
  }) async {
    _setLoading(true);
    try {
      final response = await ApiService.customerLogin(
        phone: phone,
        password: password,
        deviceToken: deviceToken,
      );
      final json = _decodeMap(response.body);
      if (response.statusCode != 200) {
        return ProviderResult.failure(
          json['message']?.toString() ?? 'Sai tài khoản hoặc mật khẩu',
          statusCode: response.statusCode,
        );
      }

      final session = LoginSession.fromJson(json, phone: phone);
      if (session.tokens.accessToken.isEmpty) {
        return const ProviderResult.failure('Server không trả về accessToken');
      }

      await _tokenStorage.save(session.tokens);
      _tokens = session.tokens;
      try {
        final prefs = await SharedPreferences.getInstance();
        await Future.wait([
          prefs.setString('fullName', session.fullName),
          prefs.setString('phone', session.phone),
          prefs.setInt('id', session.userId),
          prefs.setBool('showEventBanner', true),
        ]);
      } catch (_) {
        // Non-sensitive cached profile data is optional.
      }
      try {
        await LoginCredentialStorage.save(phone: phone, password: password);
      } catch (_) {
        // Credential autofill is optional and never blocks a valid login.
      }
      notifyListeners();
      return ProviderResult.success(session);
    } catch (error) {
      return ProviderResult.failure('Không thể đăng nhập: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> requireAccessToken() async {
    _tokens ??= await _tokenStorage.migrateLegacyTokens();
    if (_tokens?.accessToken.isNotEmpty == true) return _tokens!.accessToken;
    return await _refreshAccessToken() ? _tokens?.accessToken : null;
  }

  /// Runs an authenticated request and retries it once after refreshing a 401.
  /// Concurrent refresh attempts share the same in-flight operation.
  Future<T> authorizedRequest<T>(
    Future<T> Function(String accessToken) request, {
    required bool Function(T response) isUnauthorized,
  }) async {
    final token = await requireAccessToken();
    if (token == null) throw StateError('Phiên đăng nhập hết hạn');

    var response = await request(token);
    if (!isUnauthorized(response) || !await _refreshAccessToken()) {
      return response;
    }

    final refreshedToken = _tokens?.accessToken;
    if (refreshedToken == null || refreshedToken.isEmpty) return response;
    response = await request(refreshedToken);
    return response;
  }

  Future<void> logout() async {
    final token = await requireAccessToken();
    if (token != null) {
      try {
        await ApiService.logout(token);
      } catch (_) {
        // Local logout must still complete if the server cannot be reached.
      }
    }
    await clearSession(clearPreferences: true);
  }

  Future<void> clearSession({bool clearPreferences = false}) async {
    _tokens = null;
    await _tokenStorage.clear();
    if (clearPreferences) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
    notifyListeners();
  }

  Future<bool> _refreshAccessToken() {
    final running = _refreshOperation;
    if (running != null) return running;
    final operation = _performRefresh();
    _refreshOperation = operation;
    return operation.whenComplete(() => _refreshOperation = null);
  }

  Future<bool> _performRefresh() async {
    _tokens ??= await _tokenStorage.read();
    final refreshToken = _tokens?.refreshToken ?? '';
    if (refreshToken.isEmpty) return false;

    try {
      final response = await ApiService.refreshToken(
        refreshToken: refreshToken,
      );
      if (response.statusCode != 200) return false;
      final json = _decodeMap(response.body);
      final refreshed = AuthTokens.fromJson(json);
      if (refreshed.accessToken.isEmpty) return false;
      _tokens = AuthTokens(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken.isEmpty
            ? refreshToken
            : refreshed.refreshToken,
      );
      await _tokenStorage.save(_tokens!);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _markEventBannerVisible() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showEventBanner', true);
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
}
