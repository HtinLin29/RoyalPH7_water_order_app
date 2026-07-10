import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/order.dart';
import '../../models/profile.dart';
import '../../models/shift_status.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../widgets/driver_order_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../customer/customer_ui.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  final _orderService = OrderService();
  late final TabController _tabController;

  List<Order> _todayOrders = [];
  List<Order> _scheduledOrders = [];
  int _deliveredTodayCount = 0;
  String _shiftStatus = ShiftStatus.off;
  int _activeOrdersCount = 0;
  bool _isLoading = true;
  bool _isUpdatingShift = false;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
    final driverId = Supabase.instance.client.auth.currentUser!.id;
    _ordersSubscription = _orderService.streamDriverOrders(driverId).listen(
      (_) => _loadOrders(silent: true),
      onError: (_) {},
    );
    _profileSubscription = _orderService.streamDriverProfile(driverId).listen(
      (_) => _loadOrders(silent: true),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ordersSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final driverId = Supabase.instance.client.auth.currentUser!.id;
      final result = await Future.wait([
        _orderService.getDriverOrders(driverId),
        _orderService.getDriverHistory(driverId, period: 'today'),
        _orderService.getDriverProfile(driverId),
        _orderService.countActiveOrdersForDriver(driverId),
      ]);

      final ordersResult = result[0] as Map<String, List<Order>>;
      final history = result[1] as List<Order>;
      final profile = result[2] as Profile?;
      final activeCount = result[3] as int;

      if (mounted) {
        setState(() {
          _todayOrders = ordersResult['today'] ?? [];
          _scheduledOrders = ordersResult['scheduled'] ?? [];
          _deliveredTodayCount = history.length;
          _shiftStatus = profile?.shiftStatus ?? ShiftStatus.off;
          _activeOrdersCount = activeCount;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startShift() async {
    setState(() => _isUpdatingShift = true);
    try {
      final driverId = Supabase.instance.client.auth.currentUser!.id;
      await _orderService.updateDriverShiftStatus(
        driverId: driverId,
        shiftStatus: ShiftStatus.available,
      );
      await _loadOrders(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingShift = false);
    }
  }

  Future<void> _endShift() async {
    if (_shiftStatus == ShiftStatus.onDelivery && _activeOrdersCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete all deliveries before ending your shift'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End your shift for today?'),
        content: const Text(
          'You will not receive new delivery assignments until you start your shift again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Shift'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUpdatingShift = true);
    try {
      final driverId = Supabase.instance.client.auth.currentUser!.id;
      await _orderService.updateDriverShiftStatus(
        driverId: driverId,
        shiftStatus: ShiftStatus.off,
      );
      await _loadOrders(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingShift = false);
    }
  }

  Future<void> _logout() async {
    final authProvider = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    await AuthService().signOut(
      onClearProfile: authProvider.clearProfile,
      onClearCart: cartProvider.clearCart,
    );
    if (mounted) context.go('/login');
  }

  Color _slotColor(TimeSlot slot) {
    switch (slot) {
      case TimeSlot.morning:
        return AppColors.warning;
      case TimeSlot.afternoon:
        return AppColors.primary;
      case TimeSlot.evening:
        return AppColors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Deliveries'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _ShiftStatusBar(
            shiftStatus: _shiftStatus,
            activeOrdersCount: _activeOrdersCount,
            isUpdating: _isUpdatingShift,
            onStartShift: _startShift,
            onEndShift: _endShift,
          ),
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.today, size: 16),
                      const SizedBox(width: 6),
                      const Text('Today'),
                      if (_todayOrders.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _TabBadge(
                          count: _todayOrders.length,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month, size: 16),
                      const SizedBox(width: 6),
                      const Text('Scheduled'),
                      if (_scheduledOrders.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _TabBadge(
                          count: _scheduledOrders.length,
                          color: AppColors.warning,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _StatsSummaryBar(
            todayCount: _todayOrders.length,
            scheduledCount: _scheduledOrders.length,
            deliveredTodayCount: _deliveredTodayCount,
            shiftStatus: _shiftStatus,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TodayOrdersList(
                  orders: _todayOrders,
                  isLoading: _isLoading,
                  slotColor: _slotColor,
                ),
                _ScheduledOrdersList(
                  orders: _scheduledOrders,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftStatusBar extends StatelessWidget {
  final String shiftStatus;
  final int activeOrdersCount;
  final bool isUpdating;
  final VoidCallback onStartShift;
  final VoidCallback onEndShift;

  const _ShiftStatusBar({
    required this.shiftStatus,
    required this.activeOrdersCount,
    required this.isUpdating,
    required this.onStartShift,
    required this.onEndShift,
  });

  @override
  Widget build(BuildContext context) {
    if (shiftStatus == ShiftStatus.off) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CustomerUi.gradientButton(
            label: 'Start Shift',
            onPressed: isUpdating ? null : onStartShift,
            loading: isUpdating,
            height: 48,
          ),
        ),
      );
    }

    if (shiftStatus == ShiftStatus.onDelivery) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activeOrdersCount == 1
                      ? 'On delivery — 1 order remaining'
                      : 'On delivery — $activeOrdersCount orders remaining',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'You are available for deliveries',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: isUpdating ? null : onEndShift,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                side: const BorderSide(color: AppColors.borderMuted),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isUpdating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'End Shift',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _TabBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatsSummaryBar extends StatelessWidget {
  final int todayCount;
  final int scheduledCount;
  final int deliveredTodayCount;
  final String shiftStatus;

  const _StatsSummaryBar({
    required this.todayCount,
    required this.scheduledCount,
    required this.deliveredTodayCount,
    required this.shiftStatus,
  });

  Color _shiftColor() {
    switch (shiftStatus) {
      case ShiftStatus.available:
        return AppColors.success;
      case ShiftStatus.onDelivery:
        return AppColors.warning;
      case ShiftStatus.off:
      default:
        return AppColors.textMuted;
    }
  }

  IconData _shiftIcon() {
    switch (shiftStatus) {
      case ShiftStatus.available:
        return Icons.check_circle;
      case ShiftStatus.onDelivery:
        return Icons.local_shipping;
      case ShiftStatus.off:
      default:
        return Icons.power_settings_new;
    }
  }

  String _shiftLabel() {
    switch (shiftStatus) {
      case ShiftStatus.available:
        return 'Available';
      case ShiftStatus.onDelivery:
        return 'On Delivery';
      case ShiftStatus.off:
      default:
        return 'Off Duty';
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftColor = _shiftColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surfaceSoft,
      child: Row(
        children: [
          _StatChip(
            label: 'Today',
            value: todayCount.toString(),
            color: AppColors.primary,
          ),
          _StatChip(
            label: 'Scheduled',
            value: scheduledCount.toString(),
            color: AppColors.warning,
          ),
          _StatChip(
            label: 'Delivered',
            value: deliveredTodayCount.toString(),
            color: AppColors.success,
          ),
          _StatChip(
            label: 'Shift',
            value: '',
            color: shiftColor,
            icon: _shiftIcon(),
            subtitle: _shiftLabel(),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final String? subtitle;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            if (icon != null)
              Icon(icon, color: color, size: 22)
            else
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: color,
                ),
              ),
            Text(
              subtitle ?? label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayOrdersList extends StatelessWidget {
  final List<Order> orders;
  final bool isLoading;
  final Color Function(TimeSlot) slotColor;

  const _TodayOrdersList({
    required this.orders,
    required this.isLoading,
    required this.slotColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          DriverOrderCardShimmer(),
          DriverOrderCardShimmer(),
          DriverOrderCardShimmer(),
        ],
      );
    }

    if (orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'All done for today!',
                style: AppTextStyles.heading3,
              ),
              SizedBox(height: 8),
              Text(
                'No pending deliveries',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = <TimeSlot, List<Order>>{};
    for (final order in orders) {
      grouped.putIfAbsent(order.timeSlot, () => []).add(order);
    }

    final slots = [
      TimeSlot.morning,
      TimeSlot.afternoon,
      TimeSlot.evening,
    ].where((slot) => grouped.containsKey(slot));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final slot in slots) ...[
          _TimeSlotHeader(
            slot: slot,
            color: slotColor(slot),
          ),
          ...grouped[slot]!.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DriverOrderCard(order: order),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ScheduledOrdersList extends StatelessWidget {
  final List<Order> orders;
  final bool isLoading;

  const _ScheduledOrdersList({
    required this.orders,
    required this.isLoading,
  });

  int _daysUntil(DateTime deliveryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final delivery = DateTime(
      deliveryDate.year,
      deliveryDate.month,
      deliveryDate.day,
    );
    return delivery.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          DriverOrderCardShimmer(),
          DriverOrderCardShimmer(),
        ],
      );
    }

    if (orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_available,
                color: AppColors.textMuted,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'No scheduled deliveries',
                style: AppTextStyles.heading3,
              ),
              SizedBox(height: 8),
              Text(
                'Future orders will appear here',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = <String, List<Order>>{};
    for (final order in orders) {
      grouped.putIfAbsent(order.formattedDate, () => []).add(order);
    }

    final dates = grouped.keys.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final date in dates) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${grouped[date]!.length} orders',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text(
              '⏰ Delivery in ${_daysUntil(grouped[date]!.first.deliveryDate)} day${_daysUntil(grouped[date]!.first.deliveryDate) == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.warning,
              ),
            ),
          ),
          ...grouped[date]!.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DriverOrderCard(order: order, isScheduled: true),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TimeSlotHeader extends StatelessWidget {
  final TimeSlot slot;
  final Color color;

  const _TimeSlotHeader({required this.slot, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(slot.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            slot.label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            slot.timeRange,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
