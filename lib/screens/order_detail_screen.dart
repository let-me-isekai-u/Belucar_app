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

  String _statusText(int status) {
    switch (status) {
      case 1:
        return "Đang tìm tài xế";
      case 2:
        return "Đã tìm thấy tài xế";
      case 3:
        return "Đang di chuyển";
      case 4:
        return "Hoàn thành";
      case 5:
        return "Đã huỷ";
      default:
        return "Không xác định";
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Chi tiết chuyến xe",
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
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
                child: Text(
                  "Lỗi tải chi tiết chuyến đi:\n${snapshot.error.toString()}",
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final trip = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusHeader(trip, theme),
                const SizedBox(height: 16),
                _buildPriceDetailCard(trip, theme), // ✅ đã thêm quantity ở đây
                const SizedBox(height: 16),
                _buildPaymentMethodCard(trip, theme),
                const SizedBox(height: 16),
                _buildRouteCard(context, trip, theme),
                const SizedBox(height: 16),
                _buildDetailInfoCard(context, trip, theme), // ✅ đã thêm quantity ở đây
                const SizedBox(height: 16),
                _buildDriverInfoCard(context, trip, theme),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(TripDetailModel trip, ThemeData theme) {
    final statusColor = _statusColor(trip.status);
    return Card(
      elevation: 3,
      color: statusColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Mã chuyến: ${trip.code}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
                fontSize: 16,
              ),
            ),
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

  Widget _buildPriceDetailCard(TripDetailModel trip, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Chi tiết thanh toán",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            Divider(height: 24, color: theme.colorScheme.secondary.withOpacity(0.3)),

            _textRow("Số lượng", "x${trip.quantity}", theme),

            _priceRow("Giá cước gốc", trip.price, theme),
            _priceRow("Ưu đãi", -trip.discount, theme, color: Colors.greenAccent),
            _priceRow("Phụ phí", trip.surcharge, theme, color: Colors.orangeAccent),
            Divider(height: 24, color: theme.colorScheme.secondary.withOpacity(0.5)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Tổng thanh toán",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  formatCurrency(trip.finalPrice),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, double amount, ThemeData theme, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            formatCurrency(amount),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: row text (không format tiền) cho phần "Chi tiết thanh toán"
  Widget _textRow(String label, String value, ThemeData theme, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(TripDetailModel trip, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(Icons.account_balance_wallet, color: theme.colorScheme.secondary),
        title: Text(
          "Phương thức thanh toán",
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.secondary,
          ),
        ),
        subtitle: Text(
          trip.paymentMethod,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, TripDetailModel trip, ThemeData theme) {
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
                const Icon(Icons.circle, color: Colors.green, size: 18),
                DashedLineVertical(height: 40, color: theme.colorScheme.secondary),
                const Icon(Icons.location_on, color: Colors.red, size: 18),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _routePointText(
                    title: trip.fromProvince,
                    district: trip.fromDistrict,
                    address: trip.fromAddress,
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _routePointText(
                    title: trip.toProvince,
                    district: trip.toDistrict,
                    address: trip.toAddress,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routePointText({
    required String title,
    required String district,
    required String address,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$title - $district",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.secondary,
          ),
        ),
        Text(
          address,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDetailInfoCard(BuildContext context, TripDetailModel trip, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Thông tin bổ sung",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            Divider(height: 20, color: theme.colorScheme.secondary.withOpacity(0.3)),
            _infoRow("Số lượng người", "${trip.quantity}", icon: Icons.people, theme: theme), // ✅ NEW
            _infoRow("Ngày đón", DateFormat('dd/MM/yyyy').format(trip.pickupTime),
                icon: Icons.calendar_today, theme: theme),
            _infoRow("Giờ đón", DateFormat('HH:mm').format(trip.pickupTime),
                icon: Icons.access_time, theme: theme),
            _infoRow("Ngày đặt", DateFormat('HH:mm - dd/MM/yyyy').format(trip.createdAt),
                icon: Icons.history, theme: theme),
            _infoRow("Ghi chú", trip.note ?? "Không có ghi chú",
                icon: Icons.note_outlined, theme: theme),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {IconData? icon, required ThemeData theme}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.secondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard(BuildContext context, TripDetailModel trip, ThemeData theme) {
    final bool hasDriver = trip.status >= 2 && trip.driverName != null;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tài xế",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            Divider(height: 20, color: theme.colorScheme.secondary.withOpacity(0.3)),
            if (hasDriver)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.15),
                  backgroundImage: _buildAvatarUrl(trip.avatar) != null
                      ? NetworkImage(_buildAvatarUrl(trip.avatar)!)
                      : null,
                  child: trip.avatar == null
                      ? Icon(Icons.person, color: theme.colorScheme.secondary)
                      : null,
                ),
                title: Text(
                  trip.driverName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SĐT: ${trip.phoneNumber ?? 'Đang cập nhật'}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "BSX: ${trip.licenseNumber ?? 'Đang cập nhật'}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            else
              Text(
                trip.status == 1 ? "Hệ thống đang tìm tài xế..." : "Chưa có thông tin tài xế",
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }
}