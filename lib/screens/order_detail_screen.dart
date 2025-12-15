import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_detail_model.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatelessWidget {
  final int rideId;

  const OrderDetailScreen({
    super.key,
    required this.rideId,
  });

  static const String _baseUrl = "https://belucar.belugaexpress.com";

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("accessToken");
  }

  String formatCurrency(double value) {
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'VND',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }
  Future<TripDetailModel> _fetchTripDetail() async {
    final token = await _getAccessToken();
    if (token == null) {
      throw Exception("Chưa đăng nhập");
    }

    final data = await ApiService.getTripDetail(
      accessToken: token,
      rideId: rideId,
    );

    return TripDetailModel.fromJson(data);
  }

  // API 17: Huỷ chuyến đi
  // Future<void> _cancelTrip(BuildContext context) async {
  //   final token = await _getAccessToken();
  //   if (token == null) return;
  //
  //   try {
  //     await ApiService.cancelTrip(
  //       accessToken: token,
  //       rideId: rideId,
  //     );
  //
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Huỷ chuyến thành công")),
  //     );
  //
  //     Navigator.pop(context);
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(e.toString())),
  //     );
  //   }
  // }

  // ===== HELPER =====

  String _statusText(int status) {
    switch (status) {
      case 1:
        return "Đang tìm tài xế";
      case 2:
        return "Đang thực hiện chuyến đi";
      case 3:
        return "Hoàn thành";
      case 4:
        return "Đã huỷ";
      default:
        return "Không xác định";
    }
  }

  Color _statusColor(int status) {
    if (status == 1 || status == 2) return Colors.blue;
    if (status == 3) return Colors.green;
    return Colors.red;
  }

  String? _buildAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) return null;
    if (avatar.startsWith('http')) return avatar;
    return '$_baseUrl$avatar';
  }

  // void _confirmCancelTrip(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text("Xác nhận huỷ chuyến"),
  //       content: const Text(
  //         "Bạn có chắc chắn muốn huỷ chuyến đi này không?\n"
  //             "Hành động này không thể hoàn tác.",
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text("Không"),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             Navigator.pop(context);
  //             _cancelTrip(context);
  //           },
  //           child: const Text(
  //             "Huỷ chuyến",
  //             style: TextStyle(color: Colors.red),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ===== UI =====


  // Trong OrderDetailScreen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chi tiết chuyến xe"),
        centerTitle: true,
      ),
      body: FutureBuilder<TripDetailModel>(
        future: _fetchTripDetail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Lỗi tải chi tiết chuyến đi:\n${snapshot.error.toString()}"),
              ),
            );
          }

          final trip = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. TRẠNG THÁI VÀ GIÁ (Khối nổi bật)
                _buildStatusAndPriceCard(context, trip),

                const SizedBox(height: 20),

                // 2. TUYẾN ĐƯỜNG (Từ - Đến)
                _buildRouteCard(context, trip),

                const SizedBox(height: 20),

                // 3. THÔNG TIN THỜI GIAN VÀ GHI CHÚ
                _buildDetailInfoCard(context, trip),

                const SizedBox(height: 20),

                // 4. THÔNG TIN TÀI XẾ
                _buildDriverInfoCard(context, trip),

                const SizedBox(height: 30),


              ],
            ),
          );
        },
      ),
    );
  }



// 1. TRẠNG THÁI VÀ GIÁ (Khối nổi bật)
  Widget _buildStatusAndPriceCard(BuildContext context, TripDetailModel trip) {
    final statusColor = _statusColor(trip.status);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TRẠNG THÁI
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: statusColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _statusText(trip.status),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 25),

            // GIÁ TIỀN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Tổng tiền chuyến đi",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  formatCurrency(trip.price),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// 2. TUYẾN ĐƯỜNG (Từ - Đến)
  // 2. TUYẾN ĐƯỜNG (Từ - Đến)
  Widget _buildRouteCard(BuildContext context, TripDetailModel trip) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tuyến đường",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 15),

            // Điểm đón
            _routePoint(
              icon: Icons.circle,
              color: Colors.green,
              title: trip.fromAddress, // 🔥 ĐÃ SỬ DỤNG fromAddress
              address: "${trip.fromProvince}, ${trip.fromDistrict}", // 🔥 Địa chỉ phụ
            ),

            // Dấu chấm/đường kẻ
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
              child: SizedBox(
                height: 20,
                child: VerticalDivider(thickness: 2, color: Colors.grey.shade300),
              ),
            ),

            // Điểm đến
            _routePoint(
              icon: Icons.location_on,
              color: Colors.red,
              title: trip.toAddress, // 🔥 ĐÃ SỬ DỤNG toAddress
              address: "${trip.toProvince}, ${trip.toDistrict}", // 🔥 Địa chỉ phụ
            ),
          ],
        ),
      ),
    );
  }

// Helper cho Điểm đón/đến
  // Helper cho Điểm đón/đến
  Widget _routePoint({
    required IconData icon,
    required Color color,
    required String title, // Địa chỉ chi tiết (e.g., Số 5, Nguyễn Trãi)
    required String address, // Địa chỉ phụ (e.g., Hà Nội, Thanh Xuân)
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, // Địa chỉ chi tiết (in đậm)
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                address, // Địa chỉ Tỉnh/Huyện (mờ hơn)
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }


// 3. THÔNG TIN THỜI GIAN VÀ GHI CHÚ
  Widget _buildDetailInfoCard(BuildContext context, TripDetailModel trip) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Chi tiết khác",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 15),

            // Thời gian đón
            _infoRow(
              "Thời gian đón",
              "${trip.pickupTime.hour}:${trip.pickupTime.minute.toString().padLeft(2, '0')} "
                  "- ${trip.pickupTime.day}/${trip.pickupTime.month}/${trip.pickupTime.year}",
              icon: Icons.schedule,
            ),

            // Ghi chú
            _infoRow(
              "Ghi chú",
              trip.note ?? "Không có",
              icon: Icons.notes,
            ),
          ],
        ),
      ),
    );
  }

  // Trong OrderDetailScreen (Cần đảm bảo hàm này đã được thay thế)
  Widget _infoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 25,
            child: Icon(icon, size: 18, color: Colors.grey.shade600),
          ),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

// 4. THÔNG TIN TÀI XẾ
  Widget _buildDriverInfoCard(BuildContext context, TripDetailModel trip) {
    final bool hasDriver = trip.status >= 2 && trip.driverName != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tài xế phụ trách",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 15),

            if (hasDriver)
              Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _buildAvatarUrl(trip.avatar) != null
                        ? NetworkImage(
                      _buildAvatarUrl(trip.avatar)!,
                    )
                        : null,
                    child: _buildAvatarUrl(trip.avatar) == null
                        ? const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.grey,
                    )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.driverName!,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Thêm icons cho thông tin tài xế
                        _driverDetailRow(
                            Icons.phone,
                            trip.phoneNumber ?? 'Đang cập nhật'
                        ),
                        _driverDetailRow(
                            Icons.directions_car,
                            trip.licenseNumber ?? 'Đang cập nhật'
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  trip.status == 1
                      ? "Hệ thống đang tìm kiếm tài xế phù hợp..."
                      : "Chưa có tài xế phụ trách.",
                  style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

// Helper cho thông tin chi tiết tài xế
  Widget _driverDetailRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
