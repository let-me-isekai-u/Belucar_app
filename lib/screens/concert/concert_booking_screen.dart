import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_theme.dart';
import '../../models/booking_model.dart';
import '../../models/location_models.dart';
import '../../services/login_credential_storage.dart';
import '../booking/booking_address_map_picker_screen.dart';
import '../booking/booking_ui.dart';
import '../popup/concert_round_trip_popup.dart';

enum ConcertVehicleType { standard, fiveSeat, sevenSeat }

class ConcertBookingScreen extends StatefulWidget {
  const ConcertBookingScreen({super.key, this.isGuest = false});

  final bool isGuest;

  @override
  State<ConcertBookingScreen> createState() => _ConcertBookingScreenState();
}

class _ConcertBookingScreenState extends State<ConcertBookingScreen> {
  static const _destination = 'Sân vận động Quốc gia Mỹ Đình';
  static final _concertDates = <DateTime>[
    DateTime(2026, 10, 24),
    DateTime(2026, 10, 25),
  ];
  static const _departureTimes = <String>['14:00', '15:30', '17:00', '18:30'];
  static const int _baseFare = 120000;

  final FocusNode _pickupFocusNode = FocusNode();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ticketLookupPhoneController =
      TextEditingController();
  final Set<DateTime> _selectedDates = <DateTime>{_concertDates.first};
  final Set<DateTime> _selectedReturnDates = <DateTime>{};
  String? _selectedTime;
  int _quantity = 1;
  bool _isRoundTrip = false;
  bool _isReturnOnly = false;
  bool _isOvernightJourney = false;
  bool _wantsReturnTrip = false;
  ConcertVehicleType _selectedVehicleType = ConcertVehicleType.standard;
  bool _isCharter = false;
  bool _isCreatingTicket = false;
  bool _isTicketLookupTab = false;

  bool get _hasMatchingRoundTripDates =>
      !_isReturnOnly &&
      _wantsReturnTrip &&
      _selectedReturnDates.isNotEmpty &&
      _selectedDates.length == _selectedReturnDates.length &&
      _selectedDates.every(_selectedReturnDates.contains);

  bool get _hasOvernightTwoDayJourney =>
      !_isReturnOnly &&
      _selectedDates.length == 2 &&
      _selectedReturnDates.length == 1 &&
      _selectedReturnDates.contains(_concertDates.last);

  List<DateTime> get _effectiveOutboundDates {
    if (_isReturnOnly) return const [];
    if (_hasOvernightTwoDayJourney) return [_concertDates.first];
    return _selectedDates.toList()..sort();
  }

  int get _vehicleCapacity => switch (_selectedVehicleType) {
    ConcertVehicleType.fiveSeat => 5,
    ConcertVehicleType.sevenSeat => 7,
    ConcertVehicleType.standard => 1,
  };

  int get _chargedSeatCount => _isCharter ? _vehicleCapacity : _quantity;

  int get _maxQuantity => switch (_selectedVehicleType) {
    ConcertVehicleType.fiveSeat => 5,
    ConcertVehicleType.sevenSeat => 7,
    ConcertVehicleType.standard => 6,
  };

  String get _vehicleTypeLabel => switch (_selectedVehicleType) {
    ConcertVehicleType.fiveSeat => 'Xe 5 chỗ',
    ConcertVehicleType.sevenSeat => 'Xe 7 chỗ',
    ConcertVehicleType.standard => 'Ghế lẻ',
  };

  int get _totalPrice {
    final farePerSeat = _isReturnOnly
        ? _baseFare
        : _hasMatchingRoundTripDates
        ? (_baseFare * 2 * 0.9).round() * _selectedDates.length
        : _hasOvernightTwoDayJourney
        ? _baseFare * 2
        : _baseFare *
              (_selectedDates.length +
                  (_wantsReturnTrip ? _selectedReturnDates.length : 0));
    return farePerSeat * _chargedSeatCount;
  }

