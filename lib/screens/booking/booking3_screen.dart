import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../models/booking_model.dart';

class Booking3Screen extends StatefulWidget {
  final Function(int) onRideBooked;
  const Booking3Screen({super.key, required this.onRideBooked});

  @override
  State<Booking3Screen> createState() => _Booking3ScreenState();
}

class _Booking3ScreenState extends State<Booking3Screen> {
  bool _isCreatingRide = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final model = context.read<BookingModel>();

      // Mặc định chỉ cho phép: 2 = ví, 3 = tiền mặt
      // Nếu đang là 1 (chuyển khoản) thì ép về 2 (ví)
      if (model.paymentMethod == 1) {
        model.paymentMethod = 2;
      }

      if (model.tripPrice == null && !model.isLoadingPrice) {
        model.fetchTripPrice();
      }
    });
  }

  String formatCurrency(double value) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  String _getPaymentMethodLabel(int paymentMethod) {
    switch (paymentMethod) {
      case 2:
        return 'Thanh toán bằng ví';
      case 3:
        return 'Tiền mặt';
      default:
        return 'Thanh toán bằng ví';
    }
  }

  IconData _getPaymentMethodIcon(int paymentMethod) {
    switch (paymentMethod) {
      case 2:
        return Icons.wallet;
      case 3:
        return Icons.payments_outlined;
      default:
        return Icons.wallet;
    }
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPriceRow(
      String label,
      String value, {
        bool isBold = false,
        Color? color,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
      String label,
      double amount, {
        bool isBold = false,
        Color? color,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            formatCurrency(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.white,
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
                Icon(icon, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            Divider(
              height: 20,
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required BookingModel model,
    required int value,
    required String title,
    required IconData icon,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isSelected = model.paymentMethod == value;

    return InkWell(
      onTap: () {
        model.paymentMethod = value;
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.secondary
                : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.secondary.withOpacity(0.12)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Radio<int>(
              value: value,
              groupValue: model.paymentMethod,
              onChanged: (val) {
                if (val != null) {
                  model.paymentMethod = val;
                }
              },
              activeColor: theme.colorScheme.secondary,
            ),
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.secondary
                  : Colors.white70,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? theme.colorScheme.secondary
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProvinceName(BookingModel model, int? id) {
    if (id == null) return '';
    final province = model.provinces.cast<dynamic?>().firstWhere(
          (p) => p != null && p['id'].toString() == id.toString(),
      orElse: () => null,
    );
    return province?['name']?.toString() ?? '';
  }

  String _getDistrictName(List<dynamic> districts, int? id) {
    if (id == null) return '';
    final district = districts.cast<dynamic?>().firstWhere(
          (d) => d != null && d['id'].toString() == id.toString(),
      orElse: () => null,
    );
    return district?['name']?.toString() ?? '';
  }

  Future<void> _handlePayment(BookingModel model) async {
    setState(() => _isCreatingRide = true);

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("accessToken");

    if (accessToken == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bạn chưa đăng nhập')));
      setState(() => _isCreatingRide = false);
      return;
    }

    try {
      final result = await model.createRide(accessToken);

      print("🔥 createRide result: $result");

      if (result['success'] == true) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          widget.onRideBooked(2);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      model.paymentMethod == 2
                          ? 'Đặt chuyến thành công! Thanh toán bằng ví đã được chọn.'
                          : 'Đặt chuyến thành công! Bạn sẽ thanh toán bằng tiền mặt.',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );

          setState(() => _isCreatingRide = false);
        }
      } else {
        final errorMsg = result['message'] ?? 'Đặt chuyến thất bại';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
          );
          setState(() => _isCreatingRide = false);
        }
      }
    } catch (e) {
      print("❌ Error creating ride: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isCreatingRide = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BookingModel>();
    final theme = Theme.of(context);
    final showQuantityField = model.showQuantityField;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Xác nhận đặt chuyến',
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
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
              title: "Thông tin chuyến đi",
              icon: Icons.info_outline,
              children: [
                _buildInfoRow("Loại chuyến:", model.rideTypeLabel),
                if (showQuantityField)
                  _buildInfoRow("Số lượng:", "${model.quantity}"),
                _buildInfoRow("SĐT liên hệ:", model.customerPhone ?? ''),
                if (model.note?.isNotEmpty ?? false)
                  _buildInfoRow("Ghi chú:", model.note ?? ''),
              ],
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              title: "Điểm đón",
              icon: Icons.my_location,
              children: [
                _buildInfoRow(
                  "Tỉnh/Thành:",
                  _getProvinceName(model, model.selectedProvincePickup),
                ),
                _buildInfoRow(
                  "Quận/Huyện:",
                  _getDistrictName(
                    model.pickupDistricts,
                    model.selectedDistrictPickup,
                  ),
                ),
                _buildInfoRow("Địa chỉ:", model.addressPickup ?? ''),
                _buildInfoRow(
                  "Ngày giờ đón:",
                  "${model.goDate != null ? DateFormat('dd/MM/yyyy').format(model.goDate!) : ''} - ${model.goTime != null ? model.goTime!.format(context) : ''}",
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              title: "Điểm đến",
              icon: Icons.location_on,
              children: [
                _buildInfoRow(
                  "Tỉnh/Thành:",
                  _getProvinceName(model, model.selectedProvinceDrop),
                ),
                _buildInfoRow(
                  "Quận/Huyện:",
                  _getDistrictName(
                    model.dropDistricts,
                    model.selectedDistrictDrop,
                  ),
                ),
                _buildInfoRow("Địa chỉ:", model.addressDrop ?? ''),
              ],
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              title: "Phương thức thanh toán",
              icon: _getPaymentMethodIcon(model.paymentMethod),
              children: [
                _buildPaymentOption(
                  model: model,
                  value: 2,
                  title: "Thanh toán bằng ví",
                  icon: Icons.wallet,
                  subtitle: "Thanh toán bằng số dư ví trong ứng dụng",
                ),
                _buildPaymentOption(
                  model: model,
                  value: 3,
                  title: "Tiền mặt",
                  icon: Icons.payments_outlined,
                  subtitle: "Thanh toán sau khi hoàn thành chuyến đi",
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  "Đã chọn:",
                  _getPaymentMethodLabel(model.paymentMethod),
                  isBold: true,
                ),
              ],
            ),

            const SizedBox(height: 16),


            _buildSectionCard(
              title: "Chi tiết giá",
              icon: Icons.payments_outlined,
              children: [
                if (model.isLoadingPrice)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (model.tripPrice != null) ...[
                  _buildPriceRow("Giá cước gốc:", model.basePrice ?? 0),
                  _buildPriceRow(
                    "Ưu đãi giảm giá:",
                    -(model.discount),
                    color: Colors.greenAccent,
                  ),
                  _buildPriceRow(
                    "Phụ phí ngày lễ:",
                    model.surcharge,
                    color: Colors.orangeAccent,
                  ),
                  if (showQuantityField)
                    _buildTextPriceRow(
                      "Số lượng:",
                      "x${model.quantity}",
                      isBold: true,
                    ),
                  Divider(
                    height: 20,
                    color: theme.colorScheme.secondary.withOpacity(0.5),
                    thickness: 1.5,
                  ),
                  _buildPriceRow(
                    "THÀNH TIỀN:",
                    model.tripPrice!,
                    isBold: true,
                    color: theme.colorScheme.secondary,
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Không thể tính giá. Vui lòng kiểm tra lại thông tin.",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(
                    color: theme.colorScheme.secondary,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  "QUAY LẠI",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isCreatingRide || model.tripPrice == null
                    ? null
                    : () => _handlePayment(model),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.black87,
                ),
                child: _isCreatingRide
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black87,
                  ),
                )
                    : Text(
                  model.paymentMethod == 3
                      ? "XÁC NHẬN ĐẶT XE"
                      : "THANH TOÁN",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}