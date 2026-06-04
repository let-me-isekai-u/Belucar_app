import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'belucar_signalr_http_client.dart';

class SignalRService {
  static const int _serverTimeoutInMilliseconds = 5 * 60 * 1000;
  static const int _keepAliveIntervalInMilliseconds = 15 * 1000;
  static bool _loggingInitialized = false;

  HubConnection? _connection;
  late final Logger _logger = Logger('BeluCar.SignalR');

  HubConnectionState? get state => _connection?.state;
  String? get connectionId => _connection?.connectionId;
  bool get isConnected => _connection?.state == HubConnectionState.Connected;
  bool get isReconnecting =>
      _connection?.state == HubConnectionState.Reconnecting;
  bool get isConnecting => _connection?.state == HubConnectionState.Connecting;

  void _ensureLoggingInitialized() {
    if (_loggingInitialized) return;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint(
        '[SignalR][${record.level.name}][${record.loggerName}] ${record.message}',
      );
    });

    _loggingInitialized = true;
  }

  Future<void> connect({
    required String hubUrl,
    required String accessToken,
  }) async {
    _ensureLoggingInitialized();

    if (_connection?.state == HubConnectionState.Connected ||
        _connection?.state == HubConnectionState.Connecting ||
        _connection?.state == HubConnectionState.Reconnecting) {
      return;
    }

    _connection = HubConnectionBuilder()
      .withUrl(
        hubUrl,
        options: HttpConnectionOptions(
          accessTokenFactory: () async => accessToken,
          // Production currently advertises LongPolling reliably for mobile.
          transport: HttpTransportType.LongPolling,
          httpClient: BeluCarSignalRHttpClient(_logger),
          logger: _logger,
          logMessageContent: true,
          requestTimeout: 60000,
        ),
      )
      .withAutomaticReconnect(
        retryDelays: const [0, 2000, 5000, 10000, 20000],
      )
      .configureLogging(_logger)
      .build();

    _connection!.serverTimeoutInMilliseconds = _serverTimeoutInMilliseconds;
    _connection!.keepAliveIntervalInMilliseconds =
        _keepAliveIntervalInMilliseconds;

    await _connection!.start();
  }

  Future<void> disconnect() async {
    if (_connection == null) return;

    try {
      await _connection!.stop();
    } catch (_) {}

    _connection = null;
  }

  Future<void> invoke(String methodName, {List<Object>? args}) async {
    if (_connection == null) {
      throw StateError(
        "Cannot invoke '$methodName' because HubConnection has not been created.",
      );
    }

    if (_connection!.state != HubConnectionState.Connected) {
      throw StateError(
        "Cannot invoke '$methodName' because HubConnection is in state ${_connection!.state}.",
      );
    }

    await _connection!.invoke(methodName, args: args);
  }

  void on(String eventName, void Function(List<Object?>? arguments) handler) {
    _connection?.on(eventName, handler);
  }

  void onClose(void Function({Exception? error}) handler) {
    _connection?.onclose(handler);
  }

  void onReconnecting(void Function({Exception? error}) handler) {
    _connection?.onreconnecting(handler);
  }

  void onReconnected(void Function({String? connectionId}) handler) {
    _connection?.onreconnected(handler);
  }

  void off(String eventName) {
    _connection?.off(eventName);
  }
}
