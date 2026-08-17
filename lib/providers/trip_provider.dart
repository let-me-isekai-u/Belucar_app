import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/trip_detail_model.dart';
import '../models/trip_item_model.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class TripProvider extends ChangeNotifier {
  TripProvider({required AuthProvider authProvider})
    : _authProvider = authProvider;

  final AuthProvider _authProvider;

  Future<List<TripItemModel>> fetchOngoingTrips() =>
      _fetchTrips((token) => ApiService.getTripCurrent(accessToken: token));

  Future<List<TripItemModel>> fetchHistoryTrips() =>
      _fetchTrips((token) => ApiService.getTripHistory(accessToken: token));

  Future<TripDetailModel> fetchTripDetail(int rideId) async {
    final token = await _requireToken();
    final data = await ApiService.getTripDetail(
      accessToken: token,
      rideId: rideId,
    );
    return TripDetailModel.fromJson(data);
  }

  Future<void> cancelTrip(int rideId, {required bool confirmCancel}) async {
    final token = await _requireToken();
    if (confirmCancel) {
      await ApiService.confirmCancelTrip(accessToken: token, rideId: rideId);
    } else {
      await ApiService.cancelTrip(accessToken: token, rideId: rideId);
    }
  }

  Future<List<TripItemModel>> _fetchTrips(
    Future<dynamic> Function(String token) request,
  ) async {
    final token = await _authProvider.requireAccessToken();
    if (token == null) return [];
    try {
      final response = await request(token);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      final rawItems = decoded is Map ? decoded['data'] : null;
      if (rawItems is! List) return [];
      return rawItems
          .whereType<Map>()
          .map(
            (item) => TripItemModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } catch (error) {
      debugPrint('Error fetching trips: $error');
      return [];
    }
  }

  Future<String> _requireToken() async {
    final token = await _authProvider.requireAccessToken();
    if (token == null) throw StateError('Chưa đăng nhập');
    return token;
  }
}
