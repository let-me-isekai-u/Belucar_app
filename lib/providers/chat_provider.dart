import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/chat_to_order_api_service.dart';
import '../services/signalr_service.dart';

class ChatProvider extends ChangeNotifier {
  static const String _chatHubUrl = 'https://belucar.com/hubs/chat';
  static const String _joinConversationMethod = 'JoinConversation';
  static const String _newMessageEventName = 'chat.message.created';
  static const String _conversationChangedEventName =
      'chat.conversation.changed';

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
  bool _hasRegisteredRealtimeListeners = false;
  bool _hasRegisteredConnectionLifecycleListeners = false;

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

  Future<void> initChat({
    required String accessToken,
    bool autoMarkRead = true,
    int take = 30,
  }) async {
    _log('initChat start');
    _isInitializing = true;
    _error = null;
    safeNotify();

    try {
      final convId = await ensureConversation(accessToken: accessToken);

      if (convId == null) {
        _error = 'Không mở được cuộc trò chuyện.';
        _isInitializing = false;
        _log('initChat failed: conversation is null');
        safeNotify();
        return;
      }

      final page = await ChatApiService.getMessages(
        accessToken: accessToken,
        conversationId: convId,
        take: take,
      );

      _messages = page.items;
      _hasMoreMessages = page.hasMore;
      _nextBeforeMessageId = page.nextBeforeMessageId;

      _isInitializing = false;
      _log('initChat done: conversationId=$convId, messages=${_messages.length}');
      safeNotify();

      if (autoMarkRead && _messages.isNotEmpty) {
        await markAsRead(accessToken: accessToken, silent: true);
      }
    } catch (e) {
      _error = 'Đã có lỗi xảy ra, vui lòng thử lại.';
      _isInitializing = false;
      _log('initChat error: $e');
      safeNotify();
    }
  }

  Future<int?> ensureConversation({
    required String accessToken,
  }) async {
    if (_conversationId != null) {
      _log('ensureConversation reuse: $_conversationId');
      return _conversationId;
    }

    try {
      _log('ensureConversation opening...');
      final convId = await ChatApiService.conversationOpen(
        accessToken: accessToken,
      );

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

  Future<void> loadMessages({
    required String accessToken,
    bool autoMarkRead = false,
    int take = 30,
  }) async {
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
        accessToken: accessToken,
        conversationId: _conversationId!,
        take: take,
      );

      _messages = page.items;
      _hasMoreMessages = page.hasMore;
      _nextBeforeMessageId = page.nextBeforeMessageId;

      _isLoadingMessages = false;
      _log('loadMessages done: messages=${_messages.length}');
      safeNotify();

      if (autoMarkRead && _messages.isNotEmpty) {
        await markAsRead(accessToken: accessToken, silent: true);
      }
    } catch (e) {
      _error = 'Không thể tải tin nhắn.';
      _isLoadingMessages = false;
      _log('loadMessages error: $e');
      safeNotify();
    }
  }

  Future<void> loadOlderMessages({
    required String accessToken,
    int take = 30,
  }) async {
    if (_conversationId == null) return;
    if (_isLoadingOlderMessages) return;
    if (!_hasMoreMessages) return;
    if (_nextBeforeMessageId == null) return;

    _isLoadingOlderMessages = true;
    _error = null;
    safeNotify();

    try {
      final page = await ChatApiService.getMessages(
        accessToken: accessToken,
        conversationId: _conversationId!,
        beforeMessageId: _nextBeforeMessageId,
        take: take,
      );

      final oldIds = _messages.map((e) => e.id).toSet();
      final olderItems =
      page.items.where((e) => !oldIds.contains(e.id)).toList();

      _messages = [...olderItems, ..._messages];
      _hasMoreMessages = page.hasMore;
      _nextBeforeMessageId = page.nextBeforeMessageId;

      _isLoadingOlderMessages = false;
      _log('loadOlderMessages done: added=${olderItems.length}, total=${_messages.length}');
      safeNotify();
    } catch (e) {
      _error = 'Không thể tải thêm tin nhắn cũ.';
      _isLoadingOlderMessages = false;
      _log('loadOlderMessages error: $e');
      safeNotify();
    }
  }

  Future<void> connectRealtime({
    required String accessToken,
  }) async {
    final convId = await ensureConversation(accessToken: accessToken);
    if (convId == null) {
      _log('connectRealtime aborted: conversationId is null');
      return;
    }

    if (_isRealtimeConnected || _isRealtimeConnecting) {
      _log(
        'connectRealtime skipped: connected=$_isRealtimeConnected, connecting=$_isRealtimeConnecting',
      );
      return;
    }

    _isRealtimeConnecting = true;
    safeNotify();

    try {
      _log('SignalR connecting to $_chatHubUrl ...');
      await _signalRService.connect(
        hubUrl: _chatHubUrl,
        accessToken: accessToken,
      );
      _log('SignalR connected. state=${_signalRService.state}');

      if (!_hasRegisteredConnectionLifecycleListeners) {
        _log('Registering SignalR lifecycle listeners...');
        _registerConnectionLifecycleListeners(accessToken);
        _hasRegisteredConnectionLifecycleListeners = true;
        _log('SignalR lifecycle listeners registered');
      }

      if (!_hasRegisteredRealtimeListeners) {
        _log('Registering SignalR listeners...');
        _registerRealtimeListeners(accessToken);
        _hasRegisteredRealtimeListeners = true;
        _log('SignalR listeners registered');
      }

      _log('Invoking $_joinConversationMethod with conversationId=$convId');
      await _signalRService.invoke(
        _joinConversationMethod,
        args: [convId],
      );
      _log('JoinConversation success for conversationId=$convId');

      _isRealtimeConnected = true;
      _isRealtimeConnecting = false;
      safeNotify();
    } catch (e) {
      _isRealtimeConnected = false;
      _isRealtimeConnecting = false;
      _log('connectRealtime error: $e');
      safeNotify();
    }
  }

