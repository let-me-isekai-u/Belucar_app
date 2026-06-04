import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location_models.dart';
import '../services/api_service.dart';

class BookingRideTypeOption {
  final int value;
  final String label;

  const BookingRideTypeOption({required this.value, required this.label});
}

class BookingRideType {
  static const int passenger = 1;
  static const int charter5Seats = 2;
  static const int charter7Seats = 3;

  static const List<BookingRideTypeOption> options = [
    BookingRideTypeOption(value: passenger, label: 'Chở người'),
    BookingRideTypeOption(value: charter5Seats, label: 'Bao xe 5 chỗ'),
    BookingRideTypeOption(value: charter7Seats, label: 'Bao xe 7 chỗ'),
  ];

  static bool isValid(int type) {
    return type == passenger || type == charter5Seats || type == charter7Seats;
  }

  static bool requiresPassengerQuantity(int type) => type == passenger;

  static bool isCharter(int type) =>
      type == charter5Seats || type == charter7Seats;

  static int normalizeQuantity({required int type, required int quantity}) {
    if (isCharter(type)) return 1;
    return quantity < 1 ? 1 : quantity;
  }

  static String labelOf(int type) {
    for (final option in options) {
      if (option.value == type) return option.label;
    }
    return 'Không xác định';
  }
}

class BookingSavedPlace {
  const BookingSavedPlace({
    required this.address,
    required this.point,
    required this.source,
  });

  final String address;
  final RidePointPayload point;
  final AddressSelectionSource source;

  String get identityKey => point.identityKey;

  String get title {
    final parts = address
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return parts.isEmpty ? address.trim() : parts.first;
  }

  String get subtitle {
    final parts = address
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.length <= 1) return '';
    return parts.sublist(1).join(', ');
  }

  Map<String, dynamic> toJson() {
    return {'address': address, 'point': point.toJson(), 'source': source.name};
  }

  factory BookingSavedPlace.fromJson(Map<String, dynamic> json) {
    final pointJson = (json['point'] as Map?)?.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    final placeId = pointJson?['placeId']?.toString().trim() ?? '';
    final lat = pointJson?['lat'];
    final lng = pointJson?['lng'];

    RidePointPayload? point;
    if (placeId.isNotEmpty) {
      point = RidePointPayload.placeId(placeId);
    } else if (lat is num && lng is num) {
      point = RidePointPayload.coordinates(
        lat: lat.toDouble(),
        lng: lng.toDouble(),
      );
    }

    if (point == null || !point.isValid) {
      throw const FormatException('Invalid saved point');
    }

    final sourceName = json['source']?.toString();
    final source =
        AddressSelectionSource.values
            .where((item) => item.name == sourceName)
            .firstOrNull ??
        AddressSelectionSource.search;

    return BookingSavedPlace(
      address: json['address']?.toString().trim() ?? '',
      point: point,
      source: source,
    );
  }
}

class BookingSavedRoute {
  const BookingSavedRoute({required this.pickup, required this.drop});

  final BookingSavedPlace pickup;
  final BookingSavedPlace drop;

  String get identityKey => '${pickup.identityKey}=>${drop.identityKey}';

  Map<String, dynamic> toJson() {
    return {'pickup': pickup.toJson(), 'drop': drop.toJson()};
  }

  factory BookingSavedRoute.fromJson(Map<String, dynamic> json) {
    final pickupJson = (json['pickup'] as Map?)?.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final dropJson = (json['drop'] as Map?)?.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    if (pickupJson == null || dropJson == null) {
      throw const FormatException('Invalid saved route');
    }

    return BookingSavedRoute(
      pickup: BookingSavedPlace.fromJson(pickupJson),
      drop: BookingSavedPlace.fromJson(dropJson),
    );
  }
}

class BookingModel extends ChangeNotifier {
  static const String _recentPlacesKey = 'booking_recent_places_v1';
  static const String _favoritePlacesKey = 'booking_favorite_places_v1';
  static const String _recentRoutesKey = 'booking_recent_routes_v1';
  static const int _maxRecentPlaces = 6;
  static const int _maxFavoritePlaces = 6;
  static const int _maxRecentRoutes = 4;

