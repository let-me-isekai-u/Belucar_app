import 'dart:async';

import 'package:http/http.dart' as http;

final _clientKey = Object();
final _transport = _TestTransport();

// App-level clients keep their transport after the first request. Forward each
// request to the mock for the current test, even when the app reuses its client.
Future<T> withCustomerHttp<T>(Future<T> Function() body, http.Client client) =>
    runZoned(
      () => http.runWithClient(body, () => _transport),
      zoneValues: {_clientKey: client},
    );

class _TestTransport extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final client = Zone.current[_clientKey] as http.Client?;
    if (client == null) {
      throw StateError('HTTP request outside the customer test fixture');
    }
    return client.send(request);
  }
}
