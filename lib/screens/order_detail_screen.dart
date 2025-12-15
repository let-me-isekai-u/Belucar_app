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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chi tiết chuyến xe"),
      ),
      body: FutureBuilder<TripDetailModel>(
        future: _fetchTripDetail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final trip = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ==== TRẠNG THÁI ====
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _statusColor(trip.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_car_rounded,
                        color: _statusColor(trip.status),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _statusText(trip.status),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(trip.status),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ==== THÔNG TIN CHUYẾN ĐI ====
                const Text(
                  "Thông tin chuyến đi",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                _infoRow(
                  "Điểm đón",
                  "${trip.fromProvince} (${trip.fromDistrict})",
                ),
                _infoRow(
                  "Điểm đến",
                  "${trip.toProvince} (${trip.toDistrict})",
                ),
                _infoRow(
                  "Thời gian đón",
                  "${trip.pickupTime.hour}:${trip.pickupTime.minute.toString().padLeft(2, '0')} "
                      "- ${trip.pickupTime.day}/${trip.pickupTime.month}/${trip.pickupTime.year}",
                ),

                _infoRow("Ghi chú", trip.note ?? "Không có"),
                const SizedBox(height: 15),
                Text("Giá: ${formatCurrency(trip.price)}", style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                    color: Colors.black
                ),
                ),

                const SizedBox(height: 30),

                // ==== THÔNG TIN TÀI XẾ ====
                const Text(
                  "Tài xế phụ trách",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                if (trip.status >= 2 && trip.driverName != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
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
                              Text(
                                "SĐT: ${trip.phoneNumber ?? 'Đang cập nhật'}",
                              ),
                              Text(
                                "Biển số xe: ${trip.licenseNumber ?? 'Đang cập nhật'}",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (trip.status == 1)
                  _infoRow(
                    "Trạng thái",
                    "Hệ thống đang tìm kiếm tài xế phù hợp...",
                  )
                else
                  _infoRow(
                    "Thông tin",
                    "Chưa có tài xế phụ trách.",
                  ),

                const SizedBox(height: 30),

                // ==== NÚT HUỶ ====
                // if (trip.status == 1)
                //   Center(
                //     child: TextButton(
                //       onPressed: () => _confirmCancelTrip(context),
                //       child: const Text(
                //         "Huỷ chuyến",
                //         style: TextStyle(
                //           color: Colors.red,
                //           fontSize: 16,
                //           fontWeight: FontWeight.w600,
                //         ),
                //       ),
                //     ),
                //   ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
}
