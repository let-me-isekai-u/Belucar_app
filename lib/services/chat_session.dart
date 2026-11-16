import 'customer_session.dart';

class ChatSession {
  static Future<String> accessToken() => CustomerSession.accessToken();
}
