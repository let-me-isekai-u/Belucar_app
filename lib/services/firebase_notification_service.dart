import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNoti = FlutterLocalNotificationsPlugin();

  /// Hàm xử lý thông báo khi app đang ở chế độ nền hoặc tắt hẳn
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    print('[BG] Message nhận được: ${message.messageId}');
  }

  /// Hàm khởi tạo toàn bộ dịch vụ thông báo
  static Future<void> init() async {
    // 1. Xin quyền từ người dùng
    await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true);

    // 2. Cấu hình hiển thị thông báo ngay cả khi đang mở app (Bắt buộc cho iOS)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, // Hiển thị banner
      badge: true, // Hiện số trên icon
      sound: true, // Phát âm thanh
    );

    // 3. Đăng ký Topic để nhận thông báo nhóm
    try {
      await _messaging.subscribeToTopic("customers");
      print('✅ Đã đăng ký nhận thông báo từ topic: customers');
    } catch (e) {
      print('❌ Lỗi khi đăng ký topic: $e');
    }

    // 4. Tạo Notification Channel cho Android (Bắt buộc từ Android 8.0+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // ID phải khớp với AndroidManifest.xml
      'High Importance Notifications',
      importance: Importance.max,
      playSound: true,
    );

    await _localNoti
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 5. Khởi tạo cài đặt cho từng nền tảng
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true, // Bật lên true để nhận âm thanh trên iOS
    );

    await _localNoti.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        // Xử lý logic khi người dùng nhấn vào thông báo lúc app đang mở
      },
    );

    // 6. Lắng nghe các sự kiện thông báo
    FirebaseMessaging.onMessage.listen(_onMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
  }

  /// Hàm lấy FCM Token để gửi lên server lúc Login
  static Future<String?> getDeviceToken() async {
    try {
      String? token = await _messaging.getToken();
      print('📩 FCM TOKEN: $token');
      return token;
    } catch (e) {
      print('❌ Lỗi lấy Token: $e');
      return null;
    }
  }

  /// Xử lý khi nhận được thông báo lúc đang mở app (Foreground)
  static void _onMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      _localNoti.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            icon: '@mipmap/launcher_icon',
            importance: Importance.max,
            priority: Priority.high,
          ),
          // Sửa từ "IOS" thành "iOS" (viết thường chữ i)
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true, // Bật âm thanh khi đang mở app
          ),
        ),
      );
    }
    print('[FG] Received: ${notification?.title}');
  }

  static void _onMessageOpened(RemoteMessage message) {
    print('[OPEN] Người dùng nhấn vào thông báo: ${message.notification?.title}');
  }
}