import 'package:belucar_app/services/api_service.dart';
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
}
