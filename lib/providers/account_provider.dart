import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer_profile_model.dart';
import '../models/provider_result.dart';
import '../models/wallet_model.dart';
import '../services/api_service.dart';
import '../services/login_credential_storage.dart';
import 'auth_provider.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider({required AuthProvider authProvider})
    : _authProvider = authProvider;

  final AuthProvider _authProvider;
  CustomerProfileModel? _profile;
  bool _isLoading = false;

  CustomerProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;

  Future<ProviderResult<CustomerProfileModel>> loadProfile({
    bool notify = true,
  }) async {
    if (notify) _setLoading(true);
    try {
      final response = await _authProvider.authorizedRequest(
        (token) => ApiService.getCustomerProfile(accessToken: token),
        isUnauthorized: (response) => response.statusCode == 401,
      );
      if (response.statusCode != 200) {
        return ProviderResult.failure(
          'Không thể tải thông tin. Vui lòng đăng nhập lại.',
          statusCode: response.statusCode,
        );
      }
      _profile = CustomerProfileModel.fromJson(_decodeMap(response.body));
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString('fullName', _profile!.fullName),
        prefs.setString('phone', _profile!.phone),
        prefs.setString('email', _profile!.email),
        prefs.setInt('id', _profile!.id),
      ]);
      if (notify) notifyListeners();
      return ProviderResult.success(_profile);
    } catch (error) {
      return ProviderResult.failure('Lỗi kết nối máy chủ: $error');
    } finally {
      if (notify) _setLoading(false);
    }
  }

  Future<ProviderResult<void>> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String avatarFilePath,
    String? referredByCode,
  }) async {
    _setLoading(true);
    try {
      final response = await ApiService.customerRegister(
        fullName: fullName,
        phone: phone,
        email: email,
        password: password,
        avatarFilePath: avatarFilePath,
        referredByCode: referredByCode,
      );
      final body = _decodeMap(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return const ProviderResult.success();
      }
      return ProviderResult.failure(
        body['message']?.toString() ?? 'Đăng ký thất bại',
        statusCode: response.statusCode,
      );
    } catch (error) {
      return ProviderResult.failure('Không thể đăng ký: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<ProviderResult<void>> sendForgotPasswordOtp(String email) async {
    final response = await ApiService.sendForgotPasswordOtp(email: email);
    final body = _decodeMap(response.body);
    if (response.statusCode == 200) {
      return const ProviderResult.success();
    }
    return ProviderResult.failure(
      body['message']?.toString() ?? 'Không thể gửi mã xác nhận',
      statusCode: response.statusCode,
    );
  }

  Future<ProviderResult<void>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await ApiService.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
    final body = _decodeMap(response.body);
    if (response.statusCode == 200) {
      return const ProviderResult.success();
    }
    return ProviderResult.failure(
      body['message']?.toString() ?? 'Đặt lại mật khẩu thất bại',
      statusCode: response.statusCode,
    );
  }

  Future<ProviderResult<void>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (await _authProvider.requireAccessToken() == null) {
      return const ProviderResult.failure('Phiên đăng nhập hết hạn!');
    }
    final response = await _authProvider.authorizedRequest(
      (token) => ApiService.changePassword(
        accessToken: token,
        oldPassword: oldPassword,
        newPassword: newPassword,
      ),
      isUnauthorized: (response) => response.statusCode == 401,
    );
    if (response.statusCode != 200) {
      final body = _decodeMap(response.body);
      return ProviderResult.failure(
        body['message']?.toString() ?? 'Đổi mật khẩu thất bại',
        statusCode: response.statusCode,
      );
    }
    try {
      final saved = await LoginCredentialStorage.read();
      if (saved != null) {
        await LoginCredentialStorage.save(
          phone: saved.phone,
          password: newPassword,
        );
      }
    } catch (_) {
      // Updating optional autofill credentials must not alter API success.
    }
    return const ProviderResult.success();
  }

  Future<ProviderResult<void>> updateProfile({
    required String fullName,
    required String email,
    String? avatarFilePath,
  }) async {
    if (await _authProvider.requireAccessToken() == null) {
      return const ProviderResult.failure('Phiên đăng nhập hết hạn.');
    }
    final response = await _authProvider.authorizedRequest(
      (token) => ApiService.updateProfile(
        accessToken: token,
        fullName: fullName,
        email: email,
        avatarFilePath: avatarFilePath,
      ),
      isUnauthorized: (response) => response.statusCode == 401,
    );
    if (response.statusCode == 200) {
      await loadProfile();
      return const ProviderResult.success();
    }
    final body = _decodeMap(response.body);
    return ProviderResult.failure(
      body['message']?.toString() ?? 'Lỗi cập nhật.',
      statusCode: response.statusCode,
    );
  }

  Future<ProviderResult<void>> deleteAccount() async {
    if (await _authProvider.requireAccessToken() == null) {
      return const ProviderResult.failure('Phiên đăng nhập hết hạn');
    }
    final response = await _authProvider.authorizedRequest(
      (token) => ApiService.deleteAccount(accessToken: token),
      isUnauthorized: (response) => response.statusCode == 401,
    );
    if (response.statusCode != 200) {
      return ProviderResult.failure(
        'Không thể xoá tài khoản (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    await _authProvider.clearSession(clearPreferences: true);
    await LoginCredentialStorage.clear();
    _profile = null;
    notifyListeners();
    return const ProviderResult.success();
  }

  Future<ProviderResult<WalletOverviewModel>> loadWalletOverview() async {
    try {
      num balance = 0;
      final profileResponse = await _authProvider.authorizedRequest(
        (token) => ApiService.getCustomerProfile(accessToken: token),
        isUnauthorized: (response) => response.statusCode == 401,
      );
      if (profileResponse.statusCode == 200) {
        final profile = CustomerProfileModel.fromJson(
          _decodeMap(profileResponse.body),
        );
        balance = profile.wallet;
      }

      final historyResponse = await _authProvider.authorizedRequest(
        (token) => ApiService.getWalletHistory(accessToken: token),
        isUnauthorized: (response) => response.statusCode == 401,
      );
      if (historyResponse.statusCode != 200) {
        return ProviderResult.failure(
          'Lỗi kết nối lịch sử (${historyResponse.statusCode})',
          statusCode: historyResponse.statusCode,
        );
      }
      final history = _decodeMap(historyResponse.body);
      final rawItems = history['data'] is List ? history['data'] as List : [];
      final transactions = rawItems
          .whereType<Map>()
          .map(
            (item) => WalletTransactionModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
      return ProviderResult.success(
        WalletOverviewModel(
          currentBalance: balance,
          transactions: transactions,
        ),
      );
    } catch (error) {
      return ProviderResult.failure('Đã có lỗi xảy ra: $error');
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
}
