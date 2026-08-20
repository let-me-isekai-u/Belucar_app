import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_theme.dart';
import '../../models/concert_models.dart';
import '../../providers/concert_provider.dart';
import 'concert_payment_screen.dart';

class ConcertLibraryScreen extends StatefulWidget {
  const ConcertLibraryScreen({super.key});

  @override
  State<ConcertLibraryScreen> createState() => _ConcertLibraryScreenState();
}

class _ConcertLibraryScreenState extends State<ConcertLibraryScreen> {
  bool _showTickets = false;
  String? _ticketStatus;

  Future<void> _openOrder(ConcertOrder order) async {
    final provider = context.read<ConcertProvider>();
    await provider.refreshOrder(order.orderCode);
    if (!mounted) return;
    if (provider.currentOrder?.orderCode != order.orderCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Không thể mở đơn này.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: ConcertPaymentScreen(orderCode: order.orderCode),
        ),
      ),
    );
  }

  Future<void> _openTicket(ConcertTicket ticket) async {
    final provider = context.read<ConcertProvider>();
    final detailed = ticket.qrImageBase64 != null || ticket.qrPayload != null
        ? ticket
        : await provider.loadTicket(ticket.ticketCode);
    if (!mounted) return;
    if (detailed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Không tải được mã vé.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConcertTicketScreen(ticket: detailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConcertProvider>();
    final tickets = provider.tickets
        .where(
          (ticket) => _ticketStatus == null || ticket.status == _ticketStatus,
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EC),
      appBar: AppBar(
        title: const Text('Vé xe concert'),
        centerTitle: true,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: SegmentedButton<bool>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected)
                      ? AppColors.accentGold
                      : Colors.white;
                }),
                foregroundColor: const WidgetStatePropertyAll(
                  AppColors.primaryGreen,
                ),
                iconColor: const WidgetStatePropertyAll(AppColors.primaryGreen),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                side: WidgetStateProperty.resolveWith((states) {
                  return BorderSide(
                    color: states.contains(WidgetState.selected)
                        ? AppColors.accentGold
                        : AppColors.primaryGreen,
                    width: 1.4,
                  );
                }),
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Đơn hàng'),
                  icon: Icon(Icons.receipt_long_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Vé của tôi'),
                  icon: Icon(Icons.qr_code_2_rounded),
                ),
              ],
              selected: <bool>{_showTickets},
              onSelectionChanged: (value) =>
                  setState(() => _showTickets = value.first),
            ),
          ),
          if (_showTickets)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Tất cả',
                    selected: _ticketStatus == null,
                    onSelected: () => setState(() => _ticketStatus = null),
                  ),
                  _FilterChip(
                    label: 'Còn hiệu lực',
                    selected: _ticketStatus == 'ISSUED',
                    onSelected: () => setState(() => _ticketStatus = 'ISSUED'),
                  ),
                  _FilterChip(
                    label: 'Đã dùng',
                    selected: _ticketStatus == 'USED',
                    onSelected: () => setState(() => _ticketStatus = 'USED'),
                  ),
                ],
              ),
            ),
          Expanded(
            child:
                provider.loadingLibrary &&
                    provider.orders.isEmpty &&
                    provider.tickets.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: provider.loadLibrary,
                    child: _showTickets
                        ? _TicketList(
                            tickets: tickets,
                            onOpen: _openTicket,
                            emptyMessage: provider.guestMode
                                ? 'Chưa có vé đã thanh toán trên thiết bị này.'
                                : 'Bạn chưa có vé concert.',
                          )
                        : _OrderList(
                            orders: provider.orders,
                            onOpen: _openOrder,
                            emptyMessage: provider.guestMode
                                ? 'Không có đơn guest đã lưu trên thiết bị này.'
                                : 'Bạn chưa có đơn concert.',
                          ),
                  ),
          ),
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.onOpen,
    required this.emptyMessage,
  });

  final List<ConcertOrder> orders;
  final ValueChanged<ConcertOrder> onOpen;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return _EmptyList(message: emptyMessage);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final order = orders[index];
        final color = _orderColor(order.status);
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => onOpen(order),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.orderCode,
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _StatusPill(
                        text: concertOrderStatusLabel(order.status),
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    order.eventName.isEmpty
                        ? 'BIGBANG Concert Mỹ Đình 2026'
                        : order.eventName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${order.totalQuantity} vé • ${_money(order.totalAmount)}',
                  ),
                  if (order.createdAt != null)
                    Text(
                      DateFormat('HH:mm dd/MM/yyyy').format(order.createdAt!),
                      style: const TextStyle(color: Colors.black54),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({
    required this.tickets,
    required this.onOpen,
    required this.emptyMessage,
  });

  final List<ConcertTicket> tickets;
  final ValueChanged<ConcertTicket> onOpen;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) return _EmptyList(message: emptyMessage);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _TicketCard(
        ticket: tickets[index],
        onTap: () => onOpen(tickets[index]),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final ConcertTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _ticketColor(ticket.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.accentGold,
                  size: 30,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.ticketCode,
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${concertDirectionLabel(ticket.direction)} • ${_date(ticket.serviceDate)}',
                    ),
                    Text(
                      '${ticket.stopName} • ${ticket.vehicleTypeName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                text: concertTicketStatusLabel(ticket.status),
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConcertTicketListScreen extends StatelessWidget {
  const ConcertTicketListScreen({super.key, required this.tickets});

  final List<ConcertTicket> tickets;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F5EC),
    appBar: AppBar(
      title: Text('${tickets.length} vé đã phát hành'),
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
    ),
    body: _TicketList(
      tickets: tickets,
      emptyMessage: 'Vé đang được phát hành. Vui lòng tải lại đơn.',
      onOpen: (ticket) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ConcertTicketScreen(ticket: ticket)),
      ),
    ),
  );
}

