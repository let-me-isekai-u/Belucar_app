import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Để định dạng tiền 1.000.000
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking_model.dart';
// import '../models/tet_booking_model.dart';
import '../services/api_service.dart'; // Đảm bảo bạn đã có ApiService.getCustomerProfile và ApiService.depositWallet
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

  // === BIẾN THÊM MỚI CHO VÍ ===
  double _walletBalance = 0;
  int _userId = 0;
  bool _isLoadingWallet = true;

  //Banner quảng cáo (cái cũ vẫn giữ, nhưng hiển thị lần đầu sẽ qua dialog)
  bool _showEventBanner = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchWalletInfo(); // Lấy số dư ví ngay khi khởi tạo

    // Sau khi frame đầu tiên vẽ xong, kiểm tra xem có cần show banner không.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowEventBanner();
    });
  }

  // ================= LOAD USER & WALLET INFO =================
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString("fullName") ?? '';
    if (!mounted) return;
    setState(() {
      _fullName = name;
    });
  }

  // Lấy số dư ví từ Server
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
          // CẬP NHẬT ID VÀO MÁY TẠI ĐÂY
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

  // ============== HIỂN THỊ BANNER 1 LẦN ================
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
          // Khoảng cách từ dialog đến mép màn hình
          insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
          child: FractionallySizedBox(
            heightFactor: 0.65, // Điều chỉnh tỉ lệ chiều cao (0.6 - 0.7 là đẹp nhất)
            child: Stack(
              children: [
                // 1. LỚP NỀN: Chứa ảnh bo góc và tràn toàn bộ khung
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
                    fit: BoxFit.cover, // Ảnh phủ kín toàn bộ diện tích
                  ),
                ),

                // 2. LỚP PHỦ NỀN TRONG SUỐT (GRADIENT) VÀ CHỮ
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 25),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      // Hiệu ứng Gradient mờ từ trên xuống để làm nổi bật text
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8), // Màu tối dần ở đáy
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
                            color: Color(0xFFFFD700), // Màu vàng Gold
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
                        // Thêm nút hành động (Tùy chọn - tăng UX)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              // Đóng dialog rồi chuyển sang màn tet booking
                              Navigator.of(dialogCtx).pop();
                              // Push màn đặt chuyến TET
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => tet.BookingScreen(onRideBooked: _selectTab),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F), // Đỏ đậm
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

                // 3. NÚT ĐÓNG (DẤU X)
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
                        color: Colors.black45, // Nền mờ cho nút X
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

  // Bước 1: Nhập số tiền
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
              // Bước 2: Tạo nội dung chuyển khoản và hiện QR
              final content = "$_userId${DateFormat('HHmmss').format(DateTime.now())}";
              _showQRDialog(amount, content);
            },
            child: const Text("Xác nhận nạp tiền"),
          )
        ],
      ),
    );
  }

  // Bước 2: Hiển thị QR và Polling
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
            // Đếm ngược
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown <= 0) {
                t.cancel(); pollTimer?.cancel();
                Navigator.pop(dialogCtx);
              } else if (dialogCtx.mounted) {
                setDialogState(() => countdown--);
              }
            });

            // Kiểm tra giao dịch (Polling)
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
                  _fetchWalletInfo(); // Cập nhật lại số dư trên trang chủ
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
                    // THÔNG BÁO CẢNH BÁO NHƯ YÊU CẦU
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

  // ================= UI COMPONENTS =================

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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Đặt chuyến'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Hoạt động'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_selectedIndex != 0) return null;
    return AppBar(
      title: Text(_fullName.isEmpty ? 'Xin chào' : 'Xin chào, $_fullName'),
      centerTitle: false,
    );
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _buildHomeScreen();
      case 1: return booking_old.BookingScreen(onRideBooked: _selectTab);
      case 2: return const ActivityScreen();
      case 3: return const ProfileScreen();
      default: return const SizedBox();
    }
  }

  // ================= HOME SCREEN (CHÈN THÊM VÍ VÀO ĐÂY) =================
  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBookingSection(),
          const SizedBox(height: 20),

          // --- MỤC VÍ TIỀN MỚI ---
          _buildWalletSection(),
          const SizedBox(height: 20),

          _buildWelcomeBanner(),
          const SizedBox(height: 24),
          _buildActivityButton(),
          const SizedBox(height: 24),
          _buildBenefitSection(),
          const SizedBox(height: 24),
          _buildDestinationSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Widget hiển thị Ví tiền và Nút nạp
  Widget _buildWalletSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: _showDepositAmountDialog, // Ấn xác nhận xong mới hiện QR bên trong hàm này
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text("Nạp tiền"),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        ],
      ),
    );
  }

  // ================= CÁC WIDGET GIAO DIỆN CŨ CỦA BẠN (GIỮ NGUYÊN 100%) =================

  Widget _buildBenefitSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tại sao nên chọn dịch vụ của chúng tôi?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBenefitItem(
              icon: Icons.verified_user,
              title: 'An toàn',
              color: Colors.green,
            ),
            _buildBenefitItem(
              icon: Icons.headset_mic,
              title: 'Hỗ trợ 24/7',
              color: Colors.orange,
            ),
            _buildBenefitItem(
              icon: Icons.payments,
              title: 'Giá tốt',
              color: Colors.blue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBenefitItem({required IconData icon, required String title, required Color color}) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDestinationSection() {
    final northernDestinations = [
      {'city': 'Hà Nội', 'color': Colors.blue.shade100},
      {'city': 'Hải Phòng', 'color': Colors.red.shade100},
      {'city': 'Quảng Ninh', 'color': Colors.purple.shade100},
      {'city': 'Lào Cai', 'color': Colors.green.shade100},
      {'city': 'Nam Định', 'color': Colors.orange.shade100},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tuyến đường phổ biến Miền Bắc',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: northernDestinations.length,
            itemBuilder: (context, index) {
              final destination = northernDestinations[index];
              return Padding(
                padding: EdgeInsets.only(right: 12.0, left: index == 0 ? 0 : 0),
                child: _buildDestinationCard(
                  city: destination['city'] as String,
                  imagePlaceholder: destination['color'] as Color,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationCard({required String city, required Color imagePlaceholder}) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chuyển đến màn hình đặt chuyến cho $city')),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: imagePlaceholder,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Center(
                child: Icon(Icons.location_city, color: Colors.black54),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                city,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.4),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: Image.asset(
                  'lib/assets/icons/BeluCar_logo.jpg',
                  height: 65,
                  width: 65,
                  fit: BoxFit.cover,
                ),
              ),
              const Icon(
                Icons.directions_bus,
                color: Colors.white70,
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'BeluCar xin kính chào!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy bắt đầu hành trình cùng BeluCar! Chúng tôi cam kết mang đến trải nghiệm đặt xe tiện lợi và an toàn nhất khu vực Miền Bắc.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  //backup nút đặt chuyến tắt
  /*
  * Widget _buildBookingSection() {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = 1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Tìm kiếm chuyến đi...',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }*/


  //nút sự kiện tết
  Widget _buildBookingSection() {
    return InkWell(
      onTap: () {
        // Mở màn hình tet booking bằng Navigator.push
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => tet.BookingScreen(onRideBooked: _selectTab),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          // Đã sửa: Sử dụng 0xFF thay cho dấu #
          gradient: const LinearGradient(
            colors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
          // Đã sửa: Viền vàng kim loại
          border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
        ),
        child: Row(
          children: [
            // Đã sửa: Dùng Text để hiển thị Emoji thay vì Icons
            const Text(
              "🧧",
              style: TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VỀ NHÀ ĂN TẾT!',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5
                    ),
                  ),
                  Text(
                    'Chọn vào đây để tham gia sự kiện!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Đặt lịch đón từ 07–14/02 ngay hôm nay - Giá không tăng dịp Tết!',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5
                    ),
                  ),
                ],
              ),
            ),
            // Đã sửa: Màu vàng 0xFFFFD700
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFFFFD700),
              size: 20,
            ),
          ],
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
}