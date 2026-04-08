import 'dart:async';

import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:signalr_netcore/errors.dart';
import 'package:signalr_netcore/ihub_protocol.dart';

class BeluCarSignalRHttpClient extends SignalRHttpClient {
  final Logger? _logger;

  BeluCarSignalRHttpClient(this._logger);

  @override
  Future<SignalRHttpResponse> send(SignalRHttpRequest request) {
    if ((request.abortSignal != null) && request.abortSignal!.aborted!) {
      return Future.error(AbortError());
    }

    if ((request.method == null) || request.method!.isEmpty) {
      return Future.error(ArgumentError('No method defined.'));
    }

    if ((request.url == null) || request.url!.isEmpty) {
      return Future.error(ArgumentError('No url defined.'));
    }

    return Future<SignalRHttpResponse>(() async {
      final uri = Uri.parse(request.url!);
      final httpClient = Client();

      final abortFuture = Future<void>(() {
        final completer = Completer<void>();
        if (request.abortSignal != null) {
          request.abortSignal!.onabort = () {
            if (!completer.isCompleted) {
              completer.completeError(AbortError());
            }
          };
        }
        return completer.future;
      });

      final requestContent = request.content;
      final requestText = requestContent?.toString() ?? '';
      final isJson =
          requestContent is String && requestContent.trimLeft().startsWith('{');

      final headers = MessageHeaders();
      headers.setHeaderValue('X-Requested-With', 'FlutterHttpClient');
      headers.setHeaderValue(
        'content-type',
        isJson ? 'application/json;charset=UTF-8' : 'text/plain;charset=UTF-8',
      );
      headers.addMessageHeaders(request.headers);

      _logger?.finest(
        "HTTP send: url '${request.url}', method: '${request.method}' content: '$requestText' content length = '${requestText.length}' headers: '$headers'",
      );

      final httpRespFuture = await Future.any(
        [_sendHttpRequest(httpClient, request, uri, headers), abortFuture],
      );
      final httpResp = httpRespFuture as Response;

      if (request.abortSignal != null) {
        request.abortSignal!.onabort = null;
      }

      if (httpResp.statusCode >= 200 && httpResp.statusCode < 300) {
        final contentTypeHeader = httpResp.headers['content-type'];
        final isJsonContent = contentTypeHeader == null ||
            contentTypeHeader.startsWith('application/json');

        final content = httpResp.body;
        if (!isJsonContent && uri.queryParameters['id'] == null) {
          throw ArgumentError(
            'Response Content-Type not supported: $contentTypeHeader',
          );
        }

        return SignalRHttpResponse(
          httpResp.statusCode,
          statusText: httpResp.reasonPhrase,
          content: content,
        );
      }

      throw HttpError(httpResp.reasonPhrase, httpResp.statusCode);
    });
  }

  Future<Response> _sendHttpRequest(
    Client httpClient,
    SignalRHttpRequest request,
    Uri uri,
    MessageHeaders headers,
  ) {
    Future<Response> httpResponse;

    switch (request.method!.toLowerCase()) {
      case 'post':
        httpResponse =
            httpClient.post(uri, body: request.content, headers: headers.asMap);
        break;
      case 'put':
        httpResponse =
            httpClient.put(uri, body: request.content, headers: headers.asMap);
        break;
      case 'delete':
        httpResponse = httpClient.delete(
          uri,
          body: request.content,
          headers: headers.asMap,
        );
        break;
      case 'get':
      default:
        httpResponse = httpClient.get(uri, headers: headers.asMap);
    }

    final hasTimeout = (request.timeout != null) && (request.timeout! > 0);
    if (hasTimeout) {
      httpResponse =
          httpResponse.timeout(Duration(milliseconds: request.timeout!));
    }

    return httpResponse;
  }
}
