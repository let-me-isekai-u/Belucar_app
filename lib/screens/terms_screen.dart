import 'package:flutter/material.dart';

import 'account_ui.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const String _terms = '''
1. Giới thiệu
Belucar là nền tảng kết nối người dùng với tài xế để đặt các chuyến xe cá nhân hoặc vận chuyển.
Mục tiêu là cung cấp dịch vụ nhanh chóng, minh bạch và an toàn.

2. Tài khoản người dùng
Người dùng phải cung cấp thông tin chính xác và hợp lệ khi đăng ký.
Bạn chịu trách nhiệm bảo mật thông tin đăng nhập.
Belucar có quyền từ chối hoặc khóa tài khoản nếu phát hiện gian lận hoặc thông tin sai lệch.

3. Đặt chuyến và thanh toán
Người dùng có thể tạo chuyến đi và xem chi phí dự kiến.
Thanh toán được thực hiện qua ví điện tử hoặc các phương thức do ứng dụng cung cấp.
Chính sách huỷ chuyến chỉ áp dụng cho những chuyến chưa có tài xế nhận.

4. Huỷ chuyến
Người dùng chỉ có thể huỷ chuyến ở trạng thái chưa có tài xế nhận.
Belucar có quyền từ chối huỷ chuyến nếu vi phạm các điều kiện của dịch vụ.

5. Trách nhiệm
Belucar chỉ là nền tảng kết nối, không trực tiếp vận chuyển hành khách.
Mọi sự cố, trễ giờ hoặc mất mát phát sinh trong chuyến đi được xử lý theo quy định của tài xế hoặc đối tác liên quan.

6. Thay đổi và chấm dứt dịch vụ
Belucar có quyền điều chỉnh hoặc tạm ngừng dịch vụ mà không cần báo trước.
Các thay đổi về điều khoản sẽ được thông báo trong ứng dụng; việc tiếp tục sử dụng được xem là đồng ý với các thay đổi đó.

7. Hỗ trợ
Số điện thoại: 0878 861 324
Email: beluga.fintech@gmail.com
''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AccountScaffold(
      appBar: AppBar(
        title: Text(
          'Điều khoản sử dụng',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            AccountSectionCard(
              title: 'Điều khoản BeluCar',
              subtitle:
                  'Vui lòng đọc kỹ trước khi tiếp tục sử dụng ứng dụng và dịch vụ.',
              icon: Icons.gavel_outlined,
              child: const Text(
                _terms,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('XÁC NHẬN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
