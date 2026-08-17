import 'package:flutter/foundation.dart';

import '../models/location_models.dart';
import '../models/provider_result.dart';
import '../services/api_service.dart';

class LocationProvider extends ChangeNotifier {
  Future<ProviderResult<TrackAsiaPlaceDetailData>> getPlaceDetail(
    String placeId,
  ) async {
    final response = await ApiService.getTrackAsiaPlaceDetail(placeId: placeId);
    try {
      final parsed = TrackAsiaPlaceDetailResponse.fromRawJson(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          parsed.success &&
          parsed.data != null) {
        return ProviderResult.success(parsed.data);
      }
      return ProviderResult.failure(
        parsed.message ?? 'Không thể lấy thông tin địa điểm',
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ProviderResult.failure(
        'Không thể lấy thông tin địa điểm',
        statusCode: response.statusCode,
      );
    }
  }

  Future<ProviderResult<AddressResolvedLocation>> resolvePoint({
    required double lat,
    required double lng,
  }) async {
    final response = await ApiService.resolveAddressPoint(lat: lat, lng: lng);
    try {
      final parsed = ResolvePointResponse.fromRawJson(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          parsed.success &&
          parsed.data != null) {
        return ProviderResult.success(parsed.data);
      }
      return ProviderResult.failure(
        response.statusCode == 502
            ? 'Không thể lấy địa chỉ, vui lòng thử lại'
            : parsed.message ?? 'Không xác định được địa chỉ tại vị trí này',
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ProviderResult.failure(
        response.statusCode == 502
            ? 'Không thể lấy địa chỉ, vui lòng thử lại'
            : 'Không xác định được địa chỉ tại vị trí này',
        statusCode: response.statusCode,
      );
    }
  }
}
