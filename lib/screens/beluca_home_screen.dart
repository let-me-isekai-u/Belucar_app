import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking_model.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // ================= LOAD USER FROM LOCAL =================
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();

    final name = prefs.getString("fullName") ?? '';

    if (!mounted) return;

    setState(() {
      _fullName = name;
    });
  }

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
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Đặt chuyến',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Hoạt động',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  // ================= APP BAR =================
  PreferredSizeWidget? _buildAppBar() {
    // Chỉ hiển thị AppBar nếu _selectedIndex == 0 (Trang chủ).
    // Ẩn ở các tab còn lại (Đặt chuyến, Hoạt động, Tài khoản).
    if (_selectedIndex != 0) return null;

    // Nếu _selectedIndex == 0, hiển thị App Bar
    return AppBar(
      title: Text(
        // Hiển thị tên nếu đã load, nếu không thì hiện 'Xin chào'
        _fullName.isEmpty ? 'Xin chào' : 'Xin chào, $_fullName',
      ),
      centerTitle: false,
      // Thêm các hành động (actions) nếu cần thiết, ví dụ: biểu tượng thông báo
    );
  }

  // ================= BODY =================
  // Trong _HomeViewState
  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeScreen();
      case 1:
      // TRUYỀN HÀM CALLBACK VÀO BOOKINGSCREEN
        return BookingScreen(onRideBooked: _selectTab);
      case 2:
        return const ActivityScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const SizedBox();
    }
  }

  // ================= HOME SCREEN MỚI =================
  // Trong _HomeViewState
  // ================= HOME SCREEN CẬP NHẬT THÊM BANNER =================
  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Ô tìm kiếm/Đặt chuyến nhanh
          _buildBookingSection(),
          const SizedBox(height: 20), // Giảm khoảng cách

          // 1.5. Banner chào mừng và giới thiệu (MỤC MỚI)
          _buildWelcomeBanner(),
          const SizedBox(height: 24),


          // 2. Nút chuyển hướng đến Hoạt động
          _buildActivityButton(),
          const SizedBox(height: 24),

          // 3. Phần giới thiệu các lợi ích của ứng dụng
          _buildBenefitSection(),
          const SizedBox(height: 24),

          // 4. Các tuyến đường/Điểm đến gợi ý
          _buildDestinationSection(),
          const SizedBox(height: 24),

        ],
      ),
    );
  }

  // Trong _HomeViewState
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

// Widget con cho từng lợi ích
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
    // Danh sách các điểm đến phổ biến ở miền Bắc
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
          'Tuyến đường phổ biến Miền Bắc', // Thay đổi tiêu đề
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150, // Chiều cao cố định cho các thẻ cuộn ngang
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


// Widget con cho từng điểm đến
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
          // Xử lý khi người dùng chọn điểm đến (Ví dụ: tự động điền vào form đặt chuyến)
          setState(() {
            _selectedIndex = 1; // Chuyển sang màn hình đặt chuyến
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chuyển đến màn hình đặt chuyến cho $city')),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Giả lập hình ảnh
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: imagePlaceholder,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                // Trong thực tế, bạn sẽ dùng Image.network hoặc Image.asset
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


  // ================= WELCOME BANNER MỚI (PHONG CÁCH HERO/NỔI BẬT) =================
  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25), // Tăng padding
      decoration: BoxDecoration(
        // Sử dụng Gradient nhẹ nhàng để tạo cảm giác sang trọng, nổi bật
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16), // Bo góc lớn hơn
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
              // 1. Logo (Tăng kích thước và làm tròn)
              ClipRRect(
                borderRadius: BorderRadius.circular(15.0), // Bo góc lớn hơn
                child: Image.asset(
                  'lib/assets/icons/BeluCar_logo.jpg',
                  height: 65, // Tăng kích thước
                  width: 65,  // Tăng kích thước
                  fit: BoxFit.cover,
                ),
              ),

              // Icon trang trí (tùy chọn)
              const Icon(
                Icons.directions_bus,
                color: Colors.white70,
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Nội dung Chào mừng
          const Text(
            'BeluCar xin kính chào!',
            style: TextStyle(
              fontSize: 22, // Chữ lớn hơn
              fontWeight: FontWeight.w900,
              color: Colors.white, // Màu chữ trắng tương phản
            ),
          ),
          const SizedBox(height: 8),

          // 3. Giới thiệu
          const Text(
            'Hãy bắt đầu hành trình cùng BeluCar! Chúng tôi cam kết mang đến trải nghiệm đặt xe tiện lợi và an toàn nhất khu vực Miền Bắc.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white, // Màu chữ trắng nhạt hơn
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
        // Chuyển sang BookingScreen (index 1) khi nhấp vào
        setState(() {
          _selectedIndex = 1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          // Hiệu ứng đổ bóng nổi bật để thu hút sự chú ý
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.2), // Màu bóng theo màu chủ đạo
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4), // Đổ bóng xuống dưới
            ),
          ],
        ),
        child: Row(
          children: [
            // Biểu tượng xuất phát
            Icon(
              Icons.location_on,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
            const SizedBox(width: 16),

            // Văn bản gợi ý
            const Expanded(
              child: Text(
                'Tìm kiếm chuyến đi...', // Đã thay đổi nội dung
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500
                ),
              ),
            ),

            // Biểu tượng mũi tên nhỏ gọn
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
      // KHÔNG CẦN CONST Ở ĐÂY
      color: Colors.blue.shade50,
      child: InkWell(
        onTap: () {
          // Chuyển sang ActivityScreen (index 2)
          setState(() {
            _selectedIndex = 2;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon lớn hơn và nổi bật
              Container(
                padding: const EdgeInsets.all(10),
                // KHÔNG CẦN CONST Ở ĐÂY
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon( // Loại bỏ const khỏi Icon
                  Icons.schedule,
                  // KHÔNG CẦN CONST Ở ĐÂY
                  color: Colors.blue.shade800, // <--- LỖI ĐƯỢC KHẮC PHỤC
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),

              // Nội dung chính
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
                    // Chú thích chi tiết hơn
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

              // Icon mũi tên
              const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 18),
            ],
          ),
        ),
      ),
    );
  }


}
