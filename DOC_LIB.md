# Mô tả nhanh các file chính

Tài liệu này chỉ mô tả các file do team đã viết trong `lib/` và file `pubspec.yaml`. Các file cấu hình mặc định của framework và các file sinh tự động không liệt kê ở đây.

## File gốc

- `pubspec.yaml`: Khai báo tên app, version, các `dependency`, các `asset` đang dùng, và cấu hình `flutter_launcher_icons`.
- `lib/main.dart`: Điểm vào của ứng dụng; khởi tạo Firebase, thông báo đẩy, `SharedPreferences`, và đăng ký các route chính như `splash`, `login`, `home`.
- `lib/app_theme.dart`: Khai báo bảng màu và `ThemeData` dùng chung cho toàn app.

## Models

- `lib/models/booking_model.dart`: `ChangeNotifier` giữ toàn bộ state của luồng đặt chuyến như loại chuyến, điểm đón, điểm trả, thời gian, số lượng, phương thức thanh toán, tính giá và tạo đơn.
- `lib/models/trip_item_model.dart`: Model rút gọn cho danh sách chuyến ở màn hình hoạt động.
- `lib/models/trip_detail_model.dart`: Model chi tiết của một chuyến để hiển thị ở màn hình chi tiết đơn.
- `lib/models/message_model.dart`: Model một tin nhắn trong chat realtime, có hỗ trợ đọc `metadataJson`.
- `lib/models/chat_message_page.dart`: Model phân trang cho danh sách tin nhắn chat.
- `lib/models/chat_ride_meta_model.dart`: Model dữ liệu metadata của đơn gắn trong tin nhắn chat.
- `lib/models/deposit_model.dart`: Model cho phản hồi tạo yêu cầu nạp tiền và huỷ yêu cầu nạp tiền.

## Providers

- `lib/providers/home_provider.dart`: Giữ state của màn hình home như tab đang chọn, hồ sơ ngắn của user, thời tiết, banner, và luồng tạo hoặc huỷ yêu cầu nạp tiền.
- `lib/providers/chat_provider.dart`: Điều phối toàn bộ state của chat realtime như mở `conversation`, tải tin nhắn, gửi tin, đánh dấu đã đọc, phân trang và kết nối `SignalR`.

## Services

- `lib/services/api_service.dart`: Service API tổng của app khách; chứa các hàm đăng nhập, đăng ký, hồ sơ, ví, đặt chuyến, hoạt động, chi tiết đơn, nạp tiền và các API khác.
- `lib/services/chat_to_order_api_service.dart`: Service API riêng cho luồng Chat, gồm mở `conversation`, lấy danh sách tin nhắn, gửi tin và đánh dấu đã đọc.
- `lib/services/signalr_service.dart`: Đóng gói kết nối `SignalR`, xử lý `connect`, `disconnect`, `invoke` và đăng ký lắng nghe sự kiện realtime.
- `lib/services/belucar_signalr_http_client.dart`: `HTTP client` tùy biến cho `signalr_netcore`, phục vụ kết nối realtime ổn định hơn trên mobile.
- `lib/services/firebase_notification_service.dart`: Khởi tạo `Firebase Messaging`, xin quyền thông báo, lấy `device token`, tạo `notification channel` và hiển thị thông báo cục bộ.

## Screens

- `lib/screens/splash_screen.dart`: Màn hình khởi động; kiểm tra token, thử làm mới phiên đăng nhập và điều hướng sang `login` hoặc `home`.
- `lib/screens/login_screen.dart`: Màn hình đăng nhập; gọi API login, lưu token, lưu thông tin cơ bản và chuyển vào app.
- `lib/screens/register_screen.dart`: Màn hình đăng ký tài khoản khách hàng, có kiểm tra form, ảnh đại diện và mã giới thiệu.
- `lib/screens/forgot_password_screen.dart`: Màn hình quên mật khẩu; gửi OTP qua email và đặt lại mật khẩu.
- `lib/screens/change_password_screen.dart`: Màn hình đổi mật khẩu khi người dùng đã đăng nhập.
- `lib/screens/beluca_home_screen.dart`: Lớp bọc `MultiProvider` cho home; cấp `BookingModel` và `HomeProvider` cho phần giao diện bên dưới.
- `lib/screens/beluca_home_view.dart`: Giao diện home chính; chứa `BottomNavigationBar`, banner, thời tiết, ví, chat realtime, nút nạp tiền, và điều hướng sang các tab khác.
- `lib/screens/activity_screen.dart`: Màn hình hoạt động; tách tab `Đang diễn ra` và `Lịch sử`, gọi API lấy danh sách chuyến, huỷ chuyến và làm mới dữ liệu sau khi đặt đơn.
- `lib/screens/order_detail_screen.dart`: Màn hình chi tiết một chuyến; hiển thị trạng thái, lộ trình, thanh toán và thông tin tài xế.
- `lib/screens/profile_screen.dart`: Màn hình tài khoản; tải hồ sơ người dùng, số dư ví, mã giới thiệu, hỗ trợ mở Zalo và điều hướng sang các màn liên quan.
- `lib/screens/update_profile_screen.dart`: Màn hình cập nhật họ tên, email và ảnh đại diện.
- `lib/screens/wallet_history_screen.dart`: Màn hình xem số dư hiện tại và lịch sử giao dịch ví.
- `lib/screens/terms_screen.dart`: Màn hình hiển thị điều khoản sử dụng của ứng dụng.

## Luồng đặt chuyến

- `lib/screens/booking/booking1_screen.dart`: Bước 1 của đặt chuyến; nhập thông tin cơ bản như số điện thoại, ghi chú, loại chuyến và số lượng.
- `lib/screens/booking/booking2_screen.dart`: Bước 2 của đặt chuyến; chọn tỉnh, quận, địa chỉ và thời gian, đồng thời tính giá sơ bộ.
- `lib/screens/booking/booking3_screen.dart`: Bước 3 của đặt chuyến; xác nhận thông tin, hiển thị giá cuối và gọi API tạo đơn.

## Luồng chat realtime

- `lib/screens/chat_to_order/chat_screen.dart`: Màn hình chat realtime với giao diện gửi nhận tin nhắn, tải thêm lịch sử, hiển thị trạng thái lỗi và các block tin nhắn theo ngày.

## Widgets dùng lại

- `lib/widgets/dashed_line_vertical.dart`: Widget vẽ đường dọc nét đứt, đang dùng trong một số màn hiển thị lộ trình hoặc chi tiết đơn.

## Assets tự thêm trong `lib/assets`

- Thư mục `lib/assets/` và `lib/assets/icons/`: Chứa ảnh `splash`, logo, icon, banner và ảnh nền phục vụ giao diện; không chứa logic xử lý.