  void _registerConnectionLifecycleListeners(String accessToken) {
    _signalRService.onReconnecting(({error}) {
      _log('SignalR reconnecting... error=$error');
      _isRealtimeConnected = false;
      _isRealtimeConnecting = true;
      safeNotify();
    });

    _signalRService.onReconnected(({connectionId}) async {
      _log('SignalR reconnected. connectionId=$connectionId');

      if (_isDisposed || _conversationId == null) {
        _log('Skip rejoin after reconnect because provider disposed or conversation missing');
        return;
      }

      try {
        await _signalRService.invoke(
          _joinConversationMethod,
          args: [_conversationId!],
        );
        _log('Rejoined conversationId=$_conversationId after reconnect');

        _isRealtimeConnected = true;
        _isRealtimeConnecting = false;
        safeNotify();

        await loadMessages(
          accessToken: accessToken,
          autoMarkRead: false,
        );
      } catch (e) {
        _isRealtimeConnected = false;
        _isRealtimeConnecting = false;
        _log('Rejoin after reconnect error: $e');
        safeNotify();
      }
    });

    _signalRService.onClose(({error}) {
      _log('SignalR closed. error=$error');
      _isRealtimeConnected = false;
      _isRealtimeConnecting = false;
      safeNotify();
    });
  }

  void _registerRealtimeListeners(String accessToken) {
    _signalRService.off(_newMessageEventName);
    _signalRService.off(_conversationChangedEventName);

    _signalRService.on(_newMessageEventName, (arguments) async {
      _log('EVENT $_newMessageEventName received: $arguments');

      if (_isDisposed) {
        _log('Ignore $_newMessageEventName because provider disposed');
        return;
      }
      if (arguments == null || arguments.isEmpty) {
        _log('Ignore $_newMessageEventName because arguments empty');
        return;
      }

      try {
        final raw = arguments.first;
        _log('Raw event payload type=${raw.runtimeType}');

        if (raw is Map) {
          final message = MessageModel.fromJson(
            Map<String, dynamic>.from(raw),
          );

          _log(
            'Parsed message: id=${message.id}, conversationId=${message.conversationId}',
          );

          addIncomingMessage(message);

          if (message.conversationId == _conversationId) {
            await markAsRead(
              accessToken: accessToken,
              silent: true,
            );
          }
        } else {
          _log('Unsupported payload for $_newMessageEventName: ${raw.runtimeType}');
        }
      } catch (e) {
        _log('Parse $_newMessageEventName error: $e');
      }
    });

    _signalRService.on(_conversationChangedEventName, (arguments) async {
      _log('EVENT $_conversationChangedEventName received: $arguments');

      if (_isDisposed) {
        _log('Ignore $_conversationChangedEventName because provider disposed');
        return;
      }
      if (_conversationId == null) {
        _log('Ignore $_conversationChangedEventName because no conversationId');
        return;
      }

      await loadMessages(
        accessToken: accessToken,
        autoMarkRead: false,
      );
    });
  }

  Future<void> disconnectRealtime() async {
    _log('disconnectRealtime start');

    try {
      _signalRService.off(_newMessageEventName);
      _signalRService.off(_conversationChangedEventName);
      await _signalRService.disconnect();
    } catch (e) {
      _log('disconnectRealtime error: $e');
    }

    _hasRegisteredRealtimeListeners = false;
    _hasRegisteredConnectionLifecycleListeners = false;
    _isRealtimeConnected = false;
    _isRealtimeConnecting = false;
    _log('disconnectRealtime done');
    safeNotify();
  }

  Future<bool> sendMessage({
    required String accessToken,
    required String content,
  }) async {
    final trimmed = content.trim();

    if (trimmed.isEmpty) {
      _error = 'Nội dung tin nhắn không được để trống.';
      safeNotify();
      return false;
    }

    final convId = await ensureConversation(accessToken: accessToken);
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
        accessToken: accessToken,
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

  Future<bool> markAsRead({
    required String accessToken,
    bool silent = false,
  }) async {
    if (_conversationId == null) return false;

    if (!silent) {
      _isMarkingRead = true;
      _error = null;
      safeNotify();
    }

    try {
      final ok = await ChatApiService.markAsRead(
        accessToken: accessToken,
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
      _log(
        'Skip incoming message id=${message.id} because conversation mismatch: ${message.conversationId} != $_conversationId',
      );
      return;
    }

    final exists = _messages.any((m) => m.id == message.id);
    if (exists) {
      _log('Skip duplicate incoming message id=${message.id}');
      return;
    }

    _messages = [..._messages, message];
    _log('Incoming message appended: id=${message.id}, total=${_messages.length}');
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

    final merged = map.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

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
