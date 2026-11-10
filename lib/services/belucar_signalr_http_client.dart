import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:signalr_netcore/errors.dart';
import 'package:signalr_netcore/signalr_client.dart';

class BeluCarSignalRHttpClient extends SignalRHttpClient {
  Future<void>? _handshakePost;

  @override
  Future<SignalRHttpResponse> send(SignalRHttpRequest request) async {
    final abortSignal = request.abortSignal;
    if (abortSignal?.aborted == true) throw AbortError();

    final client = Client();
    final aborted = Completer<Response>();
    abortSignal?.onabort = () {
      if (!aborted.isCompleted) aborted.completeError(AbortError());
    };

    try {
      final outgoing = Request(request.method!, Uri.parse(request.url!));
      final content = request.content;
      final handshake = outgoing.method == 'POST' &&
              content is String &&
              content.startsWith('{"protocol":')
          ? Completer<void>()
          : null;
      if (handshake != null) _handshakePost = handshake.future;
      outgoing.headers.addAll({
        'X-Requested-With': 'FlutterHttpClient',
        'content-type': 'text/plain; charset=utf-8',
        ...?request.headers?.asMap,
      });
      if (content is String) outgoing.body = content;

      var pending = Future.any([
        client.send(outgoing).then(Response.fromStream),
        aborted.future,
      ]);
      final timeout = request.timeout;
      if (timeout != null && timeout > 0) {
        pending = pending.timeout(
          Duration(milliseconds: timeout),
          onTimeout: () => throw TimeoutError(),
        );
      }
      final Response response;
      try {
        response = await pending;
      } finally {
        // The SDK starts waiting for the handshake after its POST completes.
        // Deliver a parallel poll's handshake frame after that continuation.
        if (handshake != null) Timer.run(handshake.complete);
      }
      if (outgoing.method == 'GET' && response.bodyBytes.isNotEmpty) {
        await _handshakePost;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpError(response.reasonPhrase, response.statusCode);
      }
      return SignalRHttpResponse(
        response.statusCode,
        statusText: response.reasonPhrase,
        content: utf8.decode(response.bodyBytes),
      );
    } finally {
      abortSignal?.onabort = null;
      client.close();
    }
  }
}