class ConcertTicketScreen extends StatelessWidget {
  const ConcertTicketScreen({super.key, required this.ticket});

  final ConcertTicket ticket;

  @override
  Widget build(BuildContext context) {
    final qrBytes = _decodeBase64(ticket.qrImageBase64);
    final statusColor = _ticketColor(ticket.status);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3E9),
      appBar: AppBar(
        title: const Text('Chi tiết vé'),
        centerTitle: true,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Color(0x16000000), blurRadius: 22),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'BIGBANG CONCERT MỸ ĐÌNH 2026',
                        style: TextStyle(
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        ticket.ticketCode,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: qrBytes != null
                            ? Image.memory(qrBytes, width: 230, height: 230)
                            : ticket.qrPayload != null
                            ? QrImageView(
                                data: ticket.qrPayload!,
                                size: 230,
                                backgroundColor: Colors.white,
                              )
                            : const SizedBox(
                                width: 230,
                                height: 230,
                                child: Center(
                                  child: Text(
                                    'Chưa tải được QR. Vui lòng mở lại vé khi có mạng.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                      ),
                      const Text('Đưa mã này cho tài xế để kiểm vé'),
                      const SizedBox(height: 14),
                      _StatusPill(
                        text: concertTicketStatusLabel(ticket.status),
                        color: statusColor,
                      ),
                      const Divider(height: 28),
                      _InfoRow(label: 'Ngày', value: _date(ticket.serviceDate)),
                      _InfoRow(
                        label: 'Chiều',
                        value: concertDirectionLabel(ticket.direction),
                      ),
                      _InfoRow(label: 'Tuyến', value: ticket.routeName),
                      _InfoRow(label: 'Điểm đón/trả', value: ticket.stopName),
                      _InfoRow(label: 'Loại xe', value: ticket.vehicleTypeName),
                      if (ticket.usedAt != null)
                        _InfoRow(
                          label: 'Đã dùng lúc',
                          value: DateFormat(
                            'HH:mm dd/MM/yyyy',
                          ).format(ticket.usedAt!),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primaryGreen,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.primaryGreen),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.accentGold : AppColors.primaryGreen,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 100),
      const Icon(
        Icons.confirmation_num_outlined,
        size: 62,
        color: Color(0xFF557269),
      ),
      const SizedBox(height: 12),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.primaryGreen,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

Uint8List? _decodeBase64(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}

String _date(DateTime? value) =>
    value == null ? 'Chưa cập nhật' : DateFormat('dd/MM/yyyy').format(value);

String _money(num value) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'đ',
  decimalDigits: 0,
).format(value);

Color _orderColor(String status) => switch (status) {
  'PAID' => const Color(0xFF168A4F),
  'PAYMENT_REVIEW' => const Color(0xFFB16B00),
  'EXPIRED' => Colors.redAccent,
  _ => const Color(0xFF2475C5),
};

Color _ticketColor(String status) => switch (status) {
  'ISSUED' => const Color(0xFF168A4F),
  'USED' => const Color(0xFF6B7280),
  _ => Colors.redAccent,
};
