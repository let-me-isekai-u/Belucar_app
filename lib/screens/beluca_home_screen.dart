import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Để định dạng tiền 1.000.000
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking_model.dart';
import '../services/api_service.dart'; // Đảm bảo bạn đã có ApiService.getCustomerProfile và ApiService.depositWallet
import 'activity_screen.dart';
import 'profile_screen.dart';
import 'booking_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchWalletInfo(); // Lấy số dư ví ngay khi khởi tạo
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
      case 1: return BookingScreen(onRideBooked: _selectTab);
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Số dư ví", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 4),
              _isLoadingWallet
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                "${NumberFormat("#,###").format(_walletBalance)} đ",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
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

  Widget _buildBookingSection() {
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