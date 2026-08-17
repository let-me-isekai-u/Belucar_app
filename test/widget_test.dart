import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:belucar_app/models/auth_models.dart';
import 'package:belucar_app/models/customer_profile_model.dart';
import 'package:belucar_app/services/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('auth response is parsed into a typed session', () {
    final session = LoginSession.fromJson({
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'fullName': 'Nguyễn Văn A',
      'id': '12',
    }, phone: '0900000000');

    expect(session.tokens.isComplete, isTrue);
    expect(session.userId, 12);
    expect(session.phone, '0900000000');
  });

  test('customer profile safely parses numeric API fields', () {
    final profile = CustomerProfileModel.fromJson({
      'id': '7',
      'fullName': 'Khách hàng',
      'email': 'customer@example.com',
      'phone': '0911111111',
      'wallet': '125000.5',
    });

    expect(profile.id, 7);
    expect(profile.wallet, 125000.5);
  });

  test('legacy SharedPreferences tokens migrate to secure storage', () async {
    SharedPreferences.setMockInitialValues({
      'accessToken': 'legacy-access',
      'refreshToken': 'legacy-refresh',
      'fullName': 'Dữ liệu không nhạy cảm',
    });
    final secrets = _MemorySecretStorage();
    final storage = TokenStorage(storage: secrets);

    final migrated = await storage.migrateLegacyTokens();
    final prefs = await SharedPreferences.getInstance();

    expect(migrated?.accessToken, 'legacy-access');
    expect(migrated?.refreshToken, 'legacy-refresh');
    expect(prefs.getString('accessToken'), isNull);
    expect(prefs.getString('refreshToken'), isNull);
    expect(prefs.getString('fullName'), 'Dữ liệu không nhạy cảm');
  });

  test('migration repairs a partially written secure session', () async {
    SharedPreferences.setMockInitialValues({
      'accessToken': 'legacy-access',
      'refreshToken': 'legacy-refresh',
    });
    final storage = TokenStorage(storage: _MemorySecretStorage());
    await storage.save(
      const AuthTokens(accessToken: 'secure-access', refreshToken: ''),
    );

    final migrated = await storage.migrateLegacyTokens();
    final prefs = await SharedPreferences.getInstance();

    expect(migrated?.accessToken, 'secure-access');
    expect(migrated?.refreshToken, 'legacy-refresh');
    expect(prefs.getString('accessToken'), isNull);
    expect(prefs.getString('refreshToken'), isNull);
  });
}

class _MemorySecretStorage implements SecretStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
