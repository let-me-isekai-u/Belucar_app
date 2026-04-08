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

class _ChatScreenViewState extends State<_ChatScreenView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const Color beluDarkGreen = Color(0xFF0A422D);
  static const Color beluMediumGreen = Color(0xFF145E44);

  String _accessToken = '';
  bool _isReady = false;

  ChatProvider? _provider;
  bool _didCaptureProvider = false;

  @override
  void initState() {
    super.initState();
    _initChatScreen();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didCaptureProvider) {
      _provider = context.read<ChatProvider>();
      _didCaptureProvider = true;
      debugPrint('💬 ChatScreen: provider captured');
    }
  }

  Future<void> _initChatScreen() async {
    debugPrint('💬 ChatScreen: init start');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';

    if (!mounted) {
      debugPrint('💬 ChatScreen: unmounted before token ready');
      return;
    }

    setState(() {
      _accessToken = token;
      _isReady = true;
    });

    debugPrint('💬 ChatScreen: token loaded, hasToken=${_accessToken.isNotEmpty}');

    if (_accessToken.isEmpty) return;

    final provider = _provider ?? context.read<ChatProvider>();

    debugPrint('💬 ChatScreen: initChat()');
    await provider.initChat(
      accessToken: _accessToken,
      autoMarkRead: true,
    );

    if (!mounted) {
      debugPrint('💬 ChatScreen: unmounted after initChat');
      return;
    }

    debugPrint(
      '💬 ChatScreen: initChat done, conversationId=${provider.conversationId}, messages=${provider.messages.length}',
    );

    debugPrint('💬 ChatScreen: connectRealtime()');
    await provider.connectRealtime(
      accessToken: _accessToken,
    );

    if (!mounted) {
      debugPrint('💬 ChatScreen: unmounted after connectRealtime');
      return;
    }

    debugPrint(
      '💬 ChatScreen: connectRealtime done, isRealtimeConnected=${provider.isRealtimeConnected}',
    );

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

    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    final isNearBottom = (max - current) <= 80;

    if (isNearBottom && _accessToken.isNotEmpty) {
      provider.markAsRead(accessToken: _accessToken, silent: true);
    }
  }

  @override
  void dispose() {
    debugPrint('💬 ChatScreen: dispose start');
    _provider?.disconnectRealtime();

    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    debugPrint('💬 ChatScreen: dispose done');
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
    if (text.isEmpty) return;
    if (_accessToken.isEmpty) return;

    final provider = _provider ?? context.read<ChatProvider>();

    final ok = await provider.sendMessage(
      accessToken: _accessToken,
      content: text,
    );

    if (ok) {
      _controller.clear();
      _scrollToBottom();

      await provider.markAsRead(
        accessToken: _accessToken,
        silent: true,
      );
    }
  }

  String _buildTitle(ChatProvider provider) {
    if (provider.isInitializing) return 'Đang tải...';
    return 'Chat đặt đơn';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        final messages = provider.messages;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (messages.isNotEmpty) {
            _scrollToBottom();
          }
        });

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          appBar: AppBar(
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [beluDarkGreen, beluMediumGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _buildTitle(provider),
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: !_isReady
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(provider, messages),
              ),
              _buildInputArea(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ChatProvider provider, List<MessageModel> messages) {
    if (_accessToken.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Bạn chưa đăng nhập hoặc phiên đăng nhập đã hết hạn.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (provider.isInitializing && messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (provider.error != null && messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  provider.initChat(
                    accessToken: _accessToken,
                    autoMarkRead: true,
                  );
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chưa có tin nhắn nào. Hãy bắt đầu cuộc trò chuyện.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (provider.isLoadingOlderMessages)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              return _buildChatBubble(msg);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(MessageModel msg) {
    if (msg.isRideSystemMessage) {
      return _buildRideSystemBubble(msg);
    }

    final isMe = msg.isMe;
    final isSystem = msg.isSystem;
    final text = msg.content;

    return TweenAnimationBuilder(
      key: ValueKey(msg.id),
      duration: const Duration(milliseconds: 300),
      tween: Tween<double>(begin: 0.8, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && !isSystem)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  msg.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(14),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
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
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
                border:
                isSystem ? Border.all(color: Colors.amber.shade200) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSystem)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        msg.senderName.isEmpty ? 'System' : msg.senderName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(msg.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideSystemBubble(MessageModel msg) {
    final ride = msg.rideMeta;
    final isCreate = msg.isRideCreatedMessage;

    if (ride == null) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCreate ? 'Đơn đã được tạo' : 'Đơn đã được cập nhật',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: beluDarkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                msg.content.isEmpty
                    ? 'Có thay đổi mới với đơn hàng của bạn.'
                    : msg.content,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                _formatFullTime(msg.createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ),
      );
    }

    final isCancelled = ride.status == 5;
    final title = isCreate
        ? 'Đơn đã được tạo'
        : (isCancelled ? 'Đơn đã bị huỷ' : 'Đơn đã được cập nhật');

    return TweenAnimationBuilder(
      key: ValueKey('ride_${msg.id}'),
      duration: const Duration(milliseconds: 300),
      tween: Tween<double>(begin: 0.9, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isCancelled ? Colors.red.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCancelled ? Colors.red.shade200 : Colors.blue.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCancelled
                        ? Icons.cancel_outlined
                        : Icons.local_taxi_outlined,
                    color: isCancelled ? Colors.redAccent : beluDarkGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isCancelled ? Colors.redAccent : beluDarkGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (msg.content.trim().isNotEmpty) ...[
                Text(
                  msg.content.trim(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              _buildRideInfoRow('Mã đơn', ride.code),
              _buildRideInfoRow(
                'Tuyến',
                '${ride.fromDistrictName ?? "--"} → ${ride.toDistrictName ?? "--"}',
              ),
              _buildRideInfoRow('Điểm đón', ride.fromAddress),
              _buildRideInfoRow('Điểm trả', ride.toAddress),
              _buildRideInfoRow('Số điện thoại', ride.customerPhone),
              _buildRideInfoRow(
                'Giờ đón',
                ride.pickupTime == null ? '--' : _formatFullTime(ride.pickupTime!),
              ),
              _buildRideInfoRow('Trạng thái', _statusText(ride.status)),
              _buildRideInfoRow(
                'Thanh toán',
                ride.paymentMethodText.isEmpty
                    ? 'Tiền mặt'
                    : ride.paymentMethodText,
              ),
              _buildRideInfoRow('Số lượng', ride.quantity.toString()),
              _buildRideInfoRow('Tổng tiền', _formatMoney(ride.finalPrice)),
              if ((ride.note ?? '').trim().isNotEmpty)
                _buildRideInfoRow('Ghi chú', ride.note!.trim()),
              const SizedBox(height: 8),
              Text(
                _formatFullTime(msg.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatProvider provider) {
    final disabled = _accessToken.isEmpty || provider.isSending;

    return Container(
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 30, top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      minLines: 1,
                      enabled: !disabled,
                      cursorColor: beluDarkGreen,
                      style: const TextStyle(color: Colors.black),
                      onSubmitted: (_) => _handleSendMessage(),
                      decoration: InputDecoration(
                        hintText:
                        provider.isSending ? "Đang gửi..." : "Nhập tin nhắn...",
                        hintStyle: const TextStyle(
                          color: Colors.black38,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: disabled ? Colors.grey : beluDarkGreen,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: provider.isSending
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: disabled ? null : _handleSendMessage,
            ),
          )
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time.toLocal());
  }

  String _formatFullTime(DateTime time) {
    return DateFormat('HH:mm dd/MM/yyyy').format(time.toLocal());
  }

  String _formatMoney(double value) {
    return '${NumberFormat('#,###', 'vi_VN').format(value)} đ';
  }

  String _statusText(int status) {
    switch (status) {
      case 1:
        return 'Mới tạo';
      case 2:
        return 'Đã nhận';
      case 3:
        return 'Đang thực hiện';
      case 4:
        return 'Hoàn tất';
      case 5:
        return 'Đã huỷ';
      default:
        return 'Không xác định';
    }
  }
}