import 'message_model.dart';

class ChatMessagesPage {
  final List<MessageModel> items;
  final bool hasMore;
  final int? nextBeforeMessageId;

  ChatMessagesPage({
    required this.items,
    required this.hasMore,
    required this.nextBeforeMessageId,
  });

  factory ChatMessagesPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];

    return ChatMessagesPage(
      items: rawItems
          .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasMore: json['hasMore'] == true,
      nextBeforeMessageId: json['nextBeforeMessageId'],
    );
  }
}