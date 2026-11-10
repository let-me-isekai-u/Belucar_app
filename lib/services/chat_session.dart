import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class ChatSession {
  static Future<String> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (token.isEmpty || !_expiresSoon(token)) return token;
    return await ApiService.refreshRejectedAccessToken(token) ?? '';
  }

  static bool _expiresSoon(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    try {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = claims is Map ? claims['exp'] : null;
      return exp is num &&
          exp * 1000 <=
              DateTime.now()
                  .add(const Duration(seconds: 30))
                  .millisecondsSinceEpoch;
    } on FormatException {
      return false;
    }
  }
}
