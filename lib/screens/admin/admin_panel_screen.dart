import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/driver_with_stats.dart';
import '../../models/message.dart';
import '../../models/order.dart';
import '../../services/admin_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/order_card.dart';
import '../customer/customer_ui.dart';
import 'driver_management_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final _adminService = AdminService();
  late final TabController _tabController;
  Map<String, int> _stats = {
    'total_today': 0,
    'pending': 0,
    'active': 0,
    'delivered_today': 0,
  };
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openOrdersForDriver(String driverId) {
    _AllOrdersTab.refreshKey.currentState?.setDriverFilter(driverId);
    _tabController.animateTo(1);
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final stats = await _adminService.getOrderStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadStats();
    _PendingOrdersTab.refreshKey.currentState?.reload();
    _AllOrdersTab.refreshKey.currentState?.reload();
    DriverManagementTab.refreshKey.currentState?.reload();
    _MessagesTab.refreshKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: CustomerUi.primaryGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Admin Panel',
                              style: AppTextStyles.appBarTitle,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _refreshAll,
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_outline,
                              color: Colors.white),
                          tooltip: 'Profile',
                          onPressed: () => context.push('/admin/profile'),
                        ),
                      ],
                    ),
                  ),
                  _StatsBar(stats: _stats, isLoading: _loadingStats),
                  Material(
                    color: Colors.transparent,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: Colors.white,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 13,
                      ),
                      dividerColor: Colors.transparent,
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      splashFactory: NoSplash.splashFactory,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tabs: [
                        Tab(
                          child: _TabLabel(
                            text: 'Pending',
                            badgeCount: _stats['pending'] ?? 0,
                          ),
                        ),
                        const Tab(text: 'Orders'),
                        const Tab(text: 'Drivers'),
                        const Tab(text: 'Chat'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PendingOrdersTab(
                    key: _PendingOrdersTab.refreshKey,
                    onOrdersChanged: _loadStats,
                  ),
                  _AllOrdersTab(key: _AllOrdersTab.refreshKey),
                  DriverManagementTab(
                    key: DriverManagementTab.refreshKey,
                    onViewDriverOrders: _openOrdersForDriver,
                  ),
                  _MessagesTab(key: _MessagesTab.refreshKey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String text;
  final int badgeCount;

  const _TabLabel({required this.text, required this.badgeCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (badgeCount > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                height: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatsBar extends StatelessWidget {
  final Map<String, int> stats;
  final bool isLoading;

  const _StatsBar({required this.stats, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: isLoading
          ? const Row(
              children: [
                StatCardShimmer(),
                StatCardShimmer(),
                StatCardShimmer(),
                StatCardShimmer(),
              ],
            )
          : Row(
              children: [
                _AdminStat(
                  label: 'Today',
                  value: stats['total_today'] ?? 0,
                  icon: Icons.today,
                ),
                _AdminStat(
                  label: 'Pending',
                  value: stats['pending'] ?? 0,
                  icon: Icons.hourglass_empty,
                  highlight: (stats['pending'] ?? 0) > 0,
                ),
                _AdminStat(
                  label: 'Active',
                  value: stats['active'] ?? 0,
                  icon: Icons.local_shipping,
                ),
                _AdminStat(
                  label: 'Delivered',
                  value: stats['delivered_today'] ?? 0,
                  icon: Icons.check_circle,
                ),
              ],
            ),
    );
  }
}

class _AdminStat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final bool highlight;

  const _AdminStat({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: highlight ? AppColors.warning : Colors.white,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingOrdersTab extends StatefulWidget {
  final VoidCallback? onOrdersChanged;

  const _PendingOrdersTab({super.key, this.onOrdersChanged});

  static final refreshKey = GlobalKey<_PendingOrdersTabState>();

  @override
  State<_PendingOrdersTab> createState() => _PendingOrdersTabState();
}

class _PendingOrdersTabState extends State<_PendingOrdersTab> {
  final _adminService = AdminService();
  List<Order> _orders = [];
  bool _isLoading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _subscription = _adminService.streamPendingOrders().listen(
      (_) => _loadOrders(silent: true),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void reload() => _loadOrders();

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final orders = await _adminService.getPendingOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
        widget.onOrdersChanged?.call();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _PendingCardShimmer(),
          _PendingCardShimmer(),
          _PendingCardShimmer(),
        ],
      );
    }

    if (_orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, color: AppColors.textMuted, size: 64),
              SizedBox(height: 16),
              Text(
                'No pending orders',
                style: AppTextStyles.heading3,
              ),
              SizedBox(height: 8),
              Text(
                'New orders will appear here automatically',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (context, index) => _PendingOrderCard(
        order: _orders[index],
        onAssigned: () {
          _loadOrders(silent: true);
          widget.onOrdersChanged?.call();
        },
      ),
    );
  }
}

class _PendingOrderCard extends StatefulWidget {
  final Order order;
  final VoidCallback onAssigned;

  const _PendingOrderCard({
    required this.order,
    required this.onAssigned,
  });

  @override
  State<_PendingOrderCard> createState() => _PendingOrderCardState();
}

class _PendingOrderCardState extends State<_PendingOrderCard> {
  final _adminService = AdminService();
  String? _selectedDriverId;
  bool _isAssigning = false;
  late Future<List<DriverWithStats>> _driversFuture;

  @override
  void initState() {
    super.initState();
    _driversFuture = _adminService.getDriversWithStats();
  }

  Future<void> _assignDriver() async {
    if (_selectedDriverId == null) return;

    setState(() => _isAssigning = true);

    try {
      await _adminService.assignDriver(
        orderId: widget.order.id,
        driverId: _selectedDriverId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driver assigned successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onAssigned();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: CustomerUi.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderReference,
                      style: AppTextStyles.monoBold,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.formattedDate,
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(width: 8),
                        Text(order.timeSlot.icon),
                        const SizedBox(width: 4),
                        Text(
                          order.timeSlot.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                order.displayAddress?.recipientName ?? 'Customer',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                order.formattedTotal,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.displayAddress?.shortAddress ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.shopping_basket_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  OrderCard.buildItemsSummary(order.items),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          const Text(
            'Assign Driver',
            style: CustomerUi.sectionTitle,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<DriverWithStats>>(
                  future: _driversFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }

                    final drivers = (snapshot.data ?? [])
                        .where((driver) => driver.profile.isActive)
                        .toList();

                    if (drivers.isEmpty) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No drivers available',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Add drivers in the Drivers tab',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      );
                    }

                    return DropdownButtonFormField<String>(
                      itemHeight: 56,
                      decoration: InputDecoration(
                        hintText: 'Select driver...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      value: _selectedDriverId,
                      items: drivers
                          .map(
                            (driver) => DropdownMenuItem(
                              value: driver.profile.id,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    driver.profile.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      height: 1.1,
                                    ),
                                  ),
                                  Text(
                                    driver.availabilityLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.1,
                                      color: driver.isOnDeliveryToday
                                          ? AppColors.warning
                                          : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isAssigning
                          ? null
                          : (val) =>
                              setState(() => _selectedDriverId = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _selectedDriverId != null && !_isAssigning
                        ? CustomerUi.primaryGradient
                        : null,
                    color: _selectedDriverId == null || _isAssigning
                        ? AppColors.borderMuted
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selectedDriverId != null && !_isAssigning
                          ? _assignDriver
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: _isAssigning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Assign',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllOrdersTab extends StatefulWidget {
  const _AllOrdersTab({super.key});

  static final refreshKey = GlobalKey<_AllOrdersTabState>();

  @override
  State<_AllOrdersTab> createState() => _AllOrdersTabState();
}

class _AllOrdersTabState extends State<_AllOrdersTab> {
  final _adminService = AdminService();
  String? _statusFilter;
  String? _driverFilter;
  List<Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void reload() => _loadOrders();

  void setDriverFilter(String? driverId) {
    setState(() => _driverFilter = driverId);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final orders = await _adminService.getAllOrders(
        statusFilter: _statusFilter,
        driverFilter: _driverFilter,
      );
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOrderDetail(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminOrderDetailSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_driverFilter != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Showing orders for selected driver',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setDriverFilter(null),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                value: null,
                selected: _statusFilter == null,
                onSelected: () {
                  setState(() => _statusFilter = null);
                  _loadOrders();
                },
              ),
              _FilterChip(
                label: 'Placed',
                value: 'placed',
                selected: _statusFilter == 'placed',
                onSelected: () {
                  setState(() => _statusFilter = 'placed');
                  _loadOrders();
                },
              ),
              _FilterChip(
                label: 'Confirmed',
                value: 'confirmed',
                selected: _statusFilter == 'confirmed',
                onSelected: () {
                  setState(() => _statusFilter = 'confirmed');
                  _loadOrders();
                },
              ),
              _FilterChip(
                label: 'On the Way',
                value: 'on_the_way',
                selected: _statusFilter == 'on_the_way',
                onSelected: () {
                  setState(() => _statusFilter = 'on_the_way');
                  _loadOrders();
                },
              ),
              _FilterChip(
                label: 'Delivered',
                value: 'delivered',
                selected: _statusFilter == 'delivered',
                onSelected: () {
                  setState(() => _statusFilter = 'delivered');
                  _loadOrders();
                },
              ),
              _FilterChip(
                label: 'Cancelled',
                value: 'cancelled',
                selected: _statusFilter == 'cancelled',
                onSelected: () {
                  setState(() => _statusFilter = 'cancelled');
                  _loadOrders();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const OrderListShimmer()
              : _orders.isEmpty
                  ? const Center(
                      child: Text(
                        'No orders found',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return OrderCard(
                          order: order,
                          showTrackButton: false,
                          showDriverName: true,
                          onTap: () => _showOrderDetail(order),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _MessagesTab extends StatefulWidget {
  const _MessagesTab({super.key});

  static final refreshKey = GlobalKey<_MessagesTabState>();

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  final _chatService = ChatService();
  List<ChatConversation> _conversations = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<ChatConversation>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _subscription = _chatService.streamConversations().listen(
      (conversations) {
        if (!mounted) return;
        setState(() {
          _conversations = conversations;
          _isLoading = false;
          _error = null;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void reload() => _loadConversations();

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final conversations = await _chatService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const OrderListShimmer(itemCount: 4);
    }

    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadConversations);
    }

    if (_conversations.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.chat_bubble_outline,
        title: 'No conversations yet',
        subtitle: 'Customer chats will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          return _ConversationCard(conversation: conversation);
        },
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final ChatConversation conversation;

  const _ConversationCard({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/admin/chat/${conversation.customerId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    conversation.lastMessage.isEmpty
                        ? 'No messages yet'
                        : conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  conversation.lastMessageAt == null
                      ? ''
                      : _formatConversationTime(conversation.lastMessageAt!),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                if (conversation.unreadAdmin > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${conversation.unreadAdmin}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

String _formatConversationTime(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year && local.month == now.month && local.day == now.day;

  if (sameDay) return DateFormat('h:mm a').format(local);
  return DateFormat('d MMM').format(local);
}

class _AdminOrderDetailSheet extends StatelessWidget {
  final Order order;

  const _AdminOrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderReference,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.statusLabel,
                            style: TextStyle(
                              color: order.statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle('Customer'),
                    _infoTile(
                      Icons.person,
                      order.displayAddress?.recipientName ?? 'N/A',
                    ),
                    _infoTile(Icons.phone, order.displayAddress?.phone ?? 'N/A'),
                    const SizedBox(height: 16),
                    _sectionTitle('Delivery Address'),
                    _infoTile(
                      Icons.location_on,
                      order.displayAddress?.fullAddress ?? 'N/A',
                    ),
                    if (order.displayAddress?.landmarkNote != null &&
                        order.displayAddress!.landmarkNote!.isNotEmpty)
                      _infoTile(Icons.place, order.displayAddress!.landmarkNote!),
                    const SizedBox(height: 16),
                    _sectionTitle('Delivery Schedule'),
                    _infoTile(Icons.calendar_today, order.formattedDate),
                    _infoTile(
                      Icons.schedule,
                      '${order.timeSlot.icon} ${order.timeSlot.label} (${order.timeSlot.timeRange})',
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Items'),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.productName} × ${item.quantity}',
                              ),
                            ),
                            Text(
                              '฿${item.subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          order.formattedTotal,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (order.driverName != null) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('Driver'),
                      _infoTile(Icons.drive_eta, order.driverName!),
                    ],
                    const SizedBox(height: 16),
                    _sectionTitle('Timeline'),
                    _timelineRow('Placed', order.placedAt),
                    if (order.confirmedAt != null)
                      _timelineRow('Confirmed', order.confirmedAt!),
                    if (order.onTheWayAt != null)
                      _timelineRow('On the way', order.onTheWayAt!),
                    if (order.deliveredAt != null)
                      _timelineRow('Delivered', order.deliveredAt!),
                    if (order.cancelledAt != null)
                      _timelineRow('Cancelled', order.cancelledAt!),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _timelineRow(String label, DateTime time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Text(
            DateFormat('dd MMM yyyy, hh:mm a').format(time.toLocal()),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PendingCardShimmer extends StatelessWidget {
  const _PendingCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: Colors.white,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
