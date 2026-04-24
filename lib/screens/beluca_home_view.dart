import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/deposit_model.dart';
import '../providers/home_provider.dart';
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
  late final PageController _bannerController;
  final GlobalKey<ActivityScreenState> _activityScreenKey =
      GlobalKey<ActivityScreenState>();

  Timer? _weatherTimer;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _homeProvider = context.read<HomeProvider>();
    _bannerController = PageController(viewportFraction: 0.92);

    _homeProvider.initialize();

    _weatherTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _homeProvider.fetchWeather(),
    );

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_bannerController.hasClients) return;

      _homeProvider.advanceBanner();
      _bannerController.animateToPage(
        _homeProvider.currentBanner,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    _carouselTimer?.cancel();
    _bannerController.dispose();
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

  Future<void> _showDepositAmountDialog() async {
    final controller = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nạp tiền vào ví'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Nhập số tiền (tối thiểu 50.000đ)',
                        suffixText: 'đ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gợi ý:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [50000, 100000, 200000, 500000].map((amount) {
                        return ActionChip(
                          label: Text(
                            NumberFormat.currency(
                              locale: 'vi_VN',
                              symbol: 'đ',
                              decimalDigits: 0,
                            ).format(amount),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  controller.text = amount.toString();
                                },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Huỷ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final amount = double.tryParse(
                            controller.text.trim(),
                          );
                          if (amount == null || amount < 50000) {
                            if (!mounted) return;
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
                            setDialogState(() => isSubmitting = false);
                          }

                          if (!mounted) return;

                          if (!result.success || result.data == null) {
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
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tạo yêu cầu nạp tiền'),
                ),
              ],
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
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Quét mã thanh toán',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Image.network(qrUrl),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nội dung chuyển khoản',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  depositData.content,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await Clipboard.setData(
                                    ClipboardData(text: depositData.content),
                                  );
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã sao chép nội dung'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Sau khi bạn chuyển khoản đúng nội dung, worker sẽ tự đối soát và cộng ví.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (depositData.depositId == null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'API hiện chỉ trả content, chưa trả depositId nên app chưa thể gọi API huỷ đúng chuẩn.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCancelling
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(
                    depositData.depositId == null ? 'Đóng' : 'Giữ yêu cầu',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (depositData.depositId != null)
                  ElevatedButton(
                    onPressed: isCancelling
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setDialogState(() => isCancelling = true);
                            final result = await _homeProvider
                                .cancelDepositRequest(
                                  depositId: depositData.depositId,
                                );
                            if (dialogContext.mounted) {
                              setDialogState(() => isCancelling = false);
                            }

                            if (!mounted) return;

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.success
                                      ? 'Huỷ yêu cầu nạp tiền thành công'
                                      : (result.message ??
                                            'Không thể huỷ yêu cầu nạp tiền'),
                                ),
                                backgroundColor: result.success
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            );

                            if (result.success && dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                    child: isCancelling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Huỷ yêu cầu'),
                  ),
              ],
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
          appBar: _buildAppBar(homeProvider),
          body: _buildBody(homeProvider),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: homeProvider.selectedIndex,
            onTap: homeProvider.selectTab,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).colorScheme.secondary,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            elevation: 10,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Trang chủ',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.directions_car_rounded),
                label: 'Đặt chuyến',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.access_time_rounded),
                label: 'Hoạt động',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Tài khoản',
              ),
            ],
          ),
          backgroundColor: Colors.grey.shade50,
        );
      },
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
      elevation: 0,
      toolbarHeight: 95,
      centerTitle: false,
      titleSpacing: 16,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage(
              'lib/assets/icons/new_background_appbar.png',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.3),
              BlendMode.modulate,
            ),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.85),
              Theme.of(context).primaryColor.withOpacity(0.75),
            ],
          ),
        ),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withOpacity(0.3),
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
                  '${greeting()} 👋',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  homeProvider.fullName.isEmpty
                      ? 'Khách'
                      : homeProvider.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          homeProvider.isLoadingWeather
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : InkWell(
                  onTap: _homeProvider.refreshWeather,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          homeProvider.weatherIcon,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              homeProvider.temperature,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Hà Nội',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButtons(homeProvider),
          const SizedBox(height: 20),
          _buildHomeCarousel(homeProvider),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionButtons(HomeProvider homeProvider) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildActionCard(
          assetPath: 'lib/assets/icons/booking_car.png',
          label: 'Đặt chuyến',
          onTap: () => homeProvider.selectTab(1),
        ),
        _buildActionCard(
          assetPath: 'lib/assets/icons/wallet.png',
          label: 'Nạp tiền',
          onTap: _showDepositAmountDialog,
        ),
        _buildActionCard(
          assetPath: 'lib/assets/icons/activity_history.png',
          label: 'Hoạt động',
          onTap: () => homeProvider.selectTab(2),
        ),
        _buildActionCard(
          assetPath: 'lib/assets/icons/chat_icon.png',
          label: 'Chat đặt đơn',
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
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  assetPath,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeCarousel(HomeProvider homeProvider) {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: homeProvider.carouselImages.length + 1,
            onPageChanged: homeProvider.setCurrentBanner,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildWelcomeBanner();
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    homeProvider.carouselImages[index - 1],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildCarouselIndicator(homeProvider),
      ],
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      height: 270,
      width: 450,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withBlue(200),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'lib/assets/icons/BeluCar_logo.jpg',
              height: 60,
              width: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Xin chào bạn 👋',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const Text(
                  'Vi vu cùng BeluCar!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '📍 Phủ sóng toàn Miền Bắc',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselIndicator(HomeProvider homeProvider) {
    final total = homeProvider.carouselImages.length + 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index == homeProvider.currentBanner;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }
}
