import 'dart:convert';
import 'chat_ride_meta_model.dart';

class MessageModel {
  final int id;
  final int conversationId;
  final int senderType;
  final int? senderId;
  final String senderName;
  final int messageType;
  final String content;
  final String? metadataJson;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.senderId,
    required this.senderName,
    required this.messageType,
    required this.content,
    this.metadataJson,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      conversationId: json['conversationId'] is int
          ? json['conversationId']
          : int.tryParse('${json['conversationId']}') ?? 0,
      senderType: json['senderType'] is int
          ? json['senderType']
          : int.tryParse('${json['senderType']}') ?? 0,
      senderId: json['senderId'] == null
          ? null
          : (json['senderId'] is int
          ? json['senderId']
          : int.tryParse('${json['senderId']}')),
      senderName: json['senderName']?.toString() ?? '',
      messageType: json['messageType'] is int
          ? json['messageType']
          : int.tryParse('${json['messageType']}') ?? 0,
      content: json['content']?.toString() ?? '',
      metadataJson: json['metadataJson']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderType': senderType,
      'senderId': senderId,
      'senderName': senderName,
      'messageType': messageType,
      'content': content,
      'metadataJson': metadataJson,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool get isMe => senderType == 1;
  bool get isAdmin => senderType == 2;
  bool get isSystem => senderType == 3;

  bool get isRideCreatedMessage => messageType == 3;
  bool get isRideUpdatedMessage => messageType == 4;
  bool get isRideSystemMessage => isRideCreatedMessage || isRideUpdatedMessage;

  Map<String, dynamic>? get metadata {
    final raw = metadataJson;
    if (raw == null || raw.trim().isEmpty || raw.trim() == 'null') {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  ChatRideMetaModel? get rideMeta {
    final raw = metadata;
    if (raw == null) return null;

    try {
      return ChatRideMetaModel.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  MessageModel copyWith({
    int? id,
    int? conversationId,
    int? senderType,
    int? senderId,
    String? senderName,
    int? messageType,
    String? content,
    String? metadataJson,
    DateTime? createdAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderType: senderType ?? this.senderType,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}