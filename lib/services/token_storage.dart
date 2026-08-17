import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';

abstract interface class SecretStorage {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String? value});

  Future<void> delete({required String key});
}

class FlutterSecretStorage implements SecretStorage {
  FlutterSecretStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              keyCipherAlgorithm:
                  KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
              storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String? value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

/// The only persistence gateway for authentication tokens.
///
/// Tokens are encrypted by Android Keystore / iOS Keychain. SharedPreferences
/// is consulted only once to migrate sessions created by older app versions.
class TokenStorage {
  TokenStorage({SecretStorage? storage})
    : _storage = storage ?? FlutterSecretStorage();

  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _legacyAccessTokenKey = 'accessToken';
  static const _legacyRefreshTokenKey = 'refreshToken';

  final SecretStorage _storage;

  Future<AuthTokens?> read() async {
    final values = await Future.wait([
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _refreshTokenKey),
    ]);
    final tokens = AuthTokens(
      accessToken: values[0]?.trim() ?? '',
      refreshToken: values[1]?.trim() ?? '',
    );
    return tokens.accessToken.isEmpty && tokens.refreshToken.isEmpty
        ? null
        : tokens;
  }

  Future<void> save(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: tokens.accessToken),
      _storage.write(key: _refreshTokenKey, value: tokens.refreshToken),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  Future<AuthTokens?> migrateLegacyTokens() async {
    final prefs = await SharedPreferences.getInstance();
    var secureTokens = await read();
    final legacyTokens = AuthTokens(
      accessToken: prefs.getString(_legacyAccessTokenKey)?.trim() ?? '',
      refreshToken: prefs.getString(_legacyRefreshTokenKey)?.trim() ?? '',
    );

    final hasLegacyTokens =
        legacyTokens.accessToken.isNotEmpty ||
        legacyTokens.refreshToken.isNotEmpty;
    final needsLegacyAccess =
        legacyTokens.accessToken.isNotEmpty &&
        (secureTokens?.accessToken.isEmpty ?? true);
    final needsLegacyRefresh =
        legacyTokens.refreshToken.isNotEmpty &&
        (secureTokens?.refreshToken.isEmpty ?? true);

    if (hasLegacyTokens && (needsLegacyAccess || needsLegacyRefresh)) {
      final merged = AuthTokens(
        accessToken: secureTokens?.accessToken.isNotEmpty == true
            ? secureTokens!.accessToken
            : legacyTokens.accessToken,
        refreshToken: secureTokens?.refreshToken.isNotEmpty == true
            ? secureTokens!.refreshToken
            : legacyTokens.refreshToken,
      );
      await save(merged);
      secureTokens = await read();
      if (secureTokens?.accessToken != merged.accessToken ||
          secureTokens?.refreshToken != merged.refreshToken) {
        throw StateError('Không thể xác minh dữ liệu token sau khi migration');
      }
    }

    final migrationVerified =
        !hasLegacyTokens ||
        ((legacyTokens.accessToken.isEmpty ||
                secureTokens?.accessToken.isNotEmpty == true) &&
            (legacyTokens.refreshToken.isEmpty ||
                secureTokens?.refreshToken.isNotEmpty == true));
    if (migrationVerified && hasLegacyTokens) {
      await Future.wait([
        prefs.remove(_legacyAccessTokenKey),
        prefs.remove(_legacyRefreshTokenKey),
      ]);
    }

    return secureTokens;
  }
}
