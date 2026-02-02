import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Định dạng tiền 1.000.000
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking_model.dart';
import '../services/api_service.dart';
import 'activity_screen.dart';
import 'profile_screen.dart';
import 'booking_screen.dart' as booking_old;
import 'tet_booking_screen.dart' as tet;



class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BookingModel(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  int _selectedIndex = 0;
  String _fullName = '';

  double _walletBalance = 0;
  int _userId = 0;
  bool _isLoadingWallet = true;

  bool _showEventBanner = true;

  //lặp ảnh carousel
  late PageController _bannerController;
  int _currentBanner = 0;

  final List<String> _carouselImages = [
    'lib/assets/carousel_01.jpg',
    'lib/assets/carousel_02.png',
    'lib/assets/carousel_03.jpg',
  ];


  @override
  void initState() {
    super.initState();

    _loadUserInfo();
    _fetchWalletInfo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowEventBanner();
    });

    _bannerController = PageController(viewportFraction: 0.92);

    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_bannerController.hasClients) return;

      final totalPages = _carouselImages.length + 1;

      _currentBanner = (_currentBanner + 1) % totalPages;

      _bannerController.animateToPage(
        _currentBanner,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }



  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString("fullName") ?? '';
    if (!mounted) return;
    setState(() {
      _fullName = name;
    });
  }

  Future<void> _fetchWalletInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';
      if (token.isEmpty) return;

      final res = await ApiService.getCustomerProfile(accessToken: token);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt("id", data['id'] ?? 0);
          setState(() {
            _walletBalance = (data['wallet'] as num?)?.toDouble() ?? 0.0;
            _userId = data['id'] ?? 0;
            _isLoadingWallet = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWallet = false);
    }
  }

  Future<void> _maybeShowEventBanner() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldShow = prefs.getBool('showEventBanner') ?? false;

    if (!shouldShow) return;

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          child: FractionallySizedBox(
            heightFactor: 0.65,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'lib/assets/tet_splash.png',
                    fit: BoxFit.cover,
                  ),
                ),
                // Lớp phủ chữ và gradient
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 55, 20, 25),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Chúc Mừng Năm Mới! 🧧',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 4,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Ưu đãi đặc biệt chỉ trong dịp Tết.\nĐặt chuyến ngay - Không lo tăng giá!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => tet.BookingScreen(onRideBooked: _selectTab),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'ĐẶT CHUYẾN NGAY!',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('showEventBanner');
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= LOGIC NẠP TIỀN =================

  void _showDepositAmountDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nạp tiền vào ví"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: "Nhập số tiền (ví dụ: 50000)",
            suffixText: "đ",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount < 1000) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Số tiền nạp tối thiểu là 1.000đ"))
                );
                return;
              }
              Navigator.pop(ctx);
              final content = "$_userId${DateFormat('HHmmss').format(DateTime.now())}";
              _showQRDialog(amount, content);
            },
            child: const Text("Xác nhận nạp tiền"),
          )
        ],
      ),
    );
  }

  void _showQRDialog(double amount, String content) {
    final qrUrl = "https://img.vietqr.io/image/MB-246878888-compact2.png"
        "?amount=${amount.toStringAsFixed(0)}&addInfo=$content&accountName=CTY%20CP%20CN%20VA%20DV%20TT%20THE%20BELUGAS";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        int countdown = 300;
        Timer? countdownTimer;
        Timer? pollTimer;
        bool isChecking = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown <= 0) {
                t.cancel(); pollTimer?.cancel();
                Navigator.pop(dialogCtx);
              } else if (dialogCtx.mounted) {
                setDialogState(() => countdown--);
              }
            });

            pollTimer ??= Timer.periodic(const Duration(seconds: 7), (t) async {
              if (isChecking) return;
              isChecking = true;

              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('accessToken') ?? '';
              final success = await ApiService.depositWallet(
                  accessToken: token, amount: amount, content: content
              );

              if (success) {
                t.cancel(); countdownTimer?.cancel();
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Nạp tiền thành công!"), backgroundColor: Colors.green)
                  );
                  _fetchWalletInfo();
                }
              }
              isChecking = false;
            });

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Quét mã thanh toán", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 12),
                    Image.network(qrUrl),
                    const SizedBox(height: 12),
                    Text("Nội dung: $content", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        "⚠️ Vui lòng KHÔNG tắt ứng dụng hoặc đóng mã QR cho đến khi hệ thống xác nhận chuyển khoản thành công.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text("vui lòng chuyển khoản trong: ${countdown ~/ 60}:${(countdown % 60).toString().padLeft(2, '0')}"),
                    TextButton(
                      onPressed: () {
                        countdownTimer?.cancel(); pollTimer?.cancel();
                        Navigator.pop(dialogCtx);
                      },
                      child: const Text("Hủy giao dịch"),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================= UI COMPONENTS  =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 0),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => tet.BookingScreen(onRideBooked: _selectTab),
                ),
              );
            } else {
              setState(() {
                _selectedIndex = index;
              });
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Trang chủ'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_car_rounded), label: 'Đặt chuyến'),
            BottomNavigationBarItem(icon: Icon(Icons.access_time_rounded), label: 'Hoạt động'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Tài khoản'),
          ],
        )
      ),
      backgroundColor: Colors.grey.shade50,
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_selectedIndex != 0) return null;

    // Hàm lấy lời chào theo thời gian thực
    String _getGreeting() {
      var hour = DateTime.now().hour;
      if (hour < 12) return 'Chào buổi sáng';
      if (hour < 18) return 'Chào buổi chiều';
      return 'Chào buổi tối';
    }

    return AppBar(
      elevation: 0,
      toolbarHeight: 75,
      centerTitle: false,
      titleSpacing: 16,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_getGreeting()} 👋',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fullName.isEmpty ? 'Khách' : _fullName,
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
        ],
      ),
    );
  }
  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeScreen(); // Màn hình Trang chủ
      case 1:
        return Container(); // Nội dung trống vì Tab này chuyển hướng qua Navigator
      case 2:
        return const ActivityScreen(); // Màn hình Hoạt động
      case 3:
        return const ProfileScreen(); // Màn hình Tài khoản
      default:
        return const SizedBox(); // Phòng trường hợp ngoại lệ
    }
  }

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBookingSection(),
          const SizedBox(height: 19),
          _buildWalletSection(),
          const SizedBox(height: 17),
        _buildHomeCarousel(context),
          const SizedBox(height: 26),
          _buildActivityButton(),
          const SizedBox(height: 26),
          _buildBenefitSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// --- UI Ví tiền ---
  Widget _buildWalletSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.82),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Số dư ví',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  _isLoadingWallet
                      ? const SizedBox(
                    height: 23,
                    width: 23,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Text(
                    NumberFormat.currency(
                        locale: "vi_VN", symbol: "₫", decimalDigits: 0)
                        .format(_walletBalance),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.white,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showDepositAmountDialog,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              label: const Text(
                "Nạp tiền",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --- Ảnh 'carousel' --- ///
  Widget _buildHomeCarousel(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _carouselImages.length + 1,
            onPageChanged: (index) {
              setState(() => _currentBanner = index);
            },
            itemBuilder: (context, index) {
              // Banner chào mừng (index 0)
              if (index == 0) {
                return _buildEnhancedWelcomeBanner(context);
              }

              // Ảnh carousel
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    _carouselImages[index - 1],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        _buildCarouselIndicator(),
      ],
    );
  }



  /// --- Banner chào mừng --- ///
  Widget _buildEnhancedWelcomeBanner(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildCarouselIndicator() {
    final total = _carouselImages.length + 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index == _currentBanner;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 12 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }




  /// --- Booking Section --- ///
  Widget _buildBookingSection() {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => tet.BookingScreen(onRideBooked: _selectTab),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB71C1C).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. Nền Gradient đa tầng
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB71C1C), Color(0xFFE53935), Color(0xFFD32F2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    // 2. Icon 🧧 với hiệu ứng phát sáng nhẹ
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      ),
                      child: const Center(
                        child: Text("🧧", style: TextStyle(fontSize: 35)),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 3. Nội dung văn bản
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VỀ NHÀ ĂN TẾT!',
                            style: TextStyle(
                              fontSize: 22,
                              color: const Color(0xFFFFD700),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(1, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Săn voucher - Vi vu đón xuân',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 4. Tag ưu đãi kiểu Glassmorphism
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.stars, color: Color(0xFFFFD700), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  '07–14/02 • Không lo giá',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFFFFD700),
                      size: 20,
                    ),
                  ],
                ),
              ),

              // 5. Các họa tiết trang trí (Decorations)
              // Vòng tròn lớn mờ phía góc phải
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 20),
                  ),
                ),
              ),
              // Điểm sáng nhỏ phía dưới
              Positioned(
                bottom: -10,
                left: 100,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withOpacity(0.03),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityButton() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      color: Colors.blue.shade50,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = 2;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.schedule,
                  color: Colors.blue.shade800,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quản lý Hoạt động Đặt chuyến',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Theo dõi các chuyến đang chờ tài xế và xem lại lịch sử chuyến đi của bạn.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// Benefit section
  Widget _buildBenefitSection() {
    final List<Map<String, dynamic>> benefits = [
      {
        "icon": Icons.verified_user_rounded,
        "title": "An toàn",
        "desc": "Bảo hiểm 100%",
        "color": Colors.green,
      },
      {
        "icon": Icons.headset_mic_rounded,
        "title": "Hỗ trợ",
        "desc": "Phục vụ 24/7",
        "color": Colors.orange,
      },
      {
        "icon": Icons.payments_rounded,
        "title": "Giá rẻ",
        "desc": "Tiết kiệm 20%",
        "color": Colors.blue,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Tại sao chọn BeluCar?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: benefits.map((e) => Expanded(
              child: _buildEnhancedBenefitItem(
                icon: e["icon"],
                title: e["title"],
                desc: e["desc"],
                color: e["color"],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedBenefitItem({
    required IconData icon,
    required String title,
    required String desc,
    required Color color
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon với nền gradient mờ
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}