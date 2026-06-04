import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../../models/location_models.dart';
import '../../services/api_service.dart';

class BookingAddressMapPickerScreen extends StatefulWidget {
  final String title;
  final RidePointPayload? initialPoint;

  const BookingAddressMapPickerScreen({
    super.key,
    required this.title,
    this.initialPoint,
  });

  @override
  State<BookingAddressMapPickerScreen> createState() =>
      _BookingAddressMapPickerScreenState();
}

class _BookingAddressMapPickerScreenState
    extends State<BookingAddressMapPickerScreen> {
  static const String _streetTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const latlng.LatLng _defaultCenter = latlng.LatLng(
    21.028511,
    105.804817,
  );

  final MapController _mapController = MapController();

  late latlng.LatLng _mapCenter;
  Timer? _resolveDebounce;
  AddressResolvedLocation? _resolvedLocation;
  int _previewRequestId = 0;
  bool _isResolving = false;
  bool _isResolvingPreview = false;
  bool _isLocating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mapCenter = _initialCenter();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeMapCenter();
      }
    });
  }

  @override
  void dispose() {
    _resolveDebounce?.cancel();
    super.dispose();
  }

  latlng.LatLng _initialCenter() {
    final point = widget.initialPoint;
    if (point != null && point.isCoordinates) {
      return latlng.LatLng(point.lat!, point.lng!);
    }
    return _defaultCenter;
  }

  Future<void> _initializeMapCenter() async {
    final point = widget.initialPoint;
    if (point != null && point.isPlaceId) {
      await _moveToPlaceId(point.placeId!);
      return;
    }

    _schedulePreviewResolve();
  }

  Future<void> _moveToPlaceId(String placeId) async {
    try {
      final response = await ApiService.getTrackAsiaPlaceDetail(
        placeId: placeId,
      );
      if (!mounted) return;

      final parsed = TrackAsiaPlaceDetailResponse.fromRawJson(response.body);
      final detail = parsed.data;
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          parsed.success &&
          detail != null) {
        final nextCenter = latlng.LatLng(detail.lat, detail.lng);
        _mapController.move(nextCenter, 16);
        setState(() {
          _mapCenter = nextCenter;
          _resolvedLocation = null;
          _errorMessage = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        _schedulePreviewResolve();
      }
    }
  }

  Future<void> _tryMoveToCurrentLocation() async {
    if (_isLocating) return;

    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final nextCenter = latlng.LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      _mapController.move(nextCenter, 16);
      setState(() {
        _mapCenter = nextCenter;
        _resolvedLocation = null;
        _errorMessage = null;
      });
      _schedulePreviewResolve();
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  String _extractMessage(String raw, int statusCode) {
    if (statusCode == 502) {
      return 'Không thể lấy địa chỉ, vui lòng thử lại';
    }

    try {
      final parsed = ResolvePointResponse.fromRawJson(raw);
      if (parsed.message != null && parsed.message!.trim().isNotEmpty) {
        return parsed.message!.trim();
      }
    } catch (_) {}

    return 'Không xác định được địa chỉ tại vị trí này';
  }

  String _coordinateKey(latlng.LatLng point) {
    return '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';
  }

  void _schedulePreviewResolve() {
    _resolveDebounce?.cancel();
    _resolveDebounce = Timer(const Duration(milliseconds: 350), () {
      _resolvePreviewPoint();
    });
  }

  Future<void> _resolvePreviewPoint() async {
    final requestId = ++_previewRequestId;
    final target = _mapCenter;

    setState(() {
      _isResolvingPreview = true;
      _errorMessage = null;
    });

    final response = await ApiService.resolveAddressPoint(
      lat: target.latitude,
      lng: target.longitude,
    );

    if (!mounted || requestId != _previewRequestId) return;

    try {
      final parsed = ResolvePointResponse.fromRawJson(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          parsed.success &&
          parsed.data != null) {
        setState(() {
          _resolvedLocation = parsed.data;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _resolvedLocation = null;
          _errorMessage = _extractMessage(response.body, response.statusCode);
        });
      }
    } catch (_) {
      setState(() {
        _resolvedLocation = null;
        _errorMessage = _extractMessage(response.body, response.statusCode);
      });
    } finally {
      if (mounted && requestId == _previewRequestId) {
        setState(() => _isResolvingPreview = false);
      }
    }
  }

  Future<void> _confirmSelection() async {
    final cachedLocation = _resolvedLocation;
    if (cachedLocation != null &&
        _coordinateKey(latlng.LatLng(cachedLocation.lat, cachedLocation.lng)) ==
            _coordinateKey(_mapCenter)) {
      Navigator.pop(context, cachedLocation);
      return;
    }

    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    final response = await ApiService.resolveAddressPoint(
      lat: _mapCenter.latitude,
      lng: _mapCenter.longitude,
    );

    if (!mounted) return;

    try {
      final parsed = ResolvePointResponse.fromRawJson(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          parsed.success &&
          parsed.data != null) {
        Navigator.pop(context, parsed.data);
        return;
      }

      setState(() {
        _errorMessage = _extractMessage(response.body, response.statusCode);
      });
    } catch (_) {
      setState(() {
        _errorMessage = _extractMessage(response.body, response.statusCode);
      });
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 16,
              minZoom: 5,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, hasGesture) {
                final center = camera.center;
                setState(() {
                  _mapCenter = center;
                  _resolvedLocation = null;
                  _errorMessage = null;
                });
                _schedulePreviewResolve();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _streetTileUrl,
                userAgentPackageName: 'com.belucar.app',
                maxZoom: 19,
              ),
            ],
          ),
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Kéo bản đồ để đặt ghim',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.location_on_rounded,
                    size: 46,
                    color: Color(0xFFE53935),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: FloatingActionButton.small(
                heroTag: 'current-location',
                tooltip: 'Vị trí hiện tại',
                onPressed: _isLocating ? null : _tryMoveToCurrentLocation,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF123C2E),
                child: _isLocating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Điểm đang chọn',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isResolvingPreview && _resolvedLocation == null)
                      const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Đang xác định địa chỉ gần vị trí ghim...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (_resolvedLocation != null) ...[
                      Text(
                        _resolvedLocation!.formattedAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_resolvedLocation!.districtName}, ${_resolvedLocation!.provinceName}',
                        style: const TextStyle(
                          color: Color(0xFFE7D8B0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_mapCenter.latitude.toStringAsFixed(6)}, ${_mapCenter.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else
                      Text(
                        '${_mapCenter.latitude.toStringAsFixed(6)}, ${_mapCenter.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isResolving ? null : _confirmSelection,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isResolving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black87,
                                ),
                              )
                            : const Text(
                                'CHỌN ĐIỂM NÀY',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
