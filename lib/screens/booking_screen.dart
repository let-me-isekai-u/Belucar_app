import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'activity_screen.dart';
import 'dart:async';

class BookingScreen extends StatelessWidget {
  final Function(int) onRideBooked;
  const BookingScreen({super.key, required this.onRideBooked});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BookingModel(),
      // TRUYỀN CALLBACK VÀO _BookingView
      child: _BookingView(onRideBooked: onRideBooked),
    );
  }
}
class _BookingView extends StatefulWidget {
  // THÊM CALLBACK VÀO _BookingView
  final Function(int) onRideBooked;
  const _BookingView({required this.onRideBooked});

  @override
  State<_BookingView> createState() => _BookingViewState();
}


class _BookingViewState extends State<_BookingView> {
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  void _resetControllers() {
    _phoneController.clear();
    _noteController.clear();
  }

void _handlePaymentMethodChange(BookingModel model, int? value){
    if(value == null) return;
    model.paymentMethod = value;
}


  void _showPaymentQR(BookingModel model, String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    // Nội dung chuyển khoản đồng nhất với Home
    final int userId = prefs.getInt("id") ?? 0;
    final String content = "$userId${DateFormat('HHmmss').format(DateTime.now())}";

    final qrUrl = "https://img.vietqr.io/image/MB-246878888-compact2.png"
        "?amount=${model.tripPrice!.toStringAsFixed(0)}&addInfo=$content&accountName=THE%20BELUGAS";

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        int countdown = 300;
        Timer? countdownTimer;
        Timer? pollTimer;
        bool isChecking = false;

        return StatefulBuilder(builder: (ctx, setDialogState) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (countdown <= 0) {
              t.cancel(); pollTimer?.cancel();
              Navigator.pop(dialogCtx);
            } else if (dialogCtx.mounted) {
              setDialogState(() => countdown--);
            }
          });
          // Cứ mỗi 7 giây gọi API createRide một lần
          pollTimer ??= Timer.periodic(const Duration(seconds: 7), (t) async {
            if (isChecking) return;
            isChecking = true;

            try {
              // Gọi trực tiếp createRide, nếu tiền chưa về Server sẽ trả lỗi
              // và logic try-catch sẽ bắt lại để đợi lần poll tiếp theo.
              final result = await model.createRide(accessToken, content: content);

              if (result['success'] == true) {
                t.cancel();
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx); // Đóng mã QR
                  widget.onRideBooked(2);   // Chuyển sang tab Hoạt động
                }
              }
            } catch (e) {
              // Khi tiền chưa về, Model sẽ throw error, chúng ta im lặng để nó poll tiếp
              print("Đang đợi thanh toán... $e");
            }
            isChecking = false;
          });

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Thanh toán chuyến đi",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 15),
                  Image.network(qrUrl),
                  const SizedBox(height: 15),
                  const Text("Nội dung chuyển khoản:"),
                  Text(content,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
                  const SizedBox(height: 15),
                  const Text(
                    "Hệ thống đang kiểm tra tự động...\nVui lòng giữ màn hình này.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text("Vui lòng chuyển khoản trong: ${countdown ~/ 60}:${(countdown % 60).toString().padLeft(2, '0')}"),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      pollTimer?.cancel();
                      Navigator.pop(dialogCtx);
                    },
                    child: const Text("Hủy giao dịch"),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _handleDirectBooking(BookingModel model, String accessToken) async {
    try {
      // Gọi API createRide bình thường (content mặc định rỗng)
      final result = await model.createRide(accessToken);
      if (result['success'] == true) {
        widget.onRideBooked(2); // Chuyển sang tab Hoạt động
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }


  bool _validateBeforeBooking(BookingModel model) {
    if (model.tripCategory == null) return false;

    if (model.selectedProvincePickup == null ||
        (model.addressPickup == null || model.addressPickup!.trim().isEmpty)) {
      return false;
    }

    if (model.selectedProvinceDrop == null ||
        (model.addressDrop == null || model.addressDrop!.trim().isEmpty)) {
      return false;
    }

    if (model.goDate == null || model.goTime == null) return false;

    if (_phoneController.text.trim().isEmpty) return false;

    return true;
  }


  String formatCurrency(double value) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("accessToken");
  }


  @override
  Widget build(BuildContext context) {
    final model = context.watch<BookingModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt chuyến'),
        centerTitle: true,
      ),
      body: _buildBookingForm(model),
      // THÊM BOTTOM BAR CHO GIÁ VÀ NÚT ĐẶT CHUYẾN
      bottomNavigationBar: _buildPriceAndBookingButton(model, context),
    );
  }

  //hiện qr
  void _showConfirmPaymentDialog(BookingModel model, String accessToken) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận thông tin"),
        content: const Text(
            "Bạn đã kiểm tra kỹ thông tin chuyến đi chưa?\n\n"
                "⚠️ Lưu ý: KHÔNG tắt ứng dụng hoặc đóng mã QR cho đến khi hệ thống báo thành công."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // SỬA TẠI ĐÂY: Truyền accessToken vào
              _showPaymentQR(model, accessToken);
            },
            child: const Text("Xác nhận & Hiện QR"),
          ),
        ],
      ),
    );
  }

  //GIÁ VÀ NÚT ĐẶT CHUYẾN (STICKY BOTTOM BAR)
  Widget _buildPriceAndBookingButton(BookingModel model, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HIỂN THỊ GIÁ ---
          if (model.isLoadingPrice)
            const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text("Đang tính giá...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else if (model.tripPrice != null)
            Text(
              "Tổng chi phí: ${formatCurrency(model.tripPrice!)}",
              style: const TextStyle(
                color: Colors.green,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            const Text(
              "Vui lòng chọn đầy đủ lộ trình",
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
          const SizedBox(height: 12),

          // --- NÚT ĐẶT CHUYẾN ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // 1. Kiểm tra thông tin bắt buộc
                if (!_validateBeforeBooking(model)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập đầy đủ thông tin bắt buộc'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                // 2. Lấy accessToken từ SharedPreferences
                final accessToken = await _getAccessToken();
                if (accessToken == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bạn chưa đăng nhập')),
                  );
                  return;
                }

                // 3. Cập nhật dữ liệu từ Controller vào Model
                model.customerPhone = _phoneController.text.trim();
                model.note = _noteController.text.trim();

                // 4. PHÂN NHÁNH THANH TOÁN
                if (model.paymentMethod == 1) {
                  // CHUYỂN KHOẢN: Hiện xác nhận -> Hiện QR & Polling
                  _showConfirmPaymentDialog(model, accessToken);
                } else {
                  // VÍ HOẶC TIỀN MẶT: Gọi API trực tiếp
                  _handleDirectBooking(model, accessToken);
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                "Xác nhận Đặt chuyến",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }




  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children, // Chèn các widget con
          ],
        ),
      ),
    );
  }


  //hàm chọn điểm đi, điểm đến và thời điểm đón
  Widget _buildLocationSection(BookingModel model) {
    return _buildSectionCard(
      title: "Điểm Đi và Điểm Đến",
      icon: Icons.route,
      children: [
        // === Điểm Đón ===
        _buildLocationInput(
          label: "Điểm đón",
          icon: Icons.my_location,
          color: Colors.green,
          provinceDropdown: _provinceDropdown(
            provinces: model.provinces,
            value: model.selectedProvincePickup,
            onChanged: (v) {
              model.selectedProvincePickup = v;
              model.fetchTripPrice();
            },
          ),

          addressField: TextField(
            decoration: const InputDecoration(
              labelText: "Số nhà, xã/phường, quận/huyện",
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => model.addressPickup = v,
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          title: "Ngày & Giờ Đón",
          icon: Icons.calendar_today,
          children: [
            _dateTimePicker(model),
          ],
        ),
        const SizedBox(height: 25),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
          child: Icon(Icons.arrow_downward, color: Colors.grey),
        ),

        // === Điểm Đến ===
        _buildLocationInput(
          label: "Điểm đến",
          icon: Icons.location_on,
          color: Colors.red,
          provinceDropdown: _provinceDropdown(
            provinces: model.provinces,
            value: model.selectedProvinceDrop,
            onChanged: (v) {
              model.selectedProvinceDrop = v;

              model.fetchTripPrice();
            },
          ),

          addressField: TextField(
            decoration: const InputDecoration(
              labelText: "Số nhà, xã/phường, quận/huyện",
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => model.addressDrop = v,
          ),
        ),
      ],
    );
  }


  Widget _buildLocationInput({
    required String label,
    required IconData icon,
    required Color color,
    required Widget provinceDropdown,
    required Widget addressField,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        provinceDropdown,
        const SizedBox(height: 8),
        addressField,
      ],
    );
  }

  // ================= BOOKING FORM =================
  Widget _buildBookingForm(BookingModel model) {
    const compactDensity = VisualDensity(vertical: -4);

    const radioTextStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Loại chuyến
          _buildSectionCard(
            title: "Chọn Loại Chuyến",
            icon: Icons.directions_car,
            children: [
              RadioListTile<TripCategory>(
                dense: true,
                visualDensity: compactDensity,
                contentPadding: EdgeInsets.zero,
                value: TripCategory.choNguoi,
                groupValue: model.tripCategory,
                title: const Text("Chở người", style: radioTextStyle),
                onChanged: (v) {
                  if (v != null) {
                    model.setTripCategory(v);
                    model.fetchTripPrice();
                  }
                },
              ),
              RadioListTile<TripCategory>(
                dense: true,
                visualDensity: compactDensity,
                contentPadding: EdgeInsets.zero,
                value: TripCategory.choHang,
                groupValue: model.tripCategory,
                title: const Text("Giao hàng", style: radioTextStyle),
                onChanged: (v) {
                  if (v != null) {
                    model.setTripCategory(v);
                    model.fetchTripPrice();
                  }
                },
              ),

              if (model.isChoNguoi)
                CheckboxListTile(
                  dense: true,
                  visualDensity: compactDensity,
                  contentPadding: EdgeInsets.zero,
                  value: model.isBaoXe,
                  title: const Text("Bao trọn chuyến xe", style: radioTextStyle),
                  onChanged: (v) {
                    model.setIsBaoXe(v ?? false);
                    model.fetchTripPrice();
                  },
                ),

              if (!model.isChoNguoi)
                CheckboxListTile(
                  dense: true,
                  visualDensity: compactDensity,
                  contentPadding: EdgeInsets.zero,
                  value: model.isHoaToc,
                  title: const Text(
                    "Giao Hỏa tốc (Thêm phí)",
                    style: radioTextStyle,
                  ),
                  onChanged: (v) {
                    model.setIsHoaToc(v ?? false);
                    model.fetchTripPrice();
                  },
                ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. Điểm đón & đến
          _buildLocationSection(model),
          const SizedBox(height: 16),

          // 3. Thông tin KH & ghi chú
          _buildSectionCard(
            title: "Thông tin Khách hàng & Ghi chú",
            icon: Icons.person_pin,
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Số điện thoại liên hệ",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Ghi chú cho tài xế (VD: Mã bưu kiện, số người)",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // 4. Phương thức thanh toán
          _buildSectionCard(
            title: "Phương thức thanh toán",
            icon: Icons.payments_outlined,
            children: [
              RadioListTile<int>(
                dense: true,
                visualDensity: compactDensity,
                contentPadding: EdgeInsets.zero,
                value: 1,
                groupValue: model.paymentMethod,
                title: const Text("Chuyển khoản", style: radioTextStyle),
                secondary: const Icon(Icons.account_balance, color: Colors.blue),
                onChanged: (v) => _handlePaymentMethodChange(model, v),
              ),
              RadioListTile<int>(
                dense: true,
                visualDensity: compactDensity,
                contentPadding: EdgeInsets.zero,
                value: 2,
                groupValue: model.paymentMethod,
                title: const Text(
                  "Thanh toán bằng ví",
                  style: radioTextStyle,
                ),
                secondary:
                const Icon(Icons.wallet_giftcard, color: Colors.green),
                onChanged: (v) => _handlePaymentMethodChange(model, v),
              ),
              RadioListTile<int>(
                dense: true,
                visualDensity: compactDensity,
                contentPadding: EdgeInsets.zero,
                value: 3,
                groupValue: model.paymentMethod,
                title: const Text("Thanh toán sau", style: radioTextStyle),
                secondary:
                const Icon(Icons.person_outline, color: Colors.orange),
                onChanged: (v) => _handlePaymentMethodChange(model, v),
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }



  // ================= HELPERS CẬP NHẬT =================

  Widget _provinceDropdown({
    required List<dynamic> provinces,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: provinces
          .map((p) => DropdownMenuItem(
        value: p["id"].toString(),
        child: Text(p["name"]),
      ))
          .toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: "Tỉnh / Thành phố",
        border: OutlineInputBorder(),
        isDense: true, // Làm gọn chiều cao
        prefixIcon: Icon(Icons.location_city, size: 20),
      ),
    );
  }



// Cập nhật _dateField và _timeField để hiển thị Icon
  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(
            text: date == null ? "" : DateFormat('dd/MM/yyyy').format(date), // Định dạng đẹp hơn
          ),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.event, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _timeField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(
            text: time == null ? "" : time.format(context), // Sử dụng time.format(context)
          ),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.access_time, size: 20),
          ),
        ),
      ),
    );
  }

  // ================= DATE/TIME PICKER (ĐÃ ĐƯỢC GIỮ LẠI VÀ CHỈNH SỬA) =================
  Widget _dateTimePicker(BookingModel model) {
    return Row(children: [
      Expanded(
        child: _dateField(
          label: "Ngày đón",
          date: model.goDate,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDate: model.goDate ?? DateTime.now(),
            );
            if (picked != null) {
              model.goDate = picked;
              model.notifyListeners();
            }
          },
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _timeField(
          label: "Giờ đón",
          time: model.goTime,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: model.goTime ?? TimeOfDay.now(),
            );
            if (picked != null) {
              model.goTime = picked;
              model.notifyListeners();
            }
          },
        ),
      ),
    ]);
  }
}
