import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/concert_models.dart';

class ConcertApiResponse<T> {
  const ConcertApiResponse({required this.statusCode, this.data, this.message});

  final int statusCode;
  final T? data;
  final String? message;

  bool get isSuccess => statusCode >= 200 && statusCode < 300 && data != null;
  bool get isUnauthorized => statusCode == 401;
}

class ConcertApiService {
  ConcertApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = _normalizeBaseUrl(
        baseUrl ??
            const String.fromEnvironment(
              'CONCERT_API_BASE_URL',
              defaultValue: 'https://xeghepdongduong.com',
            ),
      );

  static const eventCode = 'BIGBANG_MYDINH_2026';
  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String _baseUrl;

  Future<ConcertApiResponse<ConcertCatalog>> getCatalog() => _send(
    method: 'GET',
    path: '/api/v1/concert/catalog',
    query: const <String, String>{'eventCode': eventCode},
    decode: (json) => ConcertCatalog.fromJson(_jsonMap(json)),
  );

  Future<ConcertApiResponse<ConcertQuote>> quote(List<ConcertCartItem> items) =>
      _send(
        method: 'POST',
        path: '/api/v1/concert/quote',
        body: <String, dynamic>{
          'eventCode': eventCode,
          'items': items.map((item) => item.toJson()).toList(),
        },
        decode: (json) => ConcertQuote.fromJson(_jsonMap(json)),
      );

  Future<ConcertApiResponse<ConcertOrder>> createOrder({
    required String contactFullName,
    required String contactPhone,
    required String contactEmail,
    required List<ConcertCartItem> items,
    String? accessToken,
  }) => _send(
    method: 'POST',
    path: '/api/v1/concert/orders',
    accessToken: accessToken,
    body: <String, dynamic>{
      'eventCode': eventCode,
      'contactFullName': contactFullName,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'items': items.map((item) => item.toJson()).toList(),
    },
    decode: (json) => ConcertOrder.fromJson(_jsonMap(json)),
  );

  Future<ConcertApiResponse<ConcertOrder>> getOrder({
    required String orderCode,
    String? accessToken,
    String? guestAccessToken,
  }) => _send(
    method: 'GET',
    path: '/api/v1/concert/orders/${Uri.encodeComponent(orderCode)}',
    accessToken: accessToken,
    guestAccessToken: guestAccessToken,
    decode: (json) => ConcertOrder.fromJson(_jsonMap(json)),
  );

  Future<ConcertApiResponse<List<ConcertOrder>>> getMyOrders({
    required String accessToken,
  }) => _send(
    method: 'GET',
    path: '/api/v1/concert/me/orders',
    accessToken: accessToken,
    decode: (json) => _decodeList(json, ConcertOrder.fromJson),
  );

  Future<ConcertApiResponse<List<ConcertTicket>>> getMyTickets({
    required String accessToken,
    String? status,
  }) => _send(
    method: 'GET',
    path: '/api/v1/concert/me/tickets',
    query: status == null ? null : <String, String>{'status': status},
    accessToken: accessToken,
    decode: (json) => _decodeList(json, ConcertTicket.fromJson),
  );

  Future<ConcertApiResponse<ConcertTicket>> getTicket({
    required String ticketCode,
    required String accessToken,
  }) => _send(
    method: 'GET',
    path: '/api/v1/concert/me/tickets/${Uri.encodeComponent(ticketCode)}',
    accessToken: accessToken,
    decode: (json) => ConcertTicket.fromJson(_jsonMap(json)),
  );

  Future<ConcertApiResponse<bool>> resendEmail({
    required String orderCode,
    String? accessToken,
    String? guestAccessToken,
  }) => _send(
    method: 'POST',
    path:
        '/api/v1/concert/orders/${Uri.encodeComponent(orderCode)}/resend-email',
    accessToken: accessToken,
    guestAccessToken: guestAccessToken,
    decode: (_) => true,
  );

  Future<ConcertApiResponse<T>> _send<T>({
    required String method,
    required String path,
    required T Function(dynamic json) decode,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? accessToken,
    String? guestAccessToken,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json; charset=utf-8',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
      if (guestAccessToken != null && guestAccessToken.isNotEmpty)
        'X-Concert-Guest-Token': guestAccessToken,
    };

    try {
      final response = switch (method) {
        'GET' => await _client.get(uri, headers: headers).timeout(_timeout),
        'POST' =>
          await _client
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(_timeout),
        _ => throw UnsupportedError('Unsupported HTTP method: $method'),
      };
      final payload = _decodePayload(response.body);
      final message = _extractMessage(payload);
      final successfulStatus =
          response.statusCode >= 200 && response.statusCode < 300;
      final envelopeSucceeded = payload is! Map || payload['success'] != false;
      if (!successfulStatus || !envelopeSucceeded) {
        return ConcertApiResponse<T>(
          statusCode: response.statusCode,
          message: message,
        );
      }

      final dynamic data = payload is Map && payload.containsKey('data')
          ? payload['data']
          : payload;
      try {
        return ConcertApiResponse<T>(
          statusCode: response.statusCode,
          data: decode(data),
          message: message,
        );
      } catch (_) {
        return ConcertApiResponse<T>(
          statusCode: response.statusCode,
          message: 'Dữ liệu phản hồi từ server không đúng định dạng.',
        );
      }
    } on TimeoutException {
      return ConcertApiResponse<T>(
        statusCode: 408,
        message: 'Kết nối quá thời gian. Vui lòng kiểm tra mạng và thử lại.',
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ConcertApi] $method $path failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return ConcertApiResponse<T>(
        statusCode: 0,
        message: 'Không thể kết nối tới server. Vui lòng thử lại.',
      );
    }
  }

  static dynamic _decodePayload(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _extractMessage(dynamic payload) {
    if (payload is! Map) return 'Yêu cầu không thành công.';
    final direct = payload['message']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final title = payload['title']?.toString().trim();
    final errors = payload['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        final text = value?.toString().trim();
        if (text != null && text.isNotEmpty) return text;
      }
    }
    if (title != null && title.isNotEmpty) return title;
    return 'Yêu cầu không thành công.';
  }

  static List<T> _decodeList<T>(
    dynamic json,
    T Function(Map<String, dynamic>) decode,
  ) {
    if (json is! List) return <T>[];
    return json.whereType<Map>().map((item) {
      final map = item.map((key, value) => MapEntry(key.toString(), value));
      return decode(map);
    }).toList();
  }

  static Map<String, dynamic> _jsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
