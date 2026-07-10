import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../constants/app_decorations.dart';
import '../constants/app_text_styles.dart';
import '../models/order.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  final bool showTrackButton;
  final bool showDriverName;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.showTrackButton = true,
    this.showDriverName = false,
  });

  static String buildItemsSummary(List<OrderItem> items) {
    if (items.isEmpty) return '';
    final shown = items
        .take(2)
        .map((i) => '${i.productName} × ${i.quantity}')
        .join(', ');
    if (items.length > 2) {
      return '$shown +${items.length - 2} more';
    }
    return shown;
  }

  bool get _isActive =>
      order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => context.push('/customer/orders/${order.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppDecorations.cardRadius,
          border: Border.all(color: AppColors.border),
          boxShadow: AppDecorations.cardShadow,
        ),
        child: Column(
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
                        style: AppTextStyles.monoBold.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      if (order.isDeliveryOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: AppDecorations.chipRadius,
                          ),
                          child: Text(
                            'Overdue',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Text(
                          order.deliveryDateLabel,
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: order.statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: order.statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.shopping_basket_outlined,
                  color: AppColors.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    buildItemsSummary(order.items),
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(order.timeSlot.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  order.timeSlot.label,
                  style: AppTextStyles.bodySmall,
                ),
                const Spacer(),
                Text(
                  order.formattedTotal,
                  style: AppTextStyles.price.copyWith(fontSize: 15),
                ),
              ],
            ),
            if (showDriverName && order.driverName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.drive_eta_outlined,
                    color: AppColors.textMuted,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order.driverName!,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
            if (showTrackButton && _isActive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  onPressed: () =>
                      context.push('/customer/tracking/${order.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Track Order',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
