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

  bool _isHistoryLoaded = false;

  // ✅ NEW: Expose a method for parent (BottomNav) to force refresh after booking
  void refreshOngoing() {
    if (!mounted) return;
    setState(() {
      _ongoingFuture = _fetchOngoingTrips();
      if (_isHistoryLoaded) {
        _historyFuture = _fetchHistoryTrips();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ongoingFuture = _fetchOngoingTrips();
    _historyFuture = Future.value([]);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.index == 1 && !_isHistoryLoaded) {
      setState(() {
        _historyFuture = _fetchHistoryTrips();
        _isHistoryLoaded = true;
      });
    }
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Không",
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isConfirmCancel) {
                _callConfirmCancelTrip(rideId);
              } else {
                _callCancelTrip(rideId);
              }
            },
            child: const Text(
              "Huỷ chuyến",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Hoạt động",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary, // ✅ Màu vàng gold
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.secondary, // ✅ Tab được chọn màu vàng gold
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelColor: Colors.white70,
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          indicatorColor: Theme.of(context).colorScheme.secondary,
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
        await _ongoingFuture;
      },
      child: FutureBuilder<List<TripItemModel>>(
        future: _ongoingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data ?? [];
          if (trips.isEmpty) {
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
              return _buildHistoryCard(trip);
            }
            return _buildOngoingCard(trip);
          },
        ),
      ],
    );
  }

  // ✅ CARD CHO LỊCH SỬ
  Widget _buildHistoryCard(TripItemModel trip) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      color: Colors.white, // ✅ Nền trắng đục 100%
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(rideId: trip.rideId)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: theme.colorScheme.secondary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${trip.fromProvince} → ${trip.toProvince}",
                      maxLines: 2,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Mã chuyến: ${trip.code}",
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${trip.fromAddress}, ${trip.fromDistrict} → ${trip.toAddress}, ${trip.toDistrict}",
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Ngày đặt: ${trip.createdAt.day}/${trip.createdAt.month}/${trip.createdAt.year}",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: trip.status == 4 ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: trip.status == 4 ? Colors.green : Colors.red,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _getStatusText(trip.status),
                      style: TextStyle(
                        color: trip.status == 4 ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ CARD CHO ĐANG DIỄN RA
  Widget _buildOngoingCard(TripItemModel trip) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(rideId: trip.rideId)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, // ✅ Nền trắng đục 100%
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26, // ✅ Shadow đậm hơn
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${trip.fromProvince} → ${trip.toProvince}",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Mã chuyến: ${trip.code}",
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${trip.fromAddress}, ${trip.fromDistrict} → ${trip.toAddress}, ${trip.toDistrict}",
              maxLines: 2,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Giá: ${formatCurrency(trip.price)}",
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(trip.status),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusBorderColor(trip.status),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      "Trạng thái: ${_getStatusText(trip.status)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _getStatusBorderColor(trip.status),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (trip.status == 1 || trip.status == 2)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showCancelTripDialog(
                    rideId: trip.rideId,
                    isConfirmCancel: trip.status == 2,
                  ),
                  icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                  label: const Text(
                    "Huỷ chuyến",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ HÀM TRẢ VỀ MÀU NỀN CHO TRẠNG THÁI
  Color _getStatusBgColor(int status) {
    if (status == 1) return Colors.orange.shade50;
    if (status == 2) return Colors.purple.shade50;
    if (status == 3) return Colors.blue.shade50;
    return Colors.grey.shade50;
  }

  // ✅ HÀM TRẢ VỀ MÀU VIỀN CHO TRẠNG THÁI
  Color _getStatusBorderColor(int status) {
    if (status == 1) return Colors.orange.shade700;
    if (status == 2) return Colors.purple.shade700;
    if (status == 3) return Colors.blue.shade700;
    return Colors.grey.shade700;
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.secondary, // ✅ Màu vàng gold
                fontWeight: FontWeight.w600, // ✅ Đậm hơn để dễ đọc
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}