import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:belucar_app/screens/login_screen.dart';
import 'package:belucar_app/screens/register_screen.dart';

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('login screen shows brand, both fields and sign-up link', (tester) async {
    await tester.pumpWidget(_host(const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Đông Dương'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.text('Đăng ký'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login with empty fields shows validation message without calling the server', (tester) async {
    await tester.pumpWidget(_host(const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pump();

    expect(find.text('Vui lòng nhập số điện thoại và mật khẩu'), findsOneWidget);
  });

  testWidgets('password visibility toggles', (tester) async {
    await tester.pumpWidget(_host(const LoginScreen()));
    await tester.pumpAndSettle();

    TextField password() => tester.widget<TextField>(find.byType(TextField).at(1));
    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();
    expect(password().obscureText, isFalse);
  });

  testWidgets('register screen renders the details form without overflow', (tester) async {
    await tester.pumpWidget(_host(const RegisterScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Tạo tài khoản'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Nhập lại mật khẩu'), findsOneWidget);
    expect(find.text('GỬI MÃ XÁC MINH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration requests an email code before submitting OTP', (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const challengeId = '12345678-1234-1234-1234-123456789012';
    const email = 'customer@example.invalid';
    const phone = '0900000000';
    const password = 'Đong1!aa';
    final requests = <(String, Map<String, dynamic>)>[];
    final client = MockClient.streaming((request, body) async {
      final payload = await body.bytesToString();
      if (request is http.MultipartRequest) {
        requests.add((request.url.path, request.fields));
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"message":"Mã xác minh không hợp lệ."}')),
          400,
        );
      }
      requests.add((request.url.path, jsonDecode(payload) as Map<String, dynamic>));
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"challengeId":"$challengeId","expiresIn":600}')),
        200,
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(_host(const RegisterScreen()));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      final values = ['Test Customer', email, phone, phone, password, password];
      for (final (index, value) in values.indexed) {
        await tester.enterText(fields.at(index), value);
      }
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('GỬI MÃ XÁC MINH'));
      await tester.pumpAndSettle();

      expect(find.text('Xác minh email'), findsOneWidget);
      expect(requests.single.$1, '/api/identity/challenges');
      expect(requests.single.$2, {
        'ownerType': 1,
        'purpose': 'register',
        'email': email,
        'phone': phone,
      });

      await tester.enterText(find.byType(TextField), '012345');
      await tester.tap(find.text('ĐĂNG KÝ'));
      await tester.pumpAndSettle();

      expect(requests.last.$1, '/api/accountcustomerapi/customer-register');
      expect(requests.last.$2, containsPair('challengeId', challengeId));
      expect(requests.last.$2, containsPair('otp', '012345'));
      expect(find.text('Mã xác minh không hợp lệ.'), findsOneWidget);
      expect(find.text('Xác minh email'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  });
}
