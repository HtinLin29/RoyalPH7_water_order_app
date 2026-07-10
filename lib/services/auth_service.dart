import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'supabase_error_handler.dart';

class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('invalid login credentials') ||
          message.contains('invalid email or password')) {
        throw Exception('Invalid email or password');
      }
      throw Exception('Something went wrong. Try again');
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      if (_client.auth.currentSession != null) {
        await _client.auth.signOut();
      }

      final response = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'role': 'customer',
        },
      );

      final user = response.user;
      if (user != null &&
          user.identities != null &&
          user.identities!.isEmpty) {
        throw Exception('An account with this email already exists');
      }

      if (response.session != null && user != null) {
        await _ensureCustomerProfile(
          userId: user.id,
          fullName: fullName.trim(),
          phone: phone.trim(),
        );
      }

      return response;
    } on AuthException catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<AuthResponse> verifySignUpOtp({
    required String email,
    required String token,
    required String fullName,
    required String phone,
  }) async {
    try {
      AuthResponse response;
      try {
        response = await _client.auth.verifyOTP(
          email: email.trim().toLowerCase(),
          token: token.trim(),
          type: OtpType.email,
        );
      } on AuthException catch (e) {
        final message = e.message.toLowerCase();
        if (message.contains('invalid') || message.contains('expired')) {
          rethrow;
        }
        response = await _client.auth.verifyOTP(
          email: email.trim().toLowerCase(),
          token: token.trim(),
          type: OtpType.signup,
        );
      }

      if (response.session != null && response.user != null) {
        await _ensureCustomerProfile(
          userId: response.user!.id,
          fullName: fullName.trim(),
          phone: phone.trim(),
        );
      }

      return response;
    } on AuthException catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> resendSignUpOtp(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
      );
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('already confirmed') ||
          message.contains('already registered')) {
        throw Exception('An account with this email already exists');
      }
      throw Exception(SupabaseErrorHandler.getMessage(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> _ensureCustomerProfile({
    required String userId,
    required String fullName,
    required String phone,
  }) async {
    final existing = await getProfile(userId);
    if (existing != null) return;

    try {
      await _client.from('profiles').upsert({
        'id': userId,
        'full_name': fullName,
        'phone': phone,
        'role': 'customer',
        'is_active': true,
        'shift_status': 'off',
      });
    } catch (_) {
    }
  }

  Future<void> signOut({
    VoidCallback? onClearProfile,
    VoidCallback? onClearCart,
  }) async {
    try {
      await _client.auth.signOut();
      onClearProfile?.call();
      onClearCart?.call();
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<Profile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<String> updateEmail(String email) async {
    try {
      final cleaned = email.trim().toLowerCase();
      final response = await _client.rpc(
        'update_own_email',
        params: {'new_email': cleaned},
      );

      await _client.auth.refreshSession();
      return (response as String?) ?? cleaned;
    } on AuthException catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    } on PostgrestException catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_own_account');
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    } on PostgrestException catch (e) {
      throw Exception(SupabaseErrorHandler.getMessage(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(SupabaseErrorHandler.getMessage(e));
    }
  }
}
