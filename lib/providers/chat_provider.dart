import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/chat_to_order_api_service.dart';
import '../services/signalr_service.dart';
import '../services/chat_session.dart';

class ChatProvider extends ChangeNotifier {
  static const String _joinConversationMethod = 'JoinConversation';
  static const String _newMessageEventName = 'chat.message.created';

  int? _conversationId;
  List<MessageModel> _messages = [];

  bool _isInitializing = false;
  bool _isLoadingMessages = false;
  bool _isLoadingOlderMessages = false;
  bool _isSending = false;
  bool _isMarkingRead = false;
  bool _isRealtimeConnecting = false;
  bool _isRealtimeConnected = false;
  bool _isDisposed = false;

  bool _hasMoreMessages = false;
  int? _nextBeforeMessageId;

  String? _error;

  final SignalRService _signalRService = SignalRService();

  int? get conversationId => _conversationId;
  List<MessageModel> get messages => List.unmodifiable(_messages);

  bool get isInitializing => _isInitializing;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingOlderMessages => _isLoadingOlderMessages;
  bool get isSending => _isSending;
  bool get isMarkingRead => _isMarkingRead;
  bool get isRealtimeConnecting => _isRealtimeConnecting;
  bool get isRealtimeConnected => _isRealtimeConnected;

  bool get hasConversation => _conversationId != null;
  bool get hasMessages => _messages.isNotEmpty;
  bool get hasMoreMessages => _hasMoreMessages;
  int? get nextBeforeMessageId => _nextBeforeMessageId;

  bool get isBusy =>
      _isInitializing ||
      _isLoadingMessages ||
      _isLoadingOlderMessages ||
      _isSending ||
      _isMarkingRead ||
      _isRealtimeConnecting;

  String? get error => _error;

  void _log(String message) {
    debugPrint('💬 ChatProvider: $message');
  }

  void safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> initChat({bool autoMarkRead = true, int take = 30}) async {
    _log('initChat start');
    _isInitializing = true;
    _error = null;
    safeNotify();

    try {
      final convId = await ensureConversation();

      if (convId == null) {
        _error = 'Không mở được cuộc trò chuyện.';
        _isInitializing = false;
        _log('initChat failed: conversation is null');
        safeNotify();
        return;
      }

      final page = await ChatApiService.getMessages(
        conversationId: convId,
        take: take,
      );

      if (_messages.isEmpty) {
        _hasMoreMessages = page.hasMore;
        _nextBeforeMessageId = page.nextBeforeMessageId;
      }
      mergeMessages(page.items);

      _isInitializing = false;
      _log(
        'initChat done: conversationId=$convId, messages=${_messages.length}',
      );
      safeNotify();

      if (autoMarkRead && _messages.isNotEmpty) {
        await markAsRead(silent: true);
      }
    } catch (e) {
      _error = 'Đã có lỗi xảy ra, vui lòng thử lại.';
      _isInitializing = false;
      _log('initChat error: $e');
      safeNotify();
    }
  }

  Future<int?> ensureConversation() async {
    if (_isDisposed) return null;
    if (_conversationId != null) {
      _log('ensureConversation reuse: $_conversationId');
      return _conversationId;
    }

    try {
      _log('ensureConversation opening...');
      final convId = await ChatApiService.conversationOpen();

      if (convId != null) {
        _conversationId = convId;
        _log('ensureConversation success: $convId');
        safeNotify();
      }

      return convId;
    } catch (e) {
      _error = 'Không thể mở cuộc trò chuyện.';
      _log('ensureConversation error: $e');
      safeNotify();
      return null;
    }
  }

