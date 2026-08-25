import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../models/concert_models.dart';
import '../../providers/concert_provider.dart';
import 'concert_library_screen.dart';

class ConcertPaymentScreen extends StatefulWidget {
  const ConcertPaymentScreen({super.key, required this.orderCode});

  final String orderCode;

  @override
  State<ConcertPaymentScreen> createState() => _ConcertPaymentScreenState();
}

class _ConcertPaymentScreenState extends State<ConcertPaymentScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  Timer? _resendCooldownTimer;
  int _resendSeconds = 0;
  bool _foreground = true;
  bool _resending = false;
  bool _savingQr = false;
  bool _pollingNow = false;
  int _pollDelaySeconds = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAndSchedule());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _refreshAndSchedule();
    } else {
      _pollTimer?.cancel();
    }
  }

  Future<void> _refreshAndSchedule({bool manual = false}) async {
    if (!mounted || !_foreground || _pollingNow) return;
    if (manual) _pollDelaySeconds = 5;
    setState(() => _pollingNow = true);
    final provider = context.read<ConcertProvider>();
    try {
      final refreshed = await provider.refreshOrder(widget.orderCode);
      if (!mounted) return;
      _pollDelaySeconds = refreshed ? 5 : (_pollDelaySeconds * 2).clamp(5, 30);
      _pollTimer?.cancel();
      if (provider.currentOrder?.shouldPoll == true) {
        _pollTimer = Timer(
          Duration(seconds: _pollDelaySeconds),
          _refreshAndSchedule,
        );
      }
    } finally {
      if (mounted) setState(() => _pollingNow = false);
    }
  }

  Future<void> _resendEmail() async {
    if (_resending || _resendSeconds > 0) return;
    setState(() => _resending = true);
    final provider = context.read<ConcertProvider>();
    final error = await provider.resendEmail(widget.orderCode);
    if (!mounted) return;
    setState(() => _resending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Email vé đã được đưa vào hàng đợi gửi lại.'),
      ),
    );
    if (error != null) return;
    setState(() => _resendSeconds = 45);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  void _openTickets(ConcertOrder order) {
    final showGuestLoginNotice = context.read<ConcertProvider>().guestMode;
    if (order.tickets.length == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConcertTicketScreen(
            ticket: order.tickets.single,
            showGuestLoginNotice: showGuestLoginNotice,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConcertTicketListScreen(
          tickets: order.tickets,
          showGuestLoginNotice: showGuestLoginNotice,
        ),
      ),
    );
  }

  Future<void> _saveQrImage(ConcertPayment payment) async {
    final qrImageUrl = payment.qrImageUrl;
    _qrTerminalLog(
      'save tapped: orderCode=${widget.orderCode}, '
      'saving=$_savingQr, hasQrUrl=${qrImageUrl?.trim().isNotEmpty == true}',
    );
    if (_savingQr) {
      _qrTerminalLog('save skipped: already saving');
      return;
    }
    if (qrImageUrl == null || qrImageUrl.trim().isEmpty) {
      _qrTerminalLog('save failed: missing qrImageUrl');
      _showMessage('Không tìm thấy ảnh QR để lưu.');
      return;
    }
    final uri = Uri.tryParse(qrImageUrl.trim());
    if (uri == null || !uri.hasScheme) {
      _qrTerminalLog('save failed: invalid qrImageUrl=$qrImageUrl');
      _showMessage('Không tìm thấy đường dẫn ảnh QR hợp lệ.');
      return;
    }

    setState(() => _savingQr = true);
    try {
      _qrTerminalLog('download started: host=${uri.host}, path=${uri.path}');
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      _qrTerminalLog(
        'download response: status=${response.statusCode}, '
        'bytes=${response.bodyBytes.length}, '
        'contentType=${response.headers['content-type'] ?? '-'}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _qrTerminalLog(
          'save failed: reason=http, status=${response.statusCode}',
        );
        _showMessage('Không tải được ảnh QR để lưu.');
        return;
      }
      await Gal.putImageBytes(
        response.bodyBytes,
        name: 'belucar_concert_qr_${widget.orderCode}',
      );
      _qrTerminalLog('save success: orderCode=${widget.orderCode}');
      if (!mounted) return;
      _showMessage('Đã lưu mã QR vào thư viện ảnh.');
    } on GalException catch (error) {
      _qrTerminalLog(
        'save failed: reason=gallery, type=${error.type.name}, '
        'code=${error.type.code}, message=${error.type.message}, '
        'platformCode=${error.platformException.code}, '
        'platformMessage=${error.platformException.message ?? '-'}, '
        'platformDetails=${error.platformException.details ?? '-'}',
      );
      if (!mounted) return;
      final message = switch (error.type) {
        GalExceptionType.accessDenied =>
          'Bạn cần cấp quyền truy cập ảnh để lưu mã QR.',
        GalExceptionType.notEnoughSpace => 'Thiết bị không đủ dung lượng.',
        GalExceptionType.notSupportedFormat =>
          'Định dạng ảnh QR không được hỗ trợ.',
        GalExceptionType.unexpected => 'Không thể lưu mã QR. Vui lòng thử lại.',
      };
      _showMessage(message);
    } catch (error, stackTrace) {
      _qrTerminalLog('save failed: unexpected=$error');
      _qrTerminalLog('stackTrace=$stackTrace');
      if (!mounted) return;
      _showMessage('Không thể lưu mã QR. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _savingQr = false);
    }
  }

  void _qrTerminalLog(String message) {
    // ignore: avoid_print
    print('[ConcertQR] $message');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConcertProvider>();
    final order = provider.currentOrder;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EC),
      appBar: AppBar(
        title: const Text('Thanh toán vé concert'),
        centerTitle: true,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.accentGold,
      ),
      body: order == null
          ? _LoadingOrder(
              loading: provider.refreshingOrder,
              message: provider.errorMessage,
              onRetry: _refreshAndSchedule,
            )
          : RefreshIndicator(
              onRefresh: () => _refreshAndSchedule(manual: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  if (order.status == 'PENDING_PAYMENT' &&
                      order.payment != null) ...[
                    _PaymentCard(
                      payment: order.payment!,
                      savingQr: _savingQr,
                      onSaveQr: () => _saveQrImage(order.payment!),
                    ),
                    const SizedBox(height: 10),
                    _buildPollingControl(
                      loading: provider.refreshingOrder || _pollingNow,
                      nextDelaySeconds: _pollDelaySeconds,
                      onRefresh: () => _refreshAndSchedule(manual: true),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (order.status != 'PENDING_PAYMENT') ...[
                    _StatusCard(order: order),
                    const SizedBox(height: 14),
                  ],
                  _OrderSummary(order: order),
                  if (order.status == 'PAID') ...[
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: order.tickets.isEmpty
                          ? _refreshAndSchedule
                          : () => _openTickets(order),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: Text(
                        order.tickets.isEmpty
                            ? 'TẢI LẠI VÉ'
                            : 'XEM ${order.tickets.length} VÉ',
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: AppColors.accentGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _resending || _resendSeconds > 0
                          ? null
                          : _resendEmail,
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: Text(
                        _resendSeconds > 0
                            ? 'Gửi lại sau ${_resendSeconds}s'
                            : 'Gửi lại email vé',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                  if (provider.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPollingControl({
    required bool loading,
    required int nextDelaySeconds,
    required VoidCallback onRefresh,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFAEC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.accentGold),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              loading ? Icons.sync_rounded : Icons.hourglass_top_rounded,
              color: AppColors.accentGold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loading
                    ? 'Đang kiểm tra trạng thái thanh toán...'
                    : 'Tự kiểm tra lại sau khoảng $nextDelaySeconds giây.',
                style: const TextStyle(
                  color: Color(0xFF202020),
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: const Text('Kiểm tra lại'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF202020),
            disabledForegroundColor: const Color(0xFF606060),
            side: const BorderSide(color: AppColors.accentGold),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});

  final ConcertOrder order;

  @override
  Widget build(BuildContext context) {
    final (color, icon, message) = switch (order.status) {
      'PAID' => (
        const Color(0xFF168A4F),
        Icons.check_circle_rounded,
        'Thanh toán thành công. Vé của bạn đã được phát hành.',
      ),
      'PAYMENT_REVIEW' => (
        const Color(0xFFB16B00),
        Icons.manage_search_rounded,
        'Giao dịch cần được đối soát. Vui lòng liên hệ hỗ trợ và không tự chuyển thêm tiền.',
      ),
      'EXPIRED' => (
        Colors.redAccent,
        Icons.timer_off_outlined,
        'Đơn đã hết hạn và không thể tiếp tục thanh toán.',
      ),
      _ => (
        const Color(0xFF2475C5),
        Icons.hourglass_top_rounded,
        'Đang chờ giao dịch ngân hàng. Ứng dụng sẽ tự kiểm tra mỗi 5 giây.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concertOrderStatusLabel(order.status),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF202020),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});

  final ConcertOrder order;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thông tin đơn',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _ValueRow(label: 'Mã đơn', value: order.orderCode, selectable: true),
        _ValueRow(label: 'Số lượng', value: '${order.totalQuantity} vé'),
        _ValueRow(label: 'Tổng tiền', value: _money(order.totalAmount)),
        if (order.expiresAt != null)
          _ValueRow(
            label: 'Hết hạn',
            value: DateFormat('HH:mm dd/MM/yyyy').format(order.expiresAt!),
          ),
        const Divider(height: 24),
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.directions_bus_filled_outlined,
                  color: Colors.black,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.serviceName} × ${item.quantity}',
                        style: const TextStyle(
                          color: Color(0xFF202020),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${item.routeName} • ${item.stopName}',
                        style: const TextStyle(
                          color: Color(0xFF202020),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.vehicleTypeName,
                        style: const TextStyle(
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _money(item.lineTotal),
                  style: const TextStyle(
                    color: Color(0xFF202020),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.savingQr,
    required this.onSaveQr,
  });

  final ConcertPayment payment;
  final bool savingQr;
  final VoidCallback onSaveQr;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final qrHeight = (screenSize.height * 0.72).clamp(420.0, 680.0);
    return _Card(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      child: Column(
        children: [
          const Text(
            'Quét VietQR để thanh toán',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF202020),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (payment.qrImageUrl != null)
            Container(
              width: double.infinity,
              height: qrHeight,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6D59B)),
              ),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 3,
                child: Image.network(
                  payment.qrImageUrl!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => const Center(
                    child: Text(
                      'Không tải được ảnh QR. Hãy chuyển khoản thủ công.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF202020),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Server chưa trả ảnh QR. Hãy chuyển khoản thủ công theo thông tin bên dưới.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF202020),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: payment.qrImageUrl == null || savingQr
                  ? null
                  : onSaveQr,
              icon: savingQr
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF202020),
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                savingQr ? 'Đang lưu ảnh...' : 'Lưu mã QR',
                style: const TextStyle(color: Color(0xFF202020)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: const Color(0xFF202020),
                disabledBackgroundColor: const Color(0xFFE9C56A),
                disabledForegroundColor: const Color(0xFF202020),
                minimumSize: const Size(double.infinity, 52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(17)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: Color(0x0E000000), blurRadius: 16)],
    ),
    child: child,
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF303030),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: selectable
              ? SelectableText(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF202020),
                    fontWeight: FontWeight.w900,
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF202020),
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ],
    ),
  );
}

class _LoadingOrder extends StatelessWidget {
  const _LoadingOrder({
    required this.loading,
    required this.message,
    required this.onRetry,
  });

  final bool loading;
  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: loading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message ?? 'Không tải được thông tin đơn.'),
                TextButton(onPressed: onRetry, child: const Text('Thử lại')),
              ],
            ),
    ),
  );
}

String _money(num value) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'đ',
  decimalDigits: 0,
).format(value);
