import 'dart:convert';

String _stringValue(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final raw = value.toString();
  return raw.trim().isEmpty ? fallback : raw;
}

int _intValue(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double _doubleValue(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

bool _boolValue(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return fallback;
}

Map<String, dynamic>? _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return null;
}

enum AddressSelectionSource { search, map }

class RidePointPayload {
  const RidePointPayload._({this.placeId, this.lat, this.lng});

  final String? placeId;
  final double? lat;
  final double? lng;

  factory RidePointPayload.placeId(String placeId) {
    return RidePointPayload._(placeId: placeId.trim());
  }

  factory RidePointPayload.coordinates({
    required double lat,
    required double lng,
  }) {
    return RidePointPayload._(lat: lat, lng: lng);
  }

  bool get isPlaceId => placeId != null && placeId!.trim().isNotEmpty;

  bool get isCoordinates => lat != null && lng != null;

  bool get isValid => isPlaceId || isCoordinates;

  String get identityKey {
    if (isPlaceId) return 'place:${placeId!.trim()}';
    if (isCoordinates) {
      return 'coord:${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}';
    }
    return 'invalid';
  }

  Map<String, dynamic> toJson() {
    if (isPlaceId) {
      return {'placeId': placeId!.trim()};
    }

    if (isCoordinates) {
      return {'lat': lat, 'lng': lng};
    }

    return const <String, dynamic>{};
  }
}

class ResolvePointResponse {
  const ResolvePointResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String? message;
  final AddressResolvedLocation? data;

  factory ResolvePointResponse.fromJson(Map<String, dynamic> json) {
    final rawData = _mapValue(json['data']);
    return ResolvePointResponse(
      success: json['success'] == true,
      message: json['message']?.toString(),
      data: rawData == null ? null : AddressResolvedLocation.fromJson(rawData),
    );
  }

  factory ResolvePointResponse.fromRawJson(String raw) {
    return ResolvePointResponse.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}

class TrackAsiaAutocompleteSuggestion {
  const TrackAsiaAutocompleteSuggestion({
    required this.provider,
    required this.refId,
    required this.placeId,
    required this.name,
    required this.address,
    required this.display,
    required this.icon,
    required this.types,
  });

  final String provider;
  final String refId;
  final String placeId;
  final String name;
  final String address;
  final String display;
  final String icon;
  final List<String> types;

  factory TrackAsiaAutocompleteSuggestion.fromJson(Map<String, dynamic> json) {
    return TrackAsiaAutocompleteSuggestion(
      provider: _stringValue(json['provider']),
      refId: _stringValue(json['refId']),
      placeId: _stringValue(json['placeId']),
      name: _stringValue(json['name']),
      address: _stringValue(json['address']),
      display: _stringValue(json['display']),
      icon: _stringValue(json['icon']),
      types: (json['types'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }

  String get primaryText => name.trim().isNotEmpty ? name.trim() : displayText;

  String get secondaryText {
    if (address.trim().isNotEmpty) return address.trim();
    if (display.trim().isNotEmpty && display.trim() != primaryText) {
      return display.trim();
    }
    return '';
  }

  String get displayText {
    if (display.trim().isNotEmpty) return display.trim();
    if (name.trim().isNotEmpty && address.trim().isNotEmpty) {
      return '${name.trim()}, ${address.trim()}';
    }
    return name.trim().isNotEmpty ? name.trim() : address.trim();
  }
}

class TrackAsiaAutocompleteResponse {
  const TrackAsiaAutocompleteResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String? message;
  final List<TrackAsiaAutocompleteSuggestion> data;

  factory TrackAsiaAutocompleteResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'] as List? ?? const [];
    return TrackAsiaAutocompleteResponse(
      success: json['success'] == true,
      message: json['message']?.toString(),
      data: rawList
          .whereType<Map>()
          .map(
            (item) => TrackAsiaAutocompleteSuggestion.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(),
    );
  }

  factory TrackAsiaAutocompleteResponse.fromRawJson(String raw) {
    return TrackAsiaAutocompleteResponse.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}

class TrackAsiaPlaceDetailData {
  const TrackAsiaPlaceDetailData({
    required this.provider,
    required this.placeId,
    required this.officialId,
    required this.name,
    required this.formattedAddress,
    required this.vicinity,
    required this.lat,
    required this.lng,
    required this.types,
  });

  final String provider;
  final String placeId;
  final String officialId;
  final String name;
  final String formattedAddress;
  final String vicinity;
  final double lat;
  final double lng;
  final List<String> types;

  factory TrackAsiaPlaceDetailData.fromJson(Map<String, dynamic> json) {
    return TrackAsiaPlaceDetailData(
      provider: _stringValue(json['provider']),
      placeId: _stringValue(json['placeId']),
      officialId: _stringValue(json['officialId']),
      name: _stringValue(json['name']),
      formattedAddress: _stringValue(json['formattedAddress']),
      vicinity: _stringValue(json['vicinity']),
      lat: _doubleValue(json['lat']),
      lng: _doubleValue(json['lng']),
      types: (json['types'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }
}

class TrackAsiaPlaceDetailResponse {
  const TrackAsiaPlaceDetailResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String? message;
  final TrackAsiaPlaceDetailData? data;

  factory TrackAsiaPlaceDetailResponse.fromJson(Map<String, dynamic> json) {
    final rawData = _mapValue(json['data']);
    return TrackAsiaPlaceDetailResponse(
      success: json['success'] == true,
      message: json['message']?.toString(),
      data: rawData == null ? null : TrackAsiaPlaceDetailData.fromJson(rawData),
    );
  }

  factory TrackAsiaPlaceDetailResponse.fromRawJson(String raw) {
    return TrackAsiaPlaceDetailResponse.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}

class AddressResolvedLocation {
  const AddressResolvedLocation({
    required this.provider,
    required this.placeId,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    required this.provinceId,
    required this.provinceName,
    required this.districtId,
    required this.districtName,
  });

  final String provider;
  final String placeId;
  final String formattedAddress;
  final double lat;
  final double lng;
  final int provinceId;
  final String provinceName;
  final int districtId;
  final String districtName;

  factory AddressResolvedLocation.fromJson(Map<String, dynamic> json) {
    return AddressResolvedLocation(
      provider: _stringValue(json['provider']),
      placeId: _stringValue(json['placeId']),
      formattedAddress: _stringValue(json['formattedAddress']),
      lat: _doubleValue(json['lat']),
      lng: _doubleValue(json['lng']),
      provinceId: _intValue(json['provinceId']),
      provinceName: _stringValue(json['provinceName']),
      districtId: _intValue(json['districtId']),
      districtName: _stringValue(json['districtName']),
    );
  }
}

class ResolveRoutePreviewData {
  const ResolveRoutePreviewData({
    required this.from,
    required this.to,
    required this.tripId,
    required this.type,
    required this.quantity,
    required this.operatingRegionId,
    required this.routeId,
    required this.basePrice,
    required this.surcharge,
    required this.discount,
    required this.finalPrice,
    required this.isHoliday,
  });

  final AddressResolvedLocation from;
  final AddressResolvedLocation to;
  final int tripId;
  final int type;
  final int quantity;
  final int operatingRegionId;
  final int routeId;
  final num basePrice;
  final num surcharge;
  final num discount;
  final num finalPrice;
  final bool isHoliday;

  factory ResolveRoutePreviewData.fromJson(Map<String, dynamic> json) {
    return ResolveRoutePreviewData(
      from: AddressResolvedLocation.fromJson(
        _mapValue(json['from']) ?? const <String, dynamic>{},
      ),
      to: AddressResolvedLocation.fromJson(
        _mapValue(json['to']) ?? const <String, dynamic>{},
      ),
      tripId: _intValue(json['tripId']),
      type: _intValue(json['type']),
      quantity: _intValue(json['quantity'], fallback: 1),
      operatingRegionId: _intValue(json['operatingRegionId']),
      routeId: _intValue(json['routeId']),
      basePrice: json['basePrice'] as num? ?? 0,
      surcharge: json['surcharge'] as num? ?? 0,
      discount: json['discount'] as num? ?? 0,
      finalPrice: json['finalPrice'] as num? ?? 0,
      isHoliday: _boolValue(json['isHoliday']),
    );
  }
}

class ResolveRoutePreviewResponse {
  const ResolveRoutePreviewResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String? message;
  final ResolveRoutePreviewData? data;

  factory ResolveRoutePreviewResponse.fromJson(Map<String, dynamic> json) {
    final rawData = _mapValue(json['data']);
    return ResolveRoutePreviewResponse(
      success: json['success'] == true,
      message: json['message']?.toString(),
      data: rawData == null ? null : ResolveRoutePreviewData.fromJson(rawData),
    );
  }

  factory ResolveRoutePreviewResponse.fromRawJson(String raw) {
    return ResolveRoutePreviewResponse.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}