  Future<void> loadMessages({bool autoMarkRead = false, int take = 30}) async {
    if (_conversationId == null) {
      _error = 'Chưa có conversationId.';
      _log('loadMessages skipped: no conversationId');
      safeNotify();
      return;
    }

    _isLoadingMessages = true;
    _error = null;
    safeNotify();

    try {
      final page = await ChatApiService.getMessages(
        conversationId: _conversationId!,
        take: take,
      );

      if (_messages.isEmpty) {
        _hasMoreMessages = page.hasMore;
        _nextBeforeMessageId = page.nextBeforeMessageId;
      }
      mergeMessages(page.items);

      _isLoadingMessages = false;
      _log('loadMessages done: messages=${_messages.length}');
      safeNotify();

      if (autoMarkRead && _messages.isNotEmpty) {
        await markAsRead(silent: true);
      }
    } catch (e) {
      _error = 'Không thể tải tin nhắn.';
      _isLoadingMessages = false;
      _log('loadMessages error: $e');
      safeNotify();
    }
  }

  Future<void> loadOlderMessages({int take = 30}) async {
    if (_conversationId == null) return;
    if (_isLoadingOlderMessages) return;
    if (!_hasMoreMessages) return;
    if (_nextBeforeMessageId == null) return;

    _isLoadingOlderMessages = true;
    _error = null;
    safeNotify();

    try {
      final page = await ChatApiService.getMessages(
        conversationId: _conversationId!,
        beforeMessageId: _nextBeforeMessageId,
        take: take,
      );

      final oldIds = _messages.map((e) => e.id).toSet();
      final olderItems = page.items
          .where((e) => !oldIds.contains(e.id))
          .toList();

      _messages = [...olderItems, ..._messages];
      _hasMoreMessages = page.hasMore;
      _nextBeforeMessageId = page.nextBeforeMessageId;

      _isLoadingOlderMessages = false;
      _log(
        'loadOlderMessages done: added=${olderItems.length}, total=${_messages.length}',
      );
      safeNotify();
    } catch (e) {
      _error = 'Không thể tải thêm tin nhắn cũ.';
      _isLoadingOlderMessages = false;
      _log('loadOlderMessages error: $e');
      safeNotify();
    }
  }

  Future<void> connectRealtime() async {
    if (_isDisposed || _isRealtimeConnected || _isRealtimeConnecting) return;

    _isRealtimeConnecting = true;
    safeNotify();
    try {
      final convId = await ensureConversation();
      if (_isDisposed || convId == null) return;

      await _signalRService.connect(
        hubUrl: ChatApiService.chatHubUrl,
        accessTokenFactory: ChatSession.accessToken,
        configure: () {
          _signalRService.on(_newMessageEventName, _onRealtimeMessage);
          _signalRService.onReconnecting(({error}) {
            _isRealtimeConnected = false;
            _isRealtimeConnecting = true;
            safeNotify();
          });
          _signalRService.onReconnected(({connectionId}) async {
            await _joinAndSync(convId);
          });
          _signalRService.onClose(({error}) {
            _isRealtimeConnected = false;
            _isRealtimeConnecting = false;
            safeNotify();
            Future<void>.delayed(const Duration(seconds: 1), connectRealtime);
          });
        },
      );
      await _joinAndSync(convId);
    } catch (error) {
      _log('connectRealtime failed: ${error.runtimeType}');
    } finally {
      _isRealtimeConnecting = false;
      safeNotify();
    }
  }

  Future<void> _joinAndSync(int conversationId) async {
    if (_isDisposed) return;
    try {
      await _signalRService.invoke(
        _joinConversationMethod,
        args: [conversationId],
      );
      if (_isDisposed) return;
      _isRealtimeConnected = true;
      await loadMessages(autoMarkRead: true);
    } catch (error) {
      _isRealtimeConnected = false;
      _log('JoinConversation failed: ${error.runtimeType}');
    } finally {
      _isRealtimeConnecting = false;
      safeNotify();
    }
  }

  Future<void> _onRealtimeMessage(List<Object?>? arguments) async {
    if (_isDisposed || arguments == null || arguments.isEmpty) return;
    try {
      final raw = arguments.first;
      final data = raw is String ? jsonDecode(raw) : raw;
      if (data is! Map) return;
      final message = MessageModel.fromJson(Map<String, dynamic>.from(data));
      if (message.id <= 0 ||
          message.conversationId != _conversationId ||
          _messages.any((item) => item.id == message.id))
        return;
      addIncomingMessage(message);
      await markAsRead(silent: true);
    } catch (error) {
      _log('Invalid chat event: ${error.runtimeType}');
    }
  }

