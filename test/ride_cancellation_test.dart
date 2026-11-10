import 'dart:convert';

import 'package:belucar_app/screens/activity_screen.dart';
import 'package:belucar_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cancellation preserves its route and key after session renewal',
    () async {
      SharedPreferences.setMockInitialValues({
        'accessToken': 'expired-cancellation-token',
        'refreshToken': 'cancellation-refresh-before',
      });
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/refresh-token')) {
          return http.Response(
            '{"accessToken":"renewed","refreshToken":"cancellation-refresh-after"}',
            200,
          );
        }
        if (request.headers['Authorization'] ==
            'Bearer expired-cancellation-token') {
          return http.Response('', 401);
        }
        return http.Response('{"success":true}', 200);
      });

      await http.runWithClient(() async {
        await ApiService.cancelTrip(
          accessToken: 'expired-cancellation-token',
          rideId: 7,
          confirmed: true,
          idempotencyKey: 'cancel-confirmed-fixture',
        );
      }, () => client);

      expect(requests.map((request) => request.url.path), [
        '/api/rideapi/cancel-confirmed/7',
        '/api/accountcustomerapi/refresh-token',
        '/api/rideapi/cancel-confirmed/7',
      ]);
      expect(requests.last.method, 'PUT');
      expect(requests.last.headers['Authorization'], 'Bearer renewed');
      expect(
        requests.first.headers['Idempotency-Key'],
        'cancel-confirmed-fixture',
      );
      expect(
        requests.last.headers['Idempotency-Key'],
        'cancel-confirmed-fixture',
      );
    },
  );

  testWidgets(
    'activity reuses the cancellation key after an uncertain response',
    (tester) async {
      SharedPreferences.setMockInitialValues({'accessToken': 'fixture-access'});
      final cancellations = <http.Request>[];
      var cancelled = false;
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          cancellations.add(request);
          if (cancellations.length == 1) return http.Response('', 503);
          cancelled = true;
          return http.Response('{"success":true}', 200);
        }
        final rides = cancelled
            ? []
            : [
                {
                  'rideId': 7,
                  'code': 'BC-FIXTURE',
                  'createdAt': '2026-11-10T08:00:00',
                  'fromProvince': 'Hà Nội',
                  'fromDistrict': 'Điểm đón',
                  'fromAddress': 'Địa chỉ đón',
                  'toProvince': 'Hải Phòng',
                  'toDistrict': 'Điểm trả',
                  'toAddress': 'Địa chỉ trả',
                  'price': 200000,
                  'status': 1,
                },
              ];
        return http.Response.bytes(
          utf8.encode(jsonEncode({'data': rides})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      Future<void> confirmCancellation() async {
        await tester.tap(find.text('Huỷ chuyến'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Huỷ chuyến'),
          ),
        );
        await tester.pumpAndSettle();
      }

      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityScreen()));
        await tester.pumpAndSettle();
        await confirmCancellation();
        expect(cancellations, hasLength(1));
        expect(
          find.textContaining('Chưa xác nhận được kết quả hủy'),
          findsOneWidget,
        );

        await confirmCancellation();
        expect(cancellations, hasLength(2));
        expect(cancellations.first.url.path, '/api/rideapi/cancel/7');
        final key = cancellations.first.headers['Idempotency-Key'];
        expect(key, matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(cancellations.last.headers['Idempotency-Key'], key);
        expect(find.text('Chưa có chuyến'), findsOneWidget);
      }, () => client);
    },
  );
}
