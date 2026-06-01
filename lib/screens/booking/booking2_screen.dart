import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/booking_model.dart';
import '../../models/location_models.dart';
import 'booking3_screen.dart';
import 'booking_address_map_picker_screen.dart';
import 'booking_ui.dart';

class Booking2Screen extends StatefulWidget {
  final Function(int) onRideBooked;

  const Booking2Screen({super.key, required this.onRideBooked});

  @override
  State<Booking2Screen> createState() => _Booking2ScreenState();
}

class _Booking2ScreenState extends State<Booking2Screen> {
  bool _isCalculatingPrice = false;

  InputDecoration _addressFieldDecoration(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    return bookingInputDecoration(
      context,
      label: label,
      hint: hint,
      icon: icon,
      suffixIcon: suffixIcon,
    ).copyWith(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: Color(0xFF50635D),
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: Color(0xFF7D8D88)),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF123C2E)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 1.6),
      ),
    );
  }

  Future<void> _pickPointOnMap(
    BuildContext context,
    BookingModel model, {
    required bool isPickup,
  }) async {
    dismissBookingKeyboard();
    model.closeAutocompleteSuggestions();

    final initialPoint = isPickup
        ? model.selectedPickupPoint
        : model.selectedDropPoint;

    final resolved = await Navigator.push<AddressResolvedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => BookingAddressMapPickerScreen(
          title: isPickup
              ? 'Chọn điểm đón trên bản đồ'
              : 'Chọn điểm đến trên bản đồ',
          initialPoint: initialPoint,
        ),
      ),
    );

    if (resolved == null) return;

    if (isPickup) {
      model.selectPickupMapLocation(resolved);
    } else {
      model.selectDropMapLocation(resolved);
    }
  }

  Widget _buildAutocompleteField({
    required BuildContext context,
    required BookingModel model,
    required String label,
    required String hint,
    required IconData icon,
    required bool isPickup,
    required TextEditingController controller,
    required bool isLoading,
    required bool hasSelection,
    required List<TrackAsiaAutocompleteSuggestion> suggestions,
    required ValueChanged<TrackAsiaAutocompleteSuggestion> onSelected,
    required VoidCallback onClearSelection,
    required VoidCallback onPickOnMap,
  }) {
    final theme = Theme.of(context);
    final showSuggestions = suggestions.isNotEmpty;

    return TextFieldTapRegion(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: (value) =>
                model.onAddressTextChanged(isPickup: isPickup, query: value),
            onTapOutside: (_) => model.closeAutocompleteSuggestions(),
            style: const TextStyle(
              color: Color(0xFF123C2E),
              fontWeight: FontWeight.w600,
            ),
            cursorColor: theme.colorScheme.secondary,
            decoration: _addressFieldDecoration(
              context,
              label: label,
              hint: hint,
              icon: icon,
              suffixIcon: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : hasSelection
                  ? IconButton(
                      onPressed: onClearSelection,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF50635D),
                      ),
                    )
                  : const Icon(Icons.search_rounded, color: Color(0xFF50635D)),
            ),
          ),
          if (showSuggestions) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: Colors.black.withValues(alpha: 0.06),
                ),
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    dense: true,
                    onTap: () => onSelected(suggestion),
                    leading: Icon(
                      Icons.location_on_rounded,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                    title: Text(
                      suggestion.primaryText,
                      style: const TextStyle(
                        color: Color(0xFF123C2E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: suggestion.secondaryText.isEmpty
                        ? null
                        : Text(
                            suggestion.secondaryText,
                            style: const TextStyle(
                              color: Color(0xFF50635D),
                              fontSize: 12.5,
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onPickOnMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Chọn trên bản đồ'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget addressField,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          addressField,
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
    if (!model.hasPickupSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn điểm đón bằng gợi ý hoặc trên bản đồ'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (!model.hasDropSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn điểm đến bằng gợi ý hoặc trên bản đồ'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final routeValidationMessage = model.validateRouteSelection();
    if (routeValidationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(routeValidationMessage),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (model.goDate == null || model.goTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập ngày giờ đón'),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tạo đơn - Bước 2/3',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: BookingFlowBackground(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          padding: EdgeInsets.fromLTRB(16, 8, 16, 132 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookingStepHero(
                step: 2,
                title: 'Chọn lộ trình và thời gian đón',
                subtitle:
                    'Tìm địa chỉ bằng TrackAsia hoặc tự ghim trên bản đồ. Hệ thống sẽ chuẩn hóa địa chỉ và tính giá theo tuyến thực tế.',
                assetPath: 'lib/assets/icons/dong_duong_logo.png',
                footer: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    BookingSummaryChip(
                      icon: Icons.local_taxi_outlined,
                      label: model.rideTypeLabel,
                    ),
                    if ((model.customerPhone ?? '').isNotEmpty)
                      BookingSummaryChip(
                        icon: Icons.phone_outlined,
                        label: model.customerPhone!,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BookingSectionCard(
                title: 'Lộ trình chuyến đi',
                subtitle:
                    'Có thể kết hợp search và bản đồ cho từng điểm đón, điểm đến.',
                icon: Icons.route_rounded,
                child: Column(
                  children: [
                    _buildLocationCard(
                      title: 'Điểm đón',
                      subtitle:
                          'Tìm nơi tài xế bắt đầu đón khách hoặc nhận hàng',
                      icon: Icons.my_location_rounded,
                      accentColor: Colors.lightGreenAccent.shade100,
                      addressField: _buildAutocompleteField(
                        context: context,
                        model: model,
                        label: 'Địa chỉ đón',
                        hint: 'Ví dụ: Nội Bài, Vincom Bà Triệu...',
                        icon: Icons.location_searching_rounded,
                        isPickup: true,
                        controller: model.pickupAddressController,
                        isLoading: model.loadingPickupSuggestions,
                        hasSelection: model.hasPickupSelection,
                        suggestions: model.pickupSuggestions,
                        onSelected: model.selectPickupSuggestion,
                        onClearSelection: model.clearPickupSelection,
                        onPickOnMap: () =>
                            _pickPointOnMap(context, model, isPickup: true),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.92, end: 1),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Transform.scale(scale: value, child: child);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.south_rounded,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                    ),
                    _buildLocationCard(
                      title: 'Điểm đến',
                      subtitle: 'Tìm nơi kết thúc chuyến đi hoặc giao hàng',
                      icon: Icons.location_on_outlined,
                      accentColor: theme.colorScheme.secondary,
                      addressField: _buildAutocompleteField(
                        context: context,
                        model: model,
                        label: 'Địa chỉ đến',
                        hint: 'Ví dụ: Mỹ Đình, Times City...',
                        icon: Icons.pin_drop_outlined,
                        isPickup: false,
                        controller: model.dropAddressController,
                        isLoading: model.loadingDropSuggestions,
                        hasSelection: model.hasDropSelection,
                        suggestions: model.dropSuggestions,
                        onSelected: model.selectDropSuggestion,
                        onClearSelection: model.clearDropSelection,
                        onPickOnMap: () =>
                            _pickPointOnMap(context, model, isPickup: false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BookingSectionCard(
                title: 'Ngày và giờ đón',
                subtitle:
                    'Thời gian này sẽ được dùng để resolve tuyến và tính giá.',
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
                          model.closeAutocompleteSuggestions();

                          if (!_validate(model)) return;

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
