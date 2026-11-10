// Module Nhà xe (Xe limousine / Xe khách) — gọi /api/carrier/* bằng JWT khách hiện có.
// Contract: docs/api/carrier-module-api.md (mục 1) của backend. Giá luôn do server tính.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';

class CarrierApiException implements Exception {
  CarrierApiException(this.message, {this.status = 0});
  final String message;
  final int status;
  bool get needsLogin => status == 401;
  @override
  String toString() => message;
}

class CarrierApi {
  static const String base = '$apiOrigin/api/carrier';

  /// Khóa chống trùng cho lệnh tạo vé: bấm lại/mạng chập chờn sẽ nhận lại đúng kết quả cũ.
  static String newIdempotencyKey() => ApiService.newIdempotencyKey();

  static Future<dynamic> _call(String method, String path, {Object? body, bool auth = false, String? idempotencyKey}) async {
    final prefs = await SharedPreferences.getInstance();
    Future<http.Response> send(String? token) {
      final req = http.Request(method, Uri.parse('$base$path'))..headers['Accept'] = 'application/json';
      if (auth && token != null && token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
      if (idempotencyKey != null) req.headers['Idempotency-Key'] = idempotencyKey;
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      return req.send().then(http.Response.fromStream).timeout(const Duration(seconds: 25));
    }

    http.Response r;
    try {
      final token = prefs.getString('accessToken');
      r = await send(token);
      if (auth && r.statusCode == 401 && token != null) {
        final renewedAccess = await ApiService.refreshRejectedAccessToken(token);
        if (renewedAccess != null) r = await send(renewedAccess);
      }
    } catch (_) {
      throw CarrierApiException('Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');
    }
    dynamic decoded;
    try {
      decoded = r.body.isEmpty ? {} : jsonDecode(r.body);
    } catch (_) {
      decoded = {};
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final msg = decoded is Map && decoded['message'] is String
          ? decoded['message'] as String
          : r.statusCode == 401
              ? 'Vui lòng đăng nhập để tiếp tục.'
              : r.statusCode == 404
                  ? 'Chức năng xe limousine/xe khách chưa mở.'
                  : 'Lỗi máy chủ (${r.statusCode}).';
      throw CarrierApiException(msg, status: r.statusCode);
    }
    return decoded is Map && decoded.containsKey('data') ? decoded['data'] : decoded;
  }

  static Future<Map<String, dynamic>> search({
    required String fromPlaceId,
    required String toPlaceId,
    required String travelDate,
    required String category,
    required int passengers,
    String? preferredTime,
    String sort = 'nearest',
  }) async =>
      Map<String, dynamic>.from(await _call('POST', '/search', body: {
        'from': {'placeId': fromPlaceId},
        'to': {'placeId': toPlaceId},
        'travelDate': travelDate,
        'vehicleCategories': [category],
        'passengerCount': passengers,
        if (preferredTime != null && preferredTime.isNotEmpty) 'preferredDepartureTime': preferredTime,
        'sort': sort,
      }) as Map);

  static Future<Map<String, dynamic>> run(int runId) async => Map<String, dynamic>.from(await _call('GET', '/runs/$runId') as Map);

  static Future<Map<String, dynamic>> quote(int runId, int pickup, int dropoff, int pax) async =>
      Map<String, dynamic>.from(await _call('POST', '/quotes',
          body: {'runId': runId, 'pickupRunStopId': pickup, 'dropoffRunStopId': dropoff, 'passengerCount': pax}) as Map);

  static Future<Map<String, dynamic>> book(Map<String, dynamic> body, String idempotencyKey) async =>
      Map<String, dynamic>.from(await _call('POST', '/bookings', body: body, auth: true, idempotencyKey: idempotencyKey) as Map);

  static Future<Map<String, dynamic>> booking(String code) async =>
      Map<String, dynamic>.from(await _call('GET', '/bookings/${Uri.encodeComponent(code)}', auth: true) as Map);

  static Future<Map<String, dynamic>> myBookings(int page) async =>
      Map<String, dynamic>.from(await _call('GET', '/bookings?page=$page', auth: true) as Map);

  /// Trả vé đang chờ thanh toán bằng ví Beluga (đủ số dư, trả toàn bộ). Vé xác nhận ngay.
  static Future<Map<String, dynamic>> payWallet(String code) async => Map<String, dynamic>.from(
      await _call('POST', '/bookings/${Uri.encodeComponent(code)}/pay-wallet', body: {}, auth: true, idempotencyKey: newIdempotencyKey()) as Map);

  /// Chính sách hoàn vé dùng chung: [{minHoursBeforePickup, refundPercent}].
  static Future<List<Map<String, dynamic>>> refundPolicy() async {
    final data = await _call('GET', '/refund-policy');
    final tiers = data is Map ? data['tiers'] : null;
    return tiers is List ? tiers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  static Future<void> cancel(String code) =>
      _call('POST', '/bookings/${Uri.encodeComponent(code)}/cancel', body: {}, auth: true, idempotencyKey: newIdempotencyKey());

  static Future<Map<String, dynamic>> tracking(int runId) async =>
      Map<String, dynamic>.from(await _call('GET', '/runs/$runId/tracking', auth: true) as Map);

  /// Gợi ý địa chỉ TrackAsia (endpoint có sẵn của app).
  static Future<List<Map<String, dynamic>>> places(String input) async {
    final res = await ApiService.autocompleteTrackAsia(input: input, size: 8);
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    final list = decoded is List ? decoded : decoded is Map ? (decoded['data'] ?? decoded['items'] ?? decoded['results']) : null;
    return list is List ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }
}
