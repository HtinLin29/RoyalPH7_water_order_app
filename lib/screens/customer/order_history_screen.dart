import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../services/supabase_error_handler.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_shimmer.dart';
import 'customer_ui.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: CustomerUi.primaryGradient,
            ),
          ),
          title: const Text(
            'My Orders',
            style: AppTextStyles.appBarTitle,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: ColoredBox(
              color: Colors.white,
              child: TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.normal),
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _OrderList(
              statuses: ['placed', 'confirmed', 'on_the_way'],
              emptyType: _EmptyType.active,
            ),
            _OrderList(
              statuses: ['delivered'],
              emptyType: _EmptyType.completed,
            ),
            _OrderList(
              statuses: ['cancelled'],
              emptyType: _EmptyType.cancelled,
            ),
          ],
        ),
      ),
    );
  }
}

enum _EmptyType { active, completed, cancelled }

class _OrderList extends StatefulWidget {
  final List<String> statuses;
  final _EmptyType emptyType;

  const _OrderList({
    required this.statuses,
    required this.emptyType,
  });

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList>
    with AutomaticKeepAliveClientMixin {
  final _orderService = OrderService();
  List<Order>? _orders;
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final orders = await _orderService.getOrdersByStatus(
        userId,
        widget.statuses,
      );
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (await SupabaseErrorHandler.handleIfSessionExpired(context, e)) {
        return;
      }
      if (mounted) {
        setState(() {
          _error = SupabaseErrorHandler.getMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Widget _emptyState() {
    switch (widget.emptyType) {
      case _EmptyType.active:
        return EmptyStateWidget(
          icon: Icons.receipt_long_outlined,
          title: 'No active orders',
          subtitle: 'Place your first order!',
          buttonText: 'Order Now',
          onButton: () => context.go('/customer/home'),
        );
      case _EmptyType.completed:
        return const EmptyStateWidget(
          icon: Icons.check_circle_outline,
          title: 'No completed orders yet',
          subtitle: 'Your delivered orders will appear here',
        );
      case _EmptyType.cancelled:
        return const EmptyStateWidget(
          icon: Icons.cancel_outlined,
          title: 'No cancelled orders',
          subtitle: 'Cancelled orders will appear here',
        );
    }
  }

  bool _isActive(Order order) =>
      order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const OrderListShimmer();
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: AppErrorWidget(message: _error!, onRetry: _loadOrders),
          ),
        ],
      );
    }

    final orders = _orders ?? [];

    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: _emptyState(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _OrderHistoryCard(
            order: order,
            showTrack: _isActive(order),
            onTap: () => context.push('/customer/orders/${order.id}'),
            onTrack: () => context.push('/customer/tracking/${order.id}'),
          );
        },
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final Order order;
  final bool showTrack;
  final VoidCallback onTap;
  final VoidCallback onTrack;

  const _OrderHistoryCard({
    required this.order,
    required this.showTrack,
    required this.onTap,
    required this.onTrack,
  });

  String _itemsSummary() {
    if (order.items.isEmpty) return '';
    final shown = order.items
        .take(2)
        .map((i) => '${i.productName} × ${i.quantity}')
        .join(', ');
    if (order.items.length > 2) {
      return '$shown +${order.items.length - 2} more';
    }
    return shown;
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        CustomerUi.statusBadgeColor(order.status.dbValue);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: CustomerUi.cardDecoration,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderReference,
                    style: AppTextStyles.monoBold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  order.deliveryDateLabel,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.schedule, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  order.timeSlot.label,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.shopping_basket_outlined,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _itemsSummary(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (showTrack)
                  OutlinedButton(
                    onPressed: onTrack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Track Order',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                const Spacer(),
                Text(
                  order.formattedTotal,
                  style: AppTextStyles.price,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
