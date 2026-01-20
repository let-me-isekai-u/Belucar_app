///Tài liệu cho file api này:
///https://docs.google.com/document/d/1MD5Tx42I-CpFgTNwrrwUhB8FsdQFhiiqAN_Xy0kUfAc/edit?tab=t.d9q2g56xpd8j
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static dynamic safeDecode(String? body) {
    if (body == null || body.isEmpty) return {};

    try {
      return jsonDecode(body);
    } catch (e) {
      print("⚠️ safeDecode() JSON lỗi: $e");
      print("⚠️ raw body: $body");
      return {};
    }
  }

  // -----------------------------------------------------------
  // BASE URL CHUẨN
  // -----------------------------------------------------------
  static const String _baseUrl =
      "https://belucar.belugaexpress.com/api/accountcustomerapi";

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
    final body = jsonEncode({
      "success": false,
      "message": "Lỗi kết nối tới server: $e",
    });
    return http.Response(body, 500,
        headers: {"Content-Type": "application/json"});
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
      return await http
          .post(url, headers: _defaultHeaders(), body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      // Trả về một Response lỗi giả lập nếu có sự cố kết nối để tránh Crash App
      return http.Response(jsonEncode({"message": "Lỗi kết nối mạng: $e"}), 500);
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
  static Future<http.Response> customerRegister({
    required String fullName,
    required String phone,
    required String email,
    required String password,
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


      if (referredByCode != null && referredByCode.isNotEmpty) {
        request.fields["referredByCode"] = referredByCode;
      }

      // Đính kèm avatar nếu có
      if (avatarFilePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath("avatar", avatarFilePath),
        );
      }

      final resStream = await request.send();
      return await http.Response.fromStream(resStream);
    } catch (e) {
      return _errorResponse(e);
    }
  }


  // -----------------------------------------------------------
  // 4️⃣ REFRESH TOKEN
  // -----------------------------------------------------------
  static Future<http.Response> refreshToken({
    required String refreshToken,
  }) async {
    final url = Uri.parse("$_baseUrl/refresh-token");

    try {
      final body = jsonEncode({"refreshToken": refreshToken});

      return await http
          .post(url, headers: _defaultHeaders(), body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return _errorResponse(e);
    }
  }

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

      final responseStream = await request.send();
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

      return await http
          .post(url, headers: _defaultHeaders(), body: body)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      return _errorResponse(e);
    }
  }

  // -----------------------------------------------------------
  // 7️⃣ RESET MẬT KHẨU BẰNG OTP
  // -----------------------------------------------------------
  static Future<http.Response> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final url = Uri.parse("$_baseUrl/reset-password");

    try {
      final body =
      jsonEncode({"email": email, "otp": otp, "newPassword": newPassword});

      return await http
          .post(url, headers: _defaultHeaders(), body: body)
          .timeout(const Duration(seconds: 20));
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
      return await http
          .get(url, headers: _authHeaders(accessToken))
          .timeout(const Duration(seconds: 20));
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
      final res = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 30));

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
    final url = Uri.parse("https://belucar.belugaexpress.com/api/accountcustomerapi/change-password");

    print("🔵 [API] CALL CHANGE PASSWORD → $url");
    print("📌 oldPassword: $oldPassword");
    print("📌 newPassword: $newPassword");

    try {
      final body = jsonEncode({
        "oldPassword": oldPassword,
        "newPassword": newPassword,
      });

      final res = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: body,
      ).timeout(const Duration(seconds: 20));

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
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/provinceapi/active",
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

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
  static Future<List<dynamic>> getDistricts({
    required int  provinceId,
  })
  async{
    final url = Uri.parse("https://belucar.belugaexpress.com/api/provinceapi/district/$provinceId",
    );

    try{
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200){
        final data = jsonDecode(response.body);
        if (data is List){
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


  //Lấy giá (12)
  static Future<http.Response> getTripPrice({
    required int fromDistrictId,
    required int toDistrictId,
    required int type,
    required int paymentMethod,
    required String pickupTime,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/tripapi/getprice",
    ).replace(queryParameters: {
      "fromDistrictId": fromDistrictId.toString(),
      "toDistrictId": toDistrictId.toString(),
      "type": type.toString(),
      "paymentMethod": paymentMethod.toString(),
      "pickupTime": pickupTime,
    });

    print("🔵 [PRICE] GET $url");

    try {
      final res = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      print("📥 Status: ${res.statusCode}");
      print("📥 Body: ${res.body}");
      return res;
    } catch (e) {
      return http.Response('{"error":"$e"}', 500);
    }
  }



// 13. API TẠO CHUYẾN ĐI
  static Future<http.Response> createRide({
    required String accessToken,
    required int tripId,
    required String fromAddress,
    required String toAddress,
    required String customerPhone,
    required String pickupTime,
    required int paymentMethod,
    String note = "",
    String content = "", // Để mặc định là rỗng nếu không truyền
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/rideapi/create",
    );

    // --- LỖI TẠI ĐÂY TRƯỚC ĐÓ: Bạn không được khai báo 'String content = ""' bên trong Map ---
    final body = jsonEncode({
      "tripId": tripId,
      "fromAddress": fromAddress,
      "toAddress": toAddress,
      "customerPhone": customerPhone,
      "pickupTime": pickupTime,
      "note": note,
      "paymentMethod": paymentMethod,
      "content": content, // Truyền giá trị từ tham số vào Key của JSON
    });

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      return response;
    } catch (e) {
      print("🔥 ERROR createRide(): $e");
      // Trả về một Response giả lập lỗi để tránh crash app
      return http.Response(
        jsonEncode({"success": false, "message": "Lỗi kết nối hệ thống: $e"}),
        500,
      );
    }
  }


  //Lấy chuyến đi đang diễn ra ở trạng thái 1 và 2 (api 14)
  static Future<http.Response>
  getTripCurrent({required String accessToken})
  async {
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $accessToken",
    };
    return await http.get(
        Uri.parse("https://belucar.belugaexpress.com/api/rideapi/current"),
        headers: headers);
  }

//Lấy chuyến đi đang diễn ra ở trạng thái 1 và 2 (api 15)
  static Future<http.Response>
  getTripHistory({required String accessToken})
  async {
    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $accessToken",
    };
    return await http.get(
        Uri.parse("https://belucar.belugaexpress.com/api/rideapi/history"),
        headers: headers);
  }

  // API 16: Lấy chi tiết chuyến đi
  static Future<Map<String, dynamic>> getTripDetail({
    required String accessToken,
    required int rideId,
  }) async {
    final uri = Uri.parse(
      'https://belucar.belugaexpress.com/api/rideapi/ride-detail/$rideId',
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      final body = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        if (body['success'] == true && body['data'] != null) {
          return body['data'] as Map<String, dynamic>;
        } else {
          throw Exception('API success = false');
        }
      }

      if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token hết hạn');
      }

      throw Exception(
        'Lỗi API ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      throw Exception('getTripDetail error: $e');
    }
  }


  //API 17: Cho phép người dùng huỷ cuốc đã đặt nhưng chưa có tài xế nhận (trạng thái 1)
  static Future<void> cancelTrip({
    required String accessToken,
    required int rideId,
}) async {
    final url = Uri.parse("https://belucar.belugaexpress.com/api/rideapi/cancel/$rideId",);
    final headers = {
      "Authorization": "Bearer $accessToken",
    };
    final response = await http.put(url, headers: headers);

    if(response.statusCode != 200){
      throw Exception("Huỷ chuyến không thành công,thử lại sau hoặc liên hệ với cskh");
    }
  }

  static Future<void> confirmCancelTrip({
    required String accessToken,
    required int rideId,
  }) async {
    final url = Uri.parse("https://belucar.belugaexpress.com/api/rideapi/cancel-confirmed/$rideId",);
    final headers = {
      "Authorization": "Bearer $accessToken",
    };
    final response = await http.put(url, headers: headers);

    if(response.statusCode != 200){
      throw Exception("Huỷ chuyến không thành công,thử lại sau hoặc liên hệ với cskh");
    }
  }

  //nạp tiền vào ví
  static Future<bool> depositWallet({
    required String accessToken,
    required double amount,
    required String content,
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/paymentapi/deposite",
    );

    try {
      final res = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "amount": amount,
          "content": content,
        }),
      ).timeout(const Duration(seconds: 20));

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
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/paymentapi/history",
    );

    print("🔵 [API] WALLET HISTORY → $url");

    try {
      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 20));

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
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/tetapi/getprice",
    ).replace(queryParameters: {
      "fromDistrictId": fromDistrictId.toString(),
      "toDistrictId": toDistrictId.toString(),
      "type": type.toString(),
      "paymentMethod": paymentMethod.toString(),
      "pickupTime": pickupTime,
    });

    print("🔵 [PRICE] GET $url");

    try {
      final res = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      print("📥 Status: ${res.statusCode}");
      print("📥 Body: ${res.body}");
      return res;
    } catch (e) {
      return http.Response('{"error":"$e"}', 500);
    }
  }

  //TẠO CHUYẾN ĐI NGÀY TẾT POST
  static Future<http.Response> createRideTET({
    required String accessToken,
    required int tripId,
    required String fromAddress,
    required String toAddress,
    required String customerPhone,
    required String pickupTime,
    required int paymentMethod,
    String note = "",
    String content = "", // Để mặc định là rỗng nếu không truyền
  }) async {
    final url = Uri.parse(
      "https://belucar.belugaexpress.com/api/tetapi/create",
    );

    final body = jsonEncode({
      "tripId": tripId,
      "fromAddress": fromAddress,
      "toAddress": toAddress,
      "customerPhone": customerPhone,
      "pickupTime": pickupTime,
      "note": note,
      "paymentMethod": paymentMethod,
      "content": content, // Truyền giá trị từ tham số vào Key của JSON
    });

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      return response;
    } catch (e) {
      print("🔥 ERROR createRide(): $e");
      // Trả về một Response giả lập lỗi để tránh crash app
      return http.Response(
        jsonEncode({"success": false, "message": "Lỗi kết nối hệ thống: $e"}),
        500,
      );
    }
  }
}
