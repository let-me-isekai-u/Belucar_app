import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// ================== ENUM DÙNG CHO RADIO ==================
enum TripCategory {
  choNguoi,
  choHang,
}

class BookingModel extends ChangeNotifier {
  // ================== LOẠI CHUYẾN ==================
  bool isChoNguoi = true;   // true = chở người, false = chở hàng
  bool isBaoXe = false;     // chỉ dùng khi chở người
  bool isHoaToc = false;   // chỉ dùng khi chở hàng

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
  // 1: Chuyển khoản | 2: Thanh toán sau (tiền mặt)
  int _paymentMethod = 3;
  int get paymentMethod => _paymentMethod;

  set paymentMethod(int value) {
    if (_paymentMethod != value) {
      _paymentMethod = value;
      notifyListeners();
      fetchTripPrice();
    }
  }

  // ================== RADIO STATE ==================
  TripCategory tripCategory = TripCategory.choNguoi;

  // ================== NGÀY GIỜ ==================
  DateTime? goDate;
  TimeOfDay? goTime;

  // ================== DANH SÁCH ==================
  List<dynamic> provinces = [];
  List<dynamic> districtsPickup = [];
  List<dynamic> districtsDrop = [];

  // ================== ĐIỂM ĐÓN ==================
  String? selectedProvincePickup;
  String? selectedDistrictPickup;
  String? addressPickup;

  // ================== ĐIỂM ĐẾN ==================
  String? selectedProvinceDrop;
  String? selectedDistrictDrop;
  String? addressDrop;

  // ================== THÔNG TIN KHÁCH ==================
  String? customerPhone;
  String? note;

  // ================== GIÁ ==================
  double? tripPrice;
  bool isLoadingPrice = false;
  int? currentTripId;

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

  Future<void> fetchDistricts(String? provinceId, bool isPickup) async {
    if (provinceId == null) return;
    final id = int.tryParse(provinceId);
    if (id == null) return;

    final list = await ApiService.getDistricts(id);

    if (isPickup) {
      districtsPickup = list;
    } else {
      districtsDrop = list;
    }
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
  // 12. LẤY GIÁ
  // =====================================================
  Future<void> fetchTripPrice() async {
    if (selectedProvincePickup == null || selectedProvinceDrop == null) return;

    final fromId = int.tryParse(selectedProvincePickup!);
    final toId = int.tryParse(selectedProvinceDrop!);
    if (fromId == null || toId == null) return;

    isLoadingPrice = true;
    notifyListeners();

    try {
      final res = await ApiService.getTripPrice(
        fromProvinceId: fromId,
        toProvinceId: toId,
        type: tripType,
        paymentMethod: _paymentMethod,
      );

      if (res.statusCode == 200) {
        final json = ApiService.safeDecode(res.body);
        final data = json["data"];

        if (data != null) {
          tripPrice = (data["price"] as num).toDouble();
          currentTripId = (data["id"] as num).toInt();
        }
      } else {
        tripPrice = null;
        currentTripId = null;
      }
    } catch (_) {
      tripPrice = null;
    } finally {
      isLoadingPrice = false;
      notifyListeners();
    }
  }

  // =====================================================
  // 13. TẠO CHUYẾN (ĐÃ TRUYỀN paymentMethod)
  // =====================================================
  Future<Map<String, dynamic>> createRide(String token) async {
    if (currentTripId == null) {
      throw Exception("Chưa có giá chuyến đi");
    }

    final res = await ApiService.createRide(
      accessToken: token,
      tripId: currentTripId!,
      fromDistrictId: int.parse(selectedDistrictPickup!),
      toDistrictId: int.parse(selectedDistrictDrop!),
      fromAddress: addressPickup ?? "",
      toAddress: addressDrop ?? "",
      customerPhone: customerPhone ?? "",
      pickupTime: DateTime(
        goDate!.year,
        goDate!.month,
        goDate!.day,
        goTime!.hour,
        goTime!.minute,
      ).toIso8601String(),
      note: note ?? "",
      paymentMethod: _paymentMethod, // ✅ BỔ SUNG
    );

    return Map<String, dynamic>.from(
      ApiService.safeDecode(res.body),
    );
  }

  // =====================================================
  // RESET FORM
  // =====================================================
  void resetForm() {
    tripCategory = TripCategory.choNguoi;
    isChoNguoi = true;
    isBaoXe = false;
    isHoaToc = false;
    _paymentMethod = 3;

    selectedProvincePickup = null;
    selectedDistrictPickup = null;
    addressPickup = null;
    selectedProvinceDrop = null;
    selectedDistrictDrop = null;
    addressDrop = null;

    goDate = null;
    goTime = null;
    customerPhone = null;
    note = null;
    tripPrice = null;
    currentTripId = null;

    districtsPickup = [];
    districtsDrop = [];

    notifyListeners();
  }
}