  final pickupAddressController = TextEditingController();
  final dropAddressController = TextEditingController();

  Timer? _pickupDebounce;
  Timer? _dropDebounce;
  String _latestPickupQuery = '';
  String _latestDropQuery = '';
  Future<void>? _ongoingPriceRequest;
  bool _pendingPriceRefresh = false;

  int _userId = 0;
  int get userId => _userId;

  set userId(int value) {
    _userId = value;
    notifyListeners();
  }

  int _selectedRideType = BookingRideType.passenger;
  int get selectedRideType => _selectedRideType;

  bool get showQuantityField =>
      BookingRideType.requiresPassengerQuantity(_selectedRideType);

  int get normalizedQuantity => BookingRideType.normalizeQuantity(
    type: _selectedRideType,
    quantity: _quantity,
  );

  String get rideTypeLabel => BookingRideType.labelOf(_selectedRideType);

  void setSelectedRideType(int value) {
    if (!BookingRideType.isValid(value) || _selectedRideType == value) return;
    _selectedRideType = value;
    notifyListeners();
    fetchTripPrice();
  }

  bool get isChoNguoi => _selectedRideType == BookingRideType.passenger;
  bool get isBaoXe => BookingRideType.isCharter(_selectedRideType);
  bool get isHoaToc => false;

  void setIsBaoXe(bool value) {
    final nextType = value
        ? BookingRideType.charter5Seats
        : BookingRideType.passenger;
    if (_selectedRideType != nextType) {
      _selectedRideType = nextType;
      notifyListeners();
      fetchTripPrice();
    }
  }

  int _paymentMethod = 2;
  int get paymentMethod => _paymentMethod;

  set paymentMethod(int value) {
    if (_paymentMethod == value) return;
    _paymentMethod = value;
    notifyListeners();
    fetchTripPrice();
  }

  DateTime? goDate;
  TimeOfDay? goTime;

  void setGoDate(DateTime? value) {
    goDate = value;
    notifyListeners();
    fetchTripPrice();
  }

  void setGoTime(TimeOfDay? value) {
    goTime = value;
    notifyListeners();
    fetchTripPrice();
  }

  int _quantity = 1;
  int get quantity => _quantity;

  set quantity(int value) {
    final next = value < 1 ? 1 : value;
    if (_quantity == next) return;
    _quantity = next;
    notifyListeners();
    fetchTripPrice();
  }

  RidePointPayload? selectedPickupPoint;
  RidePointPayload? selectedDropPoint;
  AddressSelectionSource? pickupSelectionSource;
  AddressSelectionSource? dropSelectionSource;
  String? pickupSelectedAddress;
  String? dropSelectedAddress;
  TrackAsiaAutocompleteSuggestion? selectedPickupSuggestion;
  TrackAsiaAutocompleteSuggestion? selectedDropSuggestion;

  bool loadingPickupSuggestions = false;
  bool loadingDropSuggestions = false;

  List<TrackAsiaAutocompleteSuggestion> pickupSuggestions =
      <TrackAsiaAutocompleteSuggestion>[];
  List<TrackAsiaAutocompleteSuggestion> dropSuggestions =
      <TrackAsiaAutocompleteSuggestion>[];

  String? customerPhone;
  String? note;

  ResolveRoutePreviewData? routePreview;
  double? tripPrice;
  int? currentTripId;
  double? basePrice;
  double discount = 0;
  double surcharge = 0;
  bool isHoliday = false;
  String? priceErrorMessage;
  bool isLoadingPrice = false;

  List<BookingSavedPlace> recentPlaces = <BookingSavedPlace>[];
  List<BookingSavedPlace> favoritePlaces = <BookingSavedPlace>[];
  List<BookingSavedRoute> recentRoutes = <BookingSavedRoute>[];

  BookingModel() {
    unawaited(loadSavedPlaces());
  }

