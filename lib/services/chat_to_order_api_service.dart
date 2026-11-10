import 'dart:convert';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';
import '../models/chat_message_page.dart';
import 'chat_session.dart';

class ChatApiService {
  static const String chatHubUrl = '$apiOrigin/hubs/chat';
  static const String baseUrl = "$apiOrigin/api/chat/customer";

  static dynamic safeDecode(String? body) {
    if (body == null || body.isEmpty) return {};

    try {
      return jsonDecode(body);
    } catch (e) {
      print("!! safeDecode() JSON lỗi: $e !!");
      return {};
    }
  }

  //=============================
  // API 5.1: Open conversation
  //=============================
  static Future<int?> conversationOpen() async {
    final url = Uri.parse("$baseUrl/conversations/open");

    try {
      final accessToken = await ChatSession.accessToken();
      if (accessToken.isEmpty) throw StateError('Phiên đăng nhập đã hết hạn.');
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({}),
      );

      final data = safeDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['success'] == true) {
        final rawData = data['data'];
        if (rawData is Map) {
          return rawData['conversationId'];
        }
      }

      return null;
    } catch (e) {
      throw Exception("Lỗi kết nối: $e");
    }
  }

  //============================
  // API 5.4: Get messages (cursor pagination)
  //============================
  static Future<ChatMessagesPage> getMessages({
    required int conversationId,
    int? beforeMessageId,
    int take = 30,
  }) async {
    final queryParams = <String, String>{'take': take.clamp(1, 100).toString()};

    if (beforeMessageId != null) {
      queryParams['beforeMessageId'] = beforeMessageId.toString();
    }

    final url = Uri.parse(
      "$baseUrl/conversations/$conversationId/messages",
    ).replace(queryParameters: queryParams);

    try {
      final accessToken = await ChatSession.accessToken();
      if (accessToken.isEmpty) throw StateError('Phiên đăng nhập đã hết hạn.');
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $accessToken"},
      );

      final data = safeDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['success'] == true) {
        final rawData = data['data'];

        if (rawData is Map<String, dynamic>) {
          return ChatMessagesPage.fromJson(rawData);
        }

        if (rawData is Map) {
          return ChatMessagesPage.fromJson(Map<String, dynamic>.from(rawData));
        }
      }

      throw StateError('Không thể tải tin nhắn (HTTP ${response.statusCode}).');
    } catch (e) {
      throw Exception("Lỗi kết nối: $e");
    }
  }

  //============================
  // API 5.5: Send message
  //============================
  static Future<MessageModel?> sendMessage({
    required int conversationId,
    required String content,
  }) async {
    final url = Uri.parse("$baseUrl/conversations/$conversationId/messages");

    try {
      final accessToken = await ChatSession.accessToken();
      if (accessToken.isEmpty) throw StateError('Phiên đăng nhập đã hết hạn.');
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"content": content}),
      );

      final data = safeDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['success'] == true) {
        final rawData = data['data'];
        if (rawData is Map) {
          return MessageModel.fromJson(Map<String, dynamic>.from(rawData));
        }
      }

      return null;
    } catch (e) {
      throw Exception("Lỗi kết nối: $e");
    }
  }

  //============================
  // API 5.6: Mark as read
  //============================
  static Future<bool> markAsRead({required int conversationId}) async {
    final url = Uri.parse("$baseUrl/conversations/$conversationId/mark-read");

    try {
      final accessToken = await ChatSession.accessToken();
      if (accessToken.isEmpty) throw StateError('Phiên đăng nhập đã hết hạn.');
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({}),
      );

      final data = safeDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      }

      return false;
    } catch (e) {
      throw Exception("Lỗi kết nối: $e");
    }
  }
}
