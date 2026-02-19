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

  String _currentBalance = "0";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Lịch sử giao dịch",
          style: TextStyle(
            color: theme.colorScheme.secondary, // ✅ Vàng gold
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary), // ✅ Icon back vàng
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.secondary), // ✅ Icon refresh vàng
            onPressed: _fetchData,
          )
        ],
      ),
      body: Column(
        children: [
          _buildBalanceCard(theme),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Biến động số dư",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary, // ✅ Vàng gold
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorWidget(theme)
                : _transactions.isEmpty
                ? _buildEmptyState(theme)
                : _buildTransactionList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.secondary,
            theme.colorScheme.secondary.withOpacity(0.7)
          ], // ✅ Gradient vàng gold
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.secondary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Số dư ví BeluCar",
            style: TextStyle(
              color: Colors.black54, // ✅ Chữ đen nhạt
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$_currentBalance đ",
            style: const TextStyle(
              color: Colors.black87, // ✅ Chữ đen đậm
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.white30, // ✅ Divider trắng nhạt
      ),
      itemBuilder: (context, index) {
        final item = _transactions[index];
        final num amount = item['amount'] ?? 0;
        final bool isNegative = amount < 0;

        return Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isNegative
                    ? Colors.red.withOpacity(0.15)
                    : Colors.green.withOpacity(0.15),
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
                    Text(
                      item['type'] ?? "Giao dịch",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // ✅ Chữ trắng
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(item['createdDate']),
                      style: const TextStyle(
                        color: Colors.white70, // ✅ Chữ trắng nhạt
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "${isNegative ? '' : '+'}$amount đ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isNegative ? Colors.red.shade300 : Colors.green.shade300, // ✅ Màu sáng hơn
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: theme.colorScheme.secondary.withOpacity(0.5), // ✅ Icon vàng nhạt
          ),
          const SizedBox(height: 16),
          const Text(
            "Bạn chưa có giao dịch nào.",
            style: TextStyle(
              color: Colors.white70, // ✅ Chữ trắng nhạt
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh),
            label: const Text("Thử lại"),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary, // ✅ Nền vàng
              foregroundColor: Colors.black87, // ✅ Chữ đen
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return "--:--";
    try {
      final DateTime dt = DateTime.parse(dateStr);
      return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }
}