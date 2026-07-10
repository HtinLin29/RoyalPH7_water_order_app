import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import 'address.dart';

enum OrderStatus {
  placed,
  confirmed,
  onTheWay,
  delivered,
  cancelled,
}

enum TimeSlot {
  morning,
  afternoon,
  evening,
}

extension TimeSlotExtension on TimeSlot {
  String get label {
    switch (this) {
      case TimeSlot.morning:
        return 'Morning';
      case TimeSlot.afternoon:
        return 'Afternoon';
      case TimeSlot.evening:
        return 'Evening';
    }
  }

  String get timeRange {
    switch (this) {
      case TimeSlot.morning:
        return '8:00 AM – 12:00 PM';
      case TimeSlot.afternoon:
        return '12:00 PM – 5:00 PM';
      case TimeSlot.evening:
        return '5:00 PM – 8:00 PM';
    }
  }

  String get icon {
    switch (this) {
      case TimeSlot.morning:
        return '🌅';
      case TimeSlot.afternoon:
        return '☀️';
      case TimeSlot.evening:
        return '🌆';
    }
  }

  String get dbValue => name;

  static TimeSlot fromString(String value) {
    return TimeSlot.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TimeSlot.morning,
    );
  }
}

extension OrderStatusExtension on OrderStatus {
  String get dbValue {
    switch (this) {
      case OrderStatus.onTheWay:
        return 'on_the_way';
      default:
        return name;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.onTheWay:
        return 'On the way';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }

  static OrderStatus fromDb(String value) {
    if (value == 'on_the_way') return OrderStatus.onTheWay;
    return OrderStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OrderStatus.placed,
    );
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>? ??
        json['products'] as Map<String, dynamic>?;
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      productName: product?['name'] as String? ?? 'Product',
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
    );
  }
}

class Order {
  final String id;
  final String customerId;
  final String? driverId;
  final String? driverName;
  final String? addressId;
  final Address? address;
  final String? deliveryRecipientName;
  final String? deliveryPhone;
  final String? deliveryFullAddress;
  final String? deliveryLandmarkNote;
  final String orderReference;
  final OrderStatus status;
  final DateTime deliveryDate;
  final TimeSlot timeSlot;
  final String paymentMethod;
  final double totalPrice;
  final String? deliveryNote;
  final DateTime placedAt;
  final DateTime? confirmedAt;
  final DateTime? onTheWayAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.customerId,
    this.driverId,
    this.driverName,
    this.addressId,
    this.address,
    this.deliveryRecipientName,
    this.deliveryPhone,
    this.deliveryFullAddress,
    this.deliveryLandmarkNote,
    required this.orderReference,
    required this.status,
    required this.deliveryDate,
    required this.timeSlot,
    this.paymentMethod = 'cod',
    required this.totalPrice,
    this.deliveryNote,
    required this.placedAt,
    this.confirmedAt,
    this.onTheWayAt,
    this.deliveredAt,
    this.cancelledAt,
    this.items = const [],
  });

  Address? get displayAddress {
    if (address != null) return address;
    if (deliveryFullAddress == null || deliveryFullAddress!.trim().isEmpty) {
      return null;
    }
    return Address(
      id: addressId ?? '',
      userId: customerId,
      label: 'Delivery',
      recipientName: deliveryRecipientName ?? '',
      phone: deliveryPhone ?? '',
      fullAddress: deliveryFullAddress!,
      landmarkNote: deliveryLandmarkNote,
      createdAt: placedAt,
    );
  }

  String get formattedTotal => '฿${totalPrice.toStringAsFixed(0)}';

  String get formattedDate =>
      DateFormat('d MMM yyyy').format(deliveryDate);

  bool get isDeliveryOverdue {
    if (status == OrderStatus.delivered ||
        status == OrderStatus.cancelled) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final delivery = DateTime(
      deliveryDate.year,
      deliveryDate.month,
      deliveryDate.day,
    );
    return delivery.isBefore(today);
  }

  String get deliveryDateLabel =>
      isDeliveryOverdue ? 'Overdue' : formattedDate;

  String get statusLabel {
    switch (status) {
      case OrderStatus.placed:
        return 'Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.onTheWay:
        return 'On The Way';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get statusColor {
    switch (status) {
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.onTheWay:
        return AppColors.secondary;
      case OrderStatus.confirmed:
        return AppColors.primary;
      case OrderStatus.placed:
        return AppColors.warning;
    }
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    final addressJson =
        json['address'] ?? json['addresses'];
    final itemsJson = json['items'] ?? json['order_items'];
    return Order(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      driverId: json['driver_id'] as String?,
      driverName: driver?['full_name'] as String?,
      addressId: json['address_id'] as String?,
      address: addressJson != null
          ? Address.fromJson(addressJson as Map<String, dynamic>)
          : null,
      deliveryRecipientName: json['delivery_recipient_name'] as String?,
      deliveryPhone: json['delivery_phone'] as String?,
      deliveryFullAddress: json['delivery_full_address'] as String?,
      deliveryLandmarkNote: json['delivery_landmark_note'] as String?,
      orderReference: json['order_reference'] as String,
      status: OrderStatusExtension.fromDb(
        json['status'] as String? ?? 'placed',
      ),
      deliveryDate: DateTime.parse(json['delivery_date'] as String),
      timeSlot: TimeSlotExtension.fromString(
        json['time_slot'] as String? ?? 'morning',
      ),
      paymentMethod: json['payment_method'] as String? ?? 'cod',
      totalPrice: (json['total_price'] as num).toDouble(),
      deliveryNote: json['delivery_note'] as String?,
      placedAt: json['placed_at'] != null
          ? DateTime.parse(json['placed_at'] as String)
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      onTheWayAt: json['on_the_way_at'] != null
          ? DateTime.parse(json['on_the_way_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      items: itemsJson != null
          ? (itemsJson as List)
              .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}
