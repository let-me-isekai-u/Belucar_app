import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../models/location_models.dart';
import '../providers/home_provider.dart';
import '../ui/ui.dart';
import '../utils/currency_format.dart';
import 'activity_screen.dart';
import 'booking/booking1_screen.dart';
import 'booking/booking_address_map_picker_screen.dart';
import 'chat_to_order/chat_screen.dart';
import 'profile_screen.dart';

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
  final DraggableScrollableController _homeSheetController = DraggableScrollableController();
  final Completer<void> _mapReadySignal = Completer<void>();

  Timer? _weatherTimer;
  LatLng? _mapPinLocation;
  int _mapGestureRevision = 0;
  bool _locating = false;
  bool _mapReady = false;
  bool _openingMapPicker = false;
  bool _ticketsOpened = false;

  @override
  void initState() {
    super.initState();
    _homeProvider = context.read<HomeProvider>();
    _homeProvider.initialize();
    _weatherTimer = Timer.periodic(const Duration(minutes: 10), (_) => _homeProvider.fetchWeather());
  }

  @override
  void dispose() {
    _mapReady = false;
    // Release a pending readiness wait; mounted is checked before using the map.
    if (!_mapReadySignal.isCompleted) _mapReadySignal.complete();
    _homeSheetController.dispose();
    _weatherTimer?.cancel();
    _mapController.dispose();
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

  void _locationLog(String message) {
    if (kDebugMode) debugPrint('[HOME_LOCATION] $message');
  }

  Offset _currentLocationOffset({MapCamera? camera}) {
    final height = (camera ?? _mapController.camera).nonRotatedSize.height;
    final fraction = _homeSheetController.isAttached ? _homeSheetController.size : 0.5;
    if (!height.isFinite || height <= 0 || !fraction.isFinite ||
        fraction < 0 || fraction > 1) {
      throw StateError('Invalid Home map viewport');
    }
    final sheetTop = height * (1 - fraction);
    // Keep the pin above the sheet, below the greeting when space permits.
    final visibleBottom = (sheetTop - 18).clamp(0.0, height).toDouble();
    final visibleTop = MediaQuery.paddingOf(context).top + 10 + 48 + 46;
    final targetY = visibleBottom > visibleTop
        ? (visibleTop + visibleBottom) / 2
        : sheetTop / 2;
    return Offset(0, targetY - height / 2);
  }

  Future<void> _openMapPicker() async {
    if (!mounted || _openingMapPicker) return;
    final center = _mapPinLocation ??
        (_mapReady ? _mapController.camera.center : _defaultCenter);
    if (!isValidMapPoint(center)) return;
    _openingMapPicker = true;
    ++_mapGestureRevision; // Supersede a pending automatic startup locate.
    try {
      // Keep the last viewed coordinate when leaving by either back gesture
      // or the app bar. Home viewing does not need address confirmation.
      var point = center;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => BookingAddressMapPickerScreen(
            title: 'Bản đồ',
            showSelectionAction: false,
            onPointChanged: (nextPoint) {
              if (isValidMapPoint(nextPoint)) point = nextPoint;
            },
            initialPoint: RidePointPayload.coordinates(
              lat: center.latitude,
              lng: center.longitude,
            ),
          ),
        ),
      );
      if (!mounted || !isValidMapPoint(point)) return;
      setState(() => _mapPinLocation = point);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_mapReady || _homeProvider.selectedIndex != 0 ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      final moved = moveMapTo(_mapController, point, 16,
          offset: _currentLocationOffset());
      _locationLog('Camera move ${moved ? 'success' : 'failure'}: map selection');
    } catch (error, stackTrace) {
      _locationLog('Camera move failure: map picker ${error.runtimeType}');
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      _locationSnack('Không mở được vị trí trên bản đồ. Vui lòng thử lại.');
    } finally {
      _openingMapPicker = false;
    }
  }

  void _onHomeMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (!mounted || !hasGesture || !isValidMapPoint(camera.center) ||
        !isValidMapZoom(camera.zoom) || !camera.rotation.isFinite) return;
    final size = camera.nonRotatedSize;
    if (!size.width.isFinite || !size.height.isFinite ||
        size.width <= 0 || size.height <= 0) return;

    // The pin selects the location in the visible viewport as the user pans
    // or zooms. A controller move must not overwrite the GPS locate result.
    final anchor = size.center(Offset.zero) + _currentLocationOffset(camera: camera);
    if (!anchor.dx.isFinite || !anchor.dy.isFinite) return;
    final point = camera.screenOffsetToLatLng(anchor);
    if (!isValidMapPoint(point)) return;
    ++_mapGestureRevision;
    if (point != _mapPinLocation) setState(() => _mapPinLocation = point);
  }

  Future<void> _locate({bool requestPermission = true}) async {
    if (!mounted || _locating) return;
    setState(() => _locating = true);
    final gestureRevision = _mapGestureRevision;
    var stage = 'Permission';
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        _locationLog('GPS result: service disabled');
        if (requestPermission) _locationSnack('Hãy bật định vị (GPS) trên điện thoại.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (!mounted) return;
      _locationLog('Permission: ${permission.name}');
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        _locationLog('Permission: ${permission.name}');
      }
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        if (requestPermission) {
          _locationSnack(permission == LocationPermission.deniedForever
              ? 'Quyền vị trí đã bị chặn. Hãy bật quyền trong Cài đặt của điện thoại.'
              : 'Chưa có quyền vị trí. Bạn vẫn đặt xe được bằng cách nhập địa chỉ.');
        }
        return;
      }
      // Same fresh GPS request/settings as the booking map picker.
      stage = 'GPS result';
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      if (!mounted) return;
      _locationLog('GPS result: received');
      final valid = isValidMapCoordinate(pos.latitude, pos.longitude);
      _locationLog('Coordinate ${valid ? 'valid' : 'invalid'}');
      if (!valid) {
        if (requestPermission) _locationSnack('Vị trí nhận được không hợp lệ. Vui lòng thử lại.');
        return;
      }
      stage = 'Map ready';
      if (!_mapReady) {
        _locationLog('Map ready: waiting');
        await _mapReadySignal.future.timeout(const Duration(seconds: 4));
      }
      if (!mounted) return;
      // Use the current sheet size/layout, including changes made during GPS.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _locationLog('Map ready: $_mapReady');
      // IndexedStack keeps Home mounted while another tab is active.
      if (!_mapReady || _homeProvider.selectedIndex != 0 ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        _locationLog('Camera move failure: Home inactive or map unavailable');
        return;
      }
      if (!requestPermission && gestureRevision != _mapGestureRevision) {
        _locationLog('Camera move skipped: startup superseded by map gesture');
        return;
      }
      stage = 'Camera move';
      final here = LatLng(pos.latitude, pos.longitude);
      final moved = moveMapTo(_mapController, here, 16, offset: _currentLocationOffset());
      _locationLog('Camera move ${moved ? 'success' : 'failure'}');
      if (!moved) {
        if (requestPermission) _locationSnack('Bản đồ chưa sẵn sàng, vui lòng thử lại.');
        return;
      }
      setState(() => _mapPinLocation = here);
    } catch (error, stackTrace) {
      // Log the type and stack only: platform error text can include coordinates.
      _locationLog('$stage failure: ${error.runtimeType}');
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace, label: '[HOME_LOCATION] Diagnostic');
      if (requestPermission) {
        _locationSnack(stage == 'Map ready' || stage == 'Camera move'
            ? 'Bản đồ chưa sẵn sàng, vui lòng thử lại.'
            : 'Không lấy được vị trí hiện tại. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _locationSnack(String message) {
    if (!mounted || _homeProvider.selectedIndex != 0 ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _snack(message);
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _openCarrier(String category) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CarrierSearchScreen(
      category: category,
      onTickets: () {
        Navigator.pop(context);
        _openTickets();
      },
    )));
  }

  void _openChat() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  void _openTickets() {
    _ticketsOpened = true;
    _homeProvider.selectTab(4);
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
              child: SingleChildScrollView(
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
                        child: Image.network(qrUrl, height: 220, width: 220, fit: BoxFit.contain),
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
            extendBody: true,
            body: IndexedStack(
              index: homeProvider.selectedIndex,
              children: [
                _buildMapHome(homeProvider),
                Booking1Screen(onRideBooked: _handleRideBooked, onTickets: _openTickets),
                ActivityScreen(key: _activityScreenKey),
                const ProfileScreen(),
                if (_ticketsOpened)
                  MyCarrierTicketsScreen(embedded: true, isActive: homeProvider.selectedIndex == 4)
                else
                  const SizedBox.shrink(),
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
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 13,
                minZoom: mapMinZoom,
                maxZoom: mapMaxZoom,
                cameraConstraint: const FiniteMapCameraConstraint(),
                onMapReady: () {
                  _mapReady = true;
                  if (!_mapReadySignal.isCompleted) _mapReadySignal.complete();
                  _locationLog('Map ready: true');
                  // Keep startup silent and wait until the map is attached.
                  scheduleMicrotask(() {
                    if (mounted && _mapReady) _locate(requestPermission: false);
                  });
                },
                onPositionChanged: _onHomeMapPositionChanged,
                backgroundColor: Brand.mapLand,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                trackAsiaTileLayer(),
                if (_mapPinLocation != null && isValidMapPoint(_mapPinLocation!))
                  MarkerLayer(markers: [
                    // Pan/zoom selects a new coordinate; locate restores GPS.
                    // Keep this geographic marker validated before rendering.
                    Marker(
                      point: _mapPinLocation!,
                      width: 46,
                      height: 46,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 46,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  ]),
                trackAsiaAttribution(),
              ],
            ),
          ),
          // Thanh trên: chào + ví (đã bỏ nút chat; chat nằm ở tiện ích trong sheet)
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.of(context).padding.top + 10,
            child: Row(children: [
              Expanded(child: _GreetingPill(homeProvider: homeProvider, onTap: () => homeProvider.selectTab(3))),
              const SizedBox(width: 10),
              _WalletPill(amount: homeProvider.wallet, onTap: _showDepositAmountDialog),
            ]),
          ),
          DraggableScrollableSheet(
            controller: _homeSheetController,
            initialChildSize: 0.5,
            minChildSize: 0.34,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.5],
            builder: (context, scrollController) {
              return Stack(clipBehavior: Clip.none, children: [
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
          // A sibling of the sheet keeps the button inside the hit-test bounds.
          AnimatedBuilder(
            animation: _homeSheetController,
            builder: (context, child) {
              final fraction = _homeSheetController.isAttached ? _homeSheetController.size : 0.5;
              return Positioned(
                left: 16,
                right: 16,
                top: constraints.maxHeight * (1 - fraction) - 60,
                child: child!,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MapRoundButton(
                  icon: Icons.fullscreen_rounded,
                  tooltip: 'Mở rộng bản đồ',
                  square: true,
                  onPressed: _openMapPicker,
                ),
                MapRoundButton(
                  icon: _locating ? Icons.more_horiz_rounded : Icons.my_location_rounded,
                  tooltip: 'Về vị trí của tôi',
                  square: true,
                  onPressed: _locating ? null : () => _locate(),
                ),
              ],
            ),
          ),
        ],
      );
    });
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
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Brand.lane, size: 18),
                const SizedBox(width: 8),
                Text(
                  amount == null ? 'Ví' : formatWalletAmount(amount!).replaceAll(' đ', 'đ'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(width: 8),
                // Gợi ý: chạm vào ví để nạp tiền.
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: Brand.lane, shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded, size: 18, color: Brand.navy),
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
      padding: EdgeInsets.fromLTRB(16, 10, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        const SheetHandle(),
        const SizedBox(height: 14),
        // Ô chọn điểm đến
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
        // 3 dịch vụ chính
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
        const SizedBox(height: 16),
        // Tiện ích: gộp trong một thẻ riêng cho gọn mắt
        Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Brand.line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(children: [
              Expanded(child: _QuickAction(icon: Icons.add_card_rounded, label: 'Nạp ví', onTap: onDeposit)),
              Expanded(child: _QuickAction(icon: Icons.confirmation_number_outlined, label: 'Vé của tôi', onTap: onTickets)),
              Expanded(child: _QuickAction(icon: Icons.receipt_long_outlined, label: 'Chuyến đi', onTap: onActivity)),
              // Đây là nhắn tin (chat), khác với "Liên hệ hỗ trợ" trong Tài khoản.
              Expanded(child: _QuickAction(icon: Icons.chat_bubble_outline_rounded, label: 'Nhắn tin', onTap: onChat)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
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
        ],
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
          IconTile(icon, size: 48, radius: 16, bg: Brand.b50),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 58,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(color: selected ? Brand.navy : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                child: Icon(selected ? active : icon, color: selected ? Colors.white : Brand.inkMuted, size: 23),
              ),
              const SizedBox(height: 3),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: const [
                BoxShadow(color: Color(0x24041565), blurRadius: 28, offset: Offset(0, 10)),
                BoxShadow(color: Color(0x0A041565), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Material(
              color: Brand.b50.withValues(alpha: 0.97),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(36),
                side: const BorderSide(color: Brand.b100),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(children: [
                  item(0, Icons.home_outlined, Icons.home_rounded, 'Trang chủ', () => onSelect(0)),
                  item(1, Icons.directions_car_outlined, Icons.directions_car_rounded, 'Đặt xe', () => onSelect(1)),
                  item(4, Icons.confirmation_number_outlined, Icons.confirmation_number_rounded, 'Vé của tôi', onTickets),
                  item(2, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Hoạt động', () => onSelect(2)),
                  item(3, Icons.person_outline_rounded, Icons.person_rounded, 'Tài khoản', () => onSelect(3)),
                ]),
              ),
            ),
          ),
        ),
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