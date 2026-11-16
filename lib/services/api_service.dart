///Tài liệu cho file api này:
///https://docs.google.com/document/d/1MD5Tx42I-CpFgTNwrrwUhB8FsdQFhiiqAN_Xy0kUfAc/edit?tab=t.d9q2g56xpd8j
///API 21, 22 TẠM chưa dùng tới
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;
import 'customer_session.dart';

import '../models/deposit_model.dart';
import '../models/location_models.dart';

class RideCancellationException implements Exception {
  const RideCancellationException(this.message, {this.status = 0, this.code});

  final String message;
  final int status;
  final String? code;
  bool get wasRejected =>
      code == 'ride_not_cancellable' ||
      (status >= 400 && status < 500 && status != 401 && status != 409);

  @override
  String toString() => message;
}

class ApiResponseFailure implements Exception {
  const ApiResponseFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  static String newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static http.Response _jsonResponse(
    Map<String, dynamic> payload,
    int statusCode,
  ) {
    final body = jsonEncode(payload);
    return http.Response.bytes(
      utf8.encode(body),
      statusCode,
      headers: {"Content-Type": "application/json; charset=utf-8"},
    );
  }

  static dynamic safeDecode(String? body) {
    if (body == null || body.isEmpty) return {};

    try {
      return jsonDecode(body);
    } on FormatException {
      return {};
    }
  }

