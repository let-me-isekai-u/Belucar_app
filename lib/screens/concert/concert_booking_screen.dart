import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_theme.dart';
import '../../models/concert_models.dart';
import '../../providers/account_provider.dart';
import '../../providers/concert_provider.dart';
import '../booking/booking_ui.dart';
import 'concert_library_screen.dart' show ConcertLibraryScreen;
import 'concert_payment_screen.dart';

class ConcertBookingScreen extends StatefulWidget {
  const ConcertBookingScreen({super.key, this.isGuest = false});

  final bool isGuest;

  @override
  State<ConcertBookingScreen> createState() => _ConcertBookingScreenState();
}

class _ConcertBookingScreenState extends State<ConcertBookingScreen> {
  static final _concertDates = <DateTime>[
    DateTime(2026, 10, 24),
    DateTime(2026, 10, 25),
  ];
  static const _fallbackDepartureTimes = <String>[
    '14:00',
    '15:30',
    '17:00',
    '18:30',
  ];

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final Set<DateTime> _selectedDates = <DateTime>{_concertDates.first};
  final Set<DateTime> _selectedReturnDates = <DateTime>{};
  String? _selectedTime;
  int _quantity = 1;
  bool _isRoundTrip = false;
  bool _isReturnOnly = false;
  bool _wantsReturnTrip = false;
  bool _isCharter = false;
  bool _isCreatingTicket = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prefillAccountContact();
      });
    }
  }

  bool get _hasMatchingRoundTripDates =>
      !_isReturnOnly &&
      _wantsReturnTrip &&
      _selectedReturnDates.isNotEmpty &&
      _selectedDates.length == _selectedReturnDates.length &&
      _selectedDates.every(_selectedReturnDates.contains);

  List<DateTime> get _effectiveOutboundDates {
    if (_isReturnOnly) return const [];
    return _selectedDates.toList()..sort();
  }

  int get _selectedServiceCount {
    final provider = context.read<ConcertProvider>();
    return provider.services.where(_isServiceSelected).length;
  }

  int get _maxQuantity {
    final count = _selectedServiceCount.clamp(1, 20);
    return (100 ~/ count).clamp(1, 50);
  }

  int get _totalPrice => context.read<ConcertProvider>().estimatedTotal.round();

  bool get _canCharterSelectedVehicle {
    final seatCount = context
        .read<ConcertProvider>()
        .selectedVehicleType
        ?.seatCount;
    return seatCount == 4 || seatCount == 7;
  }

  List<String> get _departureTimes {
    final provider = context.read<ConcertProvider>();
    final selected = provider.services.where(_isServiceSelected).toList();
    final source = selected.isEmpty ? provider.services : selected;
    final labels = source
        .map(_apiServiceTimeLabel)
        .whereType<String>()
        .toSet()
        .toList();
    return labels.isEmpty ? _fallbackDepartureTimes : labels;
  }

  bool get _usesFallbackDepartureTimes {
    final provider = context.read<ConcertProvider>();
    final selected = provider.services.where(_isServiceSelected).toList();
    final source = selected.isEmpty ? provider.services : selected;
    return source.every((service) => _apiServiceTimeLabel(service) == null);
  }

  String? _apiServiceTimeLabel(ConcertService service) {
    if (service.departureAt != null) {
      return DateFormat('HH:mm').format(service.departureAt!);
    }
    final note = service.meetingTimeNote?.trim();
    return note == null || note.isEmpty ? null : note;
  }

  bool _isServiceSelected(ConcertService service) {
    final date = service.serviceDate;
    if (date == null) return false;
    if (service.direction == 'OUTBOUND') {
      return !_isReturnOnly &&
          _effectiveOutboundDates.any(
            (item) => DateUtils.isSameDay(item, date),
          );
    }
    if (service.direction == 'RETURN') {
      final dates = _isReturnOnly
          ? _selectedReturnDates
          : _wantsReturnTrip
          ? _selectedReturnDates
          : const <DateTime>{};
      return dates.any((item) => DateUtils.isSameDay(item, date));
    }
    return false;
  }

  void _syncApiCart() {
    final provider = context.read<ConcertProvider>();
    final seatCount = provider.selectedVehicleType?.seatCount;
    final requestedQuantity = _isCharter && (seatCount == 4 || seatCount == 7)
        ? seatCount!
        : _quantity;
    final quantity = requestedQuantity.clamp(1, _maxQuantity);
    if (_quantity != quantity) _quantity = quantity;
    provider.setCharter(_isCharter && (seatCount == 4 || seatCount == 7));
    provider.setServiceQuantities({
      for (final service in provider.services)
        service.id: _isServiceSelected(service) ? quantity : 0,
    });
  }

  void _syncJourneyType() {
    if (_isReturnOnly) return;
    final shouldBeRoundTrip = _hasMatchingRoundTripDates;
    setState(() {
      _isRoundTrip = shouldBeRoundTrip;
    });
    _syncApiCart();
  }

  void _selectOneWay() {
    setState(() {
      _isReturnOnly = false;
      _wantsReturnTrip = false;
      _selectedReturnDates.clear();
      _isRoundTrip = false;
    });
    _syncApiCart();
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
      _wantsReturnTrip = false;
      _selectedReturnDates
        ..clear()
        ..add(firstSelectedDate);
    });
    _syncApiCart();
  }

  Future<void> _openExistingTicket() async {
    if (widget.isGuest) {
      _showMessage('Vui lòng đăng nhập để xem vé đã mua.');
      return;
    }
    final provider = context.read<ConcertProvider>();
    await provider.loadLibrary();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const ConcertLibraryScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _prefillAccountContact() async {
    if (widget.isGuest || !mounted) return;
    final accountProvider = context.read<AccountProvider>();
    var profile = accountProvider.profile;
    if (profile == null) {
      final result = await accountProvider.loadProfile(notify: false);
      profile = result.data;
    }
    if (!mounted || profile == null) return;
    if (_fullNameController.text.trim().isEmpty) {
      _fullNameController.text = profile.fullName.trim();
    }
    if (_phoneController.text.trim().isEmpty) {
      _phoneController.text = profile.phone.trim();
    }
    if (_emailController.text.trim().isEmpty) {
      _emailController.text = profile.email.trim();
    }
  }

  Future<void> _createOrder() async {
    final provider = context.read<ConcertProvider>();
    if (!widget.isGuest) await _prefillAccountContact();
    if (!mounted) return;
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final emailIsValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (kDebugMode) {
      debugPrint(
        '[ConcertOrder] create tapped: mode=${widget.isGuest ? 'guest' : 'customer'}, '
        'fullNameProvided=${fullName.isNotEmpty}, phoneProvided=${phone.isNotEmpty}, '
        'emailProvided=${email.isNotEmpty}, emailValid=$emailIsValid, '
        'items=${provider.cartItems.length}, quantity=${provider.totalQuantity}',
      );
    }
    if (widget.isGuest) {
      final validationError = provider.validateContact(fullName, phone, email);
      if (validationError != null) {
        _showMessage(validationError);
        return;
      }
    }
    if (provider.selectedStop == null || provider.selectedVehicleType == null) {
      _showMessage('Vui lòng chọn đầy đủ tuyến, điểm đón/trả và loại xe.');
      return;
    }
    if ((_wantsReturnTrip || _isReturnOnly) && _selectedReturnDates.isEmpty) {
      _showMessage('Vui lòng chọn ít nhất một ngày về.');
      return;
    }
    if (!_isReturnOnly &&
        _usesFallbackDepartureTimes &&
        _selectedTime == null) {
      _showMessage('Vui lòng chọn một khung giờ khởi hành.');
      return;
    }

    setState(() => _isCreatingTicket = true);
    try {
      _syncApiCart();
      final quote = await provider.quoteSelection();
      if (!mounted) return;
      if (quote == null) {
        _showMessage(provider.errorMessage ?? 'Không thể báo giá vé.');
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFFFFF8E7),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Xác nhận đặt vé',
            style: TextStyle(
              color: Color(0xFF202020),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            '${quote.totalQuantity} vé\nTổng thanh toán: ${_formatCurrency(quote.totalAmount)}',
            style: const TextStyle(
              color: Color(0xFF303030),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B2E2E),
                backgroundColor: const Color(0xFFFFE3DE),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF8B2E2E)),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: const Color(0xFF202020),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const Text('Tạo đơn'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final order = await provider.createOrder(
        contactFullName: fullName,
        contactPhone: phone,
        contactEmail: email,
      );
      if (!mounted) return;
      if (order == null) {
        _showMessage(provider.errorMessage ?? 'Không thể tạo đơn vé.');
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: ConcertPaymentScreen(orderCode: order.orderCode),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingTicket = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatCurrency(num value) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  ).format(value);

  String get _fareSubtitle {
    final provider = context.read<ConcertProvider>();
    final prices = provider.services
        .where(_isServiceSelected)
        .map(provider.fareFor)
        .whereType<ConcertFare>()
        .map((fare) => fare.price)
        .toSet();
    if (prices.length == 1) {
      return '${_formatCurrency(prices.first)} / khách / lượt';
    }
    return prices.isEmpty
        ? 'Tổ hợp này chưa được mở bán'
        : 'Giá từng lượt được lấy từ hệ thống';
  }

  @override
  Widget build(BuildContext context) {
    final concert = context.watch<ConcertProvider>();
    if (concert.catalog == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            widget.isGuest ? 'Mua vé concert - Khách mới' : 'Đặt xe đi concert',
          ),
          centerTitle: true,
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.accentGold,
        ),
        body: Center(
          child: concert.loadingCatalog
              ? const CircularProgressIndicator(color: AppColors.primaryGreen)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        concert.errorMessage ?? 'Không tải được dữ liệu vé.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: concert.loadCatalog,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isGuest ? 'Mua vé concert - Khách mới' : 'Đặt xe đi concert',
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.accentGold,
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
                      child: SingleChildScrollView(
                        key: const ValueKey('ticket-buy-page'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.isGuest) ...[
                              _buildContactInformationCard(),
                              const SizedBox(height: 20),
                            ],
                            if (!widget.isGuest) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _openExistingTicket,
                                  icon: const Icon(
                                    Icons.confirmation_num_rounded,
                                  ),
                                  label: const Text('Xem vé đã có'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    foregroundColor: AppColors.accentGold,
                                    minimumSize: const Size(
                                      double.infinity,
                                      52,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
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
                              title: _isReturnOnly ? 'Điểm trả' : 'Điểm đón',
                              subtitle: _isReturnOnly
                                  ? 'Chọn vị trí xe sẽ trả bạn'
                                  : 'Chọn vị trí xe sẽ đón bạn',
                            ),
                            const SizedBox(height: 12),
                            _buildRouteCard(concert),
                            const SizedBox(height: 24),
                            _buildSectionTitle(
                              icon: Icons.sync_alt_rounded,
                              title: 'Loại hành trình',
                              subtitle: _isReturnOnly
                                  ? 'Chỉ mua lượt về sau concert'
                                  : _isRoundTrip
                                  ? 'Ngày đi và về trùng nhau'
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
                              subtitle: 'Chọn ghế lẻ hoặc loại xe phù hợp',
                            ),
                            const SizedBox(height: 12),
                            _buildVehicleTypePicker(concert),
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
                                subtitle: _usesFallbackDepartureTimes
                                    ? 'API chưa cấu hình giờ • Bạn tự chọn khung giờ'
                                    : 'Khung giờ lấy từ hệ thống',
                              ),
                              const SizedBox(height: 12),
                              _buildTimePicker(),
                            ],
                            const SizedBox(height: 24),
                            _buildSectionTitle(
                              icon: Icons.airline_seat_recline_normal_rounded,
                              title: 'Số lượng vé',
                              subtitle: _fareSubtitle,
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
                    child: KeyedSubtree(
                      key: const ValueKey('concert-checkout-bar'),
                      child: _buildCheckoutBar(),
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

  Widget _buildContactInformationCard() {
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
        labelStyle: const TextStyle(
          color: Color(0xFF303030),
          fontWeight: FontWeight.w700,
        ),
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
            'Thông tin liên hệ',
            style: TextStyle(
              color: Color(0xFF202020),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.isGuest
                ? 'Nhập đủ thông tin để nhận và khôi phục vé.'
                : 'Thông tin được lấy từ profile tài khoản.',
            style: const TextStyle(color: Color(0xFF404040), height: 1.35),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _fullNameController,
            readOnly: !widget.isGuest,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            style: const TextStyle(color: Colors.black87),
            decoration: decoration(
              label: 'Họ và tên liên hệ',
              hint: widget.isGuest
                  ? 'Nhập họ và tên'
                  : 'Lấy tự động từ tài khoản',
              icon: Icons.person_outline_rounded,
            ).copyWith(counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            readOnly: !widget.isGuest,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: Colors.black87),
            decoration: decoration(
              label: 'Email',
              hint: widget.isGuest
                  ? 'Nhập email của bạn'
                  : 'Lấy tự động từ tài khoản',
              icon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            readOnly: !widget.isGuest,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.black87),
            decoration: decoration(
              label: widget.isGuest
                  ? 'Số điện thoại'
                  : 'Số điện thoại tài khoản',
              hint: widget.isGuest
                  ? 'Ví dụ: 0912345678'
                  : 'Lấy tự động từ tài khoản',
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

  Widget _buildRouteCard(ConcertProvider provider) {
    final routes = provider.catalog!.routes
        .where((route) => route.selectableStops.isNotEmpty)
        .toList();
    final stops = provider.selectedRoute?.selectableStops ?? [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            initialValue: provider.routeId,
            isExpanded: true,
            dropdownColor: AppColors.primaryGreen,
            iconEnabledColor: AppColors.accentGold,
            decoration: InputDecoration(
              labelText: 'Tuyến xe',
              prefixIcon: const Icon(
                Icons.route_rounded,
                color: Color(0xFF3D7DFF),
              ),
              filled: true,
              fillColor: const Color(0xFFF6F8F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              for (final route in routes)
                DropdownMenuItem(
                  value: route.id,
                  child: Text(
                    route.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              provider.selectRoute(value);
              _syncApiCart();
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: ValueKey(provider.routeId),
            initialValue: provider.stopId,
            isExpanded: true,
            dropdownColor: AppColors.primaryGreen,
            iconEnabledColor: AppColors.accentGold,
            decoration: InputDecoration(
              labelText: _isReturnOnly ? 'Điểm trả' : 'Điểm đón',
              prefixIcon: const Icon(
                Icons.trip_origin_rounded,
                color: Color(0xFF3D7DFF),
              ),
              filled: true,
              fillColor: const Color(0xFFF6F8F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              for (final stop in stops)
                DropdownMenuItem(
                  value: stop.id,
                  child: Text(
                    stop.address == null
                        ? stop.name
                        : '${stop.name} • ${stop.address}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              provider.selectStop(value);
              _syncApiCart();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypePicker(ConcertProvider provider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accentGold),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: provider.vehicleTypeId,
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
              items: [
                for (final vehicle in provider.catalog!.vehicleTypes)
                  DropdownMenuItem(
                    value: vehicle.id,
                    child: Text(
                      '${vehicle.name.replaceAll('chỗ', 'ghế').replaceAll('Chỗ', 'Ghế')} • ${vehicle.seatCount} ghế',
                      style: const TextStyle(color: AppColors.accentGold),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                provider.selectVehicleType(value);
                setState(() {
                  _isCharter = false;
                  if (_quantity > _maxQuantity) _quantity = _maxQuantity;
                });
                _syncApiCart();
              },
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: !_canCharterSelectedVehicle
              ? const SizedBox.shrink()
              : CheckboxListTile(
                  value: _isCharter,
                  onChanged: (value) {
                    setState(() {
                      _isCharter = value ?? false;
                      if (_isCharter) {
                        _quantity = provider.selectedVehicleType!.seatCount;
                      }
                    });
                    _syncApiCart();
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: Colors.black,
                  checkColor: AppColors.accentGold,
                  side: const BorderSide(color: Colors.black, width: 1.8),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Bao xe',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
      ],
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
                  _syncApiCart();
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
                        color: selected ? AppColors.accentGold : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM').format(date),
                      style: TextStyle(
                        color: selected ? AppColors.accentGold : Colors.black,
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
              }
            });
            _syncApiCart();
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
                          color: Colors.black,
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
                    : Colors.black,
              ),
              label: Text(DateFormat('dd/MM').format(date)),
              labelStyle: TextStyle(
                color: !enabled
                    ? Colors.black26
                    : selected
                    ? AppColors.accentGold
                    : Colors.black,
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
    final usesFallback = _usesFallbackDepartureTimes;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _departureTimes.map((time) {
        final selected = usesFallback ? time == _selectedTime : true;
        return ChoiceChip(
          selected: selected,
          onSelected: usesFallback
              ? (_) => setState(() => _selectedTime = time)
              : null,
          showCheckmark: false,
          avatar: Icon(
            Icons.directions_bus_filled_rounded,
            size: 18,
            color: selected ? AppColors.accentGold : Colors.black,
          ),
          label: Text(time),
          labelStyle: TextStyle(
            color: selected ? AppColors.accentGold : Colors.black,
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
                  color: selected ? AppColors.accentGold : Colors.black,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: selected ? AppColors.accentGold : Colors.black,
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
                    color: selected ? AppColors.accentGold : Colors.black54,
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
          const Expanded(
            child: Text(
              'Hành khách',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          IconButton.filledTonal(
            onPressed: _isCharter || _quantity <= 1
                ? null
                : () {
                    setState(() => _quantity--);
                    _syncApiCart();
                  },
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '$_quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.filled(
            onPressed: _isCharter || _quantity >= _maxQuantity
                ? null
                : () {
                    setState(() => _quantity++);
                    _syncApiCart();
                  },
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

  Widget _buildCheckoutBar() {
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
                    color: Colors.black,
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
              onPressed: _isCreatingTicket ? null : _createOrder,
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
                  : Text(widget.isGuest ? 'Tiếp tục thanh toán' : 'Đặt vé'),
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
        foregroundColor: AppColors.accentGold,
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
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Chọn một vé để xem chi tiết và mã QR kiểm vé.',
                            style: TextStyle(color: Colors.black, height: 1.35),
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
                                    color: Colors.black,
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
                                color: Colors.black,
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
        Icon(icon, color: Colors.black, size: 19),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black, fontSize: 14),
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
        foregroundColor: AppColors.accentGold,
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
                        color: Colors.black,
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
                  child: const Text(
                    'Thông tin đăng nhập của tài khoản đã được gửi về email mà bạn đã đăng ký, vui lòng đăng nhập để kiểm tra vé lần sau.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      height: 1.4,
                    ),
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
                            style: const TextStyle(color: AppColors.accentGold),
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
              color: Colors.black,
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
                  color: Colors.black,
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
