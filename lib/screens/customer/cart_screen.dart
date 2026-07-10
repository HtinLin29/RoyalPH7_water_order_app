import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/address.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../services/address_service.dart';
import '../../services/order_service.dart';
import 'customer_ui.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _noteController = TextEditingController();
  final _addressService = AddressService();

  List<Address> _addresses = [];
  Address? _selectedAddress;
  DateTime? _selectedDate;
  TimeSlot? _selectedTimeSlot;
  bool _isLoading = false;
  bool _loadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final addresses = await _addressService.getAddresses(userId);
      final defaultAddress = await _addressService.getDefaultAddress(userId);

      if (mounted) {
        setState(() {
          _addresses = addresses;
          _selectedAddress = defaultAddress ??
              (addresses.isNotEmpty ? addresses.first : null);
          _loadingAddresses = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingAddresses = false);
      }
    }
  }

  List<DateTime> get _dateOptions {
    final now = DateTime.now();
    return List.generate(14, (i) => DateTime(now.year, now.month, now.day + i));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      _showError('Please select a delivery address');
      return;
    }
    if (_selectedDate == null) {
      _showError('Please select a delivery date');
      return;
    }
    if (_selectedTimeSlot == null) {
      _showError('Please select a delivery time slot');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final cartProvider = context.read<CartProvider>();

      final order = await OrderService().placeOrder(
        customerId: userId,
        addressId: _selectedAddress!.id,
        items: cartProvider.items,
        deliveryDate: _selectedDate!,
        timeSlot: _selectedTimeSlot!,
        deliveryNote: _noteController.text.isEmpty
            ? null
            : _noteController.text.trim(),
      );

      cartProvider.clearCart();

      if (mounted) {
        context.go('/customer/confirmation', extra: order);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.isEmpty) {
            return _EmptyCart(onBrowse: () => context.go('/customer/home'));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: AppColors.primary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _isLoading ? null : () => context.pop(),
                ),
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: CustomerUi.primaryGradient,
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Cart',
                      style: AppTextStyles.appBarTitle,
                    ),
                    Text(
                      '${cart.totalItems} item${cart.totalItems == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Clear cart?'),
                                content: const Text(
                                  'Remove all items from your cart?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      cart.clearCart();
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = cart.items[index];
                      return _CartItemCard(
                        product: item.product,
                        quantity: item.quantity,
                      );
                    },
                    childCount: cart.items.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: _CheckoutSections(
                    cart: cart,
                    addresses: _addresses,
                    selectedAddress: _selectedAddress,
                    loadingAddresses: _loadingAddresses,
                    selectedDate: _selectedDate,
                    dateOptions: _dateOptions,
                    selectedTimeSlot: _selectedTimeSlot,
                    noteController: _noteController,
                    isLoading: _isLoading,
                    onAddressSelected: (a) =>
                        setState(() => _selectedAddress = a),
                    onManageAddresses: () async {
                      await context.push('/customer/addresses');
                      _loadAddresses();
                    },
                    onDateSelected: (d) => setState(() => _selectedDate = d),
                    onTimeSlotSelected: (s) =>
                        setState(() => _selectedTimeSlot = s),
                    onPlaceOrder: _placeOrder,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onBrowse;

  const _EmptyCart({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomerUi.emptyIconCircle(Icons.shopping_cart_outlined),
              const SizedBox(height: 20),
              const Text(
                'Your cart is empty',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add some water bottles to get started',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              CustomerUi.gradientButton(
                label: 'Browse Products',
                onPressed: onBrowse,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final Product product;
  final int quantity;

  const _CartItemCard({required this.product, required this.quantity});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final color = CustomerUi.productColor(product.name);
    final lineTotal = product.price * quantity;

    return Dismissible(
      key: ValueKey(product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => cart.removeItem(product.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: 0.08),
            Colors.white,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: product.imageUrl != null &&
                          product.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.water_drop,
                            color: color,
                            size: 28,
                          ),
                        )
                      : Icon(Icons.water_drop, color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.formattedPrice} / unit',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _CompactStepper(
                  productId: product.id,
                  quantity: quantity,
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '฿${lineTotal.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStepper extends StatelessWidget {
  final String productId;
  final int quantity;
  final Color color;

  const _CompactStepper({
    required this.productId,
    required this.quantity,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => cart.updateQuantity(productId, quantity - 1),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Icon(Icons.remove, size: 16, color: color),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
          GestureDetector(
            onTap: quantity >= CartProvider.maxQuantity
                ? null
                : () => cart.updateQuantity(productId, quantity + 1),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: const Icon(Icons.add, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSections extends StatelessWidget {
  final CartProvider cart;
  final List<Address> addresses;
  final Address? selectedAddress;
  final bool loadingAddresses;
  final DateTime? selectedDate;
  final List<DateTime> dateOptions;
  final TimeSlot? selectedTimeSlot;
  final TextEditingController noteController;
  final bool isLoading;
  final ValueChanged<Address> onAddressSelected;
  final VoidCallback onManageAddresses;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<TimeSlot> onTimeSlotSelected;
  final VoidCallback onPlaceOrder;

  const _CheckoutSections({
    required this.cart,
    required this.addresses,
    required this.selectedAddress,
    required this.loadingAddresses,
    required this.selectedDate,
    required this.dateOptions,
    required this.selectedTimeSlot,
    required this.noteController,
    required this.isLoading,
    required this.onAddressSelected,
    required this.onManageAddresses,
    required this.onDateSelected,
    required this.onTimeSlotSelected,
    required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery Address', style: CustomerUi.sectionTitle),
        const SizedBox(height: 8),
        if (loadingAddresses)
          const Center(child: CircularProgressIndicator())
        else if (addresses.isEmpty)
          _EmptyAddressCard(onAdd: onManageAddresses)
        else
          ...addresses.map(
            (a) => _AddressCard(
              address: a,
              selected: selectedAddress?.id == a.id,
              onTap: isLoading ? null : () => onAddressSelected(a),
            ),
          ),
        TextButton.icon(
          onPressed: isLoading ? null : onManageAddresses,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Manage Addresses'),
        ),
        const SizedBox(height: 16),
        const Text('Delivery Date', style: CustomerUi.sectionTitle),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dateOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = dateOptions[index];
              final selected = selectedDate != null &&
                  date.year == selectedDate!.year &&
                  date.month == selectedDate!.month &&
                  date.day == selectedDate!.day;
              return GestureDetector(
                onTap: isLoading ? null : () => onDateSelected(date),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('d MMM').format(date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Text('Time Slot', style: CustomerUi.sectionTitle),
        const SizedBox(height: 8),
        ...TimeSlot.values.map(
          (slot) => _TimeSlotCard(
            slot: slot,
            selected: selectedTimeSlot == slot,
            onTap: isLoading ? null : () => onTimeSlotSelected(slot),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: noteController,
          enabled: !isLoading,
          maxLines: 2,
          decoration: CustomerUi.outlinedInput(
            label: 'Delivery Note (Optional)',
            hint: 'e.g. Leave at the gate...',
            prefixIcon: Icons.notes_outlined,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Items Total',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            Text(
              cart.formattedTotal,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'monospace',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Delivery',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            Text(
              'Free',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomerUi.gradientButton(
          label: 'Place Order',
          onPressed: isLoading ? null : onPlaceOrder,
          loading: isLoading,
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Address address;
  final bool selected;
  final VoidCallback? onTap;

  const _AddressCard({
    required this.address,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : Colors.transparent,
                width: 1.5,
              ),
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
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color:
                        selected ? AppColors.primary : AppColors.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.shortAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeSlotCard extends StatelessWidget {
  final TimeSlot slot;
  final bool selected;
  final VoidCallback? onTap;

  const _TimeSlotCard({
    required this.slot,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.primary.withValues(alpha: 0.25)
        : AppColors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : Colors.white,
                      border: Border.all(color: borderColor),
                    ),
                  child: Row(
                    children: [
                      Text(slot.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slot.label,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              slot.timeRange,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _EmptyAddressCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyAddressCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Text(
            'No delivery address found',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Address'),
          ),
        ],
      ),
    );
  }
}
