import 'dart:convert';

import '../models/concert_models.dart';
import 'token_storage.dart';

class GuestConcertOrderStorage {
  GuestConcertOrderStorage({SecretStorage? storage})
    : _storage = storage ?? FlutterSecretStorage();

  static const _storageKey = 'concert_guest_order_credentials_v1';

  final SecretStorage _storage;

  Future<List<GuestConcertOrderCredential>> readAll() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return <GuestConcertOrderCredential>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <GuestConcertOrderCredential>[];
      final credentials = decoded
          .whereType<Map>()
          .map((item) {
            final map = item.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            return GuestConcertOrderCredential.fromJson(map);
          })
          .where((item) {
            return item.orderCode.isNotEmpty &&
                item.guestAccessToken.isNotEmpty;
          })
          .toList();
      credentials.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return credentials;
    } catch (_) {
      return <GuestConcertOrderCredential>[];
    }
  }

  Future<void> save(GuestConcertOrderCredential credential) async {
    final credentials = await readAll();
    credentials.removeWhere((item) => item.orderCode == credential.orderCode);
    credentials.insert(0, credential);
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(credentials.map((item) => item.toJson()).toList()),
    );
  }

  Future<GuestConcertOrderCredential?> find(String orderCode) async {
    final credentials = await readAll();
    for (final item in credentials) {
      if (item.orderCode == orderCode) return item;
    }
    return null;
  }

  Future<void> remove(String orderCode) async {
    final credentials = await readAll();
    credentials.removeWhere((item) => item.orderCode == orderCode);
    if (credentials.isEmpty) {
      await _storage.delete(key: _storageKey);
      return;
    }
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(credentials.map((item) => item.toJson()).toList()),
    );
  }
}
