import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class BookingModel extends ChangeNotifier {
  final pickupAddressController = TextEditingController();
  final dropAddressController = TextEditingController();

  Timer? _pickupDebounce;
  Timer? _dropDebounce;
  String _latestPickupQuery = '';
  String _latestDropQuery = '';

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

  BookingModel();

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
      priceErrorMessage = 'Không thể tính giá chuyến đi, vui lòng thử lại sau.';
    } finally {
      isLoadingPrice = false;
      notifyListeners();
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

  @override
  void dispose() {
    _pickupDebounce?.cancel();
    _dropDebounce?.cancel();
    pickupAddressController.dispose();
    dropAddressController.dispose();
    super.dispose();
  }
}