  void _syncJourneyType({bool showPopup = true}) {
    if (_isReturnOnly) return;
    final shouldBeRoundTrip = _hasMatchingRoundTripDates;
    final shouldBeOvernight = _hasOvernightTwoDayJourney;
    final shouldShowPopup = showPopup && shouldBeRoundTrip && !_isRoundTrip;
    final shouldShowOvernightPopup =
        showPopup && shouldBeOvernight && !_isOvernightJourney;
    setState(() {
      _isRoundTrip = shouldBeRoundTrip;
      _isOvernightJourney = shouldBeOvernight;
    });
    if (shouldShowPopup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showConcertRoundTripPopup(context);
      });
    } else if (shouldShowOvernightPopup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showConcertOvernightJourneyPopup(context);
      });
    }
  }

  void _selectOneWay() {
    setState(() {
      _isReturnOnly = false;
      _wantsReturnTrip = false;
      _selectedReturnDates.clear();
      _isRoundTrip = false;
      _isOvernightJourney = false;
    });
  }

  void _selectRoundTrip() {
    setState(() {
      _isReturnOnly = false;
      _wantsReturnTrip = true;
      _selectedReturnDates
        ..clear()
        ..addAll(_selectedDates);
    });
    _syncJourneyType();
  }

  void _selectReturnOnly() {
    final firstSelectedDate = (_selectedDates.toList()..sort()).first;
    setState(() {
      _isReturnOnly = true;
      _isRoundTrip = false;
      _isOvernightJourney = false;
      _wantsReturnTrip = false;
      _selectedReturnDates
        ..clear()
        ..add(firstSelectedDate);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showConcertReturnOnlyTimePopup(context);
    });
  }

  Future<void> _openExistingTicket() async {
    await openConcertTickets(context, ConcertTicketData.demoExistingTickets());
  }

  @override
  void dispose() {
    _pickupFocusNode.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ticketLookupPhoneController.dispose();
    super.dispose();
  }

  Future<void> _lookupConcertTicket() async {
    final phone = _ticketLookupPhoneController.text.replaceAll(
      RegExp(r'\s+'),
      '',
    );
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số điện thoại dùng để mua vé.'),
        ),
      );
      return;
    }
    if (phone != '0987654321') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy vé concert với số điện thoại này.'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ConcertTicketScreen(ticket: ConcertTicketData.demoLookup()),
      ),
    );
  }

  Future<void> _pickPickupOnMap(BookingModel model) async {
    dismissBookingKeyboard();
    model.closeAutocompleteSuggestions();

    final location = await Navigator.push<AddressResolvedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => BookingAddressMapPickerScreen(
          title: _isReturnOnly
              ? 'Chọn điểm trả trên bản đồ'
              : 'Chọn điểm đón trên bản đồ',
          initialPoint: model.selectedPickupPoint,
        ),
      ),
    );

    if (location != null) {
      model.selectPickupMapLocation(location);
    }
  }

  Future<void> _createDemoTicket(BookingModel model) async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (widget.isGuest) {
      final isValidEmail = RegExp(
        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
      ).hasMatch(email);
      final normalizedPhone = phone.replaceAll(RegExp(r'\s+'), '');
      final isValidPhone = RegExp(r'^0\d{9}$').hasMatch(normalizedPhone);

      if (!isValidEmail) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập email hợp lệ.')),
        );
        return;
      }
      if (!isValidPhone) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Số điện thoại phải gồm 10 số và bắt đầu bằng 0.'),
          ),
        );
        return;
      }
    }
    if (!model.hasPickupSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isReturnOnly
                ? 'Vui lòng chọn điểm trả của bạn.'
                : 'Vui lòng chọn điểm đón của bạn.',
          ),
        ),
      );
      _pickupFocusNode.requestFocus();
      return;
    }
    if (!_isReturnOnly && _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn khung giờ khởi hành.')),
      );
      return;
    }
    if ((_wantsReturnTrip || _isReturnOnly) && _selectedReturnDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất một ngày về.')),
      );
      return;
    }

    setState(() => _isCreatingTicket = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final selectedDates = _effectiveOutboundDates;
    final selectedReturnDates = _selectedReturnDates.toList()..sort();
    final codeDates = _isReturnOnly ? selectedReturnDates : selectedDates;
    final departureTime = _isReturnOnly
        ? 'Sau khi concert kết thúc'
        : _selectedTime!;
    final normalizedPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final accountSuffix = normalizedPhone.length >= 4
        ? normalizedPhone.substring(normalizedPhone.length - 4)
        : '0000';
    final ticket = ConcertTicketData(
      ticketCode:
          'BB${codeDates.map((date) => date.day).join()}${_isReturnOnly ? 'END' : _selectedTime!.replaceAll(':', '')}${_isRoundTrip
              ? 'R'
              : _isReturnOnly
              ? 'B'
              : 'O'}${(_quantity * 37).toString().padLeft(3, '0')}',
      pickupAddress: _isReturnOnly ? _destination : model.pickupDisplayAddress,
      destination: _isReturnOnly ? model.pickupDisplayAddress : _destination,
      concertDates: selectedDates,
      returnDates: selectedReturnDates,
      departureTime: departureTime,
      quantity: _chargedSeatCount,
      isRoundTrip: _isRoundTrip,
      totalPrice: _totalPrice,
      vehicleTypeLabel: _vehicleTypeLabel,
      isCharter: _isCharter,
      customerEmail: widget.isGuest ? email : null,
      customerPhone: widget.isGuest ? normalizedPhone : null,
      username: widget.isGuest ? 'username$accountSuffix' : null,
      temporaryPassword: widget.isGuest ? 'BB@$accountSuffix' : null,
    );

    if (widget.isGuest) {
      try {
        await LoginCredentialStorage.save(
          phone: normalizedPhone,
          password: ticket.temporaryPassword!,
        );
      } catch (_) {
        // Đây là luồng mô phỏng; vé vẫn được tạo nếu secure storage bị lỗi.
      }
    }

    if (!mounted) return;
    setState(() => _isCreatingTicket = false);
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ConcertTicketScreen(ticket: ticket)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BookingModel>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isGuest ? 'Mua vé concert - Khách mới' : 'Đặt xe đi concert',
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white),
          BookingKeyboardDismissArea(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (widget.isGuest)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _SlidingTicketSwitch(
                        lookupSelected: _isTicketLookupTab,
                        onChanged: (lookupSelected) =>
                            setState(() => _isTicketLookupTab = lookupSelected),
                      ),
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final isLookupPage =
                            child.key == const ValueKey('ticket-lookup-page');
                        final begin = isLookupPage
                            ? const Offset(1, 0)
                            : const Offset(-1, 0);
                        return ClipRect(
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: begin,
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: widget.isGuest && _isTicketLookupTab
                          ? KeyedSubtree(
                              key: const ValueKey('ticket-lookup-page'),
                              child: _buildTicketLookupTab(),
                            )
                          : SingleChildScrollView(
                              key: const ValueKey('ticket-buy-page'),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.isGuest) ...[
                                    _buildGuestInformationCard(),
                                    const SizedBox(height: 20),
                                  ] else ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _openExistingTicket,
                                        icon: const Icon(
                                          Icons.confirmation_num_rounded,
                                        ),
                                        label: const Text('Xem vé đã có'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryGreen,
                                          foregroundColor: AppColors.accentGold,
                                          minimumSize: const Size(
                                            double.infinity,
                                            52,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                  _buildSectionTitle(
                                    icon: _isReturnOnly
                                        ? Icons.location_on_rounded
                                        : Icons.trip_origin_rounded,
                                    title: _isReturnOnly
                                        ? 'Điểm trả'
                                        : 'Điểm đón',
                                    subtitle: _isReturnOnly
                                        ? 'Chọn vị trí xe sẽ trả bạn'
                                        : 'Chọn vị trí xe sẽ đón bạn',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildRouteCard(model),
                                  if (model.pickupSuggestions.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildSuggestions(model),
                                  ],
                                  const SizedBox(height: 24),
                                  _buildSectionTitle(
                                    icon: Icons.sync_alt_rounded,
                                    title: 'Loại hành trình',
                                    subtitle: _isReturnOnly
                                        ? 'Chỉ mua lượt về sau concert'
                                        : _isRoundTrip
                                        ? 'Ngày đi và về trùng nhau • Đã giảm 10%'
                                        : _wantsReturnTrip
                                        ? 'Các lượt được tính như vé thường'
                                        : 'Chưa chọn lượt về',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTripTypePicker(),
                                  const SizedBox(height: 24),
                                  _buildSectionTitle(
                                    icon: Icons.directions_car_filled_rounded,
                                    title: 'Loại vé',
                                    subtitle:
                                        'Chọn ghế lẻ hoặc loại xe phù hợp',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildVehicleTypePicker(),
                                  if (_selectedVehicleType !=
                                      ConcertVehicleType.standard) ...[
                                    const SizedBox(height: 10),
                                    _buildCharterOption(),
                                  ],
                                  const SizedBox(height: 24),
                                  _buildSectionTitle(
                                    icon: Icons.calendar_month_rounded,
                                    title: _isReturnOnly
                                        ? 'Chọn ngày về'
                                        : 'Chọn ngày concert',
                                    subtitle: _isReturnOnly
                                        ? 'Chỉ chọn một ngày 24 hoặc 25'
                                        : 'Có thể chọn một hoặc cả hai ngày',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDatePicker(),
                                  if (!_isReturnOnly) ...[
                                    const SizedBox(height: 8),
                                    _buildReturnDateOption(),
                                  ],
                                  if (!_isReturnOnly) ...[
                                    const SizedBox(height: 24),
                                    _buildSectionTitle(
                                      icon: Icons.access_time_filled_rounded,
                                      title: 'Chọn khung giờ',
                                      subtitle:
                                          'Vui lòng có mặt trước giờ đi 15 phút',
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTimePicker(),
                                  ],
                                  const SizedBox(height: 24),
                                  _buildSectionTitle(
                                    icon: Icons
                                        .airline_seat_recline_normal_rounded,
                                    title: 'Số lượng vé',
                                    subtitle: _isRoundTrip
                                        ? '216.000đ / khách / ngày (đã giảm 10%)'
                                        : '120.000đ / khách / lượt',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildQuantityPicker(),
                                ],
                              ),
                            ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, animation) => SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: widget.isGuest && _isTicketLookupTab
                        ? const SizedBox.shrink()
                        : KeyedSubtree(
                            key: const ValueKey('concert-checkout-bar'),
                            child: _buildCheckoutBar(model),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketLookupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAEC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.accentGold),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tra cứu vé xe',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Nhập số điện thoại đã dùng khi mua vé để xem vé và thông tin đăng nhập.',
              style: TextStyle(color: Color(0xFF4A5650), height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ticketLookupPhoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookupConcertTicket(),
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Số điện thoại mua vé',
                hintText: 'Nhập 0987654321 để xem vé mẫu',
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                  color: AppColors.primaryGreen,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Xoá số điện thoại',
                  onPressed: _ticketLookupPhoneController.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: AppColors.accentGold,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _lookupConcertTicket,
                icon: const Icon(Icons.search_rounded),
                label: const Text('TRA VÉ XE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.accentGold,
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestInformationCard() {
    InputDecoration decoration({
      required String label,
      required String hint,
      required IconData icon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.92),
        labelStyle: const TextStyle(color: AppColors.primaryGreen),
        hintStyle: const TextStyle(color: Colors.black45),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryGreen),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 2),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin khách hàng',
            style: TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Số điện thoại sẽ được dùng làm tài khoản đăng nhập.',
            style: TextStyle(color: Color(0xFF404944), height: 1.35),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: Colors.black87),
            decoration: decoration(
              label: 'Email',
              hint: 'Nhập email của bạn',
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.black87),
            decoration: decoration(
              label: 'Số điện thoại',
              hint: 'Ví dụ: 0912345678',
              icon: Icons.phone_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.accentGold, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard(BookingModel model) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          TextField(
            controller: model.pickupAddressController,
            focusNode: _pickupFocusNode,
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
            cursorColor: AppColors.primaryGreen,
            onChanged: (value) =>
                model.onAddressTextChanged(isPickup: true, query: value),
            decoration: InputDecoration(
              hintText: _isReturnOnly
                  ? 'Nhập điểm trả của bạn'
                  : 'Nhập điểm đón của bạn',
              hintStyle: const TextStyle(
                color: Color(0xFF6B7B76),
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.trip_origin_rounded,
                color: Color(0xFF3D7DFF),
              ),
              suffixIcon: model.loadingPickupSuggestions
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : model.pickupAddressController.text.isNotEmpty
                  ? IconButton(
                      onPressed: model.clearPickupSelection,
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF6F8F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _pickPickupOnMap(model),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(
                _isReturnOnly
                    ? 'Chọn điểm trả trên bản đồ'
                    : 'Chọn điểm đón trên bản đồ',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(BookingModel model) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 18)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: model.pickupSuggestions.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
        itemBuilder: (context, index) {
          final suggestion = model.pickupSuggestions[index];
          return ListTile(
            onTap: () {
              model.selectPickupSuggestion(suggestion);
              _pickupFocusNode.unfocus();
            },
            leading: const Icon(
              Icons.location_on_outlined,
              color: AppColors.accentGold,
            ),
            title: Text(
              suggestion.primaryText,
              style: const TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: suggestion.secondaryText.isEmpty
                ? null
                : Text(
                    suggestion.secondaryText,
                    style: const TextStyle(
                      color: Color(0xFF4D5E58),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildVehicleTypePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentGold),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ConcertVehicleType>(
          value: _selectedVehicleType,
          isExpanded: true,
          dropdownColor: AppColors.primaryGreen,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.accentGold,
          ),
          style: const TextStyle(
            color: AppColors.accentGold,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          items: const [
            DropdownMenuItem(
              value: ConcertVehicleType.standard,
              child: Text(
                'Ghế lẻ',
                style: TextStyle(color: AppColors.accentGold),
              ),
            ),
            DropdownMenuItem(
              value: ConcertVehicleType.fiveSeat,
              child: Text(
                'Xe 5 chỗ',
                style: TextStyle(color: AppColors.accentGold),
              ),
            ),
            DropdownMenuItem(
              value: ConcertVehicleType.sevenSeat,
              child: Text(
                'Xe 7 chỗ',
                style: TextStyle(color: AppColors.accentGold),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedVehicleType = value;
              if (value == ConcertVehicleType.standard) {
                _isCharter = false;
              }
              if (_quantity > _maxQuantity) _quantity = _maxQuantity;
            });
          },
        ),
      ),
    );
  }

  Widget _buildCharterOption() {
    return CheckboxListTile(
      value: _isCharter,
      onChanged: (value) => setState(() => _isCharter = value ?? false),
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: Colors.black,
      checkColor: AppColors.accentGold,
      side: const BorderSide(color: Colors.black, width: 1.8),
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text(
        'Bao xe',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Row(
      children: _concertDates.map((date) {
        final selected = _isReturnOnly
            ? _selectedReturnDates.contains(date)
            : _selectedDates.contains(date);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: date == _concertDates.first ? 6 : 0,
              left: date == _concertDates.last ? 6 : 0,
            ),
            child: InkWell(
              onTap: () {
                if (_isReturnOnly) {
                  setState(() {
                    _selectedReturnDates
                      ..clear()
                      ..add(date);
                  });
                  return;
                }
                setState(() {
                  if (selected) {
                    if (_selectedDates.length > 1) {
                      _selectedDates.remove(date);
                    }
                  } else {
                    _selectedDates.add(date);
                  }
                  if (_selectedDates.isNotEmpty) {
                    final firstOutbound = _selectedDates.reduce(
                      (first, next) => first.isBefore(next) ? first : next,
                    );
                    _selectedReturnDates.removeWhere(
                      (returnDate) => returnDate.isBefore(firstOutbound),
                    );
                    if (_selectedDates.length == 1 &&
                        _selectedReturnDates.length > 1) {
                      final preferredReturn =
                          _selectedReturnDates.contains(_selectedDates.single)
                          ? _selectedDates.single
                          : (_selectedReturnDates.toList()..sort()).first;
                      _selectedReturnDates
                        ..clear()
                        ..add(preferredReturn);
                    }
                  }
                });
                _syncJourneyType();
              },
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? AppColors.accentGold
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      date.day == 24 ? 'Thứ Bảy' : 'Chủ Nhật',
                      style: TextStyle(
                        color: selected ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM').format(date),
                      style: TextStyle(
                        color: selected
                            ? AppColors.accentGold
                            : AppColors.primaryGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReturnDateOption() {
    return Column(
      children: [
        CheckboxListTile(
          value: _wantsReturnTrip,
          onChanged: (value) {
            setState(() {
              _wantsReturnTrip = value ?? false;
              if (!_wantsReturnTrip) {
                _selectedReturnDates.clear();
                _isRoundTrip = false;
                _isOvernightJourney = false;
              }
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: Colors.black,
          checkColor: AppColors.accentGold,
          side: const BorderSide(color: Colors.black, width: 1.8),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'Đặt lượt về',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: !_wantsReturnTrip
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn ngày về',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildReturnDatePicker(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReturnDatePicker() {
    final firstOutbound = _selectedDates.reduce(
      (first, next) => first.isBefore(next) ? first : next,
    );
    return Row(
      children: _concertDates.map((date) {
        final enabled = !date.isBefore(firstOutbound);
        final selected = _selectedReturnDates.contains(date);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: date == _concertDates.first ? 6 : 0,
              left: date == _concertDates.last ? 6 : 0,
            ),
            child: ChoiceChip(
              selected: selected,
              onSelected: !enabled
                  ? null
                  : (_) {
                      setState(() {
                        if (_selectedDates.length == 1) {
                          _selectedReturnDates
                            ..clear()
                            ..add(date);
                        } else if (selected) {
                          _selectedReturnDates.remove(date);
                        } else {
                          _selectedReturnDates.add(date);
                        }
                      });
                      _syncJourneyType();
                    },
              showCheckmark: false,
              avatar: Icon(
                Icons.home_rounded,
                color: !enabled
                    ? Colors.black26
                    : selected
                    ? AppColors.accentGold
                    : AppColors.primaryGreen,
              ),
              label: Text(DateFormat('dd/MM').format(date)),
              labelStyle: TextStyle(
                color: !enabled
                    ? Colors.black26
                    : selected
                    ? Colors.white
                    : AppColors.primaryGreen,
                fontWeight: FontWeight.w900,
              ),
              selectedColor: AppColors.primaryGreen,
              backgroundColor: Colors.white,
              disabledColor: const Color(0xFFF0F0F0),
              side: BorderSide(
                color: selected
                    ? AppColors.accentGold
                    : Colors.black.withValues(alpha: 0.08),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimePicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _departureTimes.map((time) {
        final selected = time == _selectedTime;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => _selectedTime = time),
          showCheckmark: false,
          avatar: Icon(
            Icons.directions_bus_filled_rounded,
            size: 18,
            color: selected ? AppColors.accentGold : AppColors.primaryGreen,
          ),
          label: Text(time),
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.primaryGreen,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          selectedColor: AppColors.primaryGreen,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: selected
                ? AppColors.accentGold
                : Colors.black.withValues(alpha: 0.08),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        );
      }).toList(),
    );
  }

  Widget _buildTripTypePicker() {
    return Row(
      children: [
        Expanded(
          child: _buildTripTypeOption(
            title: 'Vé lượt đi',
            subtitle: 'Đến Mỹ Đình',
            icon: Icons.arrow_forward_rounded,
            selected: !_isRoundTrip && !_isReturnOnly,
            onTap: _selectOneWay,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTripTypeOption(
            title: 'Vé lượt về',
            subtitle: 'Rời Mỹ Đình',
            icon: Icons.arrow_back_rounded,
            selected: _isReturnOnly,
            onTap: _selectReturnOnly,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTripTypeOption(
            title: 'Khứ hồi',
            subtitle: 'Đi và về',
            icon: Icons.sync_alt_rounded,
            selected: _isRoundTrip,
            onTap: _selectRoundTrip,
          ),
        ),
      ],
    );
  }

  Widget _buildTripTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 128,
      child: Material(
        color: selected ? AppColors.primaryGreen : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AppColors.accentGold
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected
                      ? AppColors.accentGold
                      : AppColors.primaryGreen,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.primaryGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: selected ? Colors.white70 : Colors.black54,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isCharter ? 'Số chỗ tính giá' : 'Hành khách',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          IconButton.filledTonal(
            onPressed: _isCharter || _quantity <= 1
                ? null
                : () => setState(() => _quantity--),
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${_isCharter ? _vehicleCapacity : _quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.filled(
            onPressed: _isCharter || _quantity >= _maxQuantity
                ? null
                : () => setState(() => _quantity++),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.accentGold,
              disabledBackgroundColor: AppColors.primaryGreen.withValues(
                alpha: 0.45,
              ),
              disabledForegroundColor: AppColors.accentGold.withValues(
                alpha: 0.55,
              ),
            ),
            icon: const Icon(Icons.add_rounded, color: AppColors.accentGold),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(BookingModel model) {
    final formattedPrice = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(_totalPrice);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 20)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tạm tính', style: TextStyle(color: Colors.black54)),
                Text(
                  formattedPrice,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isCreatingTicket
                  ? null
                  : () => _createDemoTicket(model),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.accentGold,
                minimumSize: const Size(double.infinity, 54),
              ),
              child: _isCreatingTicket
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentGold,
                      ),
                    )
                  : Text(
                      widget.isGuest
                          ? 'Tạo vé và tài khoản'
                          : 'Tạo vé dùng thử',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConcertTicketData {
  const ConcertTicketData({
    required this.ticketCode,
    required this.pickupAddress,
    required this.destination,
    required this.concertDates,
    this.returnDates = const [],
    required this.departureTime,
    required this.quantity,
    required this.isRoundTrip,
    required this.totalPrice,
    this.customerEmail,
    this.customerPhone,
    this.username,
    this.temporaryPassword,
    this.vehicleTypeLabel = 'Ghế lẻ',
    this.isCharter = false,
  });

  final String ticketCode;
  final String pickupAddress;
  final String destination;
  final List<DateTime> concertDates;
  final List<DateTime> returnDates;
  final String departureTime;
  final int quantity;
  final bool isRoundTrip;
  final int totalPrice;
  final String? customerEmail;
  final String? customerPhone;
  final String? username;
  final String? temporaryPassword;
  final String vehicleTypeLabel;
  final bool isCharter;

  bool get hasLoginInformation =>
      customerPhone != null && temporaryPassword != null;

  factory ConcertTicketData.demoExisting() {
    return ConcertTicketData(
      ticketCode: 'BB24251400R037',
      pickupAddress: 'Eco Park 1',
      destination: 'Sân vận động Quốc gia Mỹ Đình',
      concertDates: [DateTime(2026, 10, 24), DateTime(2026, 10, 25)],
      returnDates: [DateTime(2026, 10, 24), DateTime(2026, 10, 25)],
      departureTime: '14:00',
      quantity: 1,
      isRoundTrip: true,
      totalPrice: 432000,
    );
  }

  factory ConcertTicketData.demoAdditional() {
    return ConcertTicketData(
      ticketCode: 'BB251530O074',
      pickupAddress: 'Eco Park 1',
      destination: 'Sân vận động Quốc gia Mỹ Đình',
      concertDates: [DateTime(2026, 10, 25)],
      departureTime: '15:30',
      quantity: 1,
      isRoundTrip: false,
      totalPrice: 120000,
    );
  }

  static List<ConcertTicketData> demoExistingTickets() => [
    ConcertTicketData.demoExisting(),
    ConcertTicketData.demoAdditional(),
  ];

  factory ConcertTicketData.demoLookup() {
    return ConcertTicketData(
      ticketCode: 'BB24251400R321',
      pickupAddress: 'Eco Park 1',
      destination: 'Sân vận động Quốc gia Mỹ Đình',
      concertDates: [DateTime(2026, 10, 24), DateTime(2026, 10, 25)],
      returnDates: [DateTime(2026, 10, 24), DateTime(2026, 10, 25)],
      departureTime: '14:00',
      quantity: 1,
      isRoundTrip: true,
      totalPrice: 432000,
      customerEmail: 'concert.demo@belucar.vn',
      customerPhone: '0987654321',
      username: 'username4321',
      temporaryPassword: 'BB@4321',
    );
  }

  String get qrPayload {
    final dates = concertDates
        .map((date) => DateFormat('yyyyMMdd').format(date))
        .join(',');
    final returns = returnDates
        .map((date) => DateFormat('yyyyMMdd').format(date))
        .join(',');
    return 'BELUCAR|CONCERT|$ticketCode|$dates|$returns|$departureTime|$quantity|${isRoundTrip ? 'ROUND_TRIP' : 'REGULAR'}';
  }
}

Future<void> openConcertTickets(
  BuildContext context,
  List<ConcertTicketData> tickets,
) async {
  if (tickets.isEmpty) return;

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => tickets.length >= 2
          ? ConcertTicketListScreen(tickets: tickets)
          : ConcertTicketScreen(ticket: tickets.first),
    ),
  );
}

class ConcertTicketListScreen extends StatelessWidget {
  const ConcertTicketListScreen({super.key, required this.tickets});

  final List<ConcertTicketData> tickets;

  String _dateLabel(ConcertTicketData ticket) {
    final dates = ticket.concertDates.isNotEmpty
        ? ticket.concertDates
        : ticket.returnDates;
    return dates
        .map((date) => DateFormat('dd/MM/yyyy').format(date))
        .join(' & ');
  }

  String _journeyLabel(ConcertTicketData ticket) {
    if (ticket.isRoundTrip) return 'Khứ hồi';
    if (ticket.concertDates.isEmpty && ticket.returnDates.isNotEmpty) {
      return 'Lượt về';
    }
    return 'Lượt đi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3E9),
      appBar: AppBar(
        title: const Text('Danh sách vé'),
        centerTitle: true,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          itemCount: tickets.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7DA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.accentGold),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.confirmation_num_rounded,
                      color: AppColors.primaryGreen,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bạn đang có ${tickets.length} vé',
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Chọn một vé để xem chi tiết và mã QR kiểm vé.',
                            style: TextStyle(
                              color: Color(0xFF4A5650),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final ticket = tickets[index - 1];
            final isReturnPickup =
                ticket.departureTime == 'Sau khi concert kết thúc';
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              elevation: 1,
              shadowColor: Colors.black12,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ConcertTicketScreen(ticket: ticket),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.qr_code_2_rounded,
                              color: AppColors.accentGold,
                              size: 27,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vé ${index.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Mã vé: ${ticket.ticketCode}',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F7EA),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Còn hiệu lực',
                              style: TextStyle(
                                color: Color(0xFF12653D),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      _TicketListInformation(
                        icon: Icons.calendar_month_rounded,
                        text: _dateLabel(ticket),
                      ),
                      const SizedBox(height: 9),
                      _TicketListInformation(
                        icon: Icons.sync_alt_rounded,
                        text: _journeyLabel(ticket),
                      ),
                      const SizedBox(height: 9),
                      _TicketListInformation(
                        icon: Icons.access_time_rounded,
                        text: isReturnPickup
                            ? 'Đón sau khi concert kết thúc'
                            : 'Khởi hành ${ticket.departureTime}',
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          const Icon(
                            Icons.trip_origin_rounded,
                            color: Color(0xFF3D7DFF),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ticket.pickupAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.primaryGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TicketListInformation extends StatelessWidget {
  const _TicketListInformation({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGreen, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF4A5650), fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class ConcertTicketScreen extends StatelessWidget {
  const ConcertTicketScreen({super.key, required this.ticket});

  final ConcertTicketData ticket;

  @override
  Widget build(BuildContext context) {
    final price = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    ).format(ticket.totalPrice);
    final concertDates = ticket.concertDates
        .map((date) => DateFormat('dd/MM/yyyy').format(date))
        .join(' & ');
    final returnDates = ticket.returnDates
        .map((date) => DateFormat('dd/MM/yyyy').format(date))
        .join(' & ');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3E9),
      appBar: AppBar(
        title: const Text('Vé xe của bạn'),
        centerTitle: true,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F7EA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF168A4F)),
                    SizedBox(width: 8),
                    Text(
                      'Tạo vé mô phỏng thành công',
                      style: TextStyle(
                        color: Color(0xFF12653D),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (ticket.hasLoginInformation) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7DA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.accentGold),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vui lòng đăng nhập bằng thông tin dưới đây để xuất trình vé khi lên xe.',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w900,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _LoginInformationRow(
                        label: 'Tài khoản',
                        value: ticket.customerPhone!,
                      ),
                      _LoginInformationRow(
                        label: 'Mật khẩu',
                        value: ticket.temporaryPassword!,
                      ),
                      if (ticket.username != null)
                        _LoginInformationRow(
                          label: 'Tên người dùng',
                          value: ticket.username!,
                        ),
                      if (ticket.customerEmail != null)
                        _LoginInformationRow(
                          label: 'Email',
                          value: ticket.customerEmail!,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Color(0x16000000), blurRadius: 22),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'BIGBANG <XX : COSMOS>',
                            style: TextStyle(
                              color: AppColors.accentGold,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mã vé: ${ticket.ticketCode}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          QrImageView(data: ticket.qrPayload, size: 190),
                          const Text(
                            'Đưa mã này cho tài xế để kiểm vé',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 18),
                          const Divider(),
                          if (ticket.concertDates.isNotEmpty)
                            _TicketInfoRow(
                              icon: Icons.calendar_month_rounded,
                              label: ticket.concertDates.length > 1
                                  ? 'Các ngày đi'
                                  : 'Ngày đi',
                              value: concertDates,
                            ),
                          if (ticket.returnDates.isNotEmpty)
                            _TicketInfoRow(
                              icon: Icons.event_repeat_rounded,
                              label: ticket.returnDates.length > 1
                                  ? 'Các ngày về'
                                  : 'Ngày về',
                              value: returnDates,
                            ),
                          _TicketInfoRow(
                            icon: Icons.access_time_rounded,
                            label:
                                ticket.departureTime ==
                                    'Sau khi concert kết thúc'
                                ? 'Thời gian đón'
                                : 'Giờ khởi hành',
                            value: ticket.departureTime,
                          ),
                          _TicketInfoRow(
                            icon: Icons.sync_alt_rounded,
                            label: 'Hành trình',
                            value: ticket.isRoundTrip
                                ? 'Khứ hồi (-10%)'
                                : ticket.returnDates.isNotEmpty
                                ? ticket.concertDates.isEmpty
                                      ? 'Vé thường (lượt về)'
                                      : 'Vé theo từng lượt'
                                : 'Một chiều',
                          ),
                          _TicketInfoRow(
                            icon: Icons.directions_car_filled_rounded,
                            label: 'Loại vé',
                            value: ticket.isCharter
                                ? '${ticket.vehicleTypeLabel} • Bao xe'
                                : ticket.vehicleTypeLabel,
                          ),
                          _TicketInfoRow(
                            icon: Icons.people_alt_rounded,
                            label: 'Số khách',
                            value: '${ticket.quantity}',
                          ),
                          _TicketInfoRow(
                            icon: Icons.payments_outlined,
                            label: 'Tổng tiền',
                            value: price,
                          ),
                          const Divider(),
                          _TicketRoutePoint(
                            color: const Color(0xFF3D7DFF),
                            title: 'Điểm đón',
                            address: ticket.pickupAddress,
                          ),
                          const SizedBox(height: 14),
                          _TicketRoutePoint(
                            color: const Color(0xFF16B26A),
                            title: 'Điểm đến',
                            address: ticket.destination,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!ticket.hasLoginInformation) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Về trang chủ'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginInformationRow extends StatelessWidget {
  const _LoginInformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF404944),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketInfoRow extends StatelessWidget {
  const _TicketInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF404944),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketRoutePoint extends StatelessWidget {
  const _TicketRoutePoint({
    required this.color,
    required this.title,
    required this.address,
  });

  final Color color;
  final String title;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(Icons.circle, size: 12, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF404944),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlidingTicketSwitch extends StatefulWidget {
  const _SlidingTicketSwitch({
    required this.lookupSelected,
    required this.onChanged,
  });

  final bool lookupSelected;
  final ValueChanged<bool> onChanged;

  @override
  State<_SlidingTicketSwitch> createState() => _SlidingTicketSwitchState();
}

class _SlidingTicketSwitchState extends State<_SlidingTicketSwitch> {
  double? _dragProgress;

  void _select(bool lookupSelected) {
    setState(() => _dragProgress = null);
    if (lookupSelected != widget.lookupSelected) {
      widget.onChanged(lookupSelected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 4.0;
        const thumbHeight = 50.0;
        final thumbWidth = (constraints.maxWidth - padding * 2) / 2;
        final travel = constraints.maxWidth - thumbWidth - padding * 2;
        final progress = _dragProgress ?? (widget.lookupSelected ? 1.0 : 0.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) =>
              _select(details.localPosition.dx >= constraints.maxWidth / 2),
          onHorizontalDragStart: (_) =>
              setState(() => _dragProgress = widget.lookupSelected ? 1.0 : 0.0),
          onHorizontalDragUpdate: (details) {
            if (travel <= 0) return;
            setState(() {
              _dragProgress = ((_dragProgress ?? 0) + details.delta.dx / travel)
                  .clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() > 250) {
              _select(velocity > 0);
            } else {
              _select((_dragProgress ?? 0) >= 0.5);
            }
          },
          onHorizontalDragCancel: () => setState(() => _dragProgress = null),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.72),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedPositioned(
                  duration: _dragProgress == null
                      ? const Duration(milliseconds: 280)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  left: padding + travel * progress,
                  top: padding,
                  width: thumbWidth,
                  height: thumbHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFE09A), AppColors.accentGold],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mua vé xe',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color.lerp(
                            AppColors.primaryGreen,
                            Colors.white,
                            progress,
                          ),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Tra vé xe',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color.lerp(
                            Colors.white,
                            AppColors.primaryGreen,
                            progress,
                          ),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
