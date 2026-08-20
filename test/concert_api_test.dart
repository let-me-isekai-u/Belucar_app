import 'dart:convert';

import 'package:belucar_app/models/concert_models.dart';
import 'package:belucar_app/models/booking_model.dart';
import 'package:belucar_app/providers/account_provider.dart';
import 'package:belucar_app/providers/auth_provider.dart';
import 'package:belucar_app/providers/concert_provider.dart';
import 'package:belucar_app/screens/concert/concert_booking_screen.dart';
import 'package:belucar_app/services/concert_api_service.dart';
import 'package:belucar_app/services/guest_concert_order_storage.dart';
import 'package:belucar_app/services/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  test('catalog parses, sorts routes and excludes terminal stops', () async {
    final service = ConcertApiService(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/concert/catalog');
        expect(request.url.queryParameters['eventCode'], 'BIGBANG_MYDINH_2026');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'eventId': 1,
              'eventCode': 'BIGBANG_MYDINH_2026',
              'eventName': 'Concert',
              'venueName': 'Mỹ Đình',
              'status': 'OPEN',
              'routes': [
                {
                  'id': 2,
                  'code': 'SECOND',
                  'name': 'Tuyến 2',
                  'sequence': 2,
                  'stops': [],
                },
                {
                  'id': 1,
                  'code': 'FIRST',
                  'name': 'Tuyến 1',
                  'sequence': 1,
                  'stops': [
                    {
                      'id': 7,
                      'code': 'T',
                      'name': 'Mỹ Đình',
                      'sequence': 2,
                      'isTerminal': true,
                      'isSelectable': false,
                    },
                    {
                      'id': 1,
                      'code': '1',
                      'name': 'Ocean Park',
                      'sequence': 1,
                      'isTerminal': false,
                      'isSelectable': true,
                    },
                  ],
                },
              ],
              'vehicleTypes': [],
              'services': [],
              'fares': [],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final response = await service.getCatalog();

    expect(response.isSuccess, isTrue, reason: response.message);
    expect(response.data!.routes.first.code, 'FIRST');
    expect(response.data!.routes.first.stops.first.name, 'Ocean Park');
    expect(response.data!.routes.first.selectableStops, hasLength(1));
  });

  test('quote sends numeric values and parses official server total', () async {
    final service = ConcertApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final item = (body['items'] as List).single as Map<String, dynamic>;
        expect(item['quantity'], 2);
        expect(item['serviceId'], 1);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'eventCode': 'BIGBANG_MYDINH_2026',
              'totalQuantity': 2,
              'subtotal': 200000,
              'totalAmount': 200000,
              'items': [],
            },
          }),
          200,
        );
      }),
    );

    final response = await service.quote(const [
      ConcertCartItem(
        serviceId: 1,
        routeStopId: 1,
        vehicleTypeId: 4,
        quantity: 2,
      ),
    ]);

    expect(response.data?.totalAmount, 200000);
  });

  test('create order maps contact fields and customer authorization', () async {
    late http.Request capturedRequest;
    late String capturedBodyText;
    final service = ConcertApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        capturedRequest = request;
        capturedBodyText = request.body;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'orderCode': 'BBO1',
              'eventName': 'Concert',
              'contactFullName': 'Nguyễn Văn A',
              'contactPhone': '0912345678',
              'contactEmail': 'customer@example.com',
              'password': 'Guest@123',
              'status': 'PENDING_PAYMENT',
              'guestAccessToken': null,
              'totalQuantity': 1,
              'totalAmount': 100000,
              'items': [],
            },
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final response = await service.createOrder(
      contactFullName: 'Nguyễn Văn A',
      contactPhone: '0912345678',
      contactEmail: 'customer@example.com',
      accessToken: 'customer-token',
      items: const [
        ConcertCartItem(
          serviceId: 1,
          routeStopId: 1,
          vehicleTypeId: 4,
          quantity: 1,
        ),
      ],
    );

    final capturedBody = jsonDecode(capturedBodyText) as Map<String, dynamic>;
    expect(response.isSuccess, isTrue, reason: response.message);
    expect(capturedRequest.headers['authorization'], 'Bearer customer-token');
    expect(capturedBody['contactFullName'], 'Nguyễn Văn A');
    expect(capturedBody['contactPhone'], '0912345678');
    expect(capturedBody['contactEmail'], 'customer@example.com');
    expect(response.data?.contactFullName, 'Nguyễn Văn A');
    expect(response.data?.generatedPassword, 'Guest@123');
  });

  test('problem details validation message is surfaced', () async {
    final service = ConcertApiService(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'title': 'Validation failed',
            'status': 400,
            'errors': {
              'items': ['The Items field is required.'],
            },
          }),
          400,
        ),
      ),
    );

    final response = await service.quote(const []);

    expect(response.statusCode, 400);
    expect(response.message, 'The Items field is required.');
  });

  test('guest storage retains credentials for multiple orders', () async {
    final secrets = _MemorySecretStorage();
    final storage = GuestConcertOrderStorage(storage: secrets);
    final now = DateTime(2026, 8, 19, 15, 30);

    await storage.save(
      GuestConcertOrderCredential(
        orderCode: 'BBO1',
        guestAccessToken: 'guest-1',
        createdAt: now,
      ),
    );
    await storage.save(
      GuestConcertOrderCredential(
        orderCode: 'BBO2',
        guestAccessToken: 'guest-2',
        createdAt: now.add(const Duration(minutes: 1)),
      ),
    );

    final credentials = await storage.readAll();
    expect(credentials.map((item) => item.orderCode), ['BBO2', 'BBO1']);
    expect((await storage.find('BBO1'))?.guestAccessToken, 'guest-1');
  });

  testWidgets(
    'old booking UI shows API fare and fallback times when API has no time',
    (tester) async {
      final secrets = _MemorySecretStorage();
      final apiService = ConcertApiService(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'eventId': 1,
                'eventCode': 'BIGBANG_MYDINH_2026',
                'eventName': 'BIGBANG Concert Mỹ Đình 2026',
                'venueName': 'Sân vận động Quốc gia Mỹ Đình',
                'status': 'OPEN',
                'routes': [
                  {
                    'id': 1,
                    'code': 'EAST',
                    'name': 'EAST / Phía Đông',
                    'sequence': 1,
                    'stops': [
                      {
                        'id': 1,
                        'code': '1.1',
                        'name': 'Ocean Park 1',
                        'sequence': 1,
                        'isTerminal': false,
                        'isSelectable': true,
                      },
                    ],
                  },
                ],
                'vehicleTypes': [
                  {'id': 4, 'code': 'CAR4', 'name': 'Xe 4 chỗ', 'seatCount': 4},
                ],
                'services': [
                  {
                    'id': 1,
                    'code': '20261024_OUTBOUND',
                    'name': 'Chiều đi ngày 24/10/2026',
                    'serviceDate': '2026-10-24T00:00:00',
                    'direction': 'OUTBOUND',
                    'departureAt': null,
                    'meetingTimeNote': null,
                    'saleStatus': 'OPEN',
                  },
                ],
                'fares': [
                  {
                    'id': 1,
                    'serviceId': 1,
                    'routeStopId': 1,
                    'vehicleTypeId': 4,
                    'price': 100000,
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final authProvider = AuthProvider(
        tokenStorage: TokenStorage(storage: secrets),
      );
      final accountProvider = AccountProvider(authProvider: authProvider);
      final concertProvider = ConcertProvider(
        authProvider: authProvider,
        accountProvider: accountProvider,
        apiService: apiService,
        guestStorage: GuestConcertOrderStorage(storage: secrets),
        guestMode: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BookingModel()),
            ChangeNotifierProvider.value(value: concertProvider),
          ],
          child: const MaterialApp(home: ConcertBookingScreen(isGuest: true)),
        ),
      );
      await concertProvider.loadCatalog();
      await tester.pumpAndSettle();

      expect(
        concertProvider.catalog,
        isNotNull,
        reason: concertProvider.errorMessage,
      );
      final visibleTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .toList();
      expect(visibleTexts, contains('Loại hành trình'));
      expect(find.text('Họ và tên liên hệ'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget);
      expect(find.textContaining('100.000'), findsWidgets);
    },
  );
}

class _MemorySecretStorage implements SecretStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
