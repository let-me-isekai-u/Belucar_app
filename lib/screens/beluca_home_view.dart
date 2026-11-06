import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/map_config.dart';
import '../features/carrier/carrier_screens.dart';
import '../models/booking_model.dart';
import '../models/deposit_model.dart';
import '../providers/home_provider.dart';
import '../ui/ui.dart';
import '../utils/currency_format.dart';
import 'activity_screen.dart';
import 'booking/booking1_screen.dart';
import 'chat_to_order/chat_screen.dart';
import 'profile_screen.dart';

/// Trang chủ khách: bản đồ toàn màn + bottom sheet (điểm đến, 3 dịch vụ, tiện ích, đi gần đây)
/// và thanh điều hướng đáy. Tab: 0 trang chủ, 1 đặt xe ghép, 2 hoạt động, 3 tài khoản.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const String _vietQrAccountName =
      'CONG%20TY%20CP%20CONG%20NGHE%20VA%20QUAN%20LY%20VAN%20TAI%20DONG%20DUONG';
  static const LatLng _defaultCenter = LatLng(21.0285, 105.8542);

  late final HomeProvider _homeProvider;
  final GlobalKey<ActivityScreenState> _activityScreenKey = GlobalKey<ActivityScreenState>();
  final MapController _mapController = MapController();

  Timer? _weatherTimer;
  LatLng? _myLocation;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _homeProvider = context.read<HomeProvider>();
    _homeProvider.initialize();
    _weatherTimer = Timer.periodic(const Duration(minutes: 10), (_) => _homeProvider.fetchWeather());
    // Chỉ lấy vị trí nếu đã được cấp quyền; không bật hộp xin quyền ngay khi mở app.
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate(requestPermission: false));
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    super.dispose();
  }

  void _handleRideBooked(int index) {
    _homeProvider.selectTab(index);
    if (index == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _activityScreenKey.currentState?.refreshOngoing();
      });
    }
  }

  Future<void> _locate({bool requestPermission = true}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (requestPermission) _snack('Hãy bật định vị (GPS) trên điện thoại.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (requestPermission) _snack('Chưa có quyền vị trí. Bạn vẫn đặt xe được bằng cách nhập địa chỉ.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _myLocation = here);
      _mapController.move(here, 15);
    } catch (_) {
      if (requestPermission) _snack('Không lấy được vị trí hiện tại.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _openCarrier(String category) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CarrierSearchScreen(category: category)));
  }

  void _openChat() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  void _openTickets() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyCarrierTicketsScreen()));
  }

  // ───────────────────────────── Nạp ví ─────────────────────────────

  Future<void> _showDepositAmountDialog() async {
    final controller = TextEditingController();
    var isSubmitting = false;
    final money = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    IconTile(Icons.account_balance_wallet_outlined, size: 44),
                    SizedBox(width: 12),
                    Expanded(child: Text('Nạp tiền vào ví', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Tạo yêu cầu nạp tiền, sau đó quét QR để chuyển khoản.',
                      style: TextStyle(color: Brand.inkMuted, height: 1.4)),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofocus: true,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      labelText: 'Số tiền muốn nạp',
                      suffixText: 'đ',
                      suffixStyle: TextStyle(color: Brand.navy, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Mức gợi ý'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [50000, 100000, 200000, 500000].map((amount) {
                      return ActionChip(
                        label: Text(money.format(amount)),
                        onPressed: isSubmitting ? null : () => controller.text = amount.toString(),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  PrimaryCta(
                    label: 'Tạo yêu cầu nạp tiền',
                    loading: isSubmitting,
                    onPressed: () async {
                      final amount = double.tryParse(controller.text.trim());
                      if (amount == null || amount < 50000) {
                        _snack('Số tiền nạp tối thiểu là 50.000đ', color: Brand.warning);
                        return;
                      }
                      setSheetState(() => isSubmitting = true);
                      final result = await _homeProvider.createDepositRequest(amount: amount);
                      if (sheetContext.mounted) setSheetState(() => isSubmitting = false);
                      if (!mounted) return;
                      if (!result.success || result.data == null) {
                        _snack(result.message ?? 'Không thể tạo yêu cầu nạp tiền.', color: Brand.danger);
                        return;
                      }
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      await _showDepositQrDialog(amount: amount, depositData: result.data!);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDepositQrDialog({required double amount, required DepositContentData depositData}) async {
    var isCancelling = false;
    final qrUrl = 'https://img.vietqr.io/image/MB-08102002-compact2.png'
        '?amount=${amount.toStringAsFixed(0)}'
        '&addInfo=${depositData.content}'
        '&accountName=$_vietQrAccountName';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: Brand.b50, borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: const BrandMark(size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('QR nạp ví', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text('Chuyển đúng số tiền và nội dung.', style: TextStyle(color: Brand.inkMuted)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Brand.line, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(qrUrl, height: 220, width: 220, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('CONG TY CP CONG NGHE VA QUAN LY VAN TAI DONG DUONG',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Brand.navy, fontWeight: FontWeight.w700, fontSize: 12, height: 1.35)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _DepositInfoTile(label: 'Số tiền', value: formatWalletAmount(amount))),
                      const SizedBox(width: 10),
                      Expanded(child: _DepositInfoTile(label: 'Nội dung', value: depositData.content, copyable: true)),
                    ]),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Brand.danger,
                          side: const BorderSide(color: Color(0xFFF3C2C2), width: 1.5),
                          minimumSize: const Size.fromHeight(50),
                        ),
                        onPressed: isCancelling
                            ? null
                            : () async {
                                String message;
                                Color color;
                                setDialogState(() => isCancelling = true);
                                if (depositData.depositId == null) {
                                  message = 'QR đã đóng, nhưng hệ thống chưa trả mã yêu cầu nên chưa xác nhận huỷ được.';
                                  color = Brand.warning;
                                } else {
                                  final result = await _homeProvider.cancelDepositRequest(depositId: depositData.depositId);
                                  message = result.success
                                      ? 'Huỷ yêu cầu nạp tiền thành công'
                                      : (result.message ?? 'Không thể huỷ yêu cầu nạp tiền');
                                  color = result.success ? Brand.success : Brand.warning;
                                }
                                if (dialogContext.mounted) Navigator.pop(dialogContext);
                                _snack(message, color: color);
                              },
                        child: isCancelling
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Huỷ yêu cầu'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ───────────────────────────── Khung ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: Brand.canvas,
            body: IndexedStack(
              index: homeProvider.selectedIndex,
              children: [
                _buildMapHome(homeProvider),
                Booking1Screen(onRideBooked: _handleRideBooked),
                ActivityScreen(key: _activityScreenKey),
                const ProfileScreen(),
              ],
            ),
            bottomNavigationBar: _BottomNav(
              selectedIndex: homeProvider.selectedIndex,
              onSelect: homeProvider.selectTab,
              onTickets: _openTickets,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapHome(HomeProvider homeProvider) {
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 13,
              backgroundColor: Brand.mapLand,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              trackAsiaTileLayer(),
              if (_myLocation != null)
                MarkerLayer(markers: [
                  Marker(point: _myLocation!, width: 36, height: 36, child: const MyLocationDot()),
                ]),
              trackAsiaAttribution(),
            ],
          ),
        ),
        // Thanh trên: chào + ví + chat hỗ trợ
        Positioned(
          left: 16,
          right: 16,
          top: MediaQuery.of(context).padding.top + 10,
          child: Row(children: [
            Expanded(child: _GreetingPill(homeProvider: homeProvider, onTap: () => homeProvider.selectTab(3))),
            const SizedBox(width: 8),
            _WalletPill(amount: homeProvider.wallet, onTap: _showDepositAmountDialog),
            const SizedBox(width: 8),
            MapRoundButton(icon: Icons.support_agent_rounded, tooltip: 'Chat hỗ trợ', onPressed: _openChat, size: 48),
          ]),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.34,
          maxChildSize: 0.9,
          snap: true,
          snapSizes: const [0.5],
          builder: (context, scrollController) {
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                right: 16,
                top: -60,
                child: MapRoundButton(
                  icon: _locating ? Icons.more_horiz_rounded : Icons.my_location_rounded,
                  tooltip: 'Về vị trí của tôi',
                  square: true,
                  onPressed: () => _locate(),
                ),
              ),
              Positioned.fill(
                child: SheetPanel(
                  padding: EdgeInsets.zero,
                  child: _HomeSheet(
                    controller: scrollController,
                    onBookRide: () => homeProvider.selectTab(1),
                    onCarrier: _openCarrier,
                    onDeposit: _showDepositAmountDialog,
                    onTickets: _openTickets,
                    onChat: _openChat,
                    onActivity: () => homeProvider.selectTab(2),
                    onRecentPlace: (place) {
                      context.read<BookingModel>().applySavedPlace(place, isPickup: false);
                      homeProvider.selectTab(1);
                    },
                  ),
                ),
              ),
            ]);
          },
        ),
      ],
    );
  }
}

