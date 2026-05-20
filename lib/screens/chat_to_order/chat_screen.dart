import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: const _ChatScreenView(),
    );
  }
}

class _ChatScreenView extends StatefulWidget {
  const _ChatScreenView();

  @override
  State<_ChatScreenView> createState() => _ChatScreenViewState();
}

class _ChatScreenViewState extends State<_ChatScreenView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color beluDarkGreen   = Color(0xFF0A422D);
  static const Color beluMediumGreen = Color(0xFF145E44);
  static const Color beluAccentGold  = Color(0xFFFFD700);
  static const Color bgCanvas        = Color(0xFFF0F4F2);

  // ── State ──────────────────────────────────────────────────────────────────
  String _accessToken    = '';
  bool   _isReady        = false;
  bool   _inputFocused   = false;

  ChatProvider? _provider;
  bool _didCaptureProvider = false;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initChatScreen();
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(() {
      setState(() => _inputFocused = _focusNode.hasFocus);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCaptureProvider) {
      _provider = context.read<ChatProvider>();
      _didCaptureProvider = true;
    }
  }

  Future<void> _initChatScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
    if (!mounted) return;

    setState(() {
      _accessToken = token;
      _isReady     = true;
    });

    if (_accessToken.isEmpty) return;

    final provider = _provider ?? context.read<ChatProvider>();
    await provider.initChat(accessToken: _accessToken, autoMarkRead: true);
    if (!mounted) return;

    await provider.connectRealtime(accessToken: _accessToken);
    if (!mounted) return;

    _scrollToBottom(jump: true);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final provider = _provider ?? context.read<ChatProvider>();

    if (_scrollController.position.pixels <= 80) {
      if (!provider.isLoadingOlderMessages && provider.hasMoreMessages) {
        provider.loadOlderMessages(accessToken: _accessToken);
      }
    }

    final max     = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if ((max - current) <= 80 && _accessToken.isNotEmpty) {
      provider.markAsRead(accessToken: _accessToken, silent: true);
    }
  }

  @override
  void dispose() {
    _provider?.disconnectRealtime();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent + 80;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _accessToken.isEmpty) return;

    final provider = _provider ?? context.read<ChatProvider>();
    final ok = await provider.sendMessage(
      accessToken: _accessToken,
      content: text,
    );

    if (ok) {
      _controller.clear();
      _scrollToBottom();
      await provider.markAsRead(accessToken: _accessToken, silent: true);
    }
  }

  String _buildTitle(ChatProvider provider) {
    if (provider.isInitializing) return 'Đang tải...';
    return 'Chat';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        final messages = provider.messages;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (messages.isNotEmpty) _scrollToBottom();
        });

        return Scaffold(
          backgroundColor: bgCanvas,
          appBar: _buildAppBar(provider),
          body: Column(
            children: [
              Expanded(
                child: !_isReady
                    ? const _FullScreenLoader()
                    : _buildBody(provider, messages),
              ),
              _buildInputArea(provider),
            ],
          ),
        );
      },
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(ChatProvider provider) {
    final connected = provider.isRealtimeConnected;

    return AppBar(
      elevation: 0,
      centerTitle: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [beluDarkGreen, beluMediumGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Avatar vòng tròn
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: beluAccentGold.withOpacity(0.2),
              border: Border.all(color: beluAccentGold.withOpacity(0.6), width: 1.5),
            ),
            child: const Icon(Icons.support_agent_rounded,
                color: beluAccentGold, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _buildTitle(provider),
                style: const TextStyle(
                  color: beluAccentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected ? Colors.greenAccent : Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────
  Widget _buildBody(ChatProvider provider, List<MessageModel> messages) {
    if (_accessToken.isEmpty) {
      return const _EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Chưa đăng nhập',
        subtitle: 'Phiên đăng nhập đã hết hạn.\nVui lòng đăng nhập lại.',
      );
    }

    if (provider.isInitializing && messages.isEmpty) {
      return const _FullScreenLoader();
    }

    if (provider.error != null && messages.isEmpty) {
      return _ErrorState(
        message: provider.error!,
        onRetry: () => provider.initChat(
          accessToken: _accessToken,
          autoMarkRead: true,
        ),
      );
    }

    if (messages.isEmpty) {
      return const _EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chưa có tin nhắn',
        subtitle: 'Hãy bắt đầu cuộc trò chuyện!',
      );
    }

    return Column(
      children: [
        // Loading older
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: provider.isLoadingOlderMessages
              ? const _LoadingOlderBanner(key: ValueKey('loading'))
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg  = messages[index];
              final prev = index > 0 ? messages[index - 1] : null;

              // Hiện date separator khi khác ngày với tin trước
              final showDateSep = prev == null ||
                  !_isSameDay(msg.createdAt, prev.createdAt);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDateSep) _DateSeparator(date: msg.createdAt),
                  _buildChatBubble(msg, prev),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Chat bubble ────────────────────────────────────────────────────────────
  Widget _buildChatBubble(MessageModel msg, MessageModel? prev) {
    if (msg.isRideSystemMessage) return _buildRideSystemBubble(msg);

    final isMe     = msg.isMe;
    final isSystem = msg.isSystem;

    // Gộp thời gian nếu cùng phút với tin trước
    final showTime = prev == null ||
        msg.createdAt.difference(prev.createdAt).inMinutes >= 1 ||
        prev.isMe != isMe;

    return TweenAnimationBuilder<double>(
      key: ValueKey(msg.id),
      duration: const Duration(milliseconds: 280),
      tween: Tween(begin: 0.85, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: showTime ? 10 : 3,
          left:  isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                    colors: [beluMediumGreen, beluDarkGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: isSystem
                      ? Colors.amber.shade50
                      : (isMe ? null : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(20),
                    topRight:    const Radius.circular(20),
                    bottomLeft:  Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMe
                          ? beluDarkGreen.withOpacity(0.18)
                          : Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: isSystem
                      ? Border.all(color: Colors.amber.shade200)
                      : (!isMe
                      ? Border.all(color: Colors.grey.shade100)
                      : null),
                ),
                child: Text(
                  msg.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ),
              if (showTime)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    _formatTime(msg.createdAt),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.black38,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ride system card ───────────────────────────────────────────────────────
  Widget _buildRideSystemBubble(MessageModel msg) {
    final ride        = msg.rideMeta;
    final isCreate    = msg.isRideCreatedMessage;
    final isCancelled = ride?.status == 5;

    // Màu theme theo trạng thái
    final Color headerBg;
    final Color borderColor;
    final Color iconColor;
    final IconData headerIcon;
    final String title;

    if (ride == null) {
      headerBg    = beluDarkGreen;
      borderColor = beluMediumGreen.withOpacity(0.3);
      iconColor   = beluAccentGold;
      headerIcon  = Icons.receipt_long_outlined;
      title       = isCreate ? 'Đơn đã được tạo' : 'Đơn đã được cập nhật';
    } else if (isCancelled) {
      headerBg    = const Color(0xFFC62828);
      borderColor = Colors.red.shade200;
      iconColor   = Colors.white;
      headerIcon  = Icons.cancel_outlined;
      title       = 'Đơn đã bị huỷ';
    } else if (isCreate) {
      headerBg    = beluDarkGreen;
      borderColor = beluMediumGreen.withOpacity(0.3);
      iconColor   = beluAccentGold;
      headerIcon  = Icons.add_circle_outline_rounded;
      title       = 'Đơn đã được tạo';
    } else {
      headerBg    = const Color(0xFF1565C0);
      borderColor = Colors.blue.shade200;
      iconColor   = Colors.white;
      headerIcon  = Icons.sync_rounded;
      title       = 'Đơn đã được cập nhật';
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey('ride_${msg.id}'),
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.92, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (_, value, child) => Transform.scale(
        scale: value,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header stripe ────────────────────────────────────────────
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: headerBg,
                child: Row(
                  children: [
                    Icon(headerIcon, color: iconColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(msg.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: iconColor.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.content.trim().isNotEmpty) ...[
                      Text(
                        msg.content.trim(),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                    ],
                    if (ride != null) ...[
                      _buildInfoChip(
                        Icons.tag_rounded,
                        'Mã đơn',
                        ride.code,
                        highlight: true,
                      ),
                      _buildInfoChip(
                        Icons.route_outlined,
                        'Tuyến',
                        '${ride.fromDistrictName ?? "--"} → ${ride.toDistrictName ?? "--"}',
                      ),
                      _buildInfoChip(
                        Icons.location_on_outlined,
                        'Điểm đón',
                        ride.fromAddress,
                      ),
                      _buildInfoChip(
                        Icons.flag_outlined,
                        'Điểm trả',
                        ride.toAddress,
                      ),
                      _buildInfoChip(
                        Icons.phone_outlined,
                        'Số điện thoại',
                        ride.customerPhone,
                      ),
                      _buildInfoChip(
                        Icons.access_time_rounded,
                        'Giờ đón',
                        ride.pickupTime == null
                            ? '--'
                            : _formatFullTime(ride.pickupTime!),
                      ),
                      const SizedBox(height: 4),
                      // Badge trạng thái
                      Row(
                        children: [
                          const Text(
                            'Trạng thái  ',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.black54,
                            ),
                          ),
                          _buildStatusBadge(ride.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoChip(
                        Icons.payment_outlined,
                        'Thanh toán',
                        ride.paymentMethodText.isEmpty
                            ? 'Tiền mặt'
                            : ride.paymentMethodText,
                      ),
                      _buildInfoChip(
                        Icons.people_outline_rounded,
                        'Số lượng',
                        ride.quantity.toString(),
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tổng tiền',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            _formatMoney(ride.finalPrice),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: beluDarkGreen,
                            ),
                          ),
                        ],
                      ),
                      if ((ride.note ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border:
                            Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.sticky_note_2_outlined,
                                  size: 15, color: Colors.amber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ride.note!.trim(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      // Ride null fallback
                      Text(
                        msg.content.isEmpty
                            ? 'Có thay đổi mới với đơn hàng của bạn.'
                            : msg.content,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatFullTime(msg.createdAt),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: beluMediumGreen),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: highlight ? beluDarkGreen : Colors.black87,
                fontWeight:
                highlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(int status) {
    final Color bg;
    final Color fg;
    final String label = _statusText(status);

    switch (status) {
      case 1:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case 2:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        break;
      case 3:
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade700;
        break;
      case 4:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 5:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  // ── Input area ─────────────────────────────────────────────────────────────
  Widget _buildInputArea(ChatProvider provider) {
    final disabled = _accessToken.isEmpty || provider.isSending;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 28,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            offset: const Offset(0, -3),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _inputFocused
                    ? Colors.white
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: _inputFocused
                      ? beluMediumGreen
                      : Colors.grey.shade200,
                  width: _inputFocused ? 1.5 : 1,
                ),
                boxShadow: _inputFocused
                    ? [
                  BoxShadow(
                    color: beluDarkGreen.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
                    : [],
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                minLines: 1,
                enabled: !disabled,
                cursorColor: beluDarkGreen,
                style:
                const TextStyle(color: Colors.black87, fontSize: 14.5),
                onSubmitted: (_) => _handleSendMessage(),
                decoration: InputDecoration(
                  hintText: provider.isSending
                      ? 'Đang gửi...'
                      : 'Nhập tin nhắn...',
                  hintStyle: const TextStyle(
                      color: Colors.black38, fontSize: 14.5),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: disabled
                  ? null
                  : const LinearGradient(
                colors: [beluMediumGreen, beluDarkGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              color: disabled ? Colors.grey.shade300 : null,
              boxShadow: disabled
                  ? []
                  : [
                BoxShadow(
                  color: beluDarkGreen.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: disabled ? null : _handleSendMessage,
                child: Center(
                  child: provider.isSending
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 19),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  String _formatTime(DateTime time) =>
      DateFormat('HH:mm').format(time.toLocal());

  String _formatFullTime(DateTime time) =>
      DateFormat('HH:mm dd/MM/yyyy').format(time.toLocal());

  String _formatMoney(double value) =>
      '${NumberFormat('#,###', 'vi_VN').format(value)} đ';

  String _statusText(int status) {
    switch (status) {
      case 1:  return 'Mới tạo';
      case 2:  return 'Đã nhận';
      case 3:  return 'Đang thực hiện';
      case 4:  return 'Hoàn tất';
      case 5:  return 'Đã huỷ';
      default: return 'Không xác định';
    }
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF145E44),
        strokeWidth: 2.5,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF0A422D).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: const Color(0xFF0A422D)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String    message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 34, color: Colors.red.shade400),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
              const TextStyle(fontSize: 14.5, color: Colors.black87),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0A422D),
                backgroundColor:
                const Color(0xFF0A422D).withOpacity(0.08),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _label() {
    final d     = date.toLocal();
    final today = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'Hôm nay';
    }
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Hôm qua';
    }
    return DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFD0D8D4), thickness: 1)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0A422D).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _label(),
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF0A422D),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Color(0xFFD0D8D4), thickness: 1)),
        ],
      ),
    );
  }
}

class _LoadingOlderBanner extends StatelessWidget {
  const _LoadingOlderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF145E44),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Đang tải tin nhắn cũ...',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}