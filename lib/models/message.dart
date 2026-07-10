class Message {
  final String id;
  final String customerId;
  final String senderId;
  final String senderRole;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.customerId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String,
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  bool isSentByMe(String currentUserId) => senderId == currentUserId;
}

class ChatConversation {
  final String id;
  final String customerId;
  final String customerName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCustomer;
  final int unreadAdmin;
  final DateTime? updatedAt;

  const ChatConversation({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCustomer,
    required this.unreadAdmin,
    required this.updatedAt,
  });
}
