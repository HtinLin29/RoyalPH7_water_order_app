import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/address.dart';
import 'supabase_error_handler.dart';

class AddressService {
  AddressService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Address>> getAddresses(String userId) async {
    try {
      final response = await _client
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => Address.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<Address> addAddress({
    required String userId,
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String? landmarkNote,
    required bool isDefault,
  }) async {
    try {
      if (isDefault) {
        await _client
            .from('addresses')
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      final response = await _client
          .from('addresses')
          .insert({
            'user_id': userId,
            'label': label,
            'recipient_name': recipientName,
            'phone': phone,
            'full_address': fullAddress,
            'landmark_note': landmarkNote,
            'is_default': isDefault,
          })
          .select()
          .single();

      return Address.fromJson(response);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> setDefault(String addressId, String userId) async {
    try {
      await _client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', userId);

      await _client
          .from('addresses')
          .update({'is_default': true})
          .eq('id', addressId);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      final activeOrders = await _client
          .from('orders')
          .select('id')
          .eq('address_id', addressId)
          .inFilter('status', ['placed', 'confirmed', 'on_the_way']);

      if ((activeOrders as List).isNotEmpty) {
        throw Exception(
          'Cannot delete an address used by an active order.',
        );
      }

      await _client
          .from('orders')
          .update({'address_id': null})
          .eq('address_id', addressId)
          .inFilter('status', ['delivered', 'cancelled']);

      await _client.from('addresses').delete().eq('id', addressId);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw Exception(
          'Cannot delete an address that is used by an existing order.',
        );
      }
      throw Exception(SupabaseErrorHandler.getMessage(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<Address?> getDefaultAddress(String userId) async {
    try {
      final response = await _client
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .eq('is_default', true)
          .maybeSingle();

      if (response == null) return null;
      return Address.fromJson(response);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }
}
