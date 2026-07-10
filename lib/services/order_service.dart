import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import '../models/profile.dart';
import '../models/shift_status.dart';
import '../providers/cart_provider.dart';
import 'supabase_error_handler.dart';

class OrderService {
  OrderService({SupabaseClient? client})
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

  Future<Order> placeOrder({
    required String customerId,
    required String addressId,
    required List<CartItem> items,
    required DateTime deliveryDate,
    required TimeSlot timeSlot,
    String? deliveryNote,
  }) async {
    if (items.isEmpty) {
      throw Exception('Cart is empty');
    }

    try {
      final ref = await _generateUniqueReference();
      final totalPrice = items.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );

      final addressResponse = await _client
          .from('addresses')
          .select()
          .eq('id', addressId)
          .single();

      final orderResponse = await _client
          .from('orders')
          .insert({
            'customer_id': customerId,
            'address_id': addressId,
            'delivery_recipient_name': addressResponse['recipient_name'],
            'delivery_phone': addressResponse['phone'],
            'delivery_full_address': addressResponse['full_address'],
            'delivery_landmark_note': addressResponse['landmark_note'],
            'order_reference': ref,
            'status': 'placed',
            'delivery_date':
                deliveryDate.toIso8601String().split('T').first,
            'time_slot': timeSlot.dbValue,
            'payment_method': 'cod',
            'total_price': totalPrice,
            'delivery_note': deliveryNote,
            'placed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      final orderId = orderResponse['id'] as String;

      final itemsData = items
          .map(
            (item) => {
              'order_id': orderId,
              'product_id': item.product.id,
              'quantity': item.quantity,
              'unit_price': item.product.price,
              'subtotal': item.subtotal,
            },
          )
          .toList();

      try {
        await _client.from('order_items').insert(itemsData);
      } catch (_) {
        await _client.from('order_items').insert(itemsData);
      }

      try {
        await _client.from('notifications').insert({
          'user_id': customerId,
          'order_id': orderId,
          'title': 'Order Placed! 🎉',
          'message':
              'Your order $ref has been placed successfully. We will confirm it shortly.',
          'is_read': false,
        });
      } catch (_) {
      }

      return await getOrderById(orderId);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<Order> getOrderById(String orderId) async {
    try {
      final response = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('id', orderId)
          .single();

      return Order.fromJson(response);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<List<Order>> getCustomerOrders(
    String customerId, {
    String? statusFilter,
  }) async {
    try {
      var query = _client
          .from('orders')
          .select(_orderSelect)
          .eq('customer_id', customerId);

      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      final response =
          await query.order('placed_at', ascending: false);

      return (response as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      final order = await getOrderById(orderId);
      if (order.status != OrderStatus.placed) {
        throw Exception('Only unconfirmed orders can be cancelled');
      }

      await _client.from('orders').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', orderId);
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<Order?> getOrderByReference(String reference) async {
    try {
      final response = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('order_reference', reference)
          .maybeSingle();

      if (response == null) return null;
      return Order.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<List<Order>> getOrdersByStatus(
    String customerId,
    List<String> statuses,
  ) async {
    if (statuses.isEmpty) return [];

    try {
      final response = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('customer_id', customerId)
          .inFilter('status', statuses)
          .order('placed_at', ascending: false);

      return (response as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Stream<Order> streamOrder(String orderId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .asyncMap((data) async {
          if (data.isEmpty) return null;
          return getOrderById(orderId);
        })
        .where((order) => order != null)
        .cast<Order>();
  }

  Future<Map<String, List<Order>>> getDriverOrders(String driverId) async {
    try {
      final response = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('driver_id', driverId)
          .inFilter('status', ['confirmed', 'on_the_way']);

      final orders = (response as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayOrders = orders.where((order) {
        final delivery = DateTime(
          order.deliveryDate.year,
          order.deliveryDate.month,
          order.deliveryDate.day,
        );
        return delivery.year == today.year &&
            delivery.month == today.month &&
            delivery.day == today.day;
      }).toList()
        ..sort(
          (a, b) => _timeSlotOrder(a.timeSlot)
              .compareTo(_timeSlotOrder(b.timeSlot)),
        );

      final scheduledOrders = orders.where((order) {
        final delivery = DateTime(
          order.deliveryDate.year,
          order.deliveryDate.month,
          order.deliveryDate.day,
        );
        return delivery.isAfter(today);
      }).toList()
        ..sort((a, b) {
          final dateCompare = a.deliveryDate.compareTo(b.deliveryDate);
          if (dateCompare != 0) return dateCompare;
          return _timeSlotOrder(a.timeSlot)
              .compareTo(_timeSlotOrder(b.timeSlot));
        });

      return {
        'today': todayOrders,
        'scheduled': scheduledOrders,
      };
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
    required String driverId,
  }) async {
    try {
      final order = await getOrderById(orderId);

      if (order.driverId != driverId) {
        throw Exception('You can only update your own orders');
      }

      final isValidTransition =
          (order.status == OrderStatus.confirmed &&
                  newStatus == 'on_the_way') ||
              (order.status == OrderStatus.onTheWay &&
                  newStatus == 'delivered');

      if (!isValidTransition) {
        throw Exception('Invalid status update');
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final delivery = DateTime(
        order.deliveryDate.year,
        order.deliveryDate.month,
        order.deliveryDate.day,
      );

      if (delivery.isAfter(today)) {
        throw Exception('Cannot update status for future orders');
      }

      final updateData = <String, dynamic>{'status': newStatus};
      final timestamp = DateTime.now().toUtc().toIso8601String();

      if (newStatus == 'on_the_way') {
        updateData['on_the_way_at'] = timestamp;
      } else if (newStatus == 'delivered') {
        updateData['delivered_at'] = timestamp;
      }

      await _client.from('orders').update(updateData).eq('id', orderId);

      if (newStatus == 'delivered') {
        final remaining = await _countActiveOrdersForDriver(driverId);
        if (remaining == 0) {
          await _client.from('profiles').update({
            'shift_status': ShiftStatus.available,
          }).eq('id', driverId);
        }
      } else if (newStatus == 'confirmed') {
        await _client.from('profiles').update({
          'shift_status': ShiftStatus.onDelivery,
        }).eq('id', driverId);
      }

      String notifTitle;
      String notifMessage;

      if (newStatus == 'on_the_way') {
        notifTitle = 'On The Way! 🚚';
        notifMessage =
            'Your order ${order.orderReference} is out for delivery. Get ready to receive it!';
      } else {
        notifTitle = 'Delivered! ✅';
        notifMessage =
            'Your order ${order.orderReference} has been delivered. Thank you for choosing Royal Ph7!';
      }

      try {
        await _client.from('notifications').insert({
          'user_id': order.customerId,
          'order_id': orderId,
          'title': notifTitle,
          'message': notifMessage,
          'is_read': false,
        });
      } catch (_) {
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<List<Order>> getDriverHistory(
    String driverId, {
    String period = 'today',
  }) async {
    try {
      final now = DateTime.now();
      final DateTime startDate;

      switch (period) {
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
        case 'month':
          startDate = now.subtract(const Duration(days: 30));
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }

      final response = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('driver_id', driverId)
          .eq('status', 'delivered')
          .gte('delivered_at', startDate.toUtc().toIso8601String())
          .order('delivered_at', ascending: false);

      return (response as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Stream<List<Map<String, dynamic>>> streamDriverOrders(String driverId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId);
  }

  Stream<List<Map<String, dynamic>>> streamDriverProfile(String driverId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', driverId);
  }

  Future<Profile?> getDriverProfile(String driverId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', driverId)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
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

  Future<int> countActiveOrdersForDriver(String driverId) async {
    return _countActiveOrdersForDriver(driverId);
  }

  Future<int> _countActiveOrdersForDriver(String driverId) async {
    final response = await _client
        .from('orders')
        .select('id')
        .eq('driver_id', driverId)
        .inFilter('status', ['confirmed', 'on_the_way']);

    return (response as List).length;
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

  String _generateReference() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final suffix = List.generate(
      8,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'RPH7-$suffix';
  }

  Future<String> _generateUniqueReference() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final ref = _generateReference();
      final existing = await _client
          .from('orders')
          .select('id')
          .eq('order_reference', ref)
          .maybeSingle();

      if (existing == null) return ref;
    }
    throw Exception('Failed to generate order reference');
  }
}
