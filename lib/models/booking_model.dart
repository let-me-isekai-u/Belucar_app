import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// ================== ENUM DÙNG CHO RADIO ==================
enum TripCategory {
  choNguoi,
  choHang,
}

class BookingModel extends ChangeNotifier {
  // ================== LOẠI CHUYẾN (GIỮ NGUYÊN BOOL) ==================
  bool isChoNguoi = true;   // true = chở người, false = chở hàng
  bool isBaoXe = false;     // chỉ dùng khi chở người
  bool isHoaToc = false;   // chỉ dùng khi chở hàng

  void setIsBaoXe(bool value) {
    if (isBaoXe != value) {
      isBaoXe = value;
      notifyListeners();
    }
  }

  void setIsHoaToc(bool value) {
    if (isHoaToc != value) {
      isHoaToc = value;
      notifyListeners();
    }
  }

  // ================== RADIO STATE (MỚI - FIX DEPRECATED) ==================
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
  // tripID của giá cuốc trong api 12 sau khi chọn điểm đến và đón, dùng để khai báo cho api 13
  int? currentTripId;

  BookingModel() {
    fetchProvinces();
  }

  // =====================================================
  // RADIO HANDLER (QUAN TRỌNG)
  // =====================================================
  void setTripCategory(TripCategory value) {
    tripCategory = value;

    if (value == TripCategory.choNguoi) {
      isChoNguoi = true;
      isHoaToc = false; // reset logic không liên quan
    } else {
      isChoNguoi = false;
      isBaoXe = false;
    }

    notifyListeners();
  }

  // =====================================================
  // LẤY TỈNH
  // =====================================================
  Future<void> fetchProvinces() async {
    provinces = await ApiService.getProvinces();
    notifyListeners();
  }

  // =====================================================
  // LẤY HUYỆN
  // =====================================================
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
  // MAP UI → TYPE API (CHUẨN THEO TÀI LIỆU)
  // =====================================================
  int get tripType {
    if (isChoNguoi) {
      return isBaoXe ? 2 : 1;
    } else {
      return isHoaToc ? 4 : 3;
    }
  }

  // 12. LẤY GIÁ
  Future<void> fetchTripPrice() async {
    debugPrint("🔵 [PRICE] fetchTripPrice() called");

    if (selectedProvincePickup == null || selectedProvinceDrop == null) {
      debugPrint("❌ [PRICE] Missing province");
      return;
    }

    final fromId = int.tryParse(selectedProvincePickup!);
    final toId = int.tryParse(selectedProvinceDrop!);

    if (fromId == null || toId == null) {
      debugPrint("❌ [PRICE] ProvinceId parse failed");
      return;
    }

    debugPrint("📌 fromProvinceId: $fromId");
    debugPrint("📌 toProvinceId: $toId");
    debugPrint("📌 tripType: $tripType");

    isLoadingPrice = true;
    notifyListeners();

    final res = await ApiService.getTripPrice(
      fromProvinceId: fromId,
      toProvinceId: toId,
      type: tripType,
    );

    debugPrint("📥 [PRICE] StatusCode: ${res.statusCode}");
    debugPrint("📥 [PRICE] Body: ${res.body}");

    if (res.statusCode == 200) {
      final json = ApiService.safeDecode(res.body);

      final data = json["data"];
      final price = data?["price"];
      final id = data?["id"];

      debugPrint("[PRICE] price = $price");
      debugPrint("ID báo giá: $id");

      if (price != null) {
        tripPrice = (price as num).toDouble();
      } if(id != null){
        currentTripId = (id as num).toInt();
      }
    } else {
      debugPrint("❌ [PRICE] API error");
    }

    isLoadingPrice = false;
    notifyListeners();
  }


  // 13. TẠO CHUYẾN
  Future<Map<String, dynamic>> createRide(String token) async {
    //Kiểm tra xem đã lưu giá ở id chưa
    if(currentTripId == null){
      throw Exception("Lỗi: Chưa có giá chuyến đi, vui lòng thử lại sau");
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
    );

    return Map<String, dynamic>.from(
      ApiService.safeDecode(res.body),
    );
  }

  void resetForm() {
    // 1. Reset các tùy chọn chính về mặc định
    tripCategory = TripCategory.choNguoi;
    isChoNguoi = true;
    isBaoXe = false;
    isHoaToc = false;

    // 2. Reset điểm đón/đến
    selectedProvincePickup = null;
    selectedDistrictPickup = null;
    addressPickup = null;

    selectedProvinceDrop = null;
    selectedDistrictDrop = null;
    addressDrop = null;

    // 3. Reset ngày giờ và thông tin khách
    goDate = null;
    goTime = null;
    customerPhone = null;
    note = null;

    // 4. Reset thông tin giá
    tripPrice = null;
    currentTripId = null;

    // 5. Reset danh sách huyện (Tùy chọn, nếu bạn muốn làm sạch UI nhanh hơn)
    districtsPickup = [];
    districtsDrop = [];

    // Cần gọi notifyListeners() để tất cả các widget đang nghe (như dropdown, date picker)
    // cập nhật lại UI thành trạng thái rỗng
    notifyListeners();
  }
}
