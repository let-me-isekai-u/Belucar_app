import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'beluca_home_screen.dart';
import 'order_detail_screen.dart';
import '../models/trip_item_model.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'booking_screen.dart';

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

  // Biến kiểm soát để chỉ load API lịch sử 1 lần khi nhấn vào tab
  bool _isHistoryLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 1. Chỉ gọi API cho tab "Đang diễn ra" ngay từ đầu
    _ongoingFuture = _fetchOngoingTrips();

    // 2. Khởi tạo Future lịch sử rỗng trước để tránh lỗi build
    _historyFuture = Future.value([]);

    // 3. Lắng nghe sự kiện chuyển tab
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    // Nếu người dùng chuyển sang tab Lịch sử (index 1) và chưa từng load trước đó
    if (_tabController.index == 1 && !_isHistoryLoaded) {
      setState(() {
        _historyFuture = _fetchHistoryTrips();
        _isHistoryLoaded = true;
      });
    }
    // Nếu quay lại tab Đang diễn ra, bạn có thể chọn load lại hoặc không
    // Ở đây mình giữ nguyên để tiết kiệm tài nguyên
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
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  // ================= UTIL =================

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return "Đang chờ tài xế";
      case 2:
        return "Đã có tài xế";
      case 3:
        return "Đang di chuyển";
      case 4:
        return "Đã đến nơi";
      case 5:
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

    try {
      final res = await ApiService.getTripCurrent(accessToken: token);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body["data"] ?? [];
        return list.map((e) => TripItemModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching ongoing trips: $e");
    }
    return [];
  }

  Future<List<TripItemModel>> _fetchHistoryTrips() async {
    final token = await _getAccessToken();
    if (token == null) return [];

    try {
      final res = await ApiService.getTripHistory(accessToken: token);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body["data"] ?? [];
        return list.map((e) => TripItemModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching history trips: $e");
    }
    return [];
  }

  // ================= HUỶ CHUYẾN =================

  Future<void> _callCancelTrip(int rideId) async {
    final token = await _getAccessToken();
    if (token == null) return;

    try {
      await ApiService.cancelTrip(accessToken: token, rideId: rideId);
      _onActionSuccess("Huỷ chuyến thành công");
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _callConfirmCancelTrip(int rideId) async {
    final token = await _getAccessToken();
    if (token == null) return;

    try {
      await ApiService.confirmCancelTrip(accessToken: token, rideId: rideId);
      _onActionSuccess("Huỷ chuyến thành công");
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  void _onActionSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() {
      _ongoingFuture = _fetchOngoingTrips();
      // Nếu đã từng xem lịch sử thì mới load lại lịch sử
      if (_isHistoryLoaded) {
        _historyFuture = _fetchHistoryTrips();
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCancelTripDialog({required int rideId, required bool isConfirmCancel}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận huỷ chuyến"),
        content: const Text(
          "Bạn có chắc chắn muốn huỷ chuyến đi này không?\nHành động này không thể hoàn tác.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Không")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isConfirmCancel) {
                _callConfirmCancelTrip(rideId);
              } else {
                _callCancelTrip(rideId);
              }
            },
            child: const Text("Huỷ chuyến", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ================= UI BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hoạt động", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelColor: Colors.white70,
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
  }

  Widget _buildOngoingTrips() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _ongoingFuture = _fetchOngoingTrips();
        });
        await _ongoingFuture; // Đợi load xong để vòng xoay biến mất
      },
      child: FutureBuilder<List<TripItemModel>>(
        future: _ongoingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
            // Bọc empty state trong SingleChildScrollView để có thể vuốt reload
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: _buildEmptyState("Hiện tại bạn không có chuyến xe nào.", showButton: true),
              ),
            );
          }
          return _buildTripList(trips, isHistory: false);
        },
      ),
    );
  }

  Widget _buildHistoryTrips() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _historyFuture = _fetchHistoryTrips();
        });
        await _historyFuture;
      },
      child: FutureBuilder<List<TripItemModel>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data ?? [];
          if (trips.isEmpty && _isHistoryLoaded) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: _buildEmptyState("Hiện tại bạn không có lịch sử chuyến xe nào."),
              ),
            );
          }
          if (!_isHistoryLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildTripList(trips, isHistory: true);
        },
      ),
    );
  }

  Widget _buildTripList(List<TripItemModel> trips, {required bool isHistory}) {
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.18,
            child: Image.asset('lib/assets/icons/ActivityLogo.png', fit: BoxFit.cover),
          ),
        ),
        ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final trip = trips[index];
            if (isHistory) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OrderDetailScreen(rideId: trip.rideId))
                  ),
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(
                      "${trip.fromProvince} → ${trip.toProvince}",
                      style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  // --- CHỈNH SỬA Ở ĐÂY ---
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Căn lề trái cho các dòng text
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Mã chuyến: ${trip.code}"), // Thêm mã chuyến
                      Text("Ngày đặt: ${trip.createdAt.day}/${trip.createdAt.month}/${trip.createdAt.year}"),
                    ],
                  ),
                  // -----------------------
                  trailing: Text(
                    _getStatusText(trip.status),
                    style: TextStyle(
                        color: trip.status == 4 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              );
            }
            return _buildOngoingCard(trip);
          },
        ),
      ],
    );
  }

  Widget _buildOngoingCard(TripItemModel trip) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(rideId: trip.rideId))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text("${trip.fromProvince} → ${trip.toProvince}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text("Mã chuyến: ${trip.code}"),
            Text("Giá: ${formatCurrency(trip.price)}"),
            Text("Trạng thái: ${_getStatusText(trip.status)}"),
            if (trip.status == 1 || trip.status == 2)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showCancelTripDialog(rideId: trip.rideId, isConfirmCancel: trip.status == 2),
                  child: const Text("Huỷ chuyến", style: TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, {bool showButton = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('lib/assets/icons/ActivityLogo.png', width: 140, height: 140),
            const SizedBox(height: 28),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 20),
            // if (showButton)
            //   TextButton(
            //     onPressed: () {
            //       Navigator.push(
            //         context,
            //         MaterialPageRoute(
            //           builder: (context) => BookingScreen(
            //             // Sửa () thành (id) hoặc (_) để nhận tham số int mà BookingScreen truyền ra
            //             onRideBooked: (id) {
            //               setState(() {
            //                 _ongoingFuture = _fetchOngoingTrips();
            //               });
            //             },
            //           ),
            //         ),
            //       );
            //     },
            //     child: const Text(
            //       "Đặt ngay",
            //       style: TextStyle(
            //         fontSize: 16,
            //         color: Colors.blue,
            //         fontWeight: FontWeight.w600,
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }
}