import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_detail_model.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

import '../widgets/dashed_line_vertical.dart';


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

  // ===== HELPER =====
  String _statusText(int status) {
    switch (status) {
      case 1: return "Đang tìm tài xế";
      case 2: return "Đã tìm thấy tài xế";
      case 3: return "Đang di chuyển";
      case 4: return "Hoàn thành";
      case 5: return "Đã huỷ";
      default: return "Không xác định";
    }
  }

  Color _statusColor(int status) {
    if (status == 1 || status == 2 || status == 3) return Colors.blue;
    if (status == 4) return Colors.green;
    return Colors.red;
  }

  String? _buildAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) return null;
    if (avatar.startsWith('http')) return avatar;
    return '$_baseUrl$avatar';
  }

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
                // 1. Trạng thái & Mã chuyến
                _buildStatusHeader(trip),
                const SizedBox(height: 16),

                // 2. Chi tiết giá tiền (Mới cập nhật theo Model)
                _buildPriceDetailCard(trip),
                const SizedBox(height: 16),

                // 3. Phương thức thanh toán
                _buildPaymentMethodCard(trip),
                const SizedBox(height: 16),

                // 4. Tuyến đường
                _buildRouteCard(context, trip),
                const SizedBox(height: 16),

                // 5. Thông tin thời gian & Ghi chú
                _buildDetailInfoCard(context, trip),
                const SizedBox(height: 16),

                // 6. Thông tin tài xế
                _buildDriverInfoCard(context, trip),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // Khối Header Trạng thái
  Widget _buildStatusHeader(TripDetailModel trip) {
    final statusColor = _statusColor(trip.status);
    return Card(
      elevation: 0,
      color: statusColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Mã chuyến: ${trip.code}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  _statusText(trip.status).toUpperCase(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // KHỐI CHI TIẾT GIÁ (CẬP NHẬT THEO MODEL MỚI)
  Widget _buildPriceDetailCard(TripDetailModel trip) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Chi tiết thanh toán", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            _priceRow("Giá cước gốc", trip.price),
            _priceRow("Ưu đãi", -trip.discount, color: Colors.green),
            _priceRow("Phụ phí", trip.surcharge, color: Colors.orange),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tổng thanh toán", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  formatCurrency(trip.finalPrice),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black87)),
          Text(formatCurrency(amount), style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(TripDetailModel trip) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet, color: Colors.blue),
        title: const Text("Phương thức thanh toán", style: TextStyle(fontSize: 13, color: Colors.grey)),
        subtitle: Text(trip.paymentMethod, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, TripDetailModel trip) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(Icons.circle, color: Colors.green, size: 18),
                DashedLineVertical(height: 40, color: Colors.brown),
                Icon(Icons.location_on, color: Colors.red, size: 18),
              ],
            ),
            const SizedBox(width: 10),

            // cột bên phải: text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _routePointText(
                    title: trip.fromProvince,
                    district: trip.fromDistrict,
                    address: trip.fromAddress,
                  ),
                  const SizedBox(height: 8),
                  _routePointText(
                    title: trip.toProvince,
                    district: trip.toDistrict,
                    address: trip.toAddress,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routePointText({required String title, required String district, required String address}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$title - $district", style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(address),
      ],
    );
  }


  Widget _routePoint({required IconData icon, required Color color, required String title, required String district, required String address}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(district, style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
              Text(address, style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailInfoCard(BuildContext context, TripDetailModel trip) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Thông tin bổ sung", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            _infoRow("Ngày đón", DateFormat('dd/MM/yyyy').format(trip.pickupTime), icon: Icons.calendar_today),
            _infoRow("Giờ đón", DateFormat('HH:mm').format(trip.pickupTime), icon: Icons.access_time),
            _infoRow("Ngày đặt", DateFormat('HH:mm - dd/MM/yyyy').format(trip.createdAt), icon: Icons.history),
            _infoRow("Ghi chú", trip.note ?? "Không có ghi chú", icon: Icons.note_outlined),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

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
            const Text("Tài xế", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            if (hasDriver)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 25,
                  backgroundImage: _buildAvatarUrl(trip.avatar) != null ? NetworkImage(_buildAvatarUrl(trip.avatar)!) : null,
                  child: trip.avatar == null ? const Icon(Icons.person) : null,
                ),
                title: Text(trip.driverName!, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("SĐT: ${trip.phoneNumber ?? 'Đang cập nhật'}"),
                    Text("BSX: ${trip.licenseNumber ?? 'Đang cập nhật'}"),
                  ],
                ),

              )
            else
              Text(
                trip.status == 1 ? "Hệ thống đang tìm tài xế..." : "Chưa có thông tin tài xế",
                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}