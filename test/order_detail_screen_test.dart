import 'dart:convert';

import 'package:belucar_app/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ride detail displays the phone saved for the passenger', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'accessToken': 'fixture-token'});
    final client = MockClient((request) async {
      expect(request.url.path, '/api/rideapi/ride-detail/7');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 7,
            'type': 1,
            'createdAt': '2026-11-10T08:00:00',
            'pickupTime': '2026-11-10T10:00:00',
            'customerPhone': '0900000000',
            'price': 200000,
            'finnalPrice': 200000,
            'discount': 0,
            'surcharge': 0,
            'status': 1,
          },
        }),
        200,
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: OrderDetailScreen(rideId: 7)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Số điện thoại người đi'), findsOneWidget);
      expect(find.text('0900000000'), findsOneWidget);
    }, () => client);
  });
}