class _GreetingPill extends StatelessWidget {
  const _GreetingPill({required this.homeProvider, required this.onTap});
  final HomeProvider homeProvider;
  final VoidCallback onTap;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final name = homeProvider.fullName.isEmpty ? 'Khách hàng' : homeProvider.fullName;
    final avatar = homeProvider.avatarUrl;
    final hasAvatar = avatar != null && avatar.isNotEmpty;
    return Container(
      height: 48,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), boxShadow: Brand.floatShadow, color: Colors.white),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 6, right: 14),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Brand.b100,
                backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
                child: hasAvatar
                    ? null
                    : Text(name.characters.first.toUpperCase(), style: const TextStyle(color: Brand.navy, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting, style: const TextStyle(fontSize: 11, color: Brand.inkMuted, fontWeight: FontWeight.w600, height: 1.2)),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.25)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.amount, required this.onTap});
  final double? amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Nạp tiền vào ví',
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(999), boxShadow: Brand.ctaShadow),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Brand.lane, size: 18),
                const SizedBox(width: 8),
                Text(
                  amount == null ? 'Ví' : formatWalletAmount(amount!).replaceAll(' đ', 'đ'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeSheet extends StatelessWidget {
  const _HomeSheet({
    required this.controller,
    required this.onBookRide,
    required this.onCarrier,
    required this.onDeposit,
    required this.onTickets,
    required this.onChat,
    required this.onActivity,
    required this.onRecentPlace,
  });

  final ScrollController controller;
  final VoidCallback onBookRide;
  final void Function(String category) onCarrier;
  final VoidCallback onDeposit;
  final VoidCallback onTickets;
  final VoidCallback onChat;
  final VoidCallback onActivity;
  final void Function(BookingSavedPlace place) onRecentPlace;

  @override
  Widget build(BuildContext context) {
    final recent = context.watch<BookingModel>().recentPlaces.take(4).toList();
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        const SheetHandle(),
        const SizedBox(height: 14),
        Material(
          color: Brand.canvas,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onBookRide,
            child: SizedBox(
              height: 56,
              child: Row(children: [
                const SizedBox(width: 16),
                const DropoffDot(size: 13),
                const SizedBox(width: 12),
                const Expanded(child: Text('Bạn muốn đi đâu?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_rounded, size: 15, color: Brand.navy),
                    SizedBox(width: 4),
                    Text('Hẹn giờ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Brand.navy)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _ServiceTile(
              title: 'Xe ghép',
              subtitle: 'Đón tận nhà',
              icon: Icons.directions_car_filled_rounded,
              primary: true,
              onTap: onBookRide,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ServiceTile(
              title: 'Limousine',
              subtitle: 'Ghế VIP',
              icon: Icons.airport_shuttle_rounded,
              onTap: () => onCarrier('LIMOUSINE'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ServiceTile(
              title: 'Xe khách',
              subtitle: 'Đường dài',
              icon: Icons.directions_bus_filled_rounded,
              onTap: () => onCarrier('COACH'),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _QuickAction(icon: Icons.add_card_rounded, label: 'Nạp ví', onTap: onDeposit)),
          Expanded(child: _QuickAction(icon: Icons.confirmation_number_outlined, label: 'Vé của tôi', onTap: onTickets)),
          Expanded(child: _QuickAction(icon: Icons.receipt_long_outlined, label: 'Chuyến đi', onTap: onActivity)),
          Expanded(child: _QuickAction(icon: Icons.support_agent_rounded, label: 'Hỗ trợ', onTap: onChat)),
        ]),
        const SizedBox(height: 18),
        if (recent.isNotEmpty) ...[
          const SectionHeader('Đi gần đây'),
          for (final place in recent)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onRecentPlace(place),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const IconTile(Icons.history_rounded, size: 40, bg: Brand.canvas),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(place.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Brand.inkMuted)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Brand.inkSubtle),
                ]),
              ),
            ),
        ] else
          const InfoBanner(
            'Chạm "Bạn muốn đi đâu?" để đặt xe ghép đón tận nơi, hoặc chọn Limousine / Xe khách để mua vé nhà xe.',
            tone: Tone.brand,
            icon: Icons.lightbulb_outline_rounded,
          ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.title, required this.subtitle, required this.icon, required this.onTap, this.primary = false});
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : Brand.navy;
    return Material(
      color: primary ? Brand.navy : Brand.b50,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 96,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Icon(icon, color: primary ? Brand.lane : Brand.navy, size: 28),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: primary ? Brand.b200 : Brand.b500, fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          IconTile(icon, size: 48, radius: 16, bg: Brand.canvas),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onSelect, required this.onTickets});
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onTickets;

  @override
  Widget build(BuildContext context) {
    Widget item(int? index, IconData icon, IconData active, String label, VoidCallback onTap) {
      final selected = index != null && index == selectedIndex;
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 62,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(color: selected ? Brand.b50 : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                child: Icon(selected ? active : icon, color: selected ? Brand.navy : Brand.inkMuted, size: 23),
              ),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Brand.navy : Brand.inkMuted,
                  )),
            ]),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Brand.lineSoft))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          item(0, Icons.home_outlined, Icons.home_rounded, 'Trang chủ', () => onSelect(0)),
          item(1, Icons.directions_car_outlined, Icons.directions_car_rounded, 'Đặt xe', () => onSelect(1)),
          item(null, Icons.confirmation_number_outlined, Icons.confirmation_number_rounded, 'Vé của tôi', onTickets),
          item(2, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Hoạt động', () => onSelect(2)),
          item(3, Icons.person_outline_rounded, Icons.person_rounded, 'Tài khoản', () => onSelect(3)),
        ]),
      ),
    );
  }
}

class _DepositInfoTile extends StatelessWidget {
  const _DepositInfoTile({required this.label, required this.value, this.copyable = false});
  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: copyable
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chép nội dung chuyển khoản')));
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: FieldLabel(label)),
            if (copyable) const Icon(Icons.copy_rounded, size: 14, color: Brand.inkMuted),
          ]),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Brand.navy, fontWeight: FontWeight.w800, fontSize: 15, height: 1.3)),
        ]),
      ),
    );
  }
}