  static Map<String, dynamic>? responseJson(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data is Map<String, dynamic> ? data : null;
    } on FormatException {
      return null;
    }
  }

  static String responseError(http.Response response, String fallback) {
    final body = responseJson(response);
    final message = body?['message'] ?? body?['title'];
    if (message is String && message.trim().isNotEmpty) return message;
    return switch (response.statusCode) {
      401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      429 => 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.',
      _ => fallback,
    };
  }

  // -----------------------------------------------------------
  // BASE URL CHUẨN
  // -----------------------------------------------------------
  static const String _baseUrl = "$apiOrigin/api/accountcustomerapi";

  // Default headers
  static Map<String, String> _defaultHeaders() => {
    "Accept": "application/json",
    "Content-Type": "application/json",
  };

  // Auth headers
  static Map<String, String> _authHeaders(String accessToken) => {
    "Accept": "application/json",
    "Authorization": "Bearer $accessToken",
  };

  // Lỗi fallback
  static http.Response _errorResponse(Object e) {
    final timedOut = e is TimeoutException;
    return _jsonResponse({
      "success": false,
      "code": timedOut ? "connection_timeout" : "connection_failed",
      "message": timedOut
          ? "Máy chủ phản hồi quá chậm. Vui lòng thử lại."
          : "Không kết nối được máy chủ. Vui lòng kiểm tra mạng và thử lại.",
    }, timedOut ? 504 : 503);
  }

  // -----------------------------------------------------------
  // 1️⃣ LOGIN
  // -----------------------------------------------------------
  static Future<http.Response> customerLogin({
    required String phone,
    required String password,
    required String deviceToken,
  }) async {
    final url = Uri.parse("$_baseUrl/customer/login");

    try {
      // Build body đúng theo tài liệu API
      final body = jsonEncode({
        "phone": phone,
        "password": password,
        "deviceToken": deviceToken,
      });

      // Thực hiện gọi POST
      return await customerHttp.post(
        url,
        headers: _defaultHeaders(),
        body: body,
      );
    } catch (e) {
      // Trả về một Response lỗi giả lập nếu có sự cố kết nối để tránh Crash App
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // 2️⃣ LOGOUT
  // -----------------------------------------------------------
  static Future<http.Response> logout(String accessToken) async {
    final url = Uri.parse("$_baseUrl/logout");

    try {
      return await http
          .post(url, headers: _authHeaders(accessToken))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // 3️⃣ ĐĂNG KÝ (FORM-DATA + FILE)
  // -----------------------------------------------------------
  static Future<http.Response> sendRegistrationCode({
    required String email,
    required String phone,
  }) async {
    try {
      return await customerHttp.post(
        Uri.parse('$apiOrigin/api/identity/challenges'),
        headers: _defaultHeaders(),
        body: jsonEncode({
          'ownerType': 1,
          'purpose': 'register',
          'email': email,
          'phone': phone,
        }),
      );
    } catch (_) {
      return _jsonResponse({
        'message': 'Không thể kết nối. Vui lòng thử lại.',
      }, 503);
    }
  }

  static Future<http.Response> customerRegister({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String challengeId,
    required String otp,
    required String avatarFilePath,
    String? referredByCode, // 👈 thêm mã giới thiệu (optional)
  }) async {
    final url = Uri.parse("$_baseUrl/customer-register");

    try {
      final request = http.MultipartRequest("POST", url);

      request.fields["fullName"] = fullName;
      request.fields["phone"] = phone;
      request.fields["email"] = email;
      request.fields["password"] = password;
      request.fields["challengeId"] = challengeId;
      request.fields["otp"] = otp;

      if (referredByCode != null && referredByCode.isNotEmpty) {
        request.fields["referredByCode"] = referredByCode;
      }

      // Đính kèm avatar nếu có
      if (avatarFilePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath("avatar", avatarFilePath),
        );
      }

      return await request
          .send()
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      return _jsonResponse({
        'message': 'Không thể kết nối. Vui lòng thử lại.',
      }, 503);
    }
  }

  static Future<http.Response> _withCustomerSession(
    String accessToken,
    Future<http.Response> Function(String token) send,
  ) => send(
    accessToken,
  ); // Authentication and replay live in CustomerHttpClient.

  // -----------------------------------------------------------
  // 5️⃣ UPDATE PROFILE (PUT – FORM-DATA)
  // -----------------------------------------------------------
  static Future<http.Response> updateProfile({
    required String accessToken,
    required String fullName,
    required String email,
    String? avatarFilePath, // optional
  }) async {
    final url = Uri.parse("$_baseUrl/customer-update-profile");

    try {
      final request = http.MultipartRequest("PUT", url);

      request.headers["Authorization"] = "Bearer $accessToken";
      request.headers["Accept"] = "application/json";

      request.fields["fullName"] = fullName;
      request.fields["email"] = email;

      if (avatarFilePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath("avatar", avatarFilePath),
        );
      }

      final responseStream = await customerHttp.send(request);
      return await http.Response.fromStream(responseStream);
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // 6️⃣ GỬI OTP QUÊN MẬT KHẨU
  // -----------------------------------------------------------
  static Future<http.Response> sendForgotPasswordOtp({
    required String email,
  }) async {
    final url = Uri.parse("$_baseUrl/forgot-password");

    try {
      final body = jsonEncode({"email": email});

      return await customerHttp.post(
        url,
        headers: _defaultHeaders(),
        body: body,
      );
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // 7️⃣ RESET MẬT KHẨU BẰNG OTP
  // -----------------------------------------------------------
  static Future<http.Response> resetPassword({
    required String email,
    required String challengeId,
    required String otp,
    required String newPassword,
  }) async {
    final url = Uri.parse("$_baseUrl/reset-password");

    try {
      final body = jsonEncode({
        "email": email,
        "challengeId": challengeId,
        "otp": otp,
        "newPassword": newPassword,
      });

      return await customerHttp.post(
        url,
        headers: _defaultHeaders(),
        body: body,
      );
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // 8️⃣ LẤY PROFILE KHÁCH HÀNG
  // -----------------------------------------------------------
  static Future<http.Response> getCustomerProfile({
    required String accessToken,
  }) async {
    final url = Uri.parse("$_baseUrl/profile");

    try {
      return await customerHttp.get(url, headers: _authHeaders(accessToken));
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // (10) Xoá tài khoản
  static Future<http.Response> deleteAccount({
    required String accessToken,
  }) async {
    final url = Uri.parse("$_baseUrl/delete");

    print("🔵 [API] CALL DELETE ACCOUNT → $url");

    try {
      final res = await customerHttp.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      );

      print("📥 [API] Status: ${res.statusCode}");
      print("📥 [API] Body: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] ERROR DELETE ACCOUNT: $e");
      return _errorResponse(e);
    }
  }

  //(11) Đổi mật khẩu
  static Future<http.Response> changePassword({
    required String accessToken,
    required String oldPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse("$apiOrigin/api/accountcustomerapi/change-password");

    print("🔵 [API] CALL CHANGE PASSWORD → $url");

    try {
      final body = jsonEncode({
        "oldPassword": oldPassword,
        "newPassword": newPassword,
      });

      final res = await customerHttp.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: body,
      );

      print("📥 [API] Status: ${res.statusCode}");
      print("📥 [API] Body: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] ERROR CHANGE PASSWORD: $e");
      return _errorResponse(e);
    }
  }

  // =============================
  // Lấy danh sách Tỉnh
  // =============================
  static Future<List<dynamic>> getProvinces() async {
    final url = Uri.parse("$apiOrigin/api/provinceapi/active");

    try {
      final response = await customerHttp.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        }
      }

      print("⚠️ getProvinces(): Unexpected response ${response.statusCode}");
      return [];
    } catch (e) {
      print("🔥 getProvinces() ERROR: $e");
      return [];
    }
  }

  //Lấy huyện theo tỉnh
  static Future<List<dynamic>> getDistricts({required int provinceId}) async {
    final url = Uri.parse("$apiOrigin/api/provinceapi/district/$provinceId");

    try {
      final response = await customerHttp.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        }
      }

      print("⚠️ getDistricts: Unexpected response ${response.statusCode}");
      return [];
    } catch (e) {
      print("🔥 getDistricts() ERROR: $e");
      return [];
    }
  }

  static Future<http.Response> autocompleteTrackAsia({
    required String input,
    String? location,
    int size = 10,
  }) async {
    final url = Uri.parse("$apiOrigin/api/track-asia/autocomplete").replace(
      queryParameters: {
        "input": input,
        "size": size.toString(),
        if (location != null && location.trim().isNotEmpty)
          "location": location.trim(),
      },
    );

    try {
      return await customerHttp.get(
        url,
        headers: {"Accept": "application/json"},
      );
    } catch (e) {
      return _errorResponse(e);
    }
  }

  static Future<http.Response> getTrackAsiaPlaceDetail({
    required String placeId,
  }) async {
    final url = Uri.parse(
      "$apiOrigin/api/track-asia/place-detail",
    ).replace(queryParameters: {"placeId": placeId});

    try {
      return await customerHttp.get(
        url,
        headers: {"Accept": "application/json"},
      );
    } catch (e) {
      return _errorResponse(e);
    }
  }

  static Future<http.Response> resolveAddressPoint({
    required double lat,
    required double lng,
  }) async {
    final url = Uri.parse("$apiOrigin/api/v2/address/resolve-point");

    try {
      final body = jsonEncode({"lat": lat, "lng": lng});
      return await customerHttp.post(
        url,
        headers: _defaultHeaders(),
        body: body,
      );
    } catch (e) {
      return _errorResponse(e);
    }
  }

  static Future<http.Response> resolveRoutePreview({
    required RidePointPayload from,
    required RidePointPayload to,
    required int type,
    required String pickupTime,
    required int paymentMethod,
    required int quantity,
  }) async {
    final url = Uri.parse("$apiOrigin/api/v2/address/resolve-route");

    try {
      final body = jsonEncode({
        "from": from.toJson(),
        "to": to.toJson(),
        "type": type,
        "pickupTime": pickupTime,
        "paymentMethod": paymentMethod,
        "quantity": quantity,
      });

      return await customerHttp.post(
        url,
        headers: _defaultHeaders(),
        body: body,
      );
    } catch (e) {
      return _errorResponse(e);
    }
  }

  //Lấy giá (12)
  static Future<http.Response> getTripPrice({
    required int fromDistrictId,
    required int toDistrictId,
    required int type,
    required int paymentMethod,
    required String pickupTime,
    required int quantity,
  }) async {
    final url = Uri.parse("$apiOrigin/api/tripapi/getprice").replace(
      queryParameters: <String, String>{
        "fromDistrictId": fromDistrictId.toString(),
        "toDistrictId": toDistrictId.toString(),
        "type": type.toString(),
        "paymentMethod": paymentMethod.toString(),
        "pickupTime": pickupTime,
        "quantity": quantity.toString(),
      },
    );

    print("🔵 [PRICE] GET $url");

    try {
      final res = await customerHttp.get(url);

      print("📥 Status: ${res.statusCode}");
      print("📥 Body: ${res.body}");
      return res;
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // 13. API TẠO CHUYẾN ĐI
  static Future<http.Response> createRide({
    required String accessToken,
    required int tripId,
    required RidePointPayload from,
    required RidePointPayload to,
    required int type,
    required String customerPhone,
    required bool isBookingForOther,
    required String pickupTime,
    required int paymentMethod,
    required int quantity,
    String note = "",
    String? content,
  }) async {
    final url = Uri.parse("$apiOrigin/api/v2/ride/create");
    final idempotencyKey = newIdempotencyKey();

    final body = jsonEncode({
      "tripId": tripId,
      "from": from.toJson(),
      "to": to.toJson(),
      "type": type,
      "customerPhone": customerPhone,
      "isBookingForOther": isBookingForOther,
      "pickupTime": pickupTime,
      "note": note,
      "paymentMethod": paymentMethod,
      "content": content,
      "voucherCode": null,
      "quantity": quantity,
    });

    Future<http.Response> send(String token) => customerHttp.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
        "Idempotency-Key": idempotencyKey,
      },
      body: body,
    );

    try {
      return await _withCustomerSession(accessToken, send);
    } catch (_) {
      return _jsonResponse({
        "success": false,
        "message":
            "Chưa xác nhận được kết quả. Vui lòng kiểm tra Hoạt động trước khi đặt lại.",
      }, 500);
    }
  }

  //Lấy chuyến đi đang diễn ra ở trạng thái 1 và 2 (api 14)
  static Future<http.Response> getTripCurrent({required String accessToken}) =>
      _getTripList(accessToken, 'current');

  //Lấy chuyến đi đang diễn ra ở trạng thái 1 và 2 (api 15)
  static Future<http.Response> getTripHistory({required String accessToken}) =>
      _getTripList(accessToken, 'history');

  static Future<http.Response> _getTripList(String accessToken, String action) {
    final uri = Uri.parse("$apiOrigin/api/rideapi/$action");
    return _withCustomerSession(
      accessToken,
      (token) => customerHttp.get(uri, headers: _authHeaders(token)),
    );
  }

  // API 16: Lấy chi tiết chuyến đi
  static Future<Map<String, dynamic>> getTripDetail({
    required String accessToken,
    required int rideId,
  }) async {
    final uri = Uri.parse('$apiOrigin/api/rideapi/ride-detail/$rideId');

    final http.Response response;
    try {
      response = await _withCustomerSession(
        accessToken,
        (token) => customerHttp.get(uri, headers: _authHeaders(token)),
      );
    } catch (error) {
      throw ApiResponseFailure(
        responseError(_errorResponse(error), 'Không tải được chi tiết chuyến.'),
      );
    }
    final body = responseJson(response);
    final data = body?['data'];
    if (response.statusCode == 200 &&
        body?['success'] == true &&
        data is Map<String, dynamic>) {
      return data;
    }
    throw ApiResponseFailure(
      responseError(response, 'Không tải được chi tiết chuyến.'),
    );
  }

  static Future<void> cancelTrip({
    required String accessToken,
    required int rideId,
    required String idempotencyKey,
    required bool confirmed,
  }) async {
    final action = confirmed ? 'cancel-confirmed' : 'cancel';
    final url = Uri.parse("$apiOrigin/api/rideapi/$action/$rideId");
    const uncertain =
        'Chưa xác nhận được kết quả hủy. Vui lòng kiểm tra Hoạt động trước khi thử lại.';

    final http.Response response;
    try {
      response = await _withCustomerSession(
        accessToken,
        (token) => customerHttp.put(
          url,
          headers: {..._authHeaders(token), "Idempotency-Key": idempotencyKey},
        ),
      );
    } catch (_) {
      throw const RideCancellationException(uncertain);
    }

    final status = response.statusCode;
    if (status == 200) return;
    if (status == 401) {
      throw const RideCancellationException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để hủy chuyến.',
        status: 401,
      );
    }
    if (status >= 500) {
      throw RideCancellationException(uncertain, status: status);
    }

    throw RideCancellationException(
      responseError(response, 'Không thể hủy chuyến (HTTP $status).'),
      status: status,
      code: responseJson(response)?['code']?.toString(),
    );
  }

  //nạp tiền vào ví
  static Future<bool> depositWallet({
    required String accessToken,
    required double amount,
    required String content,
  }) async {
    final url = Uri.parse("$apiOrigin/api/paymentapi/deposite");

    try {
      final res = await customerHttp.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"amount": amount, "content": content}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        /// theo tài liệu: success = true mới hợp lệ
        return data["success"] == true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  //lấy lịch sử thay đổi số dư ví
  static Future<http.Response> getWalletHistory({
    required String accessToken,
  }) async {
    final url = Uri.parse("$apiOrigin/api/paymentapi/history");

    print("🔵 [API] WALLET HISTORY → $url");

    try {
      final res = await customerHttp.get(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      );

      print("📥 [API] STATUS: ${res.statusCode}");
      print("📥 [API] BODY: ${res.body}");

      return res;
    } catch (e) {
      print("❌ [API] WALLET HISTORY ERROR: $e");
      return _errorResponse(e);
    }
  }

  //====TẾT=========//
  //LẤY GIÁ SỰ KIỆN TÊT
  static Future<http.Response> getTripPriceTET({
    required int fromDistrictId,
    required int toDistrictId,
    required int type,
    required int paymentMethod,
    required String pickupTime,
  }) async {
    final url = Uri.parse("$apiOrigin/api/tetapi/getprice").replace(
      queryParameters: {
        "fromDistrictId": fromDistrictId.toString(),
        "toDistrictId": toDistrictId.toString(),
        "type": type.toString(),
        "paymentMethod": paymentMethod.toString(),
        "pickupTime": pickupTime,
      },
    );

    try {
      final res = await customerHttp.get(url);
      return res;
    } catch (e) {
      return _errorResponse(e);
    }
  }

  /// Tạo chuyến đi Tết (bổ sung voucherCode, trả đúng theo tài liệu)
  static Future<http.Response> createRideTET({
    required String accessToken,
    required int tripId,
    required String fromAddress,
    required String toAddress,
    required String customerPhone,
    required String pickupTime,
    required int paymentMethod,
    String note = "",
    String content =
        "", // truyền "" nếu thanh toán sau, truyền mã cố định nếu chuyển khoản
    String voucherCode = "", // voucherCode nên có parameter riêng
  }) async {
    final url = Uri.parse("$apiOrigin/api/tetapi/create");

    final body = jsonEncode({
      "tripId": tripId,
      "fromAddress": fromAddress,
      "toAddress": toAddress,
      "customerPhone": customerPhone,
      "pickupTime": pickupTime,
      "note": note,
      "paymentMethod": paymentMethod,
      "content": content,
      "voucherCode": voucherCode,
    });

    try {
      final response = await customerHttp.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: body,
      );
      return response;
    } catch (e) {
      return _errorResponse(e);
    }
  }

  /// Áp dụng voucher Tết lấy giá (chuẩn hóa đúng spec)
  static Future<Map<String, dynamic>> applyVoucherTET({
    required String accessToken,
    required int tripId,
    required String pickupTime,
    required String voucherCode,
  }) async {
    final url = Uri.parse("$apiOrigin/api/tetapi/apply-voucher");

    try {
      final response = await customerHttp.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "tripId": tripId,
          "pickupTime": pickupTime,
          "voucherCode": voucherCode,
        }),
      );

      final json = jsonDecode(response.body);

      // Chuẩn hóa mọi trường hợp kể cả success = false
      return {
        "success": json["success"] == true,
        "data": json["data"],
        "message": json["message"] ?? json["error"] ?? null,
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Không thể kết nối hệ thống",
        "data": null,
      };
    }
  }

  // 21. Tạo content trả về khi nạp tiền (POST)
  static Future<DepositContentResponse> createDepositContent({
    required String accessToken,
    required double amount,
  }) async {
    final url = Uri.parse("$apiOrigin/api/depositapi/create");
    try {
      final response = await customerHttp.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({"amount": amount}),
      );

      final data = safeDecode(response.body);
      if (data is Map<String, dynamic>) {
        return DepositContentResponse.fromJson(data);
      }

      if (data is Map) {
        return DepositContentResponse.fromJson(Map<String, dynamic>.from(data));
      }

      return DepositContentResponse(
        success: false,
        message: 'Dữ liệu phản hồi không hợp lệ.',
      );
    } catch (e) {
      return DepositContentResponse(
        success: false,
        message: "Không thể tạo nạp tiền, lỗi: $e",
      );
    }
  }

  // 22. Hủy nạp tiền sau khi hiện QR (PUT)
  static Future<CancelDepositResponse> cancelDeposit({
    required String accessToken,
    required int depositId,
  }) async {
    final url = Uri.parse("$apiOrigin/api/depositapi/cancel/$depositId");
    try {
      final response = await customerHttp.put(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      );

      if (response.body.isEmpty) {
        return CancelDepositResponse(success: response.statusCode == 200);
      }

      final data = safeDecode(response.body);
      if (data is Map<String, dynamic>) {
        return CancelDepositResponse.fromJson(data);
      }

      if (data is Map) {
        return CancelDepositResponse.fromJson(Map<String, dynamic>.from(data));
      }

      return CancelDepositResponse(
        success: response.statusCode == 200,
        message: response.statusCode == 200
            ? null
            : 'Không thể huỷ yêu cầu nạp tiền.',
      );
    } catch (e) {
      return CancelDepositResponse(
        success: false,
        message: 'Không thể huỷ yêu cầu nạp tiền, lỗi: $e',
      );
    }
  }
}
