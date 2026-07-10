import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'scaffold_messenger_key.dart';

void _showSnackBar(SnackBar snackBar, BuildContext context) {
  final messenger = rootScaffoldMessengerKey.currentState ??
      ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(snackBar);
}

void showErrorSnackBar(BuildContext context, String message) {
  _showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 3),
    ),
    context,
  );
}

void showSuccessSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  _showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.success,
      duration: duration,
    ),
    context,
  );
}
