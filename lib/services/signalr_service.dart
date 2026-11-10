import 'package:signalr_netcore/signalr_client.dart';

import 'belucar_signalr_http_client.dart';

class SignalRService {
  static const int _serverTimeoutInMilliseconds = 5 * 60 * 1000;
  static const int _keepAliveIntervalInMilliseconds = 15 * 1000;

  HubConnection? _connection;

  HubConnectionState? get state => _connection?.state;
  String? get connectionId => _connection?.connectionId;
  bool get isConnected => _connection?.state == HubConnectionState.Connected;
  bool get isReconnecting =>
      _connection?.state == HubConnectionState.Reconnecting;
  bool get isConnecting => _connection?.state == HubConnectionState.Connecting;

  Future<void> connect({
    required String hubUrl,
    required Future<String> Function() accessTokenFactory,
    required void Function() configure,
  }) async {
    if (_connection?.state == HubConnectionState.Connected ||
        _connection?.state == HubConnectionState.Connecting ||
        _connection?.state == HubConnectionState.Reconnecting) {
      return;
    }

    _connection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: accessTokenFactory,
            // Production currently advertises LongPolling reliably for mobile.
            transport: HttpTransportType.LongPolling,
            httpClient: BeluCarSignalRHttpClient(),
            logMessageContent: false,
            requestTimeout: 60000,
          ),
        )
        .withAutomaticReconnect(
          retryDelays: const [0, 2000, 5000, 10000, 20000],
        )
        .build();

    _connection!.serverTimeoutInMilliseconds = _serverTimeoutInMilliseconds;
    _connection!.keepAliveIntervalInMilliseconds =
        _keepAliveIntervalInMilliseconds;

    configure();
    await _connection!.start();
  }

  Future<void> disconnect() async {
    final connection = _connection;
    if (connection == null) return;
    _connection = null;

    try {
      await connection.stop();
    } catch (_) {}
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
    final connection = _connection;
    connection?.onclose(({error}) {
      if (identical(_connection, connection)) handler(error: error);
    });
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
