import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  bool _isCalculatingPrice = false;
  final _pickupAddressController = TextEditingController();
  final _dropAddressController = TextEditingController();

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _dropAddressController.dispose();
    super.dispose();
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String? _findName(List<dynamic> items, int? id) {
    if (id == null) return null;
    final selected = items.cast<dynamic>().firstWhere(
      (item) => item != null && item['id'].toString() == id.toString(),
      orElse: () => null,
    );
    return selected?['name']?.toString();
  }

  Widget _buildPickerField({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback? onTap,
    String? hint,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: value ?? ''),
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: bookingInputDecoration(
            context,
            label: label,
            hint: hint,
            icon: icon,
            suffixIcon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
    );
  }

  Future<int?> _showSelectionSheet({
    required String title,
    required List<dynamic> items,
    required int? selectedId,
    required IconData leadingIcon,
    String searchHint = 'Tìm kiếm',
    bool Function(int id)? isDisabled,
  }) {
    String query = '';

    return showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredItems = items.where((item) {
              final name = item['name']?.toString().toLowerCase() ?? '';
              return name.contains(query.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.78,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF123C2E),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext, null),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      onChanged: (value) {
                        setSheetState(() => query = value);
                      },
                      decoration: InputDecoration(
                        hintText: searchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredItems.isEmpty
                        ? const Center(
                            child: Text(
                              'Không tìm thấy lựa chọn phù hợp',
                              style: TextStyle(
                                color: Color(0xFF50635D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                            itemCount: filteredItems.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final id = item['id'] is int
                                  ? item['id'] as int
                                  : int.tryParse(item['id'].toString());
                              final name = item['name']?.toString() ?? '';
                              final disabled =
                                  id == null || (isDisabled?.call(id) ?? false);
                              final isSelected = id == selectedId;

                              return Material(
                                color: disabled
                                    ? Colors.grey.shade200
                                    : isSelected
                                    ? const Color(0xFF123C2E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: disabled
                                      ? null
                                      : () => Navigator.pop(sheetContext, id),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: disabled
                                                ? Colors.grey.shade300
                                                : isSelected
                                                ? Colors.white12
                                                : const Color(0x14123C2E),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Icon(
                                            leadingIcon,
                                            color: disabled
                                                ? Colors.grey
                                                : isSelected
                                                ? Colors.white
                                                : const Color(0xFF123C2E),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              color: disabled
                                                  ? Colors.grey
                                                  : isSelected
                                                  ? Colors.white
                                                  : const Color(0xFF123C2E),
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _provincePickerWidget({
    required BookingModel model,
    required bool isPickup,
  }) {
    final selectedId = isPickup
        ? model.selectedProvincePickup
        : model.selectedProvinceDrop;
    final selectedName = _findName(model.provinces, selectedId);
    final otherSelected = isPickup
        ? model.selectedProvinceDrop
        : model.selectedProvincePickup;

    return _buildPickerField(
      label: 'Tỉnh / Thành phố',
      value: selectedName,
      hint: 'Chọn tỉnh / thành phố',
      icon: Icons.location_city_outlined,
      onTap: () async {
        final chosen = await _showSelectionSheet(
          title: isPickup ? 'Chọn tỉnh đón khách' : 'Chọn tỉnh điểm đến',
          items: model.provinces,
          selectedId: selectedId,
          leadingIcon: Icons.location_city_outlined,
          searchHint: 'Tìm tỉnh / thành phố',
          isDisabled: (id) =>
              otherSelected != null &&
              id == otherSelected &&
              !model.canSelectSameProvince(id),
        );
        if (!mounted || chosen == null) return;
        if (isPickup) {
          await model.setSelectedProvincePickup(chosen);
        } else {
          await model.setSelectedProvinceDrop(chosen);
        }
      },
    );
  }

  Widget _districtPickerWidget({
    required List<dynamic> districts,
    required int? value,
    required void Function(int?) onChanged,
    required String title,
  }) {
    final selectedName = _findName(districts, value);
    return _buildPickerField(
      label: 'Quận / Huyện',
      value: selectedName,
      hint: districts.isEmpty
          ? 'Chưa có lựa chọn phù hợp'
          : 'Chọn quận / huyện',
      icon: Icons.map_outlined,
      onTap: districts.isEmpty
          ? null
          : () async {
              final chosen = await _showSelectionSheet(
                title: title,
                items: districts,
                selectedId: value,
                leadingIcon: Icons.place_outlined,
                searchHint: 'Tìm quận / huyện',
              );
              if (!mounted || chosen == null) return;
              onChanged(chosen);
            },
    );
  }

  Widget _buildLocationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget provinceDropdown,
    required Widget districtDropdown,
    required Widget addressField,
    Widget? helper,
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
          provinceDropdown,
          const SizedBox(height: 12),
          districtDropdown,
          if (helper != null) ...[const SizedBox(height: 12), helper],
          const SizedBox(height: 12),
          addressField,
        ],
      ),
    );
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
    if (model.selectedProvincePickup == null ||
        model.selectedDistrictPickup == null ||
        (model.addressPickup?.trim().isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ điểm đón'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (model.selectedProvinceDrop == null ||
        model.selectedDistrictDrop == null ||
        (model.addressDrop?.trim().isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ điểm đến'),
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

    _syncController(_pickupAddressController, model.addressPickup ?? '');
    _syncController(_dropAddressController, model.addressDrop ?? '');

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookingStepHero(
                step: 2,
                title: 'Chọn lộ trình và thời gian đón',
                subtitle:
                    'Phần này giữ nguyên logic tính giá cũ, nhưng bổ sung gợi ý chọn điểm đến để tránh chọn sai tuyến Hà Nội và Nội Bài.',
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
              if (model.dropDistrictRuleMessage != null) ...[
                const SizedBox(height: 16),
                BookingInfoBanner(
                  text: model.dropDistrictRuleMessage!,
                  icon: Icons.rule_folder_outlined,
                ),
              ],
              const SizedBox(height: 18),
              BookingSectionCard(
                title: 'Lộ trình chuyến đi',
                subtitle:
                    'Ưu tiên chọn theo thứ tự điểm đón trước, hệ thống sẽ tự lọc huyện điểm đến phù hợp.',
                icon: Icons.route_rounded,
                child: Column(
                  children: [
                    _buildLocationCard(
                      title: 'Điểm đón',
                      subtitle: 'Nơi tài xế bắt đầu đón khách hoặc nhận hàng',
                      icon: Icons.my_location_rounded,
                      accentColor: Colors.lightGreenAccent.shade100,
                      provinceDropdown: _provincePickerWidget(
                        model: model,
                        isPickup: true,
                      ),
                      districtDropdown: _districtPickerWidget(
                        districts: model.availablePickupDistricts,
                        value: model.selectedDistrictPickup,
                        title: 'Chọn quận / huyện điểm đón',
                        onChanged: model.setSelectedDistrictPickup,
                      ),
                      addressField: TextField(
                        controller: _pickupAddressController,
                        style: const TextStyle(color: Colors.white),
                        decoration: bookingInputDecoration(
                          context,
                          label: 'Số nhà, xã/phường',
                          hint: 'Nhập địa chỉ chi tiết điểm đón',
                          icon: Icons.home_work_outlined,
                        ),
                        onChanged: (value) => model.addressPickup = value,
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
                      subtitle: 'Nơi kết thúc chuyến đi hoặc giao hàng',
                      icon: Icons.location_on_outlined,
                      accentColor: theme.colorScheme.secondary,
                      provinceDropdown: _provincePickerWidget(
                        model: model,
                        isPickup: false,
                      ),
                      districtDropdown: _districtPickerWidget(
                        districts: model.availableDropDistricts,
                        value: model.selectedDistrictDrop,
                        title: 'Chọn quận / huyện điểm đến',
                        onChanged: model.setSelectedDistrictDrop,
                      ),
                      helper: model.dropDistrictRuleMessage == null
                          ? null
                          : BookingInfoBanner(
                              text: model.dropDistrictRuleMessage!,
                              icon: Icons.local_airport_outlined,
                              color: theme.colorScheme.secondary,
                            ),
                      addressField: TextField(
                        controller: _dropAddressController,
                        style: const TextStyle(color: Colors.white),
                        decoration: bookingInputDecoration(
                          context,
                          label: 'Số nhà, xã/phường',
                          hint: 'Nhập địa chỉ chi tiết điểm đến',
                          icon: Icons.pin_drop_outlined,
                        ),
                        onChanged: (value) => model.addressDrop = value,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              BookingSectionCard(
                title: 'Ngày và giờ đón',
                subtitle:
                    'Giữ nguyên cách tính giá theo mốc thời gian, chỉ làm rõ thao tác chọn nhanh hơn.',
                icon: Icons.schedule_rounded,
                child: Column(
                  children: [
                    _dateField(
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
                          if (!_validate(model)) return;

                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);

                          setState(() => _isCalculatingPrice = true);

                          try {
                            await model.fetchTripPrice();

                            if (!mounted) return;

                            if (model.tripPrice == null) {
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
