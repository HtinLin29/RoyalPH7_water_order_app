import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/auth_errors.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/auth_form_scaffold.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String fullName;
  final String phone;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.fullName,
    required this.phone,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _authService = AuthService();

  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isVerifying = true);

    try {
      if (Supabase.instance.client.auth.currentSession != null) {
        await _authService.signOut(
          onClearProfile: context.read<AuthProvider>().clearProfile,
        );
      }

      final response = await _authService.verifySignUpOtp(
        email: widget.email,
        token: _codeController.text.trim(),
        fullName: widget.fullName,
        phone: widget.phone,
      );

      if (!mounted) return;

      if (response.session == null) {
        showErrorSnackBar(
          context,
          'Verification failed. Please check the code and try again.',
        );
        return;
      }

      final authProvider = context.read<AuthProvider>();
      await authProvider.loadProfile();

      if (!mounted) return;

      if (authProvider.currentProfile == null) {
        showErrorSnackBar(
          context,
          'Verified but profile setup failed. Please sign in.',
        );
        context.go('/login');
        return;
      }

      showSuccessSnackBar(context, 'Email verified! Welcome to Royal Ph7.');
      context.go('/customer/home');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, mapAuthError(e));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      await _authService.resendSignUpOtp(widget.email);
      if (!mounted) return;
      showSuccessSnackBar(context, 'A new verification code was sent.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, mapAuthError(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: 'Verify Email',
      subtitle: 'Enter the code sent to\n${widget.email}',
      formContent: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _verifyCode(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: authInputDecoration(
                label: 'Verification Code',
                prefixIcon: Icons.pin_outlined,
              ).copyWith(
                counterText: '',
                hintText: '000000',
              ),
              validator: (value) {
                final code = value?.trim() ?? '';
                if (code.length < 4 || code.length > 6) {
                  return 'Enter the 4–6 digit code from your email';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verify & Continue',
                        style: AppTextStyles.button,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isResending || _isVerifying ? null : _resendCode,
              child: _isResending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Resend code',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Wrong email? ',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                GestureDetector(
                  onTap: _isVerifying ? null : () => context.go('/register'),
                  child: const Text(
                    'Go back',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
