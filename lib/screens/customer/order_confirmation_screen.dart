import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../models/order.dart';
import 'customer_ui.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final Order order;

  const OrderConfirmationScreen({super.key, required this.order});

  Future<void> _shareOrder() async {
    final summary = '''
🚰 Royal Ph7 - Order Confirmed!

Order: ${order.orderReference}
Date: ${order.formattedDate}
Time: ${order.timeSlot.label} (${order.timeSlot.timeRange})

Items:
${order.items.map((i) => '• ${i.productName} × ${i.quantity} = ฿${i.subtotal.toStringAsFixed(0)}').join('\n')}

Total: ${order.formattedTotal}
Payment: Cash on Delivery

Deliver to:
${order.displayAddress?.recipientName ?? ''}
${order.displayAddress?.fullAddress ?? ''}

Thank you for ordering with Royal Ph7! 💧
''';

    final encoded = Uri.encodeComponent(summary);
    final url = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topHeight = MediaQuery.of(context).size.height * 0.45;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/customer/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: topHeight,
                width: double.infinity,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: CustomerUi.primaryGradient,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) => Transform.scale(
                          scale: value,
                          child: child,
                        ),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.success,
                            size: 52,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Order Placed!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your order has been received successfully',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          order.orderReference,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: [
                          _DetailCard(
                            title: 'Delivery Details',
                            icon: Icons.local_shipping_outlined,
                            children: [
                              _DetailRow('Date', order.formattedDate),
                              _DetailRow(
                                'Time Slot',
                                '${order.timeSlot.icon} ${order.timeSlot.label}\n${order.timeSlot.timeRange}',
                              ),
                              const _DetailRow('Payment', 'Cash on Delivery 💵'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _DetailCard(
                            title: 'Delivery Address',
                            icon: Icons.location_on_outlined,
                            children: [
                              if (order.displayAddress != null) ...[
                                _DetailRow(
                                  'To',
                                  order.displayAddress!.recipientName,
                                ),
                                _DetailRow(
                                  'Phone',
                                  order.displayAddress!.phone,
                                ),
                                _DetailRow(
                                  'Address',
                                  order.displayAddress!.fullAddress,
                                ),
                                if (order.displayAddress!.landmarkNote !=
                                        null &&
                                    order
                                        .displayAddress!.landmarkNote!.isNotEmpty)
                                  _DetailRow(
                                    'Landmark',
                                    order.displayAddress!.landmarkNote!,
                                  ),
                              ] else
                                const _DetailRow('Address', 'Not available'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _DetailCard(
                            title: 'Items Ordered',
                            icon: Icons.shopping_basket_outlined,
                            children: [
                              ...order.items.map(
                                (item) => _DetailRow(
                                  '${item.productName} × ${item.quantity}',
                                  '฿${item.subtotal.toStringAsFixed(0)}',
                                ),
                              ),
                              const Divider(height: 16),
                              _DetailRow(
                                'Total',
                                order.formattedTotal,
                                isBold: true,
                                valueColor: AppColors.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          CustomerUi.gradientButton(
                            label: 'Track My Order',
                            onPressed: () => context.go(
                              '/customer/tracking/${order.id}',
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () => context.go('/customer/home'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Back to Home',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _shareOrder,
                            icon: const Icon(
                              Icons.share_outlined,
                              color: AppColors.textMuted,
                              size: 18,
                            ),
                            label: const Text(
                              'Share Order Details',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DetailCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: CustomerUi.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(title, style: CustomerUi.sectionTitle),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _DetailRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? AppColors.textPrimary,
                fontFamily: isBold ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
