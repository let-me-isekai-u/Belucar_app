import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:belucar_app/app_theme.dart';

import '../models/booking_model.dart';
import '../services/api_service.dart';
import 'activity_screen.dart';
import 'profile_screen.dart';
import 'booking1_screen.dart';

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

class _HomeViewState extends State<_HomeView> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String _fullName = '';

  int _userId = 0;

  // ✅ Weather
  String _weatherIcon = '🌤️';
  String _temperature = '--';
  bool _isLoadingWeather = true;
  Timer? _weatherTimer;

  // ✅ Carousel timer (FIX build failed: missing field)
  Timer? _carouselTimer;

  // ✅ Avatar
  String? _avatarUrl;

  // Carousel
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
    _fetchWeather();

    // Auto refresh weather every 10 minutes
    _weatherTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchWeather();
    });

    _bannerController = PageController(viewportFraction: 0.92);

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
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

  @override
  void dispose() {
    _bannerController.dispose();
    _weatherTimer?.cancel();
    super.dispose();
    _carouselTimer?.cancel();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString("fullName") ?? '';
    final token = prefs.getString('accessToken') ?? '';

    if (token.isNotEmpty) {
      try {
        final res = await ApiService.getCustomerProfile(accessToken: token);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (mounted) {
            await prefs.setInt("id", data['id'] ?? 0);
            setState(() {
              _userId = data['id'] ?? 0;
              _avatarUrl = data['avatarUrl'];
            });
          }
        }
      } catch (e) {
        // Handle error silently
      }
    }

    if (!mounted) return;
    setState(() {
      _fullName = name;
    });
  }

  // ✅ Fetch weather for Hanoi
  Future<void> _fetchWeather() async {
    try {
      const lat = 21.0285;
      const lon = 105.8542;

      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?'
          'latitude=$lat&'
          'longitude=$lon&'
          'current_weather=true&'
          'timezone=Asia/Bangkok');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current_weather'];

        if (mounted) {
          setState(() {
            _temperature = '${current['temperature'].round()}°';
            _weatherIcon = _getWeatherEmoji(current['weathercode']);
            _isLoadingWeather = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  String _getWeatherEmoji(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌦️';
    if (code <= 99) return '⛈️';
    return '🌤️';
  }

  // ================= LOGIC NẠP TIỀN =================

  void _showDepositAmountDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nạp tiền vào ví"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Nhập số tiền (tối thiểu 50.000đ)",
                suffixText: "đ",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Gợi ý:",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [50000, 100000, 200000, 500000].map((amount) {
                return ActionChip(
                  label: Text(NumberFormat.currency(
                    locale: "vi_VN",
                    symbol: "đ",
                    decimalDigits: 0,
                  ).format(amount)),
                  onPressed: () {
                    controller.text = amount.toString();
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Hủy",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount < 50000) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Số tiền nạp tối thiểu là 50.000đ"),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final content =
                  "$_userId${DateFormat('HHmmss').format(DateTime.now())}";
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
                t.cancel();
                pollTimer?.cancel();
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
                  accessToken: token, amount: amount, content: content);

              if (success) {
                t.cancel();
                countdownTimer?.cancel();
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Nạp tiền thành công!"),
                      backgroundColor: Colors.green));
                }
              }
              isChecking = false;
            });

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Quét mã thanh toán",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 12),
                    Image.network(qrUrl),
                    const SizedBox(height: 12),
                    Text("Nội dung: $content",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        "⚠️ Vui lòng KHÔNG tắt ứng dụng hoặc đóng mã QR cho đến khi hệ thống xác nhận chuyển khoản thành công.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                        "vui lòng chuyển khoản trong: ${countdown ~/ 60}:${(countdown % 60).toString().padLeft(2, '0')}"),
                    TextButton(
                      onPressed: () {
                        countdownTimer?.cancel();
                        pollTimer?.cancel();
                        Navigator.pop(dialogCtx);
                      },
                      child: Text(
                        "Huỷ giao dịch",
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary, // ✅ Màu vàng gold
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context)
            .colorScheme
            .secondary, // ✅ Đổi sang màu vàng gold
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        elevation: 10,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Trang chủ'),
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_rounded), label: 'Đặt chuyến'),
          BottomNavigationBarItem(
              icon: Icon(Icons.access_time_rounded), label: 'Hoạt động'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Tài khoản'),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_selectedIndex != 0) return null;

    String _getGreeting() {
      var hour = DateTime.now().hour;
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
            image:
            const AssetImage('lib/assets/icons/new_background_appbar.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.3), // Làm mờ ảnh nền
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
          // ✅ Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withOpacity(0.3),
            backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ? NetworkImage(_avatarUrl!)
                : const AssetImage(
                'lib/assets/icons/user_avatar_placeholder.png')
            as ImageProvider,
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
                    color: Colors.white.withOpacity(0.85),
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
          // ✅ Weather widget
          _isLoadingWeather
              ? Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            onTap: () {
              setState(() => _isLoadingWeather = true);
              _fetchWeather();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
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
                    _weatherIcon,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _temperature,
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

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomeScreen(),
        Booking1Screen(onRideBooked: _selectTab),
        const ActivityScreen(),
        const ProfileScreen(),
      ],
    );
  }

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButtons(),
          const SizedBox(height: 20),
          _buildHomeCarousel(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Đặt chuyến
        Expanded(
          child: _buildActionCard(
            assetPath: 'lib/assets/icons/booking_car.png',
            label: 'Đặt chuyến',
            onTap: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        // Nạp tiền
        Expanded(
          child: _buildActionCard(
            assetPath: 'lib/assets/icons/wallet.png',
            label: 'Nạp tiền',
            onTap: _showDepositAmountDialog,
          ),
        ),
        const SizedBox(width: 12),
        // Hoạt động
        Expanded(
          child: _buildActionCard(
            assetPath: 'lib/assets/icons/activity_history.png',
            label: 'Hoạt động',
            onTap: () {
              setState(() {
                _selectedIndex = 2;
              });
            },
          ),
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
            // Ảnh asset = chính là nút
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
                  width: 72, // chỉnh tuỳ layout
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

  /// --- Carousel --- ///
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
              if (index == 0) {
                return _buildWelcomeBanner(context);
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
                    _carouselImages[index - 1],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildCarouselIndicator(),
      ],
    );
  }

  Widget _buildWelcomeBanner(BuildContext context) {
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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