import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/booking_model.dart';
import '../../services/api_service.dart';
import 'booking_ui.dart';

class Booking2Screen extends StatefulWidget {
  final Function(int) onRideBooked;

  const Booking2Screen({super.key, required this.onRideBooked});

  @override
  State<Booking2Screen> createState() => _Booking2ScreenState();
}

class _Booking2ScreenState extends State<Booking2Screen> {
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  bool _didSeedControllers = false;
  bool _isCalculatingPrice = false;
  bool _isCreatingRide = false;
  bool _isBookingForOther = false;
  bool _didRequestInitialPrice = false;
  String _userFullName = '';
  String _userPhone = '';
  String _proxyPhoneDraft = '';

  @override
  void initState() {
    super.initState();
    _loadUserContact();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRequestInitialPrice) return;
    _didRequestInitialPrice = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchPriceIfReady(context.read<BookingModel>());
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _noteController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadUserContact() async {
    final prefs = await SharedPreferences.getInstance();
    var fullName = prefs.getString('fullName') ?? '';
    var phone = prefs.getString('phone') ?? '';

    if (phone.isEmpty) {
      final accessToken = prefs.getString('accessToken') ?? '';
      if (accessToken.isNotEmpty) {
        try {
          final res = await ApiService.getCustomerProfile(
            accessToken: accessToken,
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            fullName = data['fullName']?.toString() ?? fullName;
            phone = data['phone']?.toString() ?? phone;
            await prefs.setString('fullName', fullName);
            await prefs.setString('phone', phone);
          }
        } catch (_) {
          // Keep local fallback values if profile fetch fails.
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _userFullName = fullName;
      _userPhone = phone;
    });

    _applyPhoneMode();
  }

  void _seedControllers(BookingModel model) {
    if (_didSeedControllers) return;
    _didSeedControllers = true;
    _noteController.text = model.note ?? '';
    _quantityController.text = model.quantity.toString();
    _phoneController.text = model.customerPhone ?? '';

    if (_userPhone.isNotEmpty && model.customerPhone == _userPhone) {
      _isBookingForOther = false;
    } else if (_userPhone.isNotEmpty &&
        (model.customerPhone?.trim().isNotEmpty ?? false)) {
      _isBookingForOther = model.customerPhone!.trim() != _userPhone;
      if (_isBookingForOther) {
        _proxyPhoneDraft = model.customerPhone!.trim();
      }
    }

    _applyPhoneMode();
  }

  void _applyPhoneMode() {
    if (_isBookingForOther) {
      final nextPhone = _proxyPhoneDraft.isNotEmpty
          ? _proxyPhoneDraft
          : (_phoneController.text.trim() == _userPhone
                ? ''
                : _phoneController.text.trim());
      _phoneController.value = TextEditingValue(
        text: nextPhone,
        selection: TextSelection.collapsed(offset: nextPhone.length),
      );
      return;
    }

    final nextPhone = _userPhone.isNotEmpty
        ? _userPhone
        : _phoneController.text.trim();
    _phoneController.value = TextEditingValue(
      text: nextPhone,
      selection: TextSelection.collapsed(offset: nextPhone.length),
    );
  }

  void _toggleBookingForOther() {
    setState(() {
      if (_isBookingForOther) {
        _proxyPhoneDraft = _phoneController.text.trim();
      }
      _isBookingForOther = !_isBookingForOther;
      _applyPhoneMode();
    });
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

  bool _hasPriceInputs(BookingModel model) {
    return model.hasPickupSelection &&
        model.hasDropSelection &&
        model.goDate != null &&
        model.goTime != null &&
        BookingRideType.isValid(model.selectedRideType) &&
        model.validateRouteSelection() == null;
  }

  Future<void> _fetchPriceIfReady(BookingModel model) async {
    if (!_hasPriceInputs(model) ||
        model.isLoadingPrice ||
        (model.tripPrice != null && model.routePreview != null)) {
      return;
    }

    await model.fetchTripPrice();
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

  Widget _buildRideTypeCard(
    BuildContext context,
    BookingModel model,
    BookingRideTypeOption option,
  ) {
    final theme = Theme.of(context);
    final isSelected = model.selectedRideType == option.value;

    return Expanded(
      child: GestureDetector(
        onTap: () => model.setSelectedRideType(option.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.secondary.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  option.value == BookingRideType.passenger
                      ? Icons.person_2_outlined
                      : Icons.airport_shuttle_outlined,
                  size: 19,
                  color: isSelected
                      ? theme.colorScheme.secondary
                      : Colors.white70,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                option.label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityInput(BuildContext context, BookingModel model) {
    return BookingSectionCard(
      title: 'Số lượng',
      icon: Icons.groups_2_outlined,
      accentColor: Colors.lightGreenAccent.shade100,
      child: Row(
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: bookingInputDecoration(
                context,
                label: 'Số người',
                hint: 'Từ 1 trở lên',
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
    );
  }

  Widget _buildAddressSummaryCard(BookingModel model) {
    final theme = Theme.of(context);
    final preview = model.routePreview;

    Widget addressLine({
      required IconData icon,
      required Color color,
      required String label,
      required String value,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          addressLine(
            icon: Icons.trip_origin_rounded,
            color: Colors.lightBlueAccent.shade100,
            label: 'Điểm đón',
            value: preview?.from.formattedAddress ?? model.pickupDisplayAddress,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Container(
                  width: 1.5,
                  height: 18,
                  color: Colors.white.withValues(alpha: 0.24),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.south_rounded,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
          ),
          addressLine(
            icon: Icons.location_on_rounded,
            color: Colors.greenAccent.shade100,
            label: 'Điểm đến',
            value: preview?.to.formattedAddress ?? model.dropDisplayAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildRiderContactSection(BuildContext context) {
    final theme = Theme.of(context);

    return BookingSectionCard(
      title: 'Thông tin người đi',
      icon: Icons.support_agent_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _toggleBookingForOther,
              icon: Icon(
                _isBookingForOther
                    ? Icons.person_outline_rounded
                    : Icons.swap_horiz_rounded,
                size: 18,
              ),
              label: Text(
                _isBookingForOther ? 'Đặt cho bản thân' : 'Đặt hộ',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary,
                side: BorderSide(color: theme.colorScheme.secondary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          if (!_isBookingForOther) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                _userFullName.isNotEmpty ? _userFullName : 'Người dùng BeluCar',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _phoneController,
            readOnly: !_isBookingForOther,
            enableInteractiveSelection: _isBookingForOther,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              color: !_isBookingForOther
                  ? Colors.white.withValues(alpha: 0.78)
                  : Colors.white,
            ),
            decoration: bookingInputDecoration(
              context,
              label: 'Số điện thoại',
              hint: '09xxxxxxxx',
              icon: Icons.phone_outlined,
            ),
            onChanged: _isBookingForOther
                ? (value) => _proxyPhoneDraft = value.trim()
                : null,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: bookingInputDecoration(
              context,
              label: 'Ghi chú',
              hint: 'Thêm ghi chú nếu cần',
              icon: Icons.edit_note_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(
            text: date == null ? '' : DateFormat('dd/MM/yyyy').format(date),
          ),
          style: const TextStyle(color: Colors.white),
          decoration: bookingInputDecoration(
            context,
            label: label,
            hint: 'Chọn ngày đón',
            icon: Icons.event_outlined,
            suffixIcon: Icon(
              Icons.calendar_today_outlined,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeField({required BookingModel model}) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () async {
        int selectedHour = model.goTime?.hour ?? TimeOfDay.now().hour;
        int selectedMinute = model.goTime?.minute ?? TimeOfDay.now().minute;

        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Container(
                    height: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(
                                  'Hủy',
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Text(
                                'Chọn giờ đón',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF123C2E),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  model.setGoTime(
                                    TimeOfDay(
                                      hour: selectedHour,
                                      minute: selectedMinute,
                                    ),
                                  );
                                  Navigator.pop(dialogContext);
                                },
                                child: Text(
                                  'Xong',
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                    initialItem: selectedHour,
                                  ),
                                  itemExtent: 40,
                                  selectionOverlay: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: theme.colorScheme.secondary,
                                          width: 1.5,
                                        ),
                                        bottom: BorderSide(
                                          color: theme.colorScheme.secondary,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  onSelectedItemChanged: (index) {
                                    setDialogState(() => selectedHour = index);
                                  },
                                  children: List.generate(24, (index) {
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF123C2E),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              Text(
                                ':',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                    initialItem: selectedMinute,
                                  ),
                                  itemExtent: 40,
                                  selectionOverlay: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: theme.colorScheme.secondary,
                                          width: 1.5,
                                        ),
                                        bottom: BorderSide(
                                          color: theme.colorScheme.secondary,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  onSelectedItemChanged: (index) {
                                    setDialogState(() => selectedMinute = index);
                                  },
                                  children: List.generate(60, (index) {
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF123C2E),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(
            text: model.goTime == null
                ? ''
                : '${model.goTime!.hour.toString().padLeft(2, '0')}:${model.goTime!.minute.toString().padLeft(2, '0')}',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          decoration: bookingInputDecoration(
            context,
            label: 'Giờ đón',
            hint: 'HH:MM',
            icon: Icons.access_time_rounded,
            suffixIcon: Icon(
              Icons.schedule_rounded,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => model.paymentMethod = value,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondary.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
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
                width: 22,
                height: 22,
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
                    width: 9,
                    height: 9,
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
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(left: 10, right: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.secondary.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
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
                        fontSize: 12.5,
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

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
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

  bool _validate(BookingModel model) {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số điện thoại'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (model.showQuantityField) {
      final q = _parseQuantity();
      if (q == null || q < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Số lượng người phải từ 1 trở lên'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      model.quantity = q;
    }

    if (model.goDate == null || model.goTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày giờ đón'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _handleCreateRide(BookingModel model) async {
    dismissBookingKeyboard();

    if (!_validate(model)) return;

    model.customerPhone = _phoneController.text.trim();
    model.note = _noteController.text.trim();

    if (model.tripPrice == null || model.routePreview == null) {
      setState(() => _isCalculatingPrice = true);
      try {
        await model.fetchTripPrice();
      } finally {
        if (mounted) {
          setState(() => _isCalculatingPrice = false);
        }
      }
    }

    if (!mounted) return;

    if (model.tripPrice == null || model.routePreview == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            model.priceErrorMessage ??
                'Không thể tính giá. Vui lòng kiểm tra lại thông tin.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

    _seedControllers(model);

    if (showQuantityField &&
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
          'Đặt xe',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: BookingKeyboardDismissArea(
        child: BookingFlowBackground(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 146),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAddressSummaryCard(model),
                const SizedBox(height: 18),
                BookingSectionCard(
                  title: 'Loại chuyến',
                  icon: Icons.directions_car_filled_outlined,
                  child: Row(
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
                ),
                if (showQuantityField) ...[
                  const SizedBox(height: 18),
                  _buildQuantityInput(context, model),
                ],
                const SizedBox(height: 18),
                _buildRiderContactSection(context),
                const SizedBox(height: 18),
                BookingSectionCard(
                  title: 'Ngày giờ đón',
                  icon: Icons.schedule_rounded,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _dateField(
                          context: context,
                          label: 'Ngày đón',
                          date: model.goDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              initialDate: model.goDate ?? DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: theme.colorScheme.secondary,
                                      onPrimary: Colors.black87,
                                      onSurface: const Color(0xFF123C2E),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              model.setGoDate(picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _timeField(model: model)),
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
                      const SizedBox(height: 2),
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
                      'Giá sẽ tự cập nhật ngay khi thay đổi thông tin tính giá.',
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
                              'Giá sẽ hiển thị ngay khi đủ điểm đón, điểm đến, ngày giờ và loại chuyến.',
                          icon: Icons.info_outline,
                          color: Colors.orangeAccent,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BookingBottomActionBar(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'thành tiền',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        model.tripPrice != null
                            ? formatCurrency(model.tripPrice!)
                            : '--',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isCalculatingPrice || _isCreatingRide
                        ? null
                        : () => _handleCreateRide(model),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: _isCalculatingPrice || _isCreatingRide
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black87,
                            ),
                          )
                        : const Text('ĐẶT XE'),
                  ),
                ),
              ],
            ),
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
          height: 48,
          child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        ),
      ),
    );
  }
}
