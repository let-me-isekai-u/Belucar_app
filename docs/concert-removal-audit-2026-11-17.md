# Audit concert BIGBANG — 17/11/2026

Đã sửa trực tiếp; không commit/push. Branch `main`, HEAD `9d72813a7b2e3f23ae9b0780aa50452e3a6739da` giữ nguyên. Trước task chỉ có thay đổi local `ios/Runner.xcodeproj/project.pbxproj`, không staged/untracked. File iOS được giữ nguyên byte-for-byte.

Không tìm thấy module concert/BIGBANG, API/route/model/vé concert trong source Flutter hiện dùng và các source lưu kèm. Chỉ tìm thấy khóa `showEventBanner` được ghi tại Login/Splash nhưng không có nơi đọc trên toàn repo.

Đã xóa đúng hai dòng `prefs.setBool('showEventBanner', true)` trong `lib/screens/login_screen.dart` và `lib/screens/splash_screen.dart`. Không xóa file, asset, dependency hoặc dữ liệu người dùng. Thêm báo cáo này.

Giữ `intro_splash.mp4`/video_player; CustomerSession và global token refresh; carrier booking/Vé của tôi/QR thanh toán; xe ghép; ví; chat; GPS/map/tracking. Các `ticket` trong carrier và `event` trong callback/UI không phải concert. Đã xem ba ảnh carousel: nội dung Tết, không liên quan BIGBANG, được giữ.

Không có dependency chỉ thuộc concert được xác minh; pubspec và lockfile không đổi. Không thay banner/quảng cáo khác. Không sửa bản sao source không có dấu vết concert.

Dart static analysis toàn bộ `lib`/`test`: 0 error, còn lint info hiện hữu. `git diff --check` đạt. Tìm lại source/test không còn `showEventBanner`/concert/BIGBANG. **Không chạy Flutter build/run/test; runtime UNVERIFIED.**

Owner cần hồi quy iOS/Android: intro video (kể cả video lỗi), login/restore/refresh, xe ghép, đặt xe khách/limousine, Vé của tôi, thanh toán/VietQR/ví, chat và tracking. Không gọi API production hay xóa token/data hiện có để thử nghiệm.

Git status sau sửa:

```text
 M ios/Runner.xcodeproj/project.pbxproj  (có sẵn, giữ nguyên)
 M lib/screens/login_screen.dart
 M lib/screens/splash_screen.dart
?? docs/concert-removal-audit-2026-11-17.md
```

Không staged, không thay branch/HEAD; không thao tác stash/reset/clean/pull/merge/rebase.
