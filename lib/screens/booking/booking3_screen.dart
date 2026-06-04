import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/booking_model.dart';
import 'booking_ui.dart';

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
        return 'Thanh toán trả sau / COD';
      default:
        return 'Chuyển khoản';
    }
  }

  IconData _getPaymentMethodIcon(int paymentMethod) {
    switch (paymentMethod) {
      case 2:
        return Icons.wallet_outlined;
      case 3:
        return Icons.payments_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: highlight ? theme.colorScheme.secondary : Colors.white,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressBlock({
    required String title,
    required IconData icon,
    required String province,
    required String district,
    required String address,
    Color? iconColor,
  }) {
    final color = iconColor ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Tỉnh / Thành', province),
          _buildInfoRow('Quận / Huyện', district),
          _buildInfoRow('Địa chỉ', address),
        ],
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => model.paymentMethod = value,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondary.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.secondary
                  : Colors.white.withValues(alpha: 0.10),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : Colors.white54,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? theme.colorScheme.secondary
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                margin: const EdgeInsets.only(left: 12, right: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.secondary.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.secondary
                      : Colors.white70,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.secondary
                            : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color:
                  valueColor ??
                  (isTotal ? theme.colorScheme.secondary : Colors.white),
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
              fontSize: isTotal ? 18 : 15,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePayment(BookingModel model) async {
    setState(() => _isCreatingRide = true);

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bạn chưa đăng nhập')));
      setState(() => _isCreatingRide = false);
      return;
    }

    try {
      final result = await model.createRide(accessToken);

      if (result['success'] == true) {
        if (!mounted) return;
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
                        ? 'Đặt chuyến thành công. Thanh toán bằng ví đã được chọn.'
                        : 'Đặt chuyến thành công. Bạn sẽ thanh toán khi hoàn thành chuyến đi.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        final errorMsg = result['message'] ?? 'Đặt chuyến thất bại';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingRide = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BookingModel>();
    final theme = Theme.of(context);
    final showQuantityField = model.showQuantityField;
    final preview = model.routePreview;

    final pickupDateTime = model.goDate == null || model.goTime == null
        ? 'Chưa chọn'
        : '${DateFormat('dd/MM/yyyy').format(model.goDate!)} - ${model.goTime!.format(context)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tạo đơn - Bước 3/3',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: BookingFlowBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookingSectionCard(
                title: 'Thông tin chuyến đi',
                subtitle: 'Phần này lấy trực tiếp từ các bước trước.',
                icon: Icons.fact_check_outlined,
                child: Column(
                  children: [
                    _buildInfoRow('Loại chuyến', model.rideTypeLabel),
                    if (showQuantityField)
                      _buildInfoRow('Số lượng', '${model.quantity}'),
                    _buildInfoRow('SĐT liên hệ', model.customerPhone ?? ''),
                    if (model.note?.isNotEmpty ?? false)
                      _buildInfoRow('Ghi chú', model.note ?? ''),
                    _buildInfoRow(
                      'Ngày giờ đón',
                      pickupDateTime,
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BookingSectionCard(
                title: 'Hành trình',
                subtitle:
                    'Địa chỉ dưới đây là địa chỉ đã được backend chuẩn hóa.',
                icon: Icons.route_outlined,
                child: Column(
                  children: [
                    _buildAddressBlock(
                      title: 'Điểm đón',
                      icon: Icons.my_location_rounded,
                      province: preview?.from.provinceName ?? '',
                      district: preview?.from.districtName ?? '',
                      address:
                          preview?.from.formattedAddress ??
                          model.pickupDisplayAddress,
                      iconColor: Colors.lightGreenAccent.shade100,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Icon(
                        Icons.south_rounded,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    _buildAddressBlock(
                      title: 'Điểm đến',
                      icon: Icons.location_on_outlined,
                      province: preview?.to.provinceName ?? '',
                      district: preview?.to.districtName ?? '',
                      address:
                          preview?.to.formattedAddress ??
                          model.dropDisplayAddress,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BookingSectionCard(
                title: 'Phương thức thanh toán',
                subtitle: 'Chọn hình thức thanh toán trước khi tạo đơn.',
                icon: _getPaymentMethodIcon(model.paymentMethod),
                child: Column(
                  children: [
                    _buildPaymentOption(
                      model: model,
                      value: 2,
                      title: 'Thanh toán bằng ví',
                      icon: Icons.wallet_outlined,
                      subtitle: 'Thanh toán bằng số dư ví trong ứng dụng',
                    ),
                    _buildPaymentOption(
                      model: model,
                      value: 3,
                      title: 'Thanh toán trả sau / COD',
                      icon: Icons.payments_outlined,
                      subtitle: 'Thanh toán khi hoàn thành chuyến đi',
                    ),
                    const SizedBox(height: 4),
                    _buildInfoRow(
                      'Đã chọn',
                      _getPaymentMethodLabel(model.paymentMethod),
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BookingSectionCard(
                title: 'Chi tiết giá',
                subtitle:
                    'Giá được tính từ tuyến đã resolve và hình thức thanh toán hiện tại.',
                icon: Icons.receipt_long_outlined,
                child: model.isLoadingPrice
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : model.tripPrice != null
                    ? Column(
                        children: [
                          _buildPriceRow(
                            'Giá cước gốc',
                            formatCurrency(model.basePrice ?? 0),
                          ),
                          _buildPriceRow(
                            'Ưu đãi giảm giá',
                            formatCurrency(-(model.discount)),
                            valueColor: Colors.greenAccent.shade100,
                          ),
                          _buildPriceRow(
                            'Phụ phí ngày lễ',
                            formatCurrency(model.surcharge),
                            valueColor: Colors.orangeAccent.shade100,
                          ),
                          if (showQuantityField)
                            _buildPriceRow(
                              'Số lượng tính giá',
                              'x${model.quantity}',
                            ),
                          Divider(
                            height: 28,
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.28,
                            ),
                          ),
                          _buildPriceRow(
                            'THÀNH TIỀN',
                            formatCurrency(model.tripPrice!),
                            isTotal: true,
                          ),
                        ],
                      )
                    : BookingInfoBanner(
                        text:
                            model.priceErrorMessage ??
                            'Không thể tính giá. Vui lòng quay lại kiểm tra thông tin.',
                        icon: Icons.warning_amber_rounded,
                        color: Colors.orangeAccent,
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('QUAY LẠI'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      _isCreatingRide ||
                          model.tripPrice == null ||
                          model.routePreview == null
                      ? null
                      : () => _handlePayment(model),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: _isCreatingRide
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black87,
                          ),
                        )
                      : Text(
                          model.paymentMethod == 3
                              ? 'XÁC NHẬN ĐẶT XE'
                              : 'THANH TOÁN',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
