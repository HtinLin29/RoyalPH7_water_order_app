import 'dart:async';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/loading_shimmer.dart';
import 'customer_ui.dart';

class TrackingStep {
  final String status;
  final String label;
  final String description;
  final DateTime? timestamp;

  const TrackingStep({
    required this.status,
    required this.label,
    required this.description,
    this.timestamp,
  });
}

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  final _orderService = OrderService();
  Order? _order;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<Order>? _subscription;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadOrder();
    _subscription = _orderService.streamOrder(widget.orderId).listen(
      (updatedOrder) {
        if (mounted) setState(() => _order = updatedOrder);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final order = await _orderService.getOrderById(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  int _getStatusIndex(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return 0;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.onTheWay:
        return 2;
      case OrderStatus.delivered:
        return 3;
      case OrderStatus.cancelled:
        return -1;
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _orderService.cancelOrder(widget.orderId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/customer/orders'),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: CustomerUi.primaryGradient,
          ),
        ),
        title: const Text(
          'Track Order',
          style: AppTextStyles.appBarTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadOrder,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _order == null) {
      return const OrderTrackingShimmer();
    }

    if (_error != null && _order == null) {
      return AppErrorWidget(message: _error!, onRetry: _loadOrder);
    }

    final order = _order!;
    final steps = _buildSteps(order);
    final currentStepIndex = _getStatusIndex(order.status);
    final isCancelled = order.status == OrderStatus.cancelled;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(order),
          const SizedBox(height: 16),
          const Text('Order Status', style: CustomerUi.sectionTitle),
          const SizedBox(height: 12),
          if (isCancelled) _buildCancelledBanner(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: CustomerUi.cardDecoration,
            child: Column(
              children: List.generate(steps.length, (index) {
                final step = steps[index];
                final isLast = index == steps.length - 1;
                final isCompleted =
                    !isCancelled && index < currentStepIndex;
                final isCurrent =
                    !isCancelled && index == currentStepIndex;
                final isPastOrCurrent =
                    !isCancelled && index <= currentStepIndex;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        _StepCircle(
                          isCompleted: isPastOrCurrent && !isCurrent,
                          isCurrent: isCurrent,
                          pulseController: _pulseController,
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 56,
                            color: isCompleted
                                ? AppColors.success
                                : AppColors.border,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isPastOrCurrent
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              step.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            if (step.timestamp != null)
                              Text(
                                DateFormat('dd MMM, hh:mm a')
                                    .format(step.timestamp!.toLocal()),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          if (order.driverName != null) ...[
            const SizedBox(height: 16),
            _InfoCard(
              icon: Icons.person,
              iconBg: AppColors.primary.withValues(alpha: 0.1),
              title: order.driverName!,
              subtitle: 'Your delivery driver',
            ),
          ],
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.location_on_outlined,
            iconBg: AppColors.primary.withValues(alpha: 0.1),
            title: order.displayAddress?.recipientName ?? 'Recipient',
            subtitle: order.displayAddress?.fullAddress ?? '',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: CustomerUi.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Items', style: CustomerUi.sectionTitle),
                const SizedBox(height: 8),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '×${item.quantity}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.productName,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '฿${item.subtotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      order.formattedTotal,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'monospace',
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (order.status == OrderStatus.placed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _cancelOrder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Cancel Order',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<TrackingStep> _buildSteps(Order order) {
    return [
      TrackingStep(
        status: 'placed',
        label: 'Order Placed',
        description: 'Your order has been received',
        timestamp: order.placedAt,
      ),
      TrackingStep(
        status: 'confirmed',
        label: 'Confirmed',
        description: 'A driver has been assigned to your order',
        timestamp: order.confirmedAt,
      ),
      TrackingStep(
        status: 'on_the_way',
        label: 'On The Way',
        description: 'Your order is out for delivery',
        timestamp: order.onTheWayAt,
      ),
      TrackingStep(
        status: 'delivered',
        label: 'Delivered',
        description: 'Order delivered successfully!',
        timestamp: order.deliveredAt,
      ),
    ];
  }

  Widget _buildHeaderCard(Order order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: CustomerUi.primaryGradient,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.orderReference,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderChip(
                icon: Icons.calendar_today,
                text: order.formattedDate,
              ),
              const SizedBox(width: 8),
              _HeaderChip(
                icon: Icons.schedule,
                text: order.timeSlot.label,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel, color: AppColors.error, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This order was cancelled',
              style: TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final bool isCompleted;
  final bool isCurrent;
  final AnimationController pulseController;

  const _StepCircle({
    required this.isCompleted,
    required this.isCurrent,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrent
            ? AppColors.primary
            : isCompleted
                ? AppColors.success
                : Colors.transparent,
        border: isCompleted || isCurrent
            ? null
            : Border.all(color: AppColors.borderMuted, width: 2),
      ),
      child: isCompleted
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : isCurrent
              ? const Icon(Icons.circle, size: 10, color: Colors.white)
              : null,
    );

    if (!isCurrent) return inner;

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(4 + pulseController.value * 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary
                  .withValues(alpha: 0.3 * (1 - pulseController.value)),
              width: 2,
            ),
          ),
          child: child,
        );
      },
      child: inner,
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeaderChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CustomerUi.cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
