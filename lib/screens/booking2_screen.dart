import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import 'booking3_screen.dart';

class Booking2Screen extends StatefulWidget {
  final Function(int) onRideBooked;
  const Booking2Screen({super.key, required this.onRideBooked});

  @override
  State<Booking2Screen> createState() => _Booking2ScreenState();
}

class _Booking2ScreenState extends State<Booking2Screen> {
  bool _isCalculatingPrice = false;

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
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInput({
    required String label,
    required IconData icon,
    required Color color,
    required Widget provinceDropdown,
    Widget? districtDropdown,
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
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        provinceDropdown,
        if (districtDropdown != null) ...[
          const SizedBox(height: 8),
          districtDropdown,
        ],
        const SizedBox(height: 8),
        addressField,
      ],
    );
  }

  Widget _provincePickerWidget({
    required BookingModel model,
    required bool isPickup,
  }) {
    final int? selectedId =
    isPickup ? model.selectedProvincePickup : model.selectedProvinceDrop;
    final String label = "Tỉnh / Thành phố";
    final displayName = () {
      final sel = selectedId == null
          ? null
          : model.provinces.cast<dynamic?>().firstWhere(
            (p) => p != null && (p['id'].toString() == selectedId.toString()),
        orElse: () => null,
      );
      return sel == null ? null : (sel['name']?.toString() ?? '');
    }();

    final controller = TextEditingController(text: displayName ?? '');
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () async {
        final chosen =
        await _showProvincePickerForBooking(context, model, isPickup: isPickup);
        if (!mounted) return;
        if (chosen == null) return;
        if (isPickup) {
          await model.setSelectedProvincePickup(chosen);
        } else {
          await model.setSelectedProvinceDrop(chosen);
        }
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            hintText: displayName == null ? 'Chọn tỉnh / thành phố' : null,
            hintStyle: const TextStyle(color: Colors.white54),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            isDense: true,
            prefixIcon: Icon(Icons.location_city,
                size: 20, color: theme.colorScheme.secondary),
            suffixIcon: const Icon(Icons.unfold_more_rounded, color: Colors.white70),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Future<int?> _showProvincePickerForBooking(
      BuildContext context,
      BookingModel model, {
        required bool isPickup,
      }) {
    final otherSelected =
    isPickup ? model.selectedProvinceDrop : model.selectedProvincePickup;

    return showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isPickup ? "Chọn tỉnh đón khách" : "Chọn tỉnh điểm đến",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text(
                        "Đóng",
                        style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                      ),
                    )
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: (model.provinces.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: model.provinces.length,
                  separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final p = model.provinces[index];
                    final id = p['id'] is int
                        ? p['id'] as int
                        : int.tryParse(p['id'].toString());
                    final name = p['name']?.toString() ?? '';
                    final bool isDisabled =
                    (id != null && otherSelected != null && id == otherSelected);
                    return ListTile(
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: isDisabled
                            ? Colors.grey[300]
                            : Theme.of(context).colorScheme.secondary,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: isDisabled ? Colors.grey : Colors.black,
                          fontWeight: isDisabled ? FontWeight.w400 : FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      onTap: isDisabled || id == null ? null : () => Navigator.pop(ctx, id),
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _districtDropdown({
    required List<dynamic> districts,
    required int? value,
    required void Function(int?) onChanged,
  }) {
    final selected = value == null
        ? null
        : districts.cast<dynamic?>().firstWhere(
          (d) => d != null && (d['id'].toString() == value.toString()),
      orElse: () => null,
    );
    final displayName = selected == null ? null : (selected['name']?.toString() ?? '');
    final controller = TextEditingController(text: displayName ?? '');
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: districts.isEmpty
          ? null
          : () async {
        final chosen = await showModalBottomSheet<int?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Chọn Quận / Huyện",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: Text(
                            "Đóng",
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: districts.length,
                      separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      itemBuilder: (context, index) {
                        final d = districts[index];
                        final id = d["id"] is int
                            ? d["id"] as int
                            : int.tryParse(d["id"].toString());
                        final name = d["name"]?.toString() ?? '';
                        final isSelected = id == value;

                        return ListTile(
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          leading: Icon(
                            Icons.location_city_outlined,
                            color: isSelected ? theme.colorScheme.secondary : Colors.black54,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          onTap: id == null ? null : () => Navigator.pop(ctx, id),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
        if (!mounted) return;
        if (chosen == null) return;
        onChanged(chosen);
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Quận / Huyện",
            labelStyle: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            hintText: displayName == null ? 'Chọn quận / huyện' : null,
            hintStyle: const TextStyle(color: Colors.white54),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            isDense: true,
            prefixIcon: Icon(Icons.map, size: 20, color: theme.colorScheme.secondary),
            suffixIcon: const Icon(Icons.unfold_more_rounded, color: Colors.white70),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: TextEditingController(
            text: date == null ? "" : DateFormat('dd/MM/yyyy').format(date),
          ),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            prefixIcon: Icon(Icons.event, size: 20, color: theme.colorScheme.secondary),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeInputFields({
    required BookingModel model,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () async {
        int selectedHour = model.goTime?.hour ?? TimeOfDay.now().hour;
        int selectedMinute = model.goTime?.minute ?? TimeOfDay.now().minute;

        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (dialogCtx) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Container(
                    height: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: Text(
                                  "Hủy",
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                "Chọn giờ đón",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  model.goTime = TimeOfDay(
                                    hour: selectedHour,
                                    minute: selectedMinute,
                                  );
                                  model.notifyListeners();
                                  Navigator.pop(dialogCtx);
                                },
                                child: Text(
                                  "Xong",
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
                              // Giờ
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
                                    setDialogState(() {
                                      selectedHour = index;
                                    });
                                  },
                                  children: List.generate(24, (index) {
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),

                              Text(
                                ":",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),

                              // Phút
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
                                    setDialogState(() {
                                      selectedMinute = index;
                                    });
                                  },
                                  children: List.generate(60, (index) {
                                    return Center(
                                      child: Text(
                                        index.toString().padLeft(2, '0'),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
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
                ? ""
                : "${model.goTime!.hour.toString().padLeft(2, '0')}:${model.goTime!.minute.toString().padLeft(2, '0')}",
          ),
          readOnly: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: "Giờ đón",
            labelStyle: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            hintText: "HH:MM",
            hintStyle: const TextStyle(color: Colors.white38),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            prefixIcon: Icon(Icons.access_time, size: 20, color: theme.colorScheme.secondary),
            suffixIcon: const Icon(Icons.unfold_more_rounded, color: Colors.white70),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Đặt chuyến - Bước 2/3',
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
              title: "Điểm Đi và Điểm Đến",
              icon: Icons.route,
              children: [
                _buildLocationInput(
                  label: "Điểm đón",
                  icon: Icons.my_location,
                  color: Colors.green,
                  provinceDropdown: _provincePickerWidget(model: model, isPickup: true),
                  districtDropdown: _districtDropdown(
                    districts: model.pickupDistricts,
                    value: model.selectedDistrictPickup,
                    onChanged: (v) {
                      model.setSelectedDistrictPickup(v);
                      // ❌ Không gọi model.fetchTripPrice() ở đây nữa
                    },
                  ),
                  addressField: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Số nhà, xã/phường",
                      labelStyle: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      isDense: true,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                    ),
                    onChanged: (v) => model.addressPickup = v,
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: "Ngày & Giờ Đón",
                  icon: Icons.calendar_today,
                  children: [
                    _dateField(
                      label: "Ngày đón",
                      date: model.goDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDate: model.goDate ?? DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: theme.colorScheme.secondary,
                                  onPrimary: Colors.black87,
                                  onSurface: Colors.black87,
                                ),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.colorScheme.secondary,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          model.goDate = picked;
                          model.notifyListeners();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _timeInputFields(model: model),
                  ],
                ),
                const SizedBox(height: 25),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                  child: Icon(Icons.arrow_downward, color: Colors.grey),
                ),
                _buildLocationInput(
                  label: "Điểm đến",
                  icon: Icons.location_on,
                  color: Colors.red,
                  provinceDropdown: _provincePickerWidget(model: model, isPickup: false),
                  districtDropdown: _districtDropdown(
                    districts: model.dropDistricts,
                    value: model.selectedDistrictDrop,
                    onChanged: (v) {
                      model.setSelectedDistrictDrop(v);
                      // ❌ Không gọi model.fetchTripPrice() ở đây nữa
                    },
                  ),
                  addressField: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Số nhà, xã/phường",
                      labelStyle: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      isDense: true,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                    ),
                    onChanged: (v) => model.addressDrop = v,
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
                onPressed: _isCalculatingPrice ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: theme.colorScheme.secondary, width: 2),
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
              child: ElevatedButton(
                onPressed: _isCalculatingPrice
                    ? null
                    : () async {
                  if (!_validate(model)) return;

                  setState(() => _isCalculatingPrice = true);

                  try {
                    await model.fetchTripPrice();

                    if (!mounted) return;

                    if (model.tripPrice == null) {
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

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: model,
                          child: Booking3Screen(onRideBooked: widget.onRideBooked),
                        ),
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => _isCalculatingPrice = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.black87,
                ),
                child: _isCalculatingPrice
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black87,
                  ),
                )
                    : const Text(
                  "TIẾP THEO",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}