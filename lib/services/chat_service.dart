import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';
import '../models/profile.dart';
import 'supabase_error_handler.dart';

class ChatService {
  ChatService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> sendMessage({
    required String customerId,
    required String senderId,
    required String senderRole,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    try {
      await _client.from('messages').insert({
        'customer_id': customerId,
        'sender_id': senderId,
        'sender_role': senderRole,
        'content': trimmed,
      });

      final currentMeta = await _getConversationMeta(customerId);
      final isAdminSender = senderRole == 'admin';

      await _client.from('conversation_meta').upsert({
        'customer_id': customerId,
        'last_message': trimmed,
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
        'unread_customer': isAdminSender
            ? (currentMeta?['unread_customer'] as int? ?? 0) + 1
            : 0,
        'unread_admin': isAdminSender
            ? 0
            : (currentMeta?['unread_admin'] as int? ?? 0) + 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'customer_id');
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<List<Message>> getMessages(String customerId) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Stream<List<Message>> streamMessages(String customerId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .map((rows) {
          final messages = rows
              .map((e) => Message.fromJson(e))
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return messages;
        });
  }

  Future<void> markAsRead(String customerId, String role) async {
    final oppositeRole = role == 'admin' ? 'customer' : 'admin';

    try {
      await _client
          .from('messages')
          .update({'is_read': true})
          .eq('customer_id', customerId)
          .eq('sender_role', oppositeRole)
          .eq('is_read', false);

      await _client.from('conversation_meta').upsert({
        'customer_id': customerId,
        if (role == 'admin') 'unread_admin': 0,
        if (role == 'customer') 'unread_customer': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'customer_id');
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<List<ChatConversation>> getConversations() async {
    try {
      final response = await _client
          .from('conversation_meta')
          .select()
          .order('last_message_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return [];

      final customerIds = rows
          .map((e) => e['customer_id'] as String)
          .toSet()
          .toList(growable: false);

      final profilesResponse = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', customerIds);

      final profileMap = {
        for (final row in (profilesResponse as List).cast<Map<String, dynamic>>())
          row['id'] as String: row['full_name'] as String? ?? 'Customer',
      };

      return rows.map((row) {
        final customerId = row['customer_id'] as String;
        return ChatConversation(
          id: row['id'] as String,
          customerId: customerId,
          customerName: profileMap[customerId] ?? 'Customer',
          lastMessage: row['last_message'] as String? ?? '',
          lastMessageAt: row['last_message_at'] != null
              ? DateTime.parse(row['last_message_at'] as String)
              : null,
          unreadCustomer: row['unread_customer'] as int? ?? 0,
          unreadAdmin: row['unread_admin'] as int? ?? 0,
          updatedAt: row['updated_at'] != null
              ? DateTime.parse(row['updated_at'] as String)
              : null,
        );
      }).toList();
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Stream<List<ChatConversation>> streamConversations() {
    return _client
        .from('conversation_meta')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => getConversations());
  }

  Stream<int> streamUnreadCustomerCount(String customerId) {
    return _client
        .from('conversation_meta')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .map((rows) {
          if (rows.isEmpty) return 0;
          return rows.first['unread_customer'] as int? ?? 0;
        });
  }

  Future<Profile> getCustomerProfile(String customerId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', customerId)
          .single();
      return Profile.fromJson(response);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<Map<String, dynamic>?> _getConversationMeta(String customerId) async {
    try {
      final response = await _client
          .from('conversation_meta')
          .select()
          .eq('customer_id', customerId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }
}
