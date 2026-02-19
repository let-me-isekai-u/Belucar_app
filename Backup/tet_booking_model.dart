import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// ================== ENUM DÙNG CHO RADIO ==================
enum TripCategory {
  choNguoi,
  choHang,
}

class BookingModel extends ChangeNotifier {
  int _userId = 0;
  int get userId => _userId;

  set userId(int value) {
    _userId = value;
    notifyListeners();
  }

  // ================== LOẠI CHUYẾN ==================
  bool isChoNguoi = true; // true = chở người, false = chở hàng
  bool isBaoXe = false; // chỉ dùng khi chở người
  bool isHoaToc = false; // chỉ dùng khi chở hàng

  void setIsBaoXe(bool value) {
    if (isBaoXe != value) {
      isBaoXe = value;
      notifyListeners();
      fetchTripPrice();
    }
  }

  void setIsHoaToc(bool value) {
    if (isHoaToc != value) {
      isHoaToc = value;
      notifyListeners();
      fetchTripPrice();
    }
  }

  // ================== PHƯƠNG THỨC THANH TOÁN ==================
  // 1: Chuyển khoản | 2: Thanh toán bằng ví | 3: Tiền mặt (Thanh toán sau)
  int _paymentMethod = 1; // Đúng với API docs (chỉ 1 hoặc 2)
  int get paymentMethod => _paymentMethod;

  set paymentMethod(int value) {
    if (_paymentMethod != value) {
      _paymentMethod = value;
      notifyListeners();
      fetchTripPrice();
    }
  }

  // ================== MÃ VOUCHER ==================
  String? voucherCode;
  String? voucherMessage; // Lưu thông báo từ API apply-voucher (nếu có)
  double voucherDiscount = 0;

  // ================== RADIO STATE ==================
  TripCategory tripCategory = TripCategory.choNguoi;

  // ================== NGÀY GIỜ ==================
  DateTime? goDate;
  TimeOfDay? goTime;

  // ================== DANH SÁCH ==================
  List<dynamic> provinces = [];
  List<dynamic> pickupDistricts = [];
  List<dynamic> dropDistricts = [];

