import 'token_storage.dart';

class SavedLoginCredentials {
  const SavedLoginCredentials({required this.phone, required this.password});

  final String phone;
  final String password;

  bool get isComplete => phone.isNotEmpty && password.isNotEmpty;
}

class LoginCredentialStorage {
  LoginCredentialStorage._();

  static const _phoneKey = 'last_login_phone';
  static const _passwordKey = 'last_login_password';
  static final SecretStorage _storage = FlutterSecretStorage();

  static Future<SavedLoginCredentials?> read() async {
    final values = await Future.wait([
      _storage.read(key: _phoneKey),
      _storage.read(key: _passwordKey),
    ]);
    final credentials = SavedLoginCredentials(
      phone: values[0]?.trim() ?? '',
      password: values[1] ?? '',
    );
    return credentials.isComplete ? credentials : null;
  }

  static Future<void> save({
    required String phone,
    required String password,
  }) async {
    await Future.wait([
      _storage.write(key: _phoneKey, value: phone.trim()),
      _storage.write(key: _passwordKey, value: password),
    ]);
  }

  static Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _phoneKey),
      _storage.delete(key: _passwordKey),
    ]);
  }
}
