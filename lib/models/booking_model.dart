import 'package:flutter/material.dart';
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
  static const int hanoiProvinceId = 1;
  static const int noiBaiDistrictId = 974;
  static const String noiBaiAirportAddress = "Cảng hàng không quốc tế Nội Bài";

  int _userId = 0;
  int get userId => _userId;

  set userId(int value) {
    _userId = value;
    notifyListeners();
  }

  // ================== LOẠI CHUYẾN ==================
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

  // ================== PHƯƠNG THỨC THANH TOÁN ==================
  // 1: Chuyển khoản | 2: Thanh toán bằng ví | 3: Tiền mặt (Thanh toán sau)
  int _paymentMethod = 1;
  int get paymentMethod => _paymentMethod;

  set paymentMethod(int value) {
    if (_paymentMethod != value) {
      _paymentMethod = value;
      notifyListeners();
      fetchTripPrice();
    }
  }

  // ================== NGÀY GIỜ ==================
  DateTime? goDate;
  TimeOfDay? goTime;

  // ================== SỐ LƯỢNG (NEW) ==================
  int _quantity = 1;
  int get quantity => _quantity;

  set quantity(int value) {
    final v = value < 1 ? 1 : value;
    if (_quantity != v) {
      _quantity = v;
      notifyListeners();
      fetchTripPrice();
    }
  }

  // ================== DANH SÁCH ==================
  List<dynamic> provinces = [];

  List<dynamic> pickupDistricts = [];
  List<dynamic> dropDistricts = [];

  List<dynamic> get availablePickupDistricts => _filterDistrictsForSelection(
    districts: pickupDistricts,
    currentProvinceId: _selectedProvincePickup,
    otherProvinceId: _selectedProvinceDrop,
    otherDistrictId: _selectedDistrictDrop,
  );

  List<dynamic> get availableDropDistricts => _filterDistrictsForSelection(
    districts: dropDistricts,
    currentProvinceId: _selectedProvinceDrop,
    otherProvinceId: _selectedProvincePickup,
    otherDistrictId: _selectedDistrictPickup,
  );

  // ================== ĐIỂM ĐÓN ==================
  // lưu id thay vì string để dễ dùng với API
  int? _selectedProvincePickup;
  int? get selectedProvincePickup => _selectedProvincePickup;

  int? _selectedDistrictPickup;
  int? get selectedDistrictPickup => _selectedDistrictPickup;

  String? addressPickup;

  // ================== ĐIỂM ĐẾN ==================
  int? _selectedProvinceDrop;
  int? get selectedProvinceDrop => _selectedProvinceDrop;

  int? _selectedDistrictDrop;
  int? get selectedDistrictDrop => _selectedDistrictDrop;

  String? addressDrop;

  // ================== THÔNG TIN KHÁCH ==================
  String? customerPhone;
  String? note;

  // ================== GIÁ ==================
  double? tripPrice; // thành tiền
  int? currentTripId;
  double? basePrice;
  double discount = 0;
  double surcharge = 0;
  bool isHoliday = false;
  String? priceErrorMessage;

  bool isLoadingPrice = false;

  BookingModel() {
    fetchProvinces();
    // Không gọi fetchDistricts() ở đây vì chưa có provinceId cụ thể
  }

  // =====================================================
  // LẤY TỈNH / HUYỆN
  // =====================================================
  Future<void> fetchProvinces() async {
    provinces = await ApiService.getProvinces();
    notifyListeners();
  }

  Future<void> fetchPickupDistricts(int provinceId) async {
    pickupDistricts = await ApiService.getDistricts(provinceId: provinceId);
    notifyListeners();
  }

  Future<void> fetchDropDistricts(int provinceId) async {
    dropDistricts = await ApiService.getDistricts(provinceId: provinceId);
    notifyListeners();
  }

  bool canSelectSameProvince(int? provinceId) {
    return provinceId == hanoiProvinceId;
  }

  List<dynamic> _filterDistrictsForSelection({
    required List<dynamic> districts,
    required int? currentProvinceId,
    required int? otherProvinceId,
    required int? otherDistrictId,
  }) {
    if (currentProvinceId != hanoiProvinceId ||
        otherProvinceId != hanoiProvinceId) {
      return districts;
    }

    if (otherDistrictId == null || otherDistrictId == noiBaiDistrictId) {
      return districts;
    }

    return districts.where((district) {
      final id = _parseLocationId(district['id']);
      return id == noiBaiDistrictId;
    }).toList();
  }

  int? _parseLocationId(dynamic rawId) {
    if (rawId is int) return rawId;
    return int.tryParse(rawId.toString());
  }

  void _syncAddressWithDistrict({
    required bool isPickup,
    required int? districtId,
  }) {
    final shouldAutofill = districtId == noiBaiDistrictId;
    final currentAddress = isPickup ? addressPickup : addressDrop;

    if (shouldAutofill) {
      if (isPickup) {
        addressPickup = noiBaiAirportAddress;
      } else {
        addressDrop = noiBaiAirportAddress;
      }
      return;
    }

    if (currentAddress == noiBaiAirportAddress) {
      if (isPickup) {
        addressPickup = null;
      } else {
        addressDrop = null;
      }
    }
  }

  // Setter cho province pickup: khi đổi tỉnh sẽ load danh sách huyện cho điểm đón
  Future<void> setSelectedProvincePickup(int? provinceId) async {
    if (_selectedProvincePickup == provinceId) return;

    _selectedProvincePickup = provinceId;
    // reset district selection khi đổi tỉnh
    _selectedDistrictPickup = null;
    _syncAddressWithDistrict(isPickup: true, districtId: null);
    pickupDistricts = [];

    notifyListeners();

    if (provinceId != null) {
      await fetchPickupDistricts(provinceId);
    }

    // cập nhật giá nếu cần
    fetchTripPrice();
  }

  // Setter cho district pickup
  void setSelectedDistrictPickup(int? districtId) {
    if (_selectedDistrictPickup == districtId) return;
    _selectedDistrictPickup = districtId;
    _syncAddressWithDistrict(isPickup: true, districtId: districtId);
    fetchTripPrice();
    notifyListeners();
  }

  void setSelectedDistrictDrop(int? districtId) {
    if (_selectedDistrictDrop == districtId) return;
    _selectedDistrictDrop = districtId;
    _syncAddressWithDistrict(isPickup: false, districtId: districtId);
    fetchTripPrice();
    notifyListeners();
  }

  // Setter cho province drop: khi đổi tỉnh sẽ load danh sách huyện cho điểm đến
  Future<void> setSelectedProvinceDrop(int? provinceId) async {
    if (_selectedProvinceDrop == provinceId) return;

    _selectedProvinceDrop = provinceId;
    // reset district selection khi đổi tỉnh
    _selectedDistrictDrop = null;
    _syncAddressWithDistrict(isPickup: false, districtId: null);
    dropDistricts = [];

    notifyListeners();

    if (provinceId != null) {
      await fetchDropDistricts(provinceId);
    }

    // cập nhật giá nếu cần
    fetchTripPrice();
  }

  // =====================================================
  // MAP UI → TYPE API
  // =====================================================
  int get tripType => _selectedRideType;

  // =====================================================
  // 12. LẤY GIÁ
  // =====================================================
  Future<void> fetchTripPrice() async {
    if (selectedProvincePickup == null ||
        selectedDistrictPickup == null ||
        selectedProvinceDrop == null ||
        selectedDistrictDrop == null ||
        goDate == null ||
        goTime == null) {
      _resetPrice();
      notifyListeners();
      return;
    }

    final fromId = selectedProvincePickup;
    final toId = selectedProvinceDrop;
    if (fromId == null || toId == null) {
      _resetPrice();
      notifyListeners();
      return;
    }

    final pickupDateTime = DateTime(
      goDate!.year,
      goDate!.month,
      goDate!.day,
      goTime!.hour,
      goTime!.minute,
    ).toIso8601String();

    isLoadingPrice = true;
    notifyListeners();

    try {
      final res = await ApiService.getTripPrice(
        fromDistrictId: selectedDistrictPickup!,
        toDistrictId: selectedDistrictDrop!,
        type: tripType,
        paymentMethod: _paymentMethod,
        pickupTime: pickupDateTime,
        quantity: normalizedQuantity,
      );

      final json = ApiService.safeDecode(res.body);

      if (res.statusCode == 200 &&
          json["success"] == true &&
          json["data"] != null) {
        final data = json["data"];

        currentTripId = data["id"];
        basePrice = (data["basePrice"] as num).toDouble();
        discount = (data["discount"] as num).toDouble();
        surcharge = (data["surcharge"] as num).toDouble();
        tripPrice = (data["finalPrice"] as num).toDouble();
        isHoliday = data["isHoliday"] ?? false;

        priceErrorMessage = null;
      } else {
        _resetPrice();
        priceErrorMessage =
            json["message"] ?? "Tuyến đường này hiện chưa có đơn giá";
      }
    } catch (e) {
      _resetPrice();
      priceErrorMessage =
      "Không thể lấy giá chuyến đi, vui lòng thử lại sau hoặc liên hệ CSKH";
    } finally {
      isLoadingPrice = false;
      notifyListeners();
    }
  }

  // RESET GIÁ
  void _resetPrice() {
    currentTripId = null;
    basePrice = null;
    tripPrice = null;
    discount = 0;
    surcharge = 0;
    isHoliday = false;
  }

  // =====================================================
  // 13. TẠO CHUYẾN (NHẬN THÊM CONTENT TỪ UI)
  // =====================================================
  Future<Map<String, dynamic>> createRide(
      String accessToken, {
        String content = "",
      }) async {
    if (currentTripId == null) {
      throw Exception("Chưa có giá chuyến đi");
    }

    final String pickupDateTime = DateTime(
      goDate!.year,
      goDate!.month,
      goDate!.day,
      goTime!.hour,
      goTime!.minute,
    ).toIso8601String();

    final res = await ApiService.createRide(
      accessToken: accessToken,
      tripId: currentTripId!,
      fromAddress: addressPickup ?? "",
      toAddress: addressDrop ?? "",
      customerPhone: customerPhone ?? "",
      pickupTime: pickupDateTime,
      note: note ?? "",
      paymentMethod: _paymentMethod,
      quantity: normalizedQuantity,
      content: content,
    );

    final data = ApiService.safeDecode(res.body);

    if (res.statusCode != 200 || data['success'] == false) {
      throw data['message'] ?? "Lỗi không xác định khi tạo chuyến";
    }

    return Map<String, dynamic>.from(data);
  }

  // =====================================================
  // RESET FORM
  // =====================================================
  void resetForm() {
    // 1️⃣ Reset loại chuyến & payment
    _selectedRideType = BookingRideType.passenger;
    _paymentMethod = 3;

    // 1.1️⃣ Reset quantity
    _quantity = 1;

    // 2️⃣ Reset địa điểm
    _selectedProvincePickup = null;
    _selectedDistrictPickup = null;
    addressPickup = null;
    pickupDistricts = [];

    _selectedProvinceDrop = null;
    _selectedDistrictDrop = null;
    addressDrop = null;
    dropDistricts = [];

    // 3️⃣ Reset thời gian & thông tin khách
    goDate = null;
    goTime = null;
    customerPhone = null;
    note = null;

    // 4️⃣ Reset giá
    _resetPrice();

    // 5️⃣ Reset loading
    isLoadingPrice = false;

    notifyListeners();
  }
}