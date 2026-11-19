import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ui/brand.dart';

class CheckoutTotals extends StatelessWidget {
  const CheckoutTotals({
    super.key,
    required this.gross,
    required this.discount,
    required this.payable,
  });

  final num gross;
  final num discount;
  final num payable;

  static final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  Widget _row(String label, num amount, {bool total = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: total ? Brand.navy : Brand.inkMuted,
                fontWeight: total ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money.format(amount),
            style: TextStyle(
              color: total ? Brand.navy : Brand.ink,
              fontSize: total ? 18 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row('Tổng tiền trước giảm', gross),
        _row('Giảm giá', discount == 0 ? 0 : -discount),
        const Divider(),
        _row('Tổng thanh toán', payable, total: true),
      ],
    );
  }
}
