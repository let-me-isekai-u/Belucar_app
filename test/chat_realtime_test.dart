import 'dart:async';
import 'dart:convert';

import 'package:belucar_app/providers/chat_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class TestHub {
  static const separator = '\u001e';
  final _events = StreamController<String>();
  late final _polls = StreamIterator<String>(_events.stream);
  final List<String> invocations = [];
  bool _firstPoll = true;

  void dropConnection() => _events.add('');

  void emit(String event, Map<String, dynamic> payload) {
    _queue({
      'type': 1,
      'target': event,
      'arguments': [payload],
    });
  }

  void _queue(Map<String, dynamic> payload) {
    _events.add('${jsonEncode(payload)}$separator');
  }

  Future<http.Response> handle(http.Request request) async {
    expect(request.url.host, 'datxedongduong.com');
    expect(request.headers['Authorization'], 'Bearer fixture-access');
    if (request.url.path.endsWith('/negotiate')) {
      _firstPoll = true;
      return http.Response(
        jsonEncode({
          'negotiateVersion': 1,
          'connectionId': 'fixture-id',
          'connectionToken': 'fixture-connection',
          'availableTransports': [
            {
              'transport': 'LongPolling',
              'transferFormats': ['Text'],
            },
          ],
        }),
        200,
      );
    }
    if (request.method == 'POST') {
      final payload = jsonDecode(request.body.split(separator).first) as Map;
      if (payload.containsKey('protocol')) {
        _queue({});
      } else if (payload['type'] == 1) {
        invocations.add(payload['target'] as String);
        _queue({'type': 3, 'invocationId': payload['invocationId']});
      }
    }
    if (request.method == 'GET') {
      if (_firstPoll) {
        _firstPoll = false;
      } else if (await _polls.moveNext()) {
        if (_polls.current.isEmpty) return http.Response('', 503);
        return http.Response.bytes(utf8.encode(_polls.current), 200);
      }
    }
    return http.Response('', 200);
  }

  Future<void> close() async {
    await _polls.cancel();
    await _events.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'customer receives messages once and catches up after reconnecting',
    () async {
      SharedPreferences.setMockInitialValues({'accessToken': 'fixture-access'});
      final hub = TestHub();
      var markReads = 0;
      final missed = <Map<String, Object>>[];
      final httpClient = MockClient((request) async {
        if (request.url.path.startsWith('/hubs/chat'))
          return hub.handle(request);
        final data = switch (request.url.path) {
          '/api/chat/customer/conversations/open' => {'conversationId': 4},
          '/api/chat/customer/conversations/4/messages' => {
            'items': missed,
            'hasMore': false,
          },
          _ => <String, dynamic>{},
        };
        if (request.url.path.endsWith('/mark-read')) markReads++;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'success': true, 'data': data})),
          200,
        );
      });

      await http.runWithClient(() async {
        final provider = ChatProvider();
        final received = Completer<void>();
        final reconnected = Completer<void>();
        provider.addListener(() {
          if (!received.isCompleted && provider.messages.length == 2) {
            received.complete();
          }
          if (!reconnected.isCompleted &&
              provider.isRealtimeConnected &&
              provider.messages.any((message) => message.id == 4)) {
            reconnected.complete();
          }
        });
        try {
          await provider.initChat();
          await provider.connectRealtime();
          expect(provider.isRealtimeConnected, true);
          expect(hub.invocations, ['JoinConversation']);
          final message = {
            'id': 2,
            'conversationId': 4,
            'content': 'Đông Dương đã trả lời',
          };
          hub.emit('chat.message.created', message);
          hub.emit('chat.message.created', message);
          hub.emit('chat.message.created', {
            'id': 3,
            'conversationId': 4,
            'content': 'Tin tiếp theo',
          });
          await received.future.timeout(const Duration(seconds: 5));
          expect(provider.messages.map((item) => item.content), [
            'Đông Dương đã trả lời',
            'Tin tiếp theo',
          ]);
          expect(markReads, lessThanOrEqualTo(2));

          missed.add({
            'id': 4,
            'conversationId': 4,
            'content': 'Tin lúc mất mạng',
          });
          hub.dropConnection();
          await reconnected.future.timeout(const Duration(seconds: 5));
          expect(hub.invocations, ['JoinConversation', 'JoinConversation']);
          expect(provider.messages.map((item) => item.id), [2, 3, 4]);
        } finally {
          await provider.disconnectRealtime();
          await hub.close();
          provider.dispose();
        }
      }, () => httpClient);
    },
  );
}
