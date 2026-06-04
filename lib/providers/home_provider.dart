import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/deposit_model.dart';
import '../services/api_service.dart';

class HomeProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  String _fullName = '';
  int _userId = 0;

  String _weatherIcon = '🌤️';
  String _temperature = '--';
  bool _isLoadingWeather = true;

  String? _avatarUrl;
  String _accessToken = '';

  int _currentBanner = 0;
  bool _isCreatingDepositRequest = false;
  bool _isCancellingDepositRequest = false;
  bool _isInitialized = false;

  final List<String> _carouselImages = const [
    'lib/assets/carousel_01.jpg',
    'lib/assets/carousel_02.png',
    'lib/assets/carousel_03.jpg',
  ];

  int get selectedIndex => _selectedIndex;
  String get fullName => _fullName;
  int get userId => _userId;
  String get weatherIcon => _weatherIcon;
  String get temperature => _temperature;
  bool get isLoadingWeather => _isLoadingWeather;
  String? get avatarUrl => _avatarUrl;
  int get currentBanner => _currentBanner;
  bool get isCreatingDepositRequest => _isCreatingDepositRequest;
  bool get isCancellingDepositRequest => _isCancellingDepositRequest;
  List<String> get carouselImages => List.unmodifiable(_carouselImages);

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await loadUserInfo();
    await fetchWeather();
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _fullName = prefs.getString('fullName') ?? '';
    _accessToken = prefs.getString('accessToken') ?? '';

    if (_accessToken.isEmpty) {
      notifyListeners();
      return;
    }

    try {
      final res = await ApiService.getCustomerProfile(
        accessToken: _accessToken,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _userId = data['id'] ?? 0;
        _avatarUrl = data['avatarUrl'];
        _fullName = (data['fullName'] ?? _fullName).toString();
        await prefs.setInt('id', _userId);
      }
    } catch (_) {
      // Keep local fallback values when the profile request fails.
    }

    notifyListeners();
  }

  Future<void> refreshWeather() async {
    _isLoadingWeather = true;
    notifyListeners();
    await fetchWeather();
  }

  Future<void> fetchWeather() async {
    try {
      const lat = 21.0285;
      const lon = 105.8542;

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=$lat&'
        'longitude=$lon&'
        'current_weather=true&'
        'timezone=Asia/Bangkok',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final current = data['current_weather'] as Map<String, dynamic>?;

        if (current != null) {
          _temperature = '${(current['temperature'] as num).round()}°';
          _weatherIcon = _getWeatherEmoji(current['weathercode'] as int? ?? 0);
        }
      }
    } catch (_) {
      // Ignore weather errors and keep the last known state.
    } finally {
      _isLoadingWeather = false;
      notifyListeners();
    }
  }

  void selectTab(int index) {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }

  void setCurrentBanner(int index) {
    if (_currentBanner == index) return;
    _currentBanner = index;
    notifyListeners();
  }

  void advanceBanner() {
    final totalPages = _carouselImages.length + 1;
    _currentBanner = (_currentBanner + 1) % totalPages;
    notifyListeners();
  }

  Future<DepositContentResponse> createDepositRequest({
    required double amount,
  }) async {
    if (_accessToken.isEmpty) {
      return DepositContentResponse(
        success: false,
        message: 'Bạn chưa đăng nhập',
      );
    }

    _isCreatingDepositRequest = true;
    notifyListeners();

    try {
      return await ApiService.createDepositContent(
        accessToken: _accessToken,
        amount: amount,
      );
    } finally {
      _isCreatingDepositRequest = false;
      notifyListeners();
    }
  }

  Future<CancelDepositResponse> cancelDepositRequest({
    required int? depositId,
  }) async {
    if (_accessToken.isEmpty) {
      return CancelDepositResponse(
        success: false,
        message: 'Bạn chưa đăng nhập',
      );
    }

    if (depositId == null) {
      return CancelDepositResponse(
        success: false,
        message: 'Backend chưa trả depositId nên chưa thể huỷ tự động.',
      );
    }

    _isCancellingDepositRequest = true;
    notifyListeners();

    try {
      return await ApiService.cancelDeposit(
        accessToken: _accessToken,
        depositId: depositId,
      );
    } finally {
      _isCancellingDepositRequest = false;
      notifyListeners();
    }
  }

  String _getWeatherEmoji(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌦️';
    if (code <= 99) return '⛈️';
    return '🌤️';
  }
}
