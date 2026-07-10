import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_with_stats.dart';
import '../models/order.dart';
import '../models/profile.dart';
import '../models/shift_status.dart';
import 'supabase_error_handler.dart';

class AdminService {
  AdminService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _orderSelect = '''
    *,
    address:addresses(*),
    items:order_items(
      *,
      product:products(*)
    ),
    driver:profiles!orders_driver_id_fkey(
      full_name,
      phone
    )
  ''';

  Future<List<Order>> getAllOrders({
    String? statusFilter,
    DateTime? dateFilter,
    String? driverFilter,
  }) async {
    try {
      var query = _client.from('orders').select(_orderSelect);

      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }
      if (dateFilter != null) {
        final dateStr = DateTime(
          dateFilter.year,
          dateFilter.month,
          dateFilter.day,
        ).toIso8601String().split('T').first;
        query = query.eq('delivery_date', dateStr);
      }
      if (driverFilter != null) {
        query = query.eq('driver_id', driverFilter);
      }

      final response = await query.order('placed_at', ascending: false);

      return (response as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<List<Order>> getPendingOrders() async {
    try {
      final response = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('status', 'placed')
          .isFilter('driver_id', null);

      final orders = (response as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          final dateCompare = a.deliveryDate.compareTo(b.deliveryDate);
          if (dateCompare != 0) return dateCompare;
          return _timeSlotOrder(a.timeSlot)
              .compareTo(_timeSlotOrder(b.timeSlot));
        });

      return orders;
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<List<DriverWithStats>> getDriversWithStats() async {
    try {
      final driversResponse = await _client
          .from('profiles')
          .select()
          .eq('role', 'driver')
          .order('full_name', ascending: true);

      final drivers = (driversResponse as List)
          .map((e) => Profile.fromJson(e as Map<String, dynamic>))
          .toList();

      if (drivers.isEmpty) return [];

      final today = _todayDateString();
      final ordersResponse = await _client
          .from('orders')
          .select('driver_id')
          .eq('delivery_date', today)
          .inFilter('status', ['confirmed', 'on_the_way']);

      final counts = <String, int>{};
      for (final row in ordersResponse as List) {
        final driverId = row['driver_id'] as String?;
        if (driverId == null) continue;
        counts[driverId] = (counts[driverId] ?? 0) + 1;
      }

      return drivers
          .map(
            (profile) => DriverWithStats(
              profile: profile,
              activeOrdersToday: counts[profile.id] ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<List<Profile>> getActiveDrivers() async {
    final drivers = await getDriversWithStats();
    return drivers
        .where((driver) => driver.profile.isActive)
        .map((driver) => driver.profile)
        .toList();
  }

  Future<String> createDriver({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    String? avatarUrl,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-driver',
        body: {
          'fullName': fullName.trim(),
          'phone': phone.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
        },
      );

      final data = response.data;
      if (response.status != 200 || data is! Map<String, dynamic>) {
        final message = data is Map<String, dynamic>
            ? data['error'] as String?
            : null;
        throw Exception(message ?? 'Failed to create driver.');
      }

      final driverId = data['driverId'] as String?;
      if (driverId == null || driverId.isEmpty) {
        throw Exception('Driver account was created without an id.');
      }

      return driverId;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> toggleDriverStatus({
    required String driverId,
    required bool currentIsActive,
  }) async {
    try {
      await _client.from('profiles').update({
        'is_active': !currentIsActive,
      }).eq('id', driverId);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<String> uploadDriverPhoto({
    required String driverId,
    required Uint8List imageBytes,
    String fileExtension = 'jpg',
  }) async {
    try {
      final path = '$driverId/profile.$fileExtension';
      await _client.storage.from('driver-avatars').uploadBinary(
            path,
            imageBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _mimeTypeForExtension(fileExtension),
            ),
          );

      final publicUrl =
          _client.storage.from('driver-avatars').getPublicUrl(path);

      await _client.from('profiles').update({
        'avatar_url': publicUrl,
      }).eq('id', driverId);

      return publicUrl;
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> deleteDriver(String driverId) async {
    try {
      final response = await _client.functions.invoke(
        'delete-driver',
        body: {'driverId': driverId},
      );

      final data = response.data;
      if (response.status != 200) {
        final message = data is Map<String, dynamic>
            ? data['error'] as String?
            : null;
        throw Exception(message ?? 'Failed to delete driver.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> assignDriver({
    required String orderId,
    required String driverId,
  }) async {
    try {
      final orderResponse = await _client
          .from('orders')
          .select('id, status, order_reference')
          .eq('id', orderId)
          .single();

      if (orderResponse['status'] != 'placed') {
        throw Exception('Order is no longer available for assignment');
      }

      final now = DateTime.now().toUtc().toIso8601String();

      await _client.from('orders').update({
        'status': 'confirmed',
        'driver_id': driverId,
        'confirmed_at': now,
      }).eq('id', orderId);

      await _client.from('profiles').update({
        'shift_status': ShiftStatus.onDelivery,
      }).eq('id', driverId);

      final customerResponse = await _client
          .from('orders')
          .select('customer_id')
          .eq('id', orderId)
          .single();

      final customerId = customerResponse['customer_id'] as String;

      try {
        await _client.from('notifications').insert([
          {
            'user_id': customerId,
            'order_id': orderId,
            'title': 'Order Confirmed! 🎉',
            'message':
                'Your order has been confirmed and a driver has been assigned. Get ready for your delivery!',
            'is_read': false,
          },
          {
            'user_id': driverId,
            'order_id': orderId,
            'title': 'New Delivery Assigned 📦',
            'message':
                'You have a new delivery assigned. Check your orders.',
            'is_read': false,
          },
        ]);
      } catch (_) {
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<Map<String, int>> getOrderStats() async {
    try {
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

      final results = await Future.wait([
        _client
            .from('orders')
            .select('id')
            .gte('placed_at', todayStart),
        _client.from('orders').select('id').eq('status', 'placed'),
        _client
            .from('orders')
            .select('id')
            .inFilter('status', ['confirmed', 'on_the_way']),
        _client
            .from('orders')
            .select('id')
            .eq('status', 'delivered')
            .gte('delivered_at', todayStart),
      ]);

      return {
        'total_today': (results[0] as List).length,
        'pending': (results[1] as List).length,
        'active': (results[2] as List).length,
        'delivered_today': (results[3] as List).length,
      };
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Stream<List<Map<String, dynamic>>> streamPendingOrders() {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'placed');
  }

  Stream<List<Map<String, dynamic>>> streamDriverProfiles() {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('role', 'driver');
  }

  Future<void> updateDriverShiftStatus({
    required String driverId,
    required String shiftStatus,
  }) async {
    try {
      await _client.from('profiles').update({
        'shift_status': shiftStatus,
      }).eq('id', driverId);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
  }) async {
    try {
      await _client.from('profiles').update({
        'full_name': fullName,
        'phone': phone,
      }).eq('id', userId);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  int _timeSlotOrder(TimeSlot slot) {
    switch (slot) {
      case TimeSlot.morning:
        return 0;
      case TimeSlot.afternoon:
        return 1;
      case TimeSlot.evening:
        return 2;
    }
  }

  String _todayDateString() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).toIso8601String().split('T').first;
  }

  String _mimeTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
