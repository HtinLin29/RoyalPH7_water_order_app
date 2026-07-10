import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_form_scaffold.dart';
import '../../widgets/loading_shimmer.dart';
import 'customer_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _adminService = AdminService();
  final _authService = AuthService();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _initControllers(Profile profile) {
    _nameController.text = profile.fullName;
    _phoneController.text = profile.phone;
    _emailController.text =
        Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'driver':
        return 'Delivery Driver';
      case 'admin':
        return 'Administrator';
      default:
        return 'Customer';
    }
  }

  Future<void> _saveProfile(Profile profile) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final currentEmail =
        (Supabase.instance.client.auth.currentUser?.email ?? '')
            .toLowerCase();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (profile.isCustomer) {
      if (email.isEmpty || !isValidEmail(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid email address'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();

    try {
      await _adminService.updateProfile(
        userId: profile.id,
        fullName: name,
        phone: phone,
      );

      if (profile.isCustomer && email != currentEmail) {
        await _authService.updateEmail(email);
      }

      await authProvider.loadProfile();

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              profile.isCustomer && email != currentEmail
                  ? 'Profile updated. You can sign in with $email'
                  : 'Profile updated!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This permanently deletes your account, email, orders, and addresses. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    final cartProvider = context.read<CartProvider>();
    final authProvider = context.read<AuthProvider>();

    try {
      await _authService.deleteAccount();
      cartProvider.clearCart();
      authProvider.clearProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/login');
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
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final cartProvider = context.read<CartProvider>();
    final authProvider = context.read<AuthProvider>();
    cartProvider.clearCart();
    authProvider.clearProfile();
    await AuthService().signOut();

    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().currentProfile;
    final isLoading = context.watch<AuthProvider>().isLoading;
    final location = GoRouterState.of(context).uri.toString();
    final isTab = location.contains('/customer/profile') ||
        location.contains('/driver/profile');

    if (profile == null && isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: ProfileShimmer(),
      );
    }

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isEditing &&
        _nameController.text.isEmpty &&
        _phoneController.text.isEmpty &&
        _emailController.text.isEmpty) {
      _initControllers(profile);
    }

    final email = _isEditing
        ? _emailController.text
        : (Supabase.instance.client.auth.currentUser?.email ?? '');

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: !isTab,
        leading: isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
        actions: [
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _initControllers(profile);
                      setState(() => _isEditing = true);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 48),
              decoration: const BoxDecoration(
                gradient: CustomerUi.primaryGradient,
              ),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _roleLabel(profile.role),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: CustomerUi.cardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Personal Information',
                                  style: CustomerUi.sectionTitle,
                                ),
                                const Spacer(),
                                if (_isEditing)
                                  TextButton(
                                    onPressed: _isSaving
                                        ? null
                                        : () {
                                            _initControllers(profile);
                                            setState(() => _isEditing = false);
                                          },
                                    child: const Text('Cancel'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _EditableInfoRow(
                              label: 'Name',
                              value: profile.fullName,
                              isEditing: _isEditing,
                              controller: _nameController,
                            ),
                            _EditableInfoRow(
                              label: 'Phone',
                              value: profile.phone.isEmpty
                                  ? 'Not set'
                                  : profile.phone,
                              isEditing: _isEditing,
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                            ),
                            if (profile.isCustomer)
                              _EditableInfoRow(
                                label: 'Email',
                                value: email.isEmpty ? 'Not set' : email,
                                isEditing: _isEditing,
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                              )
                            else
                              _InfoRow(label: 'Email', value: email),
                            if (_isEditing) ...[
                              const SizedBox(height: 8),
                              CustomerUi.gradientButton(
                                label: 'Save',
                                height: 48,
                                loading: _isSaving,
                                onPressed: _isSaving || _isDeleting
                                    ? null
                                    : () => _saveProfile(profile),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (profile.isCustomer) ...[
                        const SizedBox(height: 16),
                        _MenuCard(
                          title: 'Delivery',
                          icon: Icons.local_shipping_outlined,
                          items: [
                            _MenuItem(
                              icon: Icons.location_on_outlined,
                              label: 'My Addresses',
                              onTap: () =>
                                  context.push('/customer/addresses'),
                            ),
                            _MenuItem(
                              icon: Icons.receipt_long_outlined,
                              label: 'Order History',
                              onTap: () => context.go('/customer/orders'),
                            ),
                          ],
                        ),
                      ],
                      if (profile.isDriver) ...[
                        const SizedBox(height: 16),
                        _MenuCard(
                          title: 'My Work',
                          icon: Icons.work_outline,
                          items: [
                            _MenuItem(
                              icon: Icons.history,
                              label: 'Delivery History',
                              onTap: () => context.go('/driver/history'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: CustomerUi.cardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Account', style: CustomerUi.sectionTitle),
                            InkWell(
                              onTap: _isDeleting ? null : _logout,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.logout,
                                        color: AppColors.error, size: 22),
                                    SizedBox(width: 12),
                                    Text(
                                      'Sign Out',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (profile.isCustomer)
                              InkWell(
                                onTap: _isDeleting ? null : _deleteAccount,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      if (_isDeleting)
                                        const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.error,
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.error,
                                          size: 22,
                                        ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _isDeleting
                                            ? 'Deleting…'
                                            : 'Delete Account',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Royal Ph7 v1.0.0',
                        style:
                            AppTextStyles.caption,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isEditing;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _EditableInfoRow({
    required this.label,
    required this.value,
    required this.isEditing,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return _InfoRow(label: label, value: value);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_MenuItem> items;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.items,
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
          ...items,
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
