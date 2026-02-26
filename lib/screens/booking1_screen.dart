import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking_model.dart';
import 'booking2_screen.dart';

class Booking1Screen extends StatefulWidget {
  final Function(int) onRideBooked;
  const Booking1Screen({super.key, required this.onRideBooked});

  @override
  State<Booking1Screen> createState() => _Booking1ScreenState();
}

class _Booking1ScreenState extends State<Booking1Screen> {
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  final _quantityController = TextEditingController(text: "1");

  @override
  void dispose() {
    _phoneController.dispose();
    _noteController.dispose();
    _quantityController.dispose();
    super.dispose();
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
                Icon(icon, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  int? _parseQuantity() {
    final raw = _quantityController.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BookingModel>();
    final theme = Theme.of(context);

    const compactDensity = VisualDensity(vertical: -4);
    const radioTextStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w500);

    // Chỉ hiện số lượng khi: Chở người && không bao xe
    final bool showQuantityField = model.isChoNguoi && !model.isBaoXe;

    // Sync text field với model khi field đang hiển thị
    if (showQuantityField) {
      final modelQuantityText = model.quantity.toString();
      if (_quantityController.text != modelQuantityText) {
        _quantityController.text = modelQuantityText;
        _quantityController.selection = TextSelection.fromPosition(
          TextPosition(offset: _quantityController.text.length),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Đặt chuyến - Bước 1/3',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  activeColor: theme.colorScheme.secondary,
                  title: const Text("Chở người", style: radioTextStyle),
                  onChanged: (v) {
                    if (v != null) model.setTripCategory(v);
                  },
                ),
                RadioListTile<TripCategory>(
                  dense: true,
                  visualDensity: compactDensity,
                  contentPadding: EdgeInsets.zero,
                  value: TripCategory.choHang,
                  groupValue: model.tripCategory,
                  activeColor: theme.colorScheme.secondary,
                  title: const Text("Giao hàng", style: radioTextStyle),
                  onChanged: (v) {
                    if (v != null) model.setTripCategory(v);
                  },
                ),
                if (model.isChoNguoi)
                  CheckboxListTile(
                    dense: true,
                    visualDensity: compactDensity,
                    contentPadding: EdgeInsets.zero,
                    value: model.isBaoXe,
                    activeColor: theme.colorScheme.secondary,
                    title: const Text("Bao trọn chuyến xe", style: radioTextStyle),
                    onChanged: (v) => model.setIsBaoXe(v ?? false),
                  ),
                if (!model.isChoNguoi)
                  CheckboxListTile(
                    dense: true,
                    visualDensity: compactDensity,
                    contentPadding: EdgeInsets.zero,
                    value: model.isHoaToc,
                    activeColor: theme.colorScheme.secondary,
                    title: const Text("Giao Hỏa tốc (Thêm phí)", style: radioTextStyle),
                    onChanged: (v) => model.setIsHoaToc(v ?? false),
                  ),

                if (showQuantityField) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Số lượng người",
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.people, color: theme.colorScheme.secondary),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                      helperText: "Nhập số nguyên ≥ 1",
                      helperStyle: const TextStyle(color: Colors.white70),
                    ),
                    onChanged: (v) {
                      final q = int.tryParse(v.trim());
                      if (q != null) {
                        model.quantity = q;
                      }
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 18),

            _buildSectionCard(
              title: "Thông tin Khách hàng & Ghi chú",
              icon: Icons.person_pin,
              children: [
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Số điện thoại liên hệ",
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone, color: theme.colorScheme.secondary),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Ghi chú cho tài xế (VD: Mã bưu kiện, số người)",
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Validate phone
              if (_phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập số điện thoại'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Validate quantity CHỈ khi field đang hiển thị
              if (showQuantityField) {
                final q = _parseQuantity();
                if (q == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập số lượng người'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (q < 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Số lượng người phải >= 1'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                model.quantity = q;
              } else {
                // Khi không dùng số lượng (bao xe hoặc chở hàng), set mặc định 1 để tránh rác dữ liệu
                model.quantity = 1;
              }

              model.customerPhone = _phoneController.text.trim();
              model.note = _noteController.text.trim();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: model,
                    child: Booking2Screen(onRideBooked: widget.onRideBooked),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: Colors.black87,
            ),
            child: const Text(
              "TIẾP THEO",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}