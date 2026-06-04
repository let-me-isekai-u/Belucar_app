import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/booking_model.dart';
import 'booking3_screen.dart';
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
                fontSize: 20,
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
                                    setDialogState(
                                      () => selectedMinute = index,
                                    );
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
          'Thông tin chuyến',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: BookingKeyboardDismissArea(
        child: BookingFlowBackground(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (model.showQuantityField) ...[
                  const SizedBox(height: 18),
                  _buildQuantityInput(context, model),
                ],
                const SizedBox(height: 18),
                BookingSectionCard(
                  title: 'Liên hệ',
                  icon: Icons.support_agent_outlined,
                  child: Column(
                    children: [
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(color: Colors.white),
                        decoration: bookingInputDecoration(
                          context,
                          label: 'Số điện thoại',
                          hint: '09xxxxxxxx',
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
                          label: 'Ghi chú',
                          hint: 'Thêm ghi chú nếu cần',
                          icon: Icons.edit_note_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                BookingSectionCard(
                  title: 'Ngày giờ đón',
                  icon: Icons.schedule_rounded,
                  child: Column(
                    children: [
                      _dateField(
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
                      const SizedBox(height: 12),
                      _timeField(model: model),
                    ],
                  ),
                ),
                if (model.priceErrorMessage != null &&
                    model.priceErrorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  BookingInfoBanner(
                    text: model.priceErrorMessage!,
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                  ),
                ],
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isCalculatingPrice
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('QUAY LẠI'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isCalculatingPrice
                      ? null
                      : () async {
                          dismissBookingKeyboard();

                          if (!_validate(model)) return;

                          model.customerPhone = _phoneController.text.trim();
                          model.note = _noteController.text.trim();

                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);

                          setState(() => _isCalculatingPrice = true);

                          try {
                            await model.fetchTripPrice();

                            if (!mounted) return;

                            if (model.tripPrice == null ||
                                model.routePreview == null) {
                              messenger.showSnackBar(
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

                            navigator.push(
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: model,
                                  child: Booking3Screen(
                                    onRideBooked: widget.onRideBooked,
                                  ),
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _isCalculatingPrice = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: _isCalculatingPrice
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black87,
                          ),
                        )
                      : const Text('TÍNH GIÁ VÀ TIẾP THEO'),
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
