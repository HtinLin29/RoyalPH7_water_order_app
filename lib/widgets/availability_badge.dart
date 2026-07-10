import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_decorations.dart';

class AvailabilityBadge extends StatelessWidget {
  final bool isAvailable;

  const AvailabilityBadge({super.key, required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable ? AppColors.successSoft : AppColors.errorSoft,
        borderRadius: AppDecorations.chipRadius,
      ),
      child: Text(
        isAvailable ? 'Available' : 'Unavailable',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isAvailable ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }
}
