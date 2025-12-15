import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Điều khoản sử dụng"),
        centerTitle: true,
        automaticallyImplyLeading: true,

      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: const Text(
                  """
🧾 CHÍNH SÁCH SỬ DỤNG ỨNG DỤNG BELUGAS EXPRESS

1. Giới thiệu

Belugas Express là nền tảng trung gian kết nối giữa người có nhu cầu gửi hàng và các đối tác vận chuyển/kho trung chuyển. Mục tiêu của ứng dụng là giúp người dùng tạo, quản lý và theo dõi đơn hàng một cách thuận tiện, minh bạch và an toàn.

Bằng việc cài đặt, đăng ký và sử dụng ứng dụng, bạn xác nhận rằng mình đã đọc, hiểu và đồng ý với các điều khoản trong chính sách này.

2. Đăng ký và xác thực tài khoản

Người dùng phải cung cấp thông tin chính xác và hợp lệ, bao gồm họ tên, email và số điện thoại.

Hệ thống có quyền từ chối hoặc khoá tài khoản nếu phát hiện thông tin sai lệch, gian lận hoặc vi phạm quy định.

Người dùng chịu trách nhiệm bảo mật thông tin đăng nhập của mình.

3. Ví điện tử và đặt cọc đơn hàng

Sau khi đăng ký, người dùng cần nạp tiền vào ví trong ứng dụng để sử dụng dịch vụ.

Mỗi lần tạo đơn, hệ thống sẽ tự động trừ khoản đặt cọc 500.000 VNĐ.

Khi đơn hàng đến kho trung chuyển, hệ thống sẽ tính toán chi phí thực tế.

Nếu chi phí thấp hơn tiền cọc, phần chênh lệch sẽ được hoàn lại vào ví.

Nếu chi phí cao hơn, người dùng phải thanh toán phần còn thiếu để đơn hàng được tiếp tục vận chuyển.

4. Trách nhiệm và giới hạn trách nhiệm

Belugas Express không trực tiếp vận chuyển hàng hóa, mà chỉ đóng vai trò nền tảng trung gian kết nối giữa người gửi và đơn vị vận chuyển.

Mọi vấn đề phát sinh trong quá trình vận chuyển sẽ được xử lý theo chính sách của đối tác vận chuyển liên quan.

Ứng dụng không chịu trách nhiệm đối với thiệt hại, mất mát hoặc chậm trễ do bên vận chuyển hoặc do người dùng cung cấp thông tin sai lệch.

5. Quyền thay đổi và chấm dứt dịch vụ

Belugas Express có quyền điều chỉnh, tạm ngưng hoặc ngừng cung cấp dịch vụ mà không cần báo trước trong một số trường hợp cần thiết (ví dụ bảo trì, cập nhật hệ thống).

Các thay đổi về điều khoản sẽ được công bố trong ứng dụng, và người dùng tiếp tục sử dụng đồng nghĩa với việc chấp thuận các thay đổi đó.

6. Liên hệ hỗ trợ

Mọi thắc mắc hoặc yêu cầu hỗ trợ, vui lòng liên hệ Zalo: https://zalo.me/0932265471
                  """,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Xác nhận", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
