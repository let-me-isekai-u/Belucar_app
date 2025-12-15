import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BookingModel(),
      child: const _BookingView(),
    );
  }
}

class _BookingView extends StatefulWidget {
  const _BookingView();

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
    );
  }

  // ================= BOOKING FORM =================
  Widget _buildBookingForm(BookingModel model) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            "Đặt chuyến mới",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          /// ========= LOẠI CHUYẾN =========
          const Text(
            "Loại chuyến",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),

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

          if (model.isChoNguoi)
            CheckboxListTile(
              value: model.isBaoXe,
              title: const Text("Bao xe"),
              onChanged: (v) {
                model.setIsBaoXe(v ?? false);
                model.fetchTripPrice();
              },
            ),

          if (!model.isChoNguoi)
            CheckboxListTile(
              value: model.isHoaToc,
              title: const Text("Hỏa tốc"),
              onChanged: (v) {
                model.setIsHoaToc(v ?? false);
                model.fetchTripPrice();
              },
            ),

          const SizedBox(height: 16),

          /// ========= ĐIỂM ĐÓN =========
          const Text(
            "Điểm đón",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          _provinceDropdown(
            provinces: model.provinces,
            value: model.selectedProvincePickup,
            onChanged: (v) {
              model.selectedProvincePickup = v;
              model.selectedDistrictPickup = null;
              model.fetchDistricts(v, true);
              model.fetchTripPrice();
            },
          ),
          const SizedBox(height: 8),

          _districtDropdown(
            districts: model.districtsPickup,
            value: model.selectedDistrictPickup,
            onChanged: (v) {
              model.selectedDistrictPickup = v;
              model.notifyListeners();
            },
          ),
          const SizedBox(height: 8),

          TextField(
            decoration: const InputDecoration(
              labelText: "Địa chỉ đón",
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => model.addressPickup = v,
          ),

          const SizedBox(height: 16),

          /// ========= ĐIỂM ĐẾN =========
          const Text(
            "Điểm đến",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          _provinceDropdown(
            provinces: model.provinces,
            value: model.selectedProvinceDrop,
            onChanged: (v) {
              model.selectedProvinceDrop = v;
              model.selectedDistrictDrop = null;
              model.fetchDistricts(v, false);
              model.fetchTripPrice();
            },
          ),
          const SizedBox(height: 8),

          _districtDropdown(
            districts: model.districtsDrop,
            value: model.selectedDistrictDrop,
            onChanged: (v) {
              model.selectedDistrictDrop = v;
              model.notifyListeners();
            },
          ),
          const SizedBox(height: 8),

          TextField(
            decoration: const InputDecoration(
              labelText: "Địa chỉ đến",
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => model.addressDrop = v,
          ),

          const SizedBox(height: 16),

          /// ========= GIÁ =========
          if (model.isLoadingPrice)
            const Center(child: CircularProgressIndicator())
          else if (model.tripPrice != null)
            Text(
              "Giá chuyến đi: ${formatCurrency(model.tripPrice!)}",
              style: const TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

          const SizedBox(height: 16),

          /// ========= SĐT + GHI CHÚ =========
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: "Số điện thoại",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Ghi chú cho tài xế",
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          _dateTimePicker(model),

          const SizedBox(height: 24),

          /// ========= ĐẶT CHUYẾN =========
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

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Đặt chuyến thành công! Vui lòng đợi tài xế nhận đơn'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );

                  model.resetForm();
                  _resetControllers();
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
              child: const Text("Đặt chuyến"),
            ),
          ),
        ]),
      ),
    );
  }

  // ================= HELPERS =================
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
      ),
    );
  }

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
            text: date == null
                ? ""
                : "${date.day}/${date.month}/${date.year}",
          ),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
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
            text: time == null ? "" : "${time.hour}:${time.minute}",
          ),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
