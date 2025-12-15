import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'beluca_home_screen.dart';
import 'order_detail_screen.dart';
import '../models/trip_item_model.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late Future<List<TripItemModel>> _ongoingFuture;
  late Future<List<TripItemModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _ongoingFuture = _fetchOngoingTrips();
    _historyFuture = _fetchHistoryTrips();
  }

  String formatCurrency(double value) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ================= UTIL =================

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return "Đang chờ tài xế";
      case 2:
        return "Đang thực hiện chuyến đi";
      case 3:
        return "Đã đến nơi";
      case 4:
        return "Đã huỷ";
      default:
        return "Có lỗi, vui lòng thử lại";
    }
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  // ================= API =================

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("accessToken");
  }

  Future<List<TripItemModel>> _fetchOngoingTrips() async {
    final token = await _getAccessToken();
    if (token == null) return [];

    final res = await ApiService.getTripCurrent(accessToken: token);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List list = body["data"] ?? [];
      return list.map((e) => TripItemModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<TripItemModel>> _fetchHistoryTrips() async {
    final token = await _getAccessToken();
    if (token == null) return [];

    final res = await ApiService.getTripHistory(accessToken: token);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List list = body["data"] ?? [];
      return list.map((e) => TripItemModel.fromJson(e)).toList();
    }
    return [];
  }

  // ================= HUỶ CHUYẾN =================

  Future<void> _cancelTrip(int rideId) async {
    final token = await _getAccessToken();
    if (token == null) return;

    try {
      await ApiService.cancelTrip(
        accessToken: token,
        rideId: rideId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Huỷ chuyến thành công")),
      );

      setState(() {
        _ongoingFuture = _fetchOngoingTrips();
        _historyFuture = _fetchHistoryTrips();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _confirmCancelTrip(int rideId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận huỷ chuyến"),
        content: const Text(
          "Bạn có chắc chắn muốn huỷ chuyến đi này không?\n"
              "Hành động này không thể hoàn tác.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Không"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelTrip(rideId);
            },
            child: const Text(
              "Huỷ chuyến",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI =================



  @override
  Widget build(BuildContext context) {
    //App bar
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Hoạt động",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false, // giống Home
        elevation: 0,       // giống Home (phẳng)
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        bottom: TabBar(
          controller: _tabController,

          // 1. Màu chữ khi được chọn: Đen (Tương phản tối đa với nền xanh nhạt)
          labelColor: Colors.white,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),

          // 2. Màu chữ khi KHÔNG được chọn: Đen mờ (Vẫn tương phản tốt)
          unselectedLabelColor: Colors.white70,
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),

          // 3. Indicator: Đường gạch dưới màu Đen
          indicatorColor: Colors.green.shade700,
          indicatorWeight: 5.5,


          tabs: const [
            Tab(text: "Đang diễn ra"),
            Tab(text: "Lịch sử"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOngoingTrips(),
          _buildHistoryTrips(),
        ],
      ),
    );

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: "Đang diễn ra"),
              Tab(text: "Lịch sử"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOngoingTrips(),
              _buildHistoryTrips(),
            ],
          ),
        ),
      ],
    );
  }

  // ================= TAB ĐANG DIỄN RA =================

  Widget _buildOngoingTrips() {
    return FutureBuilder<List<TripItemModel>>(
      future: _ongoingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final trips = snapshot.data ?? [];

        if (trips.isEmpty) {
          return _buildEmptyState(
            "Hiện tại bạn không có chuyến xe nào.",
            showButton: true,
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'lib/assets/icons/ActivityLogo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrderDetailScreen(rideId: trip.rideId),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [


                        const SizedBox(height: 6),
                        Text(
                          "${trip.fromProvince} → ${trip.toProvince}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text("Mã chuyến: ${trip.code}"),
                        Text("Giá: ${formatCurrency(trip.price)}"),

                        Text(
                            "Trạng thái: ${_getStatusText(trip.status)}"),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [

                            if (trip.status == 1)
                              TextButton(
                                onPressed: () => _confirmCancelTrip(trip.rideId),
                                child: const Text(
                                  "Huỷ chuyến",
                                  style: TextStyle(
                                    color: Colors.red,

                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ================= TAB LỊCH SỬ =================

  Widget _buildHistoryTrips() {
    return FutureBuilder<List<TripItemModel>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final trips = snapshot.data ?? [];

        if (trips.isEmpty) {
          return _buildEmptyState(
            "Hiện tại bạn đang không lịch sử có chuyến xe nào.",
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'lib/assets/icons/ActivityLogo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailScreen(rideId: trip.rideId),
                        ),
                      );
                    },
                    leading:
                    const Icon(Icons.history, color: Colors.grey),
                    title: Text(
                      "${trip.fromProvince} → ${trip.toProvince}",
                      style:
                      const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Ngày: ${trip.createdAt.day}/${trip.createdAt.month}/${trip.createdAt.year}",
                    ),
                    trailing: Text(
                      _getStatusText(trip.status),
                      style: TextStyle(
                        color: trip.status == 3
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ================= EMPTY STATE =================

  Widget _buildEmptyState(String message, {bool showButton = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/assets/icons/ActivityLogo.png',
              width: 140,
              height: 140,
            ),
            const SizedBox(height: 28),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
              const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            if (showButton)
              TextButton(
                onPressed: _goToHome,
                child: const Text(
                  "Đặt ngay",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
