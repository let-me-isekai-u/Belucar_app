import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/booking_model.dart';
import 'booking2_screen.dart';
import 'booking_ui.dart';

class Booking1Screen extends StatefulWidget {
  final Function(int) onRideBooked;

  const Booking1Screen({super.key, required this.onRideBooked});

  @override
  State<Booking1Screen> createState() => _Booking1ScreenState();
}

class _Booking1ScreenState extends State<Booking1Screen> {
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  bool _didSeedControllers = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _noteController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _seedControllers(BookingModel model) {
    if (_didSeedControllers) return;
    _didSeedControllers = true;
    _phoneController.text = model.customerPhone ?? '';
    _noteController.text = model.note ?? '';
    _quantityController.text = model.quantity.toString();
  }

  int? _parseQuantity() {
    final raw = _quantityController.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  void _setQuantity(BookingModel model, int value) {
    final next = value < 1 ? 1 : value;
    model.quantity = next;
    _quantityController.value = TextEditingValue(
      text: next.toString(),
      selection: TextSelection.collapsed(offset: next.toString().length),
    );
  }

  Widget _buildRideTypeCard(
    BuildContext context,
    BookingModel model,
    BookingRideTypeOption option,
  ) {
    final theme = Theme.of(context);
    final isSelected = model.selectedRideType == option.value;
    final subtitle = switch (option.value) {
      BookingRideType.passenger => 'Tối ưu cho chuyến ghép khách',
      BookingRideType.charter5Seats => 'Riêng tư cho nhóm nhỏ hoặc gia đình',
      _ => 'Không gian rộng hơn cho nhóm nhiều hành lý',
    };

    return Expanded(
      child: GestureDetector(
        onTap: () => model.setSelectedRideType(option.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: isSelected
                ? theme.colorScheme.secondary.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.secondary
                  : Colors.white.withValues(alpha: 0.10),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.secondary.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  option.value == BookingRideType.passenger
                      ? Icons.person_2_outlined
                      : Icons.airport_shuttle_outlined,
                  color: isSelected
                      ? theme.colorScheme.secondary
                      : Colors.white70,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                option.label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
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
      ),
    );
  }

  Widget _buildQuantityInput(BuildContext context, BookingModel model) {
    final theme = Theme.of(context);

    return BookingSectionCard(
      title: 'Số lượng hành khách',
      subtitle: 'Bước này chỉ áp dụng cho loại chuyến chở người.',
      icon: Icons.groups_2_outlined,
      accentColor: Colors.lightGreenAccent.shade100,
      child: Column(
        children: [
          Row(
            children: [
              _QuantityButton(
                icon: Icons.remove_rounded,
                onTap: () => _setQuantity(model, model.quantity - 1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: bookingInputDecoration(
                    context,
                    label: 'Số người',
                    hint: 'Nhập từ 1 trở lên',
                    icon: Icons.people_alt_outlined,
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (parsed != null) {
                      model.quantity = parsed;
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              _QuantityButton(
                icon: Icons.add_rounded,
                onTap: () => _setQuantity(model, model.quantity + 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Số lượng hiện tại sẽ được dùng để tính giá ở bước tiếp theo.',
              style: TextStyle(
                color: theme.colorScheme.secondary.withValues(alpha: 0.92),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BookingModel>();
    final theme = Theme.of(context);

    _seedControllers(model);

    if (model.showQuantityField &&
        _quantityController.text != model.quantity.toString()) {
      _quantityController.value = TextEditingValue(
        text: model.quantity.toString(),
        selection: TextSelection.collapsed(
          offset: model.quantity.toString().length,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tạo đơn - Bước 1/3',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: BookingFlowBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookingStepHero(
                step: 1,
                title: 'Thiết lập nhu cầu chuyến đi',
                subtitle:
                    'Chọn loại chuyến phù hợp và để lại thông tin để hệ thống giữ nguyên logic tạo đơn hiện tại nhưng dễ thao tác hơn.',
                assetPath: 'lib/assets/icons/booking_car.png',
                footer: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    BookingSummaryChip(
                      icon: Icons.local_taxi_outlined,
                      label: model.rideTypeLabel,
                    ),
                    BookingSummaryChip(
                      icon: Icons.payment_outlined,
                      label: 'Giữ nguyên bước thanh toán cuối',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BookingSectionCard(
                title: 'Loại chuyến',
                subtitle: 'Chạm để chọn nhanh thay vì mở dropdown.',
                icon: Icons.directions_car_filled_outlined,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          BookingRideType.options
                              .map(
                                (option) =>
                                    _buildRideTypeCard(context, model, option),
                              )
                              .expand(
                                (widget) => [widget, const SizedBox(width: 12)],
                              )
                              .toList()
                            ..removeLast(),
                    ),
                    if (model.isBaoXe) ...[
                      const SizedBox(height: 14),
                      const BookingInfoBanner(
                        text:
                            'Các loại bao xe mặc định số lượng là 1, chỉ thay đổi loại xe chứ không thay đổi logic tính giá hiện tại.',
                        icon: Icons.verified_outlined,
                      ),
                    ],
                  ],
                ),
              ),
              if (model.showQuantityField) ...[
                const SizedBox(height: 18),
                _buildQuantityInput(context, model),
              ],
              const SizedBox(height: 18),
              BookingSectionCard(
                title: 'Liên hệ & ghi chú',
                subtitle: 'Thông tin này sẽ được mang sang các bước sau.',
                icon: Icons.support_agent_outlined,
                child: Column(
                  children: [
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white),
                      decoration: bookingInputDecoration(
                        context,
                        label: 'Số điện thoại liên hệ',
                        hint: 'Ví dụ: 09xxxxxxxx',
                        icon: Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _noteController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: bookingInputDecoration(
                        context,
                        label: 'Ghi chú cho tài xế',
                        hint:
                            'Mã bưu kiện, số người, điểm nhận dễ nhận biết...',
                        icon: Icons.edit_note_outlined,
                      ),
                    ),
                  ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bước tiếp theo: chọn điểm đón, điểm đến và thời gian.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '1/3',
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_phoneController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập số điện thoại'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (model.showQuantityField) {
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
                    }

                    model.customerPhone = _phoneController.text.trim();
                    model.note = _noteController.text.trim();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: model,
                          child: Booking2Screen(
                            onRideBooked: widget.onRideBooked,
                          ),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: const Text('TIẾP THEO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 52,
          height: 56,
          child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        ),
      ),
    );
  }
}