  bool get hasPickupSelection => selectedPickupPoint?.isValid == true;
  bool get hasDropSelection => selectedDropPoint?.isValid == true;

  AddressResolvedLocation? get resolvedPickup => routePreview?.from;
  AddressResolvedLocation? get resolvedDrop => routePreview?.to;

  String get pickupDisplayAddress {
    return (pickupSelectedAddress ?? pickupAddressController.text).trim();
  }

  String get dropDisplayAddress {
    return (dropSelectedAddress ?? dropAddressController.text).trim();
  }

  Future<void> loadSavedPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      recentPlaces = _decodeSavedPlaces(prefs.getString(_recentPlacesKey));
      favoritePlaces = _decodeSavedPlaces(prefs.getString(_favoritePlacesKey));
      recentRoutes = _decodeSavedRoutes(prefs.getString(_recentRoutesKey));
      notifyListeners();
    } catch (_) {
      recentPlaces = <BookingSavedPlace>[];
      favoritePlaces = <BookingSavedPlace>[];
      recentRoutes = <BookingSavedRoute>[];
      notifyListeners();
    }
  }

  void onAddressTextChanged({required bool isPickup, required String query}) {
    final trimmed = query.trim();
    final hasSelection = isPickup ? hasPickupSelection : hasDropSelection;

    if (isPickup) {
      _latestPickupQuery = trimmed;
      if (hasSelection) {
        selectedPickupPoint = null;
        pickupSelectionSource = null;
        pickupSelectedAddress = null;
        selectedPickupSuggestion = null;
      }
      pickupSuggestions = <TrackAsiaAutocompleteSuggestion>[];
      loadingPickupSuggestions = trimmed.length >= 2;
    } else {
      _latestDropQuery = trimmed;
      if (hasSelection) {
        selectedDropPoint = null;
        dropSelectionSource = null;
        dropSelectedAddress = null;
        selectedDropSuggestion = null;
      }
      dropSuggestions = <TrackAsiaAutocompleteSuggestion>[];
      loadingDropSuggestions = trimmed.length >= 2;
    }

    routePreview = null;
    _resetPrice();

    final debounce = isPickup ? _pickupDebounce : _dropDebounce;
    debounce?.cancel();

    if (trimmed.length < 2) {
      if (isPickup) {
        loadingPickupSuggestions = false;
      } else {
        loadingDropSuggestions = false;
      }
      notifyListeners();
      return;
    }

    notifyListeners();

    final timer = Timer(
      const Duration(milliseconds: 350),
      () => _fetchAutocomplete(isPickup: isPickup, query: trimmed),
    );

    if (isPickup) {
      _pickupDebounce = timer;
    } else {
      _dropDebounce = timer;
    }
  }

  Future<void> _fetchAutocomplete({
    required bool isPickup,
    required String query,
  }) async {
    try {
      final response = await ApiService.autocompleteTrackAsia(input: query);
      final latestQuery = isPickup ? _latestPickupQuery : _latestDropQuery;
      if (latestQuery != query) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final parsed = TrackAsiaAutocompleteResponse.fromRawJson(response.body);
        final suggestions = parsed.success
            ? parsed.data
            : <TrackAsiaAutocompleteSuggestion>[];

        if (isPickup) {
          pickupSuggestions = suggestions;
          loadingPickupSuggestions = false;
        } else {
          dropSuggestions = suggestions;
          loadingDropSuggestions = false;
        }
      } else {
        if (isPickup) {
          pickupSuggestions = <TrackAsiaAutocompleteSuggestion>[];
          loadingPickupSuggestions = false;
        } else {
          dropSuggestions = <TrackAsiaAutocompleteSuggestion>[];
          loadingDropSuggestions = false;
        }
      }
    } catch (_) {
      if (isPickup) {
        pickupSuggestions = <TrackAsiaAutocompleteSuggestion>[];
        loadingPickupSuggestions = false;
      } else {
        dropSuggestions = <TrackAsiaAutocompleteSuggestion>[];
        loadingDropSuggestions = false;
      }
    }

    notifyListeners();
  }

  void closeAutocompleteSuggestions() {
    _pickupDebounce?.cancel();
    _dropDebounce?.cancel();
    pickupSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    dropSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingPickupSuggestions = false;
    loadingDropSuggestions = false;
    notifyListeners();
  }

  void selectPickupSuggestion(TrackAsiaAutocompleteSuggestion suggestion) {
    pickupAddressController.value = TextEditingValue(
      text: suggestion.displayText,
      selection: TextSelection.collapsed(offset: suggestion.displayText.length),
    );

    selectedPickupPoint = RidePointPayload.placeId(suggestion.placeId);
    pickupSelectionSource = AddressSelectionSource.search;
    pickupSelectedAddress = suggestion.displayText;
    selectedPickupSuggestion = suggestion;
    pickupSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingPickupSuggestions = false;
    _latestPickupQuery = suggestion.displayText.trim();
    routePreview = null;
    _resetPrice();
    _rememberCurrentSelections();
    notifyListeners();
  }

  void selectDropSuggestion(TrackAsiaAutocompleteSuggestion suggestion) {
    dropAddressController.value = TextEditingValue(
      text: suggestion.displayText,
      selection: TextSelection.collapsed(offset: suggestion.displayText.length),
    );

    selectedDropPoint = RidePointPayload.placeId(suggestion.placeId);
    dropSelectionSource = AddressSelectionSource.search;
    dropSelectedAddress = suggestion.displayText;
    selectedDropSuggestion = suggestion;
    dropSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingDropSuggestions = false;
    _latestDropQuery = suggestion.displayText.trim();
    routePreview = null;
    _resetPrice();
    _rememberCurrentSelections();
    notifyListeners();
  }

  void selectPickupMapLocation(AddressResolvedLocation location) {
    final address = location.formattedAddress.trim();
    pickupAddressController.value = TextEditingValue(
      text: address,
      selection: TextSelection.collapsed(offset: address.length),
    );

    selectedPickupPoint = RidePointPayload.coordinates(
      lat: location.lat,
      lng: location.lng,
    );
    pickupSelectionSource = AddressSelectionSource.map;
    pickupSelectedAddress = address;
    selectedPickupSuggestion = null;
    pickupSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingPickupSuggestions = false;
    _latestPickupQuery = address;
    routePreview = null;
    _resetPrice();
    _rememberCurrentSelections();
    notifyListeners();
  }

  void selectDropMapLocation(AddressResolvedLocation location) {
    final address = location.formattedAddress.trim();
    dropAddressController.value = TextEditingValue(
      text: address,
      selection: TextSelection.collapsed(offset: address.length),
    );

    selectedDropPoint = RidePointPayload.coordinates(
      lat: location.lat,
      lng: location.lng,
    );
    dropSelectionSource = AddressSelectionSource.map;
    dropSelectedAddress = address;
    selectedDropSuggestion = null;
    dropSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingDropSuggestions = false;
    _latestDropQuery = address;
    routePreview = null;
    _resetPrice();
    _rememberCurrentSelections();
    notifyListeners();
  }

  void clearPickupSelection() {
    pickupAddressController.clear();
    selectedPickupPoint = null;
    pickupSelectionSource = null;
    pickupSelectedAddress = null;
    selectedPickupSuggestion = null;
    pickupSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingPickupSuggestions = false;
    _latestPickupQuery = '';
    routePreview = null;
    _resetPrice();
    notifyListeners();
  }

  void clearDropSelection() {
    dropAddressController.clear();
    selectedDropPoint = null;
    dropSelectionSource = null;
    dropSelectedAddress = null;
    selectedDropSuggestion = null;
    dropSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingDropSuggestions = false;
    _latestDropQuery = '';
    routePreview = null;
    _resetPrice();
    notifyListeners();
  }

  void swapRoutePoints() {
    final pickupText = pickupAddressController.text;
    final dropText = dropAddressController.text;
    final pickupPoint = selectedPickupPoint;
    final dropPoint = selectedDropPoint;
    final pickupSource = pickupSelectionSource;
    final dropSource = dropSelectionSource;
    final pickupAddress = pickupSelectedAddress;
    final dropAddress = dropSelectedAddress;
    final pickupSuggestion = selectedPickupSuggestion;
    final dropSuggestion = selectedDropSuggestion;

    pickupAddressController.value = TextEditingValue(
      text: dropText,
      selection: TextSelection.collapsed(offset: dropText.length),
    );
    dropAddressController.value = TextEditingValue(
      text: pickupText,
      selection: TextSelection.collapsed(offset: pickupText.length),
    );

    selectedPickupPoint = dropPoint;
    selectedDropPoint = pickupPoint;
    pickupSelectionSource = dropSource;
    dropSelectionSource = pickupSource;
    pickupSelectedAddress = dropAddress;
    dropSelectedAddress = pickupAddress;
    selectedPickupSuggestion = dropSuggestion;
    selectedDropSuggestion = pickupSuggestion;
    pickupSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    dropSuggestions = <TrackAsiaAutocompleteSuggestion>[];
    loadingPickupSuggestions = false;
    loadingDropSuggestions = false;
    _latestPickupQuery = dropText.trim();
    _latestDropQuery = pickupText.trim();
    routePreview = null;
    _resetPrice();
    _rememberCurrentSelections();
    notifyListeners();
    fetchTripPrice();
  }

  bool isCurrentSelectionFavorite({required bool isPickup}) {
    final place = _buildSavedPlaceFromSelection(isPickup: isPickup);
    if (place == null) return false;
    return favoritePlaces.any((item) => item.identityKey == place.identityKey);
  }

  void toggleFavoriteForSelection({required bool isPickup}) {
    final place = _buildSavedPlaceFromSelection(isPickup: isPickup);
    if (place == null) return;
    toggleFavoritePlace(place);
  }

  void toggleFavoritePlace(BookingSavedPlace place) {
    final next = List<BookingSavedPlace>.from(favoritePlaces);
    final index = next.indexWhere(
      (item) => item.identityKey == place.identityKey,
    );
    if (index >= 0) {
      next.removeAt(index);
    } else {
      next.insert(0, place);
      if (next.length > _maxFavoritePlaces) {
        next.removeRange(_maxFavoritePlaces, next.length);
      }
    }
    favoritePlaces = next;
    unawaited(_persistSavedCollections());
    notifyListeners();
  }

  void applySavedPlace(BookingSavedPlace place, {required bool isPickup}) {
    final controller = isPickup
        ? pickupAddressController
        : dropAddressController;
    controller.value = TextEditingValue(
      text: place.address,
      selection: TextSelection.collapsed(offset: place.address.length),
    );

    if (isPickup) {
      selectedPickupPoint = place.point;
      pickupSelectionSource = place.source;
      pickupSelectedAddress = place.address;
      selectedPickupSuggestion = null;
      pickupSuggestions = <TrackAsiaAutocompleteSuggestion>[];
      loadingPickupSuggestions = false;
      _latestPickupQuery = place.address.trim();
    } else {
      selectedDropPoint = place.point;
      dropSelectionSource = place.source;
      dropSelectedAddress = place.address;
      selectedDropSuggestion = null;
      dropSuggestions = <TrackAsiaAutocompleteSuggestion>[];
      loadingDropSuggestions = false;
      _latestDropQuery = place.address.trim();
    }

    routePreview = null;
    _resetPrice();
    _rememberCurrentSelections();
    notifyListeners();
  }

  void applySavedRoute(BookingSavedRoute route) {
    applySavedPlace(route.pickup, isPickup: true);
    applySavedPlace(route.drop, isPickup: false);
  }

  String? buildPickupIso() {
    if (goDate == null || goTime == null) return null;
    final dt = DateTime(
      goDate!.year,
      goDate!.month,
      goDate!.day,
      goTime!.hour,
      goTime!.minute,
    );
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt);
  }

  String? validateRouteSelection() {
    if (!hasPickupSelection || !hasDropSelection) {
      return null;
    }

    if (selectedPickupPoint!.identityKey == selectedDropPoint!.identityKey) {
      return 'Điểm đón và điểm đến không được trùng nhau.';
    }

    return null;
  }

  Future<void> fetchTripPrice() async {
    if (_ongoingPriceRequest != null) {
      _pendingPriceRefresh = true;
      return _ongoingPriceRequest!;
    }

    Future<void> runOnce() async {
      final pickupIso = buildPickupIso();
      if (!hasPickupSelection ||
          !hasDropSelection ||
          pickupIso == null ||
          !BookingRideType.isValid(_selectedRideType)) {
        routePreview = null;
        _resetPrice();
        notifyListeners();
        return;
      }

      final routeValidationMessage = validateRouteSelection();
      if (routeValidationMessage != null) {
        routePreview = null;
        _resetPrice();
        priceErrorMessage = routeValidationMessage;
        notifyListeners();
        return;
      }

      isLoadingPrice = true;
      priceErrorMessage = null;
      notifyListeners();

      try {
        final response = await ApiService.resolveRoutePreview(
          from: selectedPickupPoint!,
          to: selectedDropPoint!,
          type: _selectedRideType,
          pickupTime: pickupIso,
          paymentMethod: _paymentMethod,
          quantity: normalizedQuantity,
        );

        final parsed = ResolveRoutePreviewResponse.fromRawJson(response.body);
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            parsed.success &&
            parsed.data != null) {
          routePreview = parsed.data;
          currentTripId = parsed.data!.tripId;
          basePrice = parsed.data!.basePrice.toDouble();
          discount = parsed.data!.discount.toDouble();
          surcharge = parsed.data!.surcharge.toDouble();
          tripPrice = parsed.data!.finalPrice.toDouble();
          isHoliday = parsed.data!.isHoliday;
          priceErrorMessage = null;
        } else {
          routePreview = null;
          _resetPrice();
          priceErrorMessage = parsed.message?.trim().isNotEmpty == true
              ? parsed.message!.trim()
              : 'Không thể tính giá cho tuyến đường này.';
        }
      } catch (_) {
        routePreview = null;
        _resetPrice();
        priceErrorMessage =
            'Không thể tính giá chuyến đi, vui lòng thử lại sau.';
      } finally {
        isLoadingPrice = false;
        notifyListeners();
      }
    }

    Future<void> runSerially() async {
      await runOnce();
      while (_pendingPriceRefresh) {
        _pendingPriceRefresh = false;
        await runOnce();
      }
    }

    final request = runSerially();
    _ongoingPriceRequest = request;

    try {
      await request;
    } finally {
      _ongoingPriceRequest = null;
    }
  }

  void _resetPrice() {
    currentTripId = null;
    basePrice = null;
    tripPrice = null;
    discount = 0;
    surcharge = 0;
    isHoliday = false;
    priceErrorMessage = null;
  }

  Future<Map<String, dynamic>> createRide(
    String accessToken, {
    String? content,
  }) async {
    final pickupIso = buildPickupIso();
    if (!hasPickupSelection || !hasDropSelection || pickupIso == null) {
      throw Exception('Thông tin chuyến đi chưa đầy đủ');
    }

    final routeValidationMessage = validateRouteSelection();
    if (routeValidationMessage != null) {
      throw Exception(routeValidationMessage);
    }

    final response = await ApiService.createRide(
      accessToken: accessToken,
      from: selectedPickupPoint!,
      to: selectedDropPoint!,
      type: _selectedRideType,
      customerPhone: customerPhone ?? '',
      pickupTime: pickupIso,
      paymentMethod: _paymentMethod,
      quantity: normalizedQuantity,
      note: note ?? '',
      content: content,
    );

    final data = ApiService.safeDecode(response.body);
    if (response.statusCode != 200 || data['success'] == false) {
      throw data['message'] ?? 'Lỗi không xác định khi tạo chuyến';
    }

    return Map<String, dynamic>.from(data);
  }

  void resetForm() {
    _selectedRideType = BookingRideType.passenger;
    _paymentMethod = 2;
    _quantity = 1;

    clearPickupSelection();
    clearDropSelection();

    goDate = null;
    goTime = null;
    customerPhone = null;
    note = null;

    routePreview = null;
    _resetPrice();
    isLoadingPrice = false;
    notifyListeners();
  }

  BookingSavedPlace? _buildSavedPlaceFromSelection({required bool isPickup}) {
    final point = isPickup ? selectedPickupPoint : selectedDropPoint;
    final address = isPickup ? pickupDisplayAddress : dropDisplayAddress;
    final source = isPickup ? pickupSelectionSource : dropSelectionSource;

    if (point == null || !point.isValid || address.isEmpty) return null;

    return BookingSavedPlace(
      address: address,
      point: point,
      source: source ?? AddressSelectionSource.search,
    );
  }

  void _rememberCurrentSelections() {
    final pickup = _buildSavedPlaceFromSelection(isPickup: true);
    final drop = _buildSavedPlaceFromSelection(isPickup: false);

    if (pickup != null) {
      recentPlaces = _insertRecentPlace(recentPlaces, pickup, _maxRecentPlaces);
    }
    if (drop != null) {
      recentPlaces = _insertRecentPlace(recentPlaces, drop, _maxRecentPlaces);
    }
    if (pickup != null && drop != null) {
      final route = BookingSavedRoute(pickup: pickup, drop: drop);
      recentRoutes = _insertRecentRoute(recentRoutes, route, _maxRecentRoutes);
    }

    unawaited(_persistSavedCollections());
  }

  List<BookingSavedPlace> _insertRecentPlace(
    List<BookingSavedPlace> source,
    BookingSavedPlace place,
    int limit,
  ) {
    final next = List<BookingSavedPlace>.from(source)
      ..removeWhere((item) => item.identityKey == place.identityKey)
      ..insert(0, place);
    if (next.length > limit) {
      next.removeRange(limit, next.length);
    }
    return next;
  }

  List<BookingSavedRoute> _insertRecentRoute(
    List<BookingSavedRoute> source,
    BookingSavedRoute route,
    int limit,
  ) {
    final next = List<BookingSavedRoute>.from(source)
      ..removeWhere((item) => item.identityKey == route.identityKey)
      ..insert(0, route);
    if (next.length > limit) {
      next.removeRange(limit, next.length);
    }
    return next;
  }

  Future<void> _persistSavedCollections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recentPlacesKey,
      jsonEncode(recentPlaces.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _favoritePlacesKey,
      jsonEncode(favoritePlaces.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      _recentRoutesKey,
      jsonEncode(recentRoutes.map((item) => item.toJson()).toList()),
    );
  }

  List<BookingSavedPlace> _decodeSavedPlaces(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <BookingSavedPlace>[];
    final data = jsonDecode(raw);
    if (data is! List) return <BookingSavedPlace>[];

    return data
        .whereType<Map>()
        .map(
          (item) => BookingSavedPlace.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((item) => item.address.isNotEmpty && item.point.isValid)
        .toList();
  }

  List<BookingSavedRoute> _decodeSavedRoutes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <BookingSavedRoute>[];
    final data = jsonDecode(raw);
    if (data is! List) return <BookingSavedRoute>[];

    return data
        .whereType<Map>()
        .map(
          (item) => BookingSavedRoute.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where(
          (item) =>
              item.pickup.address.isNotEmpty &&
              item.drop.address.isNotEmpty &&
              item.pickup.point.isValid &&
              item.drop.point.isValid,
        )
        .toList();
  }

  @override
  void dispose() {
    _pickupDebounce?.cancel();
    _dropDebounce?.cancel();
    pickupAddressController.dispose();
    dropAddressController.dispose();
    super.dispose();
  }
}
