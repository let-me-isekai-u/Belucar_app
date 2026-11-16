import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class SessionUnavailable implements Exception {
  const SessionUnavailable();
}

/// The only owner of customer token rotation and persistence.
class CustomerSession {
  static final http.Client _transport = http.Client();
  static Future<void> _writes = Future.value();
  static Future<String>? _refresh;
  static int _generation = 0;
  static final Set<String> _retiredAccess = {};
  static void Function()? onExpired;

  static Future<T> _write<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static Future<void> login(String access, String refresh) {
    _generation++;
    _refresh = null;
    _retiredAccess.clear();
    return _write(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refreshToken', refresh);
      await prefs.setString('accessToken', access);
    });
  }

  static Future<void> clear({bool notify = false}) {
    final generation = ++_generation;
    _refresh = null;
    _retiredAccess.clear();
    return _write(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      if (notify && generation == _generation) onExpired?.call();
    });
  }

  static bool expiresSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = claims is Map ? claims['exp'] : null;
      return exp is num &&
          exp * 1000 <=
              DateTime.now()
                  .add(const Duration(seconds: 30))
                  .millisecondsSinceEpoch;
    } catch (_) {
      return false;
    }
  }

  static Future<String> accessToken({String? supplied}) async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('accessToken') ?? '';
    if (current.isEmpty ||
        (supplied != null &&
            supplied != current &&
            !_retiredAccess.contains(supplied))) {
      throw const SessionUnavailable();
    }
    return expiresSoon(current) ? refreshRejected(current) : current;
  }

  static Future<String> refreshRejected(String rejected) async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('accessToken') ?? '';
    if (current != rejected) {
      if (current.isNotEmpty && _retiredAccess.contains(rejected)) {
        return current;
      }
      throw const SessionUnavailable();
    }
    final pending = _refresh;
    if (pending != null) return pending;
    final refreshToken = prefs.getString('refreshToken') ?? '';
    if (refreshToken.isEmpty) {
      await clear(notify: true);
      throw const SessionUnavailable();
    }
    final generation = _generation;
    final operation = _rotate(prefs, current, refreshToken, generation);
    _refresh = operation;
    try {
      return await operation;
    } finally {
      if (identical(_refresh, operation)) _refresh = null;
    }
  }

  static Future<String> _rotate(
    SharedPreferences prefs,
    String access,
    String refresh,
    int generation,
  ) async {
    final response = await _transport
        .post(
          Uri.parse('$apiOrigin/api/accountcustomerapi/refresh-token'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'refreshToken': refresh}),
        )
        .timeout(const Duration(seconds: 20));
    if (generation != _generation) throw const SessionUnavailable();
    // Only an explicit authentication rejection invalidates the session.
    // No backend error-code contract for 400/403 is present in this repository.
    if (response.statusCode == 401) {
      await clear(notify: true);
      throw const SessionUnavailable();
    }
    if (response.statusCode != 200) {
      throw StateError('refresh_temporarily_unavailable');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded is Map && decoded['data'] is Map
        ? decoded['data']
        : decoded;
    if (data is! Map ||
        data['accessToken'] is! String ||
        (data['accessToken'] as String).isEmpty) {
      throw const FormatException('Invalid refresh response');
    }
    final nextAccess = data['accessToken'] as String;
    final nextRefresh = data['refreshToken'];
    return _write(() async {
      if (generation != _generation ||
          prefs.getString('accessToken') != access ||
          prefs.getString('refreshToken') != refresh) {
        throw const SessionUnavailable();
      }
      if (!await prefs.setString(
        'refreshToken',
        nextRefresh is String && nextRefresh.isNotEmpty ? nextRefresh : refresh,
      )) {
        throw StateError('Token persistence failed');
      }
      if (!await prefs.setString('accessToken', nextAccess)) {
        throw StateError('Token persistence failed');
      }
      if (generation != _generation) throw const SessionUnavailable();
      _retiredAccess.add(access);
      return nextAccess;
    });
  }
}

final customerHttp = CustomerHttpClient();

/// Buffers only ordinary Request bodies. Multipart/streaming requests are sent once.
class CustomerHttpClient extends http.BaseClient {
  CustomerHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();
  final http.Client _inner;

  static http.StreamedResponse _failure(
    int status,
    String code,
    String message,
  ) => http.StreamedResponse(
    Stream.value(
      utf8.encode(
        jsonEncode({'success': false, 'code': code, 'message': message}),
      ),
    ),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final authorization =
        request.headers['Authorization'] ?? request.headers['authorization'];
    final origin = Uri.parse(apiOrigin);
    if (request.url.origin != origin.origin ||
        authorization == null ||
        !authorization.startsWith('Bearer ')) {
      return _sendOnce(request);
    }
    final generation = CustomerSession._generation;
    try {
      var token = await CustomerSession.accessToken(
        supplied: authorization.substring(7),
      );
      if (generation != CustomerSession._generation) {
        throw const SessionUnavailable();
      }
      final replay = request is http.Request ? _copy(request) : null;
      request.headers['Authorization'] = 'Bearer $token';
      final response = await _sendOnce(request);
      if (response.statusCode != 401) return response;
      await response.stream.drain<void>();
      if (generation != CustomerSession._generation) {
        throw const SessionUnavailable();
      }
      token = await CustomerSession.refreshRejected(token);
      if (generation != CustomerSession._generation) {
        throw const SessionUnavailable();
      }
      // Existing idempotency support is retained only for routes already using it.
      final path = request.url.path;
      final protectedWrite =
          request.headers.containsKey('Idempotency-Key') &&
          (path == '/api/v2/ride/create' ||
              path.startsWith('/api/rideapi/cancel') ||
              path.startsWith('/api/carrier/bookings'));
      if (replay == null ||
          !(request.method == 'GET' ||
              request.method == 'HEAD' ||
              protectedWrite)) {
        return _failure(
          409,
          'session_restored_verify_result',
          'Phiên đã được khôi phục. Vui lòng kiểm tra kết quả trước khi thực hiện lại thao tác.',
        );
      }
      replay.headers['Authorization'] = 'Bearer $token';
      return await _sendOnce(
        replay,
      ); // Exactly one replay; never retry timeouts or 5xx.
    } on SessionUnavailable {
      return _failure(
        401,
        'session_unavailable',
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    } catch (_) {
      return _failure(
        503,
        'session_or_network_unavailable',
        'Chưa xác nhận được kết quả. Vui lòng kiểm tra kết quả thao tác và kết nối mạng trước khi thử lại.',
      );
    }
  }

  // Bound transport work after session preparation, including the response body.
  // No timeout/network error is ever an automatic replay trigger.
  Future<http.StreamedResponse> _sendOnce(http.BaseRequest request) async {
    final response = await _inner
        .send(request)
        .then(http.Response.fromStream)
        .timeout(
          Duration(seconds: request.url.path.startsWith('/hubs/') ? 60 : 25),
        );
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.bodyBytes.length,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      request: request,
    );
  }

  static http.Request _copy(http.Request source) =>
      http.Request(source.method, source.url)
        ..headers.addAll(source.headers)
        ..bodyBytes = List<int>.from(source.bodyBytes)
        ..followRedirects = source.followRedirects
        ..maxRedirects = source.maxRedirects
        ..persistentConnection = source.persistentConnection;

  @override
  void close() => _inner.close();
}
