import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/app_colors.dart';

BoxDecoration _shimmerCardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

class OrderCardShimmer extends StatelessWidget {
  const OrderCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: _shimmerCardDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 120,
                        color: AppColors.shimmerBase,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 80,
                        color: AppColors.shimmerBase,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 70,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.shimmerBase),
            const SizedBox(height: 16),
            Container(
              height: 12,
              width: double.infinity,
              color: AppColors.shimmerBase,
            ),
            const SizedBox(height: 8),
            Container(height: 12, width: 200, color: AppColors.shimmerBase),
            const SizedBox(height: 8),
            Container(height: 12, width: 140, color: AppColors.shimmerBase),
          ],
        ),
      ),
    );
  }
}

class OrderListShimmer extends StatelessWidget {
  final int itemCount;

  const OrderListShimmer({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (_, __) => const OrderCardShimmer(),
    );
  }
}

class AddressCardShimmer extends StatelessWidget {
  const AddressCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 160,
        decoration: _shimmerCardDecoration(),
      ),
    );
  }
}

class AddressListShimmer extends StatelessWidget {
  final int itemCount;

  const AddressListShimmer({super.key, this.itemCount = 2});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(itemCount, (_) => const AddressCardShimmer()),
      ),
    );
  }
}

class OrderTrackingShimmer extends StatelessWidget {
  const OrderTrackingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 280,
            decoration: _shimmerCardDecoration(),
          ),
          const SizedBox(height: 16),
          Container(
            height: 80,
            decoration: _shimmerCardDecoration(),
          ),
          const SizedBox(height: 16),
          Container(
            height: 80,
            decoration: _shimmerCardDecoration(),
          ),
          const SizedBox(height: 16),
          Container(
            height: 160,
            decoration: _shimmerCardDecoration(),
          ),
        ],
      ),
    );
  }
}

class DriverOrderCardShimmer extends StatelessWidget {
  const DriverOrderCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: _shimmerCardDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 110,
                        color: AppColors.shimmerBase,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 90,
                        color: AppColors.shimmerBase,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 64,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.shimmerBase),
            const SizedBox(height: 16),
            Container(
              height: 12,
              width: double.infinity,
              color: AppColors.shimmerBase,
            ),
            const SizedBox(height: 8),
            Container(height: 12, width: 160, color: AppColors.shimmerBase),
            const SizedBox(height: 12),
            Container(
              height: 36,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.shimmerBase,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCardShimmer extends StatelessWidget {
  const StatCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Container(width: 20, height: 20, color: AppColors.shimmerBase),
              const SizedBox(height: 4),
              Container(width: 28, height: 22, color: AppColors.shimmerBase),
              const SizedBox(height: 4),
              Container(width: 40, height: 11, color: AppColors.shimmerBase),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: AppColors.shimmerBase,
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 12),
                Container(width: 140, height: 22, color: Colors.white),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _shimmerCardDecoration(),
              child: Column(
                children: List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          color: AppColors.shimmerBase,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 60,
                                height: 12,
                                color: AppColors.shimmerBase,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 120,
                                height: 14,
                                color: AppColors.shimmerBase,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