  // ================== ĐIỂM ĐÓN ==================
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
  }

  // =====================================================
  // RADIO HANDLER
  // =====================================================
  void setTripCategory(TripCategory value) {
    tripCategory = value;
    if (value == TripCategory.choNguoi) {
      isChoNguoi = true;
      isHoaToc = false;
    } else {
      isChoNguoi = false;
      isBaoXe = false;
    }
    notifyListeners();
    fetchTripPrice();
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

  Future<void> setSelectedProvincePickup(int? provinceId) async {
    if (_selectedProvincePickup == provinceId) return;
    _selectedProvincePickup = provinceId;
    _selectedDistrictPickup = null;
    pickupDistricts = [];
    notifyListeners();
    if (provinceId != null) {
      await fetchPickupDistricts(provinceId);
    }
    fetchTripPrice();
  }

  void setSelectedDistrictPickup(int? districtId) {
    if (_selectedDistrictPickup == districtId) return;
    _selectedDistrictPickup = districtId;
    fetchTripPrice();
    notifyListeners();
  }

  Future<void> setSelectedProvinceDrop(int? provinceId) async {
    if (_selectedProvinceDrop == provinceId) return;
    _selectedProvinceDrop = provinceId;
    _selectedDistrictDrop = null;
    dropDistricts = [];
    notifyListeners();
    if (provinceId != null) {
      await fetchDropDistricts(provinceId);
    }
    fetchTripPrice();
  }

  void setSelectedDistrictDrop(int? districtId) {
    if (_selectedDistrictDrop == districtId) return;
    _selectedDistrictDrop = districtId;
    fetchTripPrice();
    notifyListeners();
  }

  // =====================================================
  // MAP UI → TYPE API
  // =====================================================
  int get tripType {
    if (isChoNguoi) {
      return isBaoXe ? 2 : 1;
    } else {
      return isHoaToc ? 4 : 3;
    }
  }

  // =====================================================
  // LẤY GIÁ
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
      final res = await ApiService.getTripPriceTET(
        fromDistrictId: selectedDistrictPickup!,
        toDistrictId: selectedDistrictDrop!,
        type: tripType,
        paymentMethod: paymentMethod,
        pickupTime: pickupDateTime,
      );

      final json = ApiService.safeDecode(res.body);

      if (res.statusCode == 200 &&
          json["success"] == true &&
          json["data"] != null) {
        final data = json["data"];
        currentTripId = data["id"];
        basePrice = (data["basePrice"] as num?)?.toDouble();
        discount = (data["discount"] as num?)?.toDouble() ?? 0;
        surcharge = (data["surcharge"] as num?)?.toDouble() ?? 0;
        tripPrice = (data["finalPrice"] as num?)?.toDouble();
        isHoliday = data["isHoliday"] == true;
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

  //RESET GIÁ
  void _resetPrice() {
    currentTripId = null;
    basePrice = null;
    tripPrice = null;
    discount = 0;
    surcharge = 0;
    isHoliday = false;
    voucherDiscount = 0;
    voucherMessage = null;
  }

  // =====================================================
  // ÁP DỤNG VOUCHER
  // =====================================================
  Future<void> applyVoucherTET(String accessToken) async {
    if (currentTripId == null || voucherCode == null || voucherCode!.isEmpty) {
      voucherDiscount = 0;
      voucherMessage = null;
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

    try {
      final json = await ApiService.applyVoucherTET(
        accessToken: accessToken,
        tripId: currentTripId!,
        pickupTime: pickupDateTime,
        voucherCode: voucherCode!,
      );
      if (json["success"] == true && json["data"] != null) {
        final data = json["data"];
        voucherDiscount = (data["discount"] as num?)?.toDouble() ?? 0;
        voucherMessage = data["voucherMessage"]?.toString();
        if (data["finalPrice"] != null) {
          tripPrice = (data["finalPrice"] as num?)?.toDouble();
        }
        priceErrorMessage = null;
      } else {
        voucherDiscount = 0;
        voucherMessage = "Mã voucher không đúng, vui lòng kiểm tra lại hoặc liên hệ CSKH để được hỗ trợ, xin cám ơn!";
      }
    } catch (e) {
      voucherDiscount = 0;
      voucherMessage = "Áp dụng voucher thất bại!";
    } finally {
      notifyListeners();
    }
  }

  // =====================================================
  // TẠO CHUYẾN ĐI
  // =====================================================
  Future<Map<String, dynamic>> createRideTET(String accessToken, {String content = ""}) async {
    if (currentTripId == null) {
      throw Exception("Chưa có giá chuyến đi");
    }
    final pickupDateTime = DateTime(
      goDate!.year,
      goDate!.month,
      goDate!.day,
      goTime!.hour,
      goTime!.minute,
    ).toIso8601String();

    final res = await ApiService.createRideTET(
      accessToken: accessToken,
      tripId: currentTripId!,
      fromAddress: addressPickup ?? "",
      toAddress: addressDrop ?? "",
      customerPhone: customerPhone ?? "",
      pickupTime: pickupDateTime,
      note: note ?? "",
      paymentMethod: paymentMethod,
      content: content,
      voucherCode: voucherCode ?? "",
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
    tripCategory = TripCategory.choNguoi;
    isChoNguoi = true;
    isBaoXe = false;
    isHoaToc = false;
    _paymentMethod = 1;
    _selectedProvincePickup = null;
    _selectedDistrictPickup = null;
    addressPickup = null;
    pickupDistricts = [];
    _selectedProvinceDrop = null;
    _selectedDistrictDrop = null;
    addressDrop = null;
    dropDistricts = [];
    goDate = null;
    goTime = null;
    customerPhone = null;
    note = null;
    _resetPrice();
    voucherCode = null;
    isLoadingPrice = false;
    notifyListeners();
  }
}