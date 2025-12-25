import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/beluca_home_screen.dart';
import 'app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo firebase
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
    FirebaseNotificationService.firebaseMessagingBackgroundHandler,
  );

  await FirebaseNotificationService.init();
  await SharedPreferences.getInstance();

  runApp(const BelucarApp());
}

class BelucarApp extends StatelessWidget {
  const BelucarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BeluCar',
      theme: AppTheme.theme,
      initialRoute: "/splash",
      routes: {
        "/splash": (_) => const SplashScreen(),
        "/login": (_) => const LoginScreen(),
        "/home": (_) => const HomeScreen(),
      },
    );
  }
}