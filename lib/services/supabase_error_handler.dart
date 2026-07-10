import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'auth_service.dart';

class SupabaseErrorHandler {
  SupabaseErrorHandler._();

  static String getMessage(dynamic e) {
    if (e is AuthException) {
      final lower = e.message.toLowerCase();
      if (lower.contains('invalid login credentials') ||
          lower.contains('invalid email or password') ||
          lower.contains('wrong email or password')) {
        return 'Wrong email or password';
      }
      if (lower.contains('user already registered') ||
          lower.contains('already been registered') ||
          lower.contains('already exists')) {
        return 'An account with this email already exists';
      }
      if (lower.contains('email not confirmed')) {
        return 'Please confirm your email address, then sign in';
      }
      if (e.statusCode == '429' ||
          lower.contains('rate limit') ||
          lower.contains('over_email_send')) {
        return 'Too many attempts. Please wait a minute and try again.';
      }
      if ((lower.contains('token') && lower.contains('invalid')) ||
          (lower.contains('otp') && lower.contains('invalid')) ||
          lower.contains('expired')) {
        return 'Invalid or expired code. Please try again or resend.';
      }
      if (lower.contains('jwt') ||
          lower.contains('session') ||
          lower.contains('not authenticated')) {
        return 'Session expired. Please sign in again.';
      }
      return e.message;
    }

    final text = e.toString().toLowerCase();
    final raw = e is Exception
        ? e.toString().replaceFirst('Exception: ', '')
        : e.toString();

    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('connection')) {
      return 'No internet connection';
    }
    if (text.contains('permission') || text.contains('rls')) {
      return "You don't have permission for this action";
    }
    if (text.contains('already exists') ||
        text.contains('user already registered') ||
        text.contains('already been registered')) {
      return 'An account with this email already exists';
    }
    if (text.contains('only customers can') ||
        text.contains('enter a valid email') ||
        text.contains('not authenticated')) {
      if (text.contains('not authenticated')) {
        return 'Please sign in again and try again.';
      }
      if (text.contains('enter a valid email')) {
        return 'Enter a valid email address';
      }
      return raw;
    }
    if (text.contains('signup') && text.contains('disabled')) {
      return 'Registration is currently disabled. Please contact support.';
    }
    if (text.contains('database error creating new user') ||
        text.contains('database error saving new user')) {
      return 'Could not create your account. Please try again in a moment.';
    }
    if (e is Exception) {
      return raw;
    }
    return 'Something went wrong. Please try again.';
  }

  static bool isSessionExpired(dynamic e) {
    if (e is AuthException) {
      final lower = e.message.toLowerCase();
      return lower.contains('jwt') ||
          lower.contains('session') ||
          lower.contains('not authenticated');
    }
    final text = e.toString().toLowerCase();
    return text.contains('jwt') ||
        text.contains('session') ||
        text.contains('not authenticated');
  }

  static Future<bool> handleIfSessionExpired(
    BuildContext context,
    dynamic e,
  ) async {
    if (!isSessionExpired(e) || !context.mounted) return false;

    final authProvider = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    cartProvider.clearCart();
    authProvider.clearProfile();
    await AuthService().signOut();

    if (context.mounted) {
      context.go('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please sign in again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return true;
  }
}
