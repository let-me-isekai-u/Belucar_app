import 'dart:convert';

import 'package:belucar_app/features/carrier/carrier_screens.dart';
import 'package:belucar_app/models/booking_model.dart';
import 'package:belucar_app/screens/booking/booking2_screen.dart';
import 'package:belucar_app/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/customer_http_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('xe ghép can select and clear trip insurance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: Brand.theme(),
        home: ChangeNotifierProvider(
          create: (_) => BookingModel(),
          child: Booking2Screen(onRideBooked: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _checkInsuranceToggle(tester, find.byType(SingleChildScrollView));
  });

  for (final entry in categoryLabel.entries) {
    testWidgets('${entry.value} can toggle trip insurance without requoting', (
      tester,
    ) async {
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.url.path);
        final data = switch (request.url.path) {
          '/api/carrier/runs/1' => {
            'carrierName': 'Nhà xe mẫu',
            'vehicleCategory': entry.key,
            'routeName': 'Tuyến mẫu',
            'stops': <Map<String, Object>>[],
          },
          '/api/carrier/quotes' => {
            'unitPrice': 200000,
            'passengerCount': 1,
            'totalAmount': 200000,
          },
          '/api/carrier/refund-policy' => {'tiers': []},
          _ => throw StateError('Unexpected request: ${request.url.path}'),
        };
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await withCustomerHttp(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: Brand.theme(),
            home: const CarrierCheckoutScreen(
              runId: 1,
              pickup: 2,
              dropoff: 3,
              pax: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('${entry.value} · Tuyến mẫu'), findsOneWidget);
        final initialRequests = List.of(requests);
        expect(initialRequests, contains('/api/carrier/quotes'));

        await _checkInsuranceToggle(tester, find.byType(ListView));

        expect(requests, initialRequests);
      }, client);
    });
  }
}

Future<void> _checkInsuranceToggle(
  WidgetTester tester,
  Finder scrollView,
) async {
  final label = find.text('Bảo hiểm chuyến đi');
  await tester.scrollUntilVisible(
    label,
    150,
    scrollable: find
        .descendant(of: scrollView, matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
  final checkbox = find.widgetWithText(CheckboxListTile, 'Bảo hiểm chuyến đi');
  expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);

  await tester.tap(label);
  await tester.pumpAndSettle();
  expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);

  await tester.tap(
    find.descendant(of: checkbox, matching: find.byType(Checkbox)),
  );
  await tester.pumpAndSettle();
  expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
  expect(tester.takeException(), isNull);
}
