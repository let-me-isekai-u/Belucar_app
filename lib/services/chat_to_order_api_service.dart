import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';
import '../models/chat_message_page.dart';

class ChatApiService {
  static const String baseUrl = "https://xeghepdongduong.com/api/chat/customer";

  static dynamic safeDecode(String? body) {
    if (body == null || body.isEmpty) return {};

    try {
      return jsonDecode(body);
    } catch (e) {
      print("!! safeDecode() JSON lỗi: $e !!");
      print("!! raw body: $body");
      return {};
    }
  }

  //=============================
  // API 5.1: Open conversation
  //=============================
  static Future<int?> conversationOpen({
    required String accessToken,
  }) async {
    final url = Uri.parse("$baseUrl/conversations/open");

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({}),
      );

      final data = safeDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final rawData = data['data'];
        if (rawData is Map) {
          return rawData['conversationId'];
        }
      }

      print("Open conversation lỗi: ${response.body}");
      return null;
    } catch (e) {
      throw Exception("Lỗi kết nối: $e");
    }
  }

  //============================
  // API 5.4: Get messages (cursor pagination)
  //============================
  static Future<ChatMessagesPage> getMessages({
    required String accessToken,
    required int conversationId,
    int? beforeMessageId,
    int take = 30,
  }) async {
    final queryParams = <String, String>{
      'take': take.clamp(1, 100).toString(),
    };

    if (beforeMessageId != null) {
      queryParams['beforeMessageId'] = beforeMessageId.toString();
    }

    final url = Uri.parse(
      "$baseUrl/conversations/$conversationId/messages",
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
        },
      );

      final data = safeDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final rawData = data['data'];

        if (rawData is Map<String, dynamic>) {
          return ChatMessagesPage.fromJson(rawData);
        }

        if (rawData is Map) {
          return ChatMessagesPage.fromJson(
            Map<String, dynamic>.from(rawData),
          );
        }
      }

      print("Get messages lỗi: ${response.body}");
      return ChatMessagesPage(
        items: [],
        hasMore: false,
        nextBeforeMessageId: null,
      );
    } catch (e) {
      throw Exception("Lỗi kết nối: $e");
    }
  }

  //============================
  // API 5.5: Send message
  //============================
  static Future<MessageModel?> sendMessage({
    required String accessToken,
    required int conversationId,
    required String content,
  }) async {
    final url = Uri.parse(
      "$baseUrl/conversations/$conversationId/messages",
    );

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "content": content,
        }),
      );

      final data = safeDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final rawData = data['data'];
        if (rawData is Map) {
          return MessageModel.fromJson(
            Map<String, dynamic>.from(rawData),
          );
        }
      }

      print("Send message lỗi: ${response.body}");
      return null;
    } catch (e) {
      throw Exception("Lỗi kết nối: $e");
    }
  }

  //============================
  // API 5.6: Mark as read
  //============================
  static Future<bool> markAsRead({
    required String accessToken,
    required int conversationId,
  }) async {
    final url = Uri.parse(
      "$baseUrl/conversations/$conversationId/mark-read",
    );

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({}),
      );

      final data = safeDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      }

      print("Mark read lỗi: ${response.body}");
      return false;
    } catch (e) {
      throw Exception("Lỗi kết nối: $e");
    }
  }
}