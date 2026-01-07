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
  // 1: Chuyển khoản | 2: Thanh toán bằng ví | 3: Tiền mặt (Thanh toán sau)
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


  // ================== ĐIỂM ĐÓN ==================
  String? selectedProvincePickup;
  String? addressPickup;

  // ================== ĐIỂM ĐẾN ==================
  String? selectedProvinceDrop;
  String? addressDrop;

  // ================== THÔNG TIN KHÁCH ==================
  String? customerPhone;
  String? note;

  // ================== GIÁ ==================
  double? tripPrice; // thành  tiền
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
    // ⛔ BẮT BUỘC: phải có tỉnh + ngày + giờ
    if (selectedProvincePickup == null ||
        selectedProvinceDrop == null ||
        goDate == null ||
        goTime == null) {
      _resetPrice();
      notifyListeners();
      return;
    }

    final fromId = int.tryParse(selectedProvincePickup!);
    final toId = int.tryParse(selectedProvinceDrop!);
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
        fromProvinceId: fromId,
        toProvinceId: toId,
        type: tripType,
        paymentMethod: _paymentMethod,
        pickupTime: pickupDateTime,
      );

      final json = ApiService.safeDecode(res.body);

      if (res.statusCode == 200 &&
          json["success"] == true &&
          json["data"] != null) {

        final data = json["data"];

        currentTripId = data["id"];
        basePrice   = (data["basePrice"] as num).toDouble();
        discount    = (data["discount"] as num).toDouble();
        surcharge   = (data["surcharge"] as num).toDouble();
        tripPrice   = (data["finalPrice"] as num).toDouble();
        isHoliday   = data["isHoliday"] ?? false;

        priceErrorMessage = null;
      } else {
        _resetPrice();
        priceErrorMessage =
            json["message"] ?? "Tuyến đường này hiện chưa có đơn giá";
      }
    } catch (e) {
      _resetPrice();
      priceErrorMessage = "Không thể lấy giá chuyến đi, vui lòng thử lại sau hoặc liên hệ CSKH";
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
  }


  // =====================================================
  // 13. TẠO CHUYẾN (NHẬN THÊM CONTENT TỪ UI)
  // =====================================================
  Future<Map<String, dynamic>> createRide(String accessToken, {String content = ""}) async {
    if (currentTripId == null) {
      throw Exception("Chưa có giá chuyến đi");
    }

    // Kết hợp ngày và giờ thành chuỗi ISO
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
      content: content,
    );

    final data = ApiService.safeDecode(res.body);

    // Kiểm tra lỗi từ backend (ví dụ: "Chưa chuyển khoản thành công!")
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
    tripCategory = TripCategory.choNguoi;
    isChoNguoi = true;
    isBaoXe = false;
    isHoaToc = false;
    _paymentMethod = 3;

    // 2️⃣ Reset địa điểm
    selectedProvincePickup = null;
    addressPickup = null;
    selectedProvinceDrop = null;
    addressDrop = null;

    // 3️⃣ Reset thời gian & thông tin khách
    goDate = null;
    goTime = null;
    customerPhone = null;
    note = null;

    // 4️⃣ Reset giá (1 nơi duy nhất)
    _resetPrice();

    // 5️⃣ Reset loading
    isLoadingPrice = false;

    notifyListeners();
  }



}