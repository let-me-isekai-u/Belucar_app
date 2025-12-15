import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'activity_screen.dart';

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
          // Hiển thị GIÁ
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
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            )
          else
            const Text(
              "Vui lòng chọn Điểm đi và Điểm đến",
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
          const SizedBox(height: 12),

          // Nút ĐẶT CHUYẾN
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                model.customerPhone = _phoneController.text;
                model.note = _noteController.text;

                final token = await _getAccessToken();
                if (token == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Lỗi: Bạn chưa đăng nhập. Vui lòng đăng nhập lại.'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                  return;
                }

                try {
                  await model.createRide(token);

                  // 1. Hiển thị thông báo thành công
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Đặt chuyến thành công! Chuyển sang Hoạt động.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );

                  // 2. Reset form
                  model.resetForm();
                  _resetControllers();

                  // 3. CHUYỂN SANG MÀN HÌNH ACTIVITY (thay thế màn hình hiện tại)
                  widget.onRideBooked(2);

                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi đặt chuyến: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
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
              model.selectedDistrictPickup = null;
              model.fetchDistricts(v, true);
              model.fetchTripPrice();
            },
          ),
          districtDropdown: _districtDropdown(
            districts: model.districtsPickup,
            value: model.selectedDistrictPickup,
            onChanged: (v) {
              model.selectedDistrictPickup = v;
              model.notifyListeners();
            },
          ),
          addressField: TextField(
            decoration: const InputDecoration(
              labelText: "Địa chỉ chi tiết (Số nhà, đường...)",
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => model.addressPickup = v,
          ),
        ),

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
              model.selectedDistrictDrop = null;
              model.fetchDistricts(v, false);
              model.fetchTripPrice();
            },
          ),
          districtDropdown: _districtDropdown(
            districts: model.districtsDrop,
            value: model.selectedDistrictDrop,
            onChanged: (v) {
              model.selectedDistrictDrop = v;
              model.notifyListeners();
            },
          ),
          addressField: TextField(
            decoration: const InputDecoration(
              labelText: "Địa chỉ chi tiết (Số nhà, đường...)",
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
    required Widget districtDropdown,
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
        districtDropdown,
        const SizedBox(height: 8),
        addressField,
      ],
    );
  }

  // ================= BOOKING FORM =================
  Widget _buildBookingForm(BookingModel model) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 1. Loại chuyến (Đã được bọc trong Card)
        _buildSectionCard(
          title: "Chọn Loại Chuyến",
          icon: Icons.directions_car,
          children: [
            RadioListTile<TripCategory>(
              value: TripCategory.choNguoi,
              groupValue: model.tripCategory,
              title: const Text("Chở người"),
              onChanged: (v) {
                if (v != null) {
                  model.setTripCategory(v);
                  model.fetchTripPrice();
                }
              },
            ),
            RadioListTile<TripCategory>(
              value: TripCategory.choHang,
              groupValue: model.tripCategory,
              title: const Text("Giao hàng"),
              onChanged: (v) {
                if (v != null) {
                  model.setTripCategory(v);
                  model.fetchTripPrice();
                }
              },
            ),
            // Các tùy chọn nâng cao
            if (model.isChoNguoi)
              CheckboxListTile(
                value: model.isBaoXe,
                title: const Text("Bao xe (Thêm phí)"),
                onChanged: (v) {
                  model.setIsBaoXe(v ?? false);
                  model.fetchTripPrice();
                },
              ),
            if (!model.isChoNguoi)
              CheckboxListTile(
                value: model.isHoaToc,
                title: const Text("Giao Hỏa tốc (Thêm phí)"),
                onChanged: (v) {
                  model.setIsHoaToc(v ?? false);
                  model.fetchTripPrice();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Điểm đón và Điểm đến (Sử dụng widget trực quan hơn)
        _buildLocationSection(model),
        const SizedBox(height: 16),

        // 3. Ngày giờ đón
        _buildSectionCard(
          title: "Ngày & Giờ Đón",
          icon: Icons.calendar_today,
          children: [
            _dateTimePicker(model),
          ],
        ),
        const SizedBox(height: 16),

        // 4. Thông tin liên hệ và Ghi chú
        _buildSectionCard(
          title: "Thông tin Khách hàng & Ghi chú",
          icon: Icons.person_pin,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone, // Thêm keyboard type
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
        const SizedBox(height: 100), // Khoảng cách cho bottom bar
      ]),
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

  Widget _districtDropdown({
    required List<dynamic> districts,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: districts
          .map((d) => DropdownMenuItem(
        value: d["id"].toString(),
        child: Text(d["name"]),
      ))
          .toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: "Quận / Huyện",
        border: OutlineInputBorder(),
        isDense: true, // Làm gọn chiều cao
        prefixIcon: Icon(Icons.pin_drop, size: 20),
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