  Future<void> disconnectRealtime() async {
    _signalRService.off(_newMessageEventName);
    await _signalRService.disconnect();
    _isRealtimeConnected = false;
    _isRealtimeConnecting = false;
    safeNotify();
  }

  Future<bool> sendMessage({required String content}) async {
    final trimmed = content.trim();

    if (trimmed.isEmpty) {
      _error = 'Nội dung tin nhắn không được để trống.';
      safeNotify();
      return false;
    }

    final convId = await ensureConversation();
    if (convId == null) {
      _error = 'Không tạo được cuộc trò chuyện.';
      safeNotify();
      return false;
    }

    _isSending = true;
    _error = null;
    safeNotify();

    try {
      final sent = await ChatApiService.sendMessage(
        conversationId: convId,
        content: trimmed,
      );

      if (sent == null) {
        _error = 'Gửi tin nhắn thất bại.';
        _isSending = false;
        safeNotify();
        return false;
      }

      final exists = _messages.any((m) => m.id == sent.id);
      if (!exists) {
        _messages = [..._messages, sent];
      }

      _isSending = false;
      _log('sendMessage success: id=${sent.id}');
      safeNotify();

      return true;
    } catch (e) {
      _error = 'Không thể gửi tin nhắn.';
      _isSending = false;
      _log('sendMessage error: $e');
      safeNotify();
      return false;
    }
  }

  Future<bool> markAsRead({bool silent = false}) async {
    if (_conversationId == null) return false;

    if (!silent) {
      _isMarkingRead = true;
      _error = null;
      safeNotify();
    }

    try {
      final ok = await ChatApiService.markAsRead(
        conversationId: _conversationId!,
      );

      if (!silent) {
        _isMarkingRead = false;
        if (!ok) {
          _error = 'Đánh dấu đã đọc thất bại.';
        }
        safeNotify();
      }

      return ok;
    } catch (e) {
      if (!silent) {
        _error = 'Không thể cập nhật trạng thái đã đọc.';
        _isMarkingRead = false;
        safeNotify();
      }
      return false;
    }
  }

  void addIncomingMessage(MessageModel message) {
    if (_conversationId != null && message.conversationId != _conversationId) {
      _log('Ignore message from another conversation');
      return;
    }

    final exists = _messages.any((m) => m.id == message.id);
    if (exists) {
      _log('Skip duplicate incoming message id=${message.id}');
      return;
    }

    _messages = [..._messages, message]..sort((a, b) => a.id.compareTo(b.id));
    _log(
      'Incoming message appended: id=${message.id}, total=${_messages.length}',
    );
    safeNotify();
  }

  void mergeMessages(List<MessageModel> incoming) {
    final map = <int, MessageModel>{};

    for (final msg in _messages) {
      map[msg.id] = msg;
    }

    for (final msg in incoming) {
      map[msg.id] = msg;
    }

    final merged = map.values.toList()..sort((a, b) => a.id.compareTo(b.id));

    _messages = merged;
    safeNotify();
  }

  void clearError() {
    _error = null;
    safeNotify();
  }

  void reset() {
    _conversationId = null;
    _messages = [];
    _isInitializing = false;
    _isLoadingMessages = false;
    _isLoadingOlderMessages = false;
    _isSending = false;
    _isMarkingRead = false;
    _isRealtimeConnecting = false;
    _isRealtimeConnected = false;
    _hasMoreMessages = false;
    _nextBeforeMessageId = null;
    _error = null;
    safeNotify();
  }

  @override
  void dispose() {
    _log('dispose start');
    _isDisposed = true;
    disconnectRealtime();
    _log('dispose end');
    super.dispose();
  }
}
