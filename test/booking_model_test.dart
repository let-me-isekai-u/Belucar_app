import 'dart:convert';

import 'package:belucar_app/models/booking_model.dart';
import 'package:belucar_app/models/location_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingModel model;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    model = BookingModel()
      ..selectedPickupPoint = RidePointPayload.placeId('fixture-pickup')
      ..selectedDropPoint = RidePointPayload.placeId('fixture-drop')
      ..goDate = DateTime(2026, 11, 10)
      ..goTime = const TimeOfDay(hour: 8, minute: 30)
      ..customerPhone = '0000000000';
    await model.loadSavedPlaces();
  });

  tearDown(() => model.dispose());

  test('wallet booking sends the trip ID from the quote', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v2/address/resolve-route') {
        return http.Response(
          '{"success":true,"data":{"tripId":4321,"finalPrice":200000}}',
          200,
        );
      }
      return http.Response('{"success":true,"data":{"id":1}}', 200);
    });

    await http.runWithClient(() async {
      await model.fetchTripPrice();
      expect(model.tripPrice, 200000);
      final result = await model.createRide('test-token');
      expect(result['success'], true);
    }, () => client);

    expect(requests.map((request) => request.url.path), [
      '/api/v2/address/resolve-route',
      '/api/v2/ride/create',
    ]);
    expect(jsonDecode(requests.last.body), containsPair('tripId', 4321));
    expect(jsonDecode(requests.last.body), containsPair('paymentMethod', 2));
  });

  test('booking without a quoted trip is stopped before sending', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      return http.Response('{"success":true}', 200);
    });
    await http.runWithClient(() async {
      await expectLater(model.createRide('test-token'), throwsA(isA<String>()));
    }, () => client);
    expect(requestCount, 0);
  });

  test(
    'empty 401 renews both tokens and retries the same booking once',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', 'expired');
      await prefs.setString('refreshToken', 'refresh-before');
      model.currentTripId = 4321;
      final bookings = <http.Request>[];
      var refreshCount = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/refresh-token')) {
          refreshCount++;
          expect(jsonDecode(request.body), {'refreshToken': 'refresh-before'});
          return http.Response(
            '{"accessToken":"renewed","refreshToken":"refresh-after"}',
            200,
          );
        }
        bookings.add(request);
        return bookings.length == 1
            ? http.Response('', 401)
            : http.Response('{"success":true}', 200);
      });

      await http.runWithClient(() async {
        expect((await model.createRide('expired'))['success'], true);
      }, () => client);

      expect(refreshCount, 1);
      expect(bookings, hasLength(2));
      expect(bookings.first.headers['Authorization'], 'Bearer expired');
      expect(bookings.last.headers['Authorization'], 'Bearer renewed');
      expect(bookings.last.body, bookings.first.body);
      expect(prefs.getString('accessToken'), 'renewed');
      expect(prefs.getString('refreshToken'), 'refresh-after');
    },
  );

  test(
    'empty 401 without a refresh token asks the customer to sign in',
    () async {
      model.currentTripId = 4321;
      final client = MockClient((request) async => http.Response('', 401));
      await http.runWithClient(() async {
        await expectLater(
          model.createRide('expired'),
          throwsA(contains('đăng nhập lại')),
        );
      }, () => client);
    },
  );

  test('server failure never resends an uncertain booking', () async {
    model.currentTripId = 4321;
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('', 502);
    });
    await http.runWithClient(() async {
      await expectLater(
        model.createRide('active'),
        throwsA(contains('kiểm tra Hoạt động')),
      );
    }, () => client);
    expect(requests, 1);
  });
}
