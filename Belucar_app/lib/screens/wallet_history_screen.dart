import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 1. Khai báo biến lưu số dư ở đây để dùng chung toàn màn hình
  String _currentBalance = "0";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // 2. Hàm gộp để lấy cả Profile (Số dư) và Lịch sử giao dịch
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? '';

      if (token.isEmpty) {
        setState(() {
          _errorMessage = "Phiên đăng nhập hết hạn.";
          _isLoading = false;
        });
        return;
      }

      // --- BƯỚC A: LẤY SỐ DƯ ---
      final profileRes = await ApiService.getCustomerProfile(accessToken: token);
      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        _currentBalance = profileData['wallet']?.toStringAsFixed(0) ?? "0";
      }

      // --- BƯỚC B: LẤY LỊCH SỬ GIAO DỊCH ---
      final historyRes = await ApiService.getWalletHistory(accessToken: token);
      if (historyRes.statusCode == 200) {
        final Map<String, dynamic> historyData = jsonDecode(historyRes.body);
        if (historyData['success'] == true) {
          _transactions = historyData['data'];
        }
      } else {
        _errorMessage = "Lỗi kết nối lịch sử (${historyRes.statusCode})";
      }

    } catch (e) {
      _errorMessage = "Đã có lỗi xảy ra: $e";
    } finally {
      // Kết thúc tải, cập nhật giao diện 1 lần duy nhất
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Lịch sử giao dịch"),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          )
        ],
      ),
      body: Column(
        children: [
          // Hiển thị số dư thực tế
          _buildBalanceCard(theme),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Biến động số dư",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorWidget()
                : _transactions.isEmpty
                ? const Center(child: Text("Bạn chưa có giao dịch nào."))
                : _buildTransactionList(theme),
          ),
        ],
      ),
    );
  }

  // 3. SỬA ĐOẠN HIỂN THỊ VÍ Ở ĐÂY
  Widget _buildBalanceCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Số dư ví BeluDriver", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          // Sử dụng biến _currentBalance đã lấy từ API
          Text(
            "$_currentBalance đ",
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _transactions[index];
        final num amount = item['amount'] ?? 0;
        final bool isNegative = amount < 0;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isNegative ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                child: Icon(
                  isNegative ? Icons.remove_circle_outline : Icons.add_circle_outline,
                  color: isNegative ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['type'] ?? "Giao dịch", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(_formatDateTime(item['createdDate']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                "${isNegative ? '' : '+'}$amount đ",
                style: TextStyle(fontWeight: FontWeight.bold, color: isNegative ? Colors.red : Colors.green),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _fetchData, child: const Text("Thử lại")),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return "--:--";
    try {
      final DateTime dt = DateTime.parse(dateStr);
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}";
    } catch (e) { return dateStr; }
  }
}