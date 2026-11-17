import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/beluca_home_screen.dart';
import 'app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_notification_service.dart';
import 'services/customer_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo firebase
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
    FirebaseNotificationService.firebaseMessagingBackgroundHandler,
  );

  await SharedPreferences.getInstance();

  runApp(const BelucarApp());
}

final _navigatorKey = GlobalKey<NavigatorState>();
final _sessionObserver = _SessionRouteObserver();

class _SessionRouteObserver extends NavigatorObserver {
  bool inSplash = true;
  void _track(Route<dynamic>? route) =>
      inSplash = route?.settings.name == '/splash';
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _track(newRoute);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(previousRoute);
}

class BelucarApp extends StatefulWidget {
  const BelucarApp({super.key});

  @override
  State<BelucarApp> createState() => _BelucarAppState();
}

class _BelucarAppState extends State<BelucarApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CustomerSession.onExpired = () {
      if (!_sessionObserver.inSplash) {
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (_) => false,
        );
      }
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_sessionObserver.inSplash) {
      _refreshOnResume();
    }
  }

  Future<void> _refreshOnResume() async {
    try {
      await CustomerSession.accessToken();
    } catch (_) {
      // The next user action can retry transient failures; never discard forms.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CustomerSession.onExpired = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_sessionObserver],
      debugShowCheckedModeBanner: false,
      title: 'Xe Đông Dương',
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
