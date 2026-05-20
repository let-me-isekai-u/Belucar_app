import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/deposit_model.dart';
import '../providers/home_provider.dart';
import '../widgets/brand_logo_badge.dart';
import 'activity_screen.dart';
import 'booking/booking1_screen.dart';
import 'chat_to_order/chat_screen.dart';
import 'profile_screen.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeProvider _homeProvider;
  final GlobalKey<ActivityScreenState> _activityScreenKey =
      GlobalKey<ActivityScreenState>();

  Timer? _weatherTimer;

  @override
  void initState() {
    super.initState();
    _homeProvider = context.read<HomeProvider>();

    _homeProvider.initialize();

    _weatherTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _homeProvider.fetchWeather(),
    );
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

  Color _softTint(Color color, [double amount = 0.12]) {
    return Color.alphaBlend(color.withValues(alpha: amount), Colors.white);
  }

  Future<void> _showDepositAmountDialog() async {
    final controller = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGreen,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Nạp tiền vào ví',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tạo yêu cầu nạp tiền trước, sau đó quét QR để thanh toán.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Số tiền muốn nạp',
                        suffixText: 'đ',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        labelStyle: const TextStyle(color: Colors.white70),
                        suffixStyle: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.secondary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Mức gợi ý',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [50000, 100000, 200000, 500000].map((amount) {
                        return ActionChip(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          label: Text(
                            NumberFormat.currency(
                              locale: 'vi_VN',
                              symbol: 'đ',
                              decimalDigits: 0,
                            ).format(amount),
                            style: const TextStyle(color: Colors.white),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () => controller.text = amount.toString(),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(dialogContext),
                            child: const Text('Đóng'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final amount = double.tryParse(
                                      controller.text.trim(),
                                    );
                                    if (amount == null || amount < 50000) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Số tiền nạp tối thiểu là 50.000đ',
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() => isSubmitting = true);
                                    final result = await _homeProvider
                                        .createDepositRequest(amount: amount);
                                    if (dialogContext.mounted) {
                                      setDialogState(
                                        () => isSubmitting = false,
                                      );
                                    }

                                    if (!mounted) return;

                                    if (!result.success ||
                                        result.data == null) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            result.message ??
                                                'Không thể tạo yêu cầu nạp tiền.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }

                                    await _showDepositQrDialog(
                                      amount: amount,
                                      depositData: result.data!,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black87,
                                    ),
                                  )
                                : const Text('Tạo yêu cầu nạp tiền'),
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
      },
    );
  }

  Future<void> _showDepositQrDialog({
    required double amount,
    required DepositContentData depositData,
  }) async {
    var isCancelling = false;
    final qrUrl =
        'https://img.vietqr.io/image/MB-246878888-compact2.png'
        '?amount=${amount.toStringAsFixed(0)}'
        '&addInfo=${depositData.content}'
        '&accountName=CTY%20CP%20CN%20VA%20DV%20TT%20THE%20BELUGAS';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandLogoBadge(
                      assetPath: 'lib/assets/icons/dong_duong_logo.png',
                      size: 62,
                      borderRadius: 20,
                      padding: 4,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Quét mã để thanh toán',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sau khi bấm huỷ, ứng dụng sẽ đóng QR và gửi yêu cầu huỷ giao dịch nạp tiền.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.64),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.network(
                        qrUrl,
                        height: 240,
                        width: 240,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F2E8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Số tiền',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.58),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            NumberFormat.currency(
                              locale: 'vi_VN',
                              symbol: 'đ',
                              decimalDigits: 0,
                            ).format(amount),
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nội dung chuyển khoản',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.58),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            depositData.content,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isCancelling
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                String message;
                                Color color;

                                setDialogState(() => isCancelling = true);

                                if (depositData.depositId == null) {
                                  message =
                                      'QR đã đóng, nhưng backend chưa trả depositId nên chưa thể xác nhận huỷ giao dịch.';
                                  color = Colors.orange;
                                } else {
                                  final result = await _homeProvider
                                      .cancelDepositRequest(
                                        depositId: depositData.depositId,
                                      );
                                  message = result.success
                                      ? 'Huỷ yêu cầu nạp tiền thành công'
                                      : (result.message ??
                                            'Không thể huỷ yêu cầu nạp tiền');
                                  color = result.success
                                      ? Colors.green
                                      : Colors.orange;
                                }

                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    backgroundColor: color,
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: isCancelling
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Huỷ'),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
        return Scaffold(
          extendBody: true,
          appBar: _buildAppBar(homeProvider),
          body: _buildBody(homeProvider),
          bottomNavigationBar: _buildFloatingBottomBar(homeProvider),
          backgroundColor: const Color(0xFFF4F5EF),
        );
      },
    );
  }

  Widget _buildFloatingBottomBar(HomeProvider homeProvider) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryGreen, AppColors.surfaceGreen],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            _buildBottomBarItem(
              index: 0,
              selectedIndex: homeProvider.selectedIndex,
              inactiveIcon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              onTap: () => homeProvider.selectTab(0),
            ),
            _buildBottomBarItem(
              index: 1,
              selectedIndex: homeProvider.selectedIndex,
              inactiveIcon: Icons.directions_car_outlined,
              activeIcon: Icons.directions_car_rounded,
              onTap: () => homeProvider.selectTab(1),
            ),
            _buildBottomBarItem(
              index: 2,
              selectedIndex: homeProvider.selectedIndex,
              inactiveIcon: Icons.history_toggle_off_rounded,
              activeIcon: Icons.access_time_filled_rounded,
              onTap: () => homeProvider.selectTab(2),
            ),
            _buildBottomBarItem(
              index: 3,
              selectedIndex: homeProvider.selectedIndex,
              inactiveIcon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              onTap: () => homeProvider.selectTab(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBarItem({
    required int index,
    required int selectedIndex,
    required IconData inactiveIcon,
    required IconData activeIcon,
    required VoidCallback onTap,
  }) {
    final isSelected = index == selectedIndex;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: isSelected ? 56 : 44,
            height: isSelected ? 44 : 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.secondary.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.secondary.withValues(alpha: 0.45)
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected
                  ? AppColors.accentGold
                  : Colors.white.withValues(alpha: 0.84),
              size: isSelected ? 24 : 22,
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(HomeProvider homeProvider) {
    if (homeProvider.selectedIndex != 0) return null;

    String greeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Chào buổi sáng';
      if (hour < 18) return 'Chào buổi chiều';
      return 'Chào buổi tối';
    }

    return AppBar(
      toolbarHeight: 110,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryGreen, AppColors.surfaceGreen],
          ),
        ),
      ),
      titleSpacing: 18,
      title: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            backgroundImage:
                (homeProvider.avatarUrl != null &&
                    homeProvider.avatarUrl!.isNotEmpty)
                ? NetworkImage(homeProvider.avatarUrl!)
                : const AssetImage(
                        'lib/assets/icons/user_avatar_placeholder.png',
                      )
                      as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  homeProvider.fullName.isEmpty
                      ? 'Khách hàng'
                      : homeProvider.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildWeatherPill(homeProvider),
        ],
      ),
    );
  }

  Widget _buildWeatherPill(HomeProvider homeProvider) {
    if (homeProvider.isLoadingWeather) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    return InkWell(
      onTap: _homeProvider.refreshWeather,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              homeProvider.weatherIcon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  homeProvider.temperature,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Hà Nội',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(HomeProvider homeProvider) {
    return IndexedStack(
      index: homeProvider.selectedIndex,
      children: [
        _buildHomeScreen(homeProvider),
        Booking1Screen(onRideBooked: _handleRideBooked),
        ActivityScreen(key: _activityScreenKey),
        const ProfileScreen(),
      ],
    );
  }

  Widget _buildHomeScreen(HomeProvider homeProvider) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF143C2E), Color(0xFFEDEFE6)],
                stops: [0, 0.38],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -40,
                  child: _BackdropGlow(
                    size: 240,
                    color: AppColors.accentGold.withValues(alpha: 0.10),
                  ),
                ),
                Positioned(
                  top: 110,
                  left: -80,
                  child: _BackdropGlow(
                    size: 220,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
          ),
        ),
        RefreshIndicator(
          onRefresh: () async {
            await _homeProvider.loadUserInfo();
            await _homeProvider.fetchWeather();
          },
          color: Theme.of(context).colorScheme.secondary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(homeProvider),
                const SizedBox(height: 18),
                _buildStatusStrip(homeProvider),
                const SizedBox(height: 22),
                _buildSectionTitle(
                  title: 'Lối vào nhanh',
                  subtitle: 'Các thao tác chính được gom lại để vào nhanh hơn.',
                ),
                const SizedBox(height: 12),
                _buildPrimaryActionRow(homeProvider),
                const SizedBox(height: 18),
                _buildHomeSectionCard(
                  title: 'Tiện ích nhanh',
                  subtitle:
                      'Các mục theo dõi và trao đổi để không trùng với lối vào chính.',
                  icon: Icons.dashboard_customize_outlined,
                  child: _buildActionButtons(homeProvider),
                ),
                const SizedBox(height: 18),
                _buildHomeSectionCard(
                  title: 'Gợi ý hôm nay',
                  subtitle:
                      'Một vài lưu ý để thao tác trong app nhanh và chính xác hơn.',
                  icon: Icons.lightbulb_outline_rounded,
                  child: Column(
                    children: [
                      _buildInsightCard(
                        title: 'Đặt chuyến nội thành Hà Nội',
                        body:
                            'Chọn điểm đón trước để hệ thống tự lọc điểm đến Nội Bài đúng theo rule hiện tại.',
                        icon: Icons.local_airport_outlined,
                        accent: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 12),
                      _buildInsightCard(
                        title: 'Thanh toán bằng ví',
                        body:
                            'Nạp tiền trước khi đặt để bước xác nhận cuối gọn hơn và không phải xử lý tiền mặt.',
                        icon: Icons.account_balance_wallet_outlined,
                        accent: const Color(0xFF2AA876),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(HomeProvider homeProvider) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreen,
            AppColors.surfaceGreen,
            AppColors.primaryGreen.withValues(alpha: 0.92),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandLogoBadge(
                assetPath: 'lib/assets/icons/dong_duong_logo.png',
                size: 68,
                borderRadius: 22,
                padding: 4,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đông Dương',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sẵn sàng cho hành trình tiếp theo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _HeroChip(icon: Icons.local_taxi_outlined, label: 'Đặt xe nhanh'),
              _HeroChip(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Nạp ví bằng QR',
              ),
              _HeroChip(icon: Icons.chat_bubble_outline_rounded, label: 'Chat'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStrip(HomeProvider homeProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusTile(
            icon: Icons.wb_sunny_outlined,
            title: homeProvider.temperature,
            subtitle: 'Thời tiết Hà Nội',
            accent: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusTile(
            icon: Icons.route_outlined,
            title: 'Điểm đón trước',
            subtitle: 'Lọc tuyến chuẩn hơn',
            accent: const Color(0xFF2AA876),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusTile(
            icon: Icons.flash_on_outlined,
            title: 'QR nạp ví',
            subtitle: 'Huỷ trực tiếp',
            accent: const Color(0xFF56B6FF),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              height: 1.35,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    bool light = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: light ? Colors.white : AppColors.primaryGreen,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: light
                ? Colors.white.withValues(alpha: 0.74)
                : Colors.black.withValues(alpha: 0.58),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionRow(HomeProvider homeProvider) {
    return Row(
      children: [
        Expanded(
          child: _buildPrimaryActionCard(
            title: 'Đặt chuyến',
            subtitle: 'Tạo đơn mới với flow 3 bước đã được làm gọn.',
            icon: Icons.directions_car_rounded,
            accent: Theme.of(context).colorScheme.secondary,
            backgroundColor: _softTint(
              Theme.of(context).colorScheme.secondary,
              0.16,
            ),
            onTap: () => homeProvider.selectTab(1),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildPrimaryActionCard(
            title: 'Nạp tiền',
            subtitle: 'Tạo QR nạp ví và huỷ giao dịch trực tiếp từ QR.',
            icon: Icons.account_balance_wallet_rounded,
            accent: const Color(0xFF2AA876),
            backgroundColor: _softTint(const Color(0xFF2AA876), 0.14),
            onTap: _showDepositAmountDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.62),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildActionButtons(HomeProvider homeProvider) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.92,
      children: [
        _buildActionCard(
          assetPath: 'lib/assets/icons/activity_history.png',
          label: 'Hoạt động',
          subtitle: 'Theo dõi các chuyến đang diễn ra',
          backgroundColor: _softTint(AppColors.primaryGreen, 0.08),
          iconBackgroundColor: _softTint(AppColors.primaryGreen, 0.10),
          onTap: () => homeProvider.selectTab(2),
        ),
        _buildActionCard(
          assetPath: 'lib/assets/icons/chat_icon.png',
          label: 'Chat',
          subtitle: 'Trao đổi trực tiếp',
          backgroundColor: _softTint(const Color(0xFF2AA876), 0.12),
          iconBackgroundColor: _softTint(const Color(0xFF2AA876), 0.16),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => const ChatScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String assetPath,
    required String label,
    required String subtitle,
    required Color backgroundColor,
    required Color iconBackgroundColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset(assetPath, fit: BoxFit.contain),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.58),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String body,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.62),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _BackdropGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}
