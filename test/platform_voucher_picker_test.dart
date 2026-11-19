import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/widgets/platform_voucher_picker.dart';
import 'support/customer_http_fixture.dart';

void main() {
  testWidgets('shows the applied voucher and returns the quote token', (
    tester,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    Map<String, dynamic>? selected;
    final busy = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlatformVoucherPicker(
            preview: (code, replacementId) {
              expect(code, 'DONGDUONG');
              expect(replacementId, isNull);
              return response.future;
            },
            onChange: (value) => selected = value,
            onBusy: busy.add,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'DONGDUONG');
    await tester.tap(find.text('Áp dụng'));
    await tester.pump();
    expect(busy, [true]);
    response.complete({
      'code': 'DONGDUONG',
      'title': 'Khuyến mãi thử',
      'discount': 30000,
      'payable': 170000,
      'token': 'protected-quote',
    });
    await tester.pumpAndSettle();
    expect(find.text('DONGDUONG · Khuyến mãi thử'), findsOneWidget);
    expect(selected?['payable'], 170000);
    expect(selected?['token'], 'protected-quote');
    expect(busy, [true, false]);
    await tester.tap(find.text('Bỏ mã'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('refreshes the catalog after saving a voucher', (tester) async {
    SharedPreferences.setMockInitialValues({'accessToken': 'fixture-token'});
    var saved = false;
    final client = MockClient((request) async {
      final data = switch ((request.method, request.url.path)) {
        ('GET', '/api/v2/ride/voucher-catalog') => {
          'items': [
            {
              'id': 1,
              'code': 'QASAVE',
              'title': 'Mã thử',
              'requireClaim': true,
              'saved': saved,
            },
          ],
        },
        ('GET', '/api/v2/ride/replacement-vouchers') => {'items': []},
        ('POST', '/api/v2/ride/voucher-catalog/1/claim') => {
          'saved': saved = true,
        },
        _ => throw StateError('Unexpected request: ${request.url.path}'),
      };
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);

    await withCustomerHttp(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlatformVoucherPicker(
              preview: (_, _) async => throw StateError('Unexpected preview'),
              onChange: (_) {},
              onBusy: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Kho ưu đãi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu mã'));
      await tester.pumpAndSettle();

      expect(saved, isTrue);
      expect(find.textContaining('setState()'), findsNothing);
      expect(find.text('Dùng mã'), findsOneWidget);
      expect(find.text('Lưu mã'), findsNothing);
    }, client);
  });
}
