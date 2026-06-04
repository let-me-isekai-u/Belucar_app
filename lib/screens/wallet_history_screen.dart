import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../utils/currency_format.dart';
import 'account_ui.dart';

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  num _currentBalance = 0;

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
          _errorMessage = 'Phiên đăng nhập hết hạn.';
          _isLoading = false;
        });
        return;
      }

      final profileRes = await ApiService.getCustomerProfile(
        accessToken: token,
      );
      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        _currentBalance = _parseAmount(profileData['wallet']);
      }

      final historyRes = await ApiService.getWalletHistory(accessToken: token);
      if (historyRes.statusCode == 200) {
        final Map<String, dynamic> historyData = jsonDecode(historyRes.body);
        if (historyData['success'] == true) {
          _transactions = historyData['data'];
        }
      } else {
        _errorMessage = 'Lỗi kết nối lịch sử (${historyRes.statusCode})';
      }
    } catch (e) {
      _errorMessage = 'Đã có lỗi xảy ra: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AccountScaffold(
      appBar: AppBar(
        title: Text(
          'Lịch sử giao dịch',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.secondary,
            ),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBalanceCard(theme),
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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.secondary.withValues(alpha: 0.92),
            const Color(0xFFFFD166),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số dư ví hiện tại',
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatWalletAmount(_currentBalance),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        AccountSectionCard(
          title: 'Biến động số dư',
          subtitle:
              'Theo dõi các giao dịch nạp tiền, thanh toán và điều chỉnh.',
          icon: Icons.receipt_long_outlined,
          child: Column(
            children: List.generate(_transactions.length, (index) {
              final item = _transactions[index];
              final amount = _parseAmount(item['amount']);
              final bool isNegative = amount < 0;
              final color = isNegative ? Colors.redAccent : Colors.greenAccent;

              return Container(
                margin: EdgeInsets.only(
                  bottom: index == _transactions.length - 1 ? 0 : 12,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isNegative
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['type'] ?? 'Giao dịch',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(item['createdDate']),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatWalletAmount(amount, showPlusForPositive: true),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AccountSectionCard(
          title: 'Chưa có giao dịch',
          subtitle: 'Khi ví phát sinh biến động, lịch sử sẽ hiển thị tại đây.',
          icon: Icons.account_balance_wallet_outlined,
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 72,
                color: theme.colorScheme.secondary.withValues(alpha: 0.65),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bạn chưa có giao dịch nào.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AccountSectionCard(
          title: 'Không tải được dữ liệu',
          subtitle: _errorMessage,
          icon: Icons.error_outline_rounded,
          child: Column(
            children: [
              const SizedBox(height: 6),
              ElevatedButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '--:--';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  num _parseAmount(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
