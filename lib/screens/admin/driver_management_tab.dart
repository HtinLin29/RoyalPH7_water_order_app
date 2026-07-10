import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/driver_with_stats.dart';
import '../../models/profile.dart';
import '../../models/shift_status.dart';
import '../../services/admin_service.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_shimmer.dart';
import '../customer/customer_ui.dart';

typedef ViewDriverOrdersCallback = void Function(String driverId);

class DriverManagementTab extends StatefulWidget {
  final ViewDriverOrdersCallback onViewDriverOrders;

  const DriverManagementTab({
    super.key,
    required this.onViewDriverOrders,
  });

  static final refreshKey = GlobalKey<DriverManagementTabState>();

  @override
  State<DriverManagementTab> createState() => DriverManagementTabState();
}

class DriverManagementTabState extends State<DriverManagementTab> {
  final _adminService = AdminService();
  List<DriverWithStats> _drivers = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _driversSubscription;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _driversSubscription = _adminService.streamDriverProfiles().listen(
      (_) => _loadDrivers(silent: true),
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _driversSubscription?.cancel();
    super.dispose();
  }

  void reload() => _loadDrivers();

  Future<void> _loadDrivers({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final drivers = await _adminService.getDriversWithStats();
      if (mounted) {
        setState(() {
          _drivers = drivers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  int get _activeDriversCount =>
      _drivers.where((driver) => driver.profile.isActive).length;

  int get _availableNowCount => _drivers
      .where((driver) => driver.profile.shiftStatus == ShiftStatus.available)
      .length;

  int get _onDeliveryCount => _drivers
      .where((driver) => driver.profile.shiftStatus == ShiftStatus.onDelivery)
      .length;

  void _showAddDriverSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddDriverSheet(
        onCreated: () {
          Navigator.pop(ctx);
          _loadDrivers();
        },
      ),
    );
  }

  Future<void> _toggleDriver(DriverWithStats driver) async {
    try {
      await _adminService.toggleDriverStatus(
        driverId: driver.profile.id,
        currentIsActive: driver.profile.isActive,
      );
      await _loadDrivers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            driver.profile.isActive
                ? 'Driver marked inactive'
                : 'Driver marked active',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _setShiftStatus(
    DriverWithStats driver,
    String shiftStatus,
  ) async {
    try {
      await _adminService.updateDriverShiftStatus(
        driverId: driver.profile.id,
        shiftStatus: shiftStatus,
      );
      await _loadDrivers(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shiftStatus == ShiftStatus.available
                ? 'Driver set to available'
                : 'Driver set to off duty',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteDriver(DriverWithStats driver) async {
    if (driver.isOnDeliveryToday) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete driver?'),
        content: Text(
          'Remove ${driver.profile.fullName} permanently? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _adminService.deleteDriver(driver.profile.id);
      await _loadDrivers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver deleted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const OrderListShimmer(itemCount: 4);
    }

    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadDrivers);
    }

    return RefreshIndicator(
      onRefresh: _loadDrivers,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryChip(
                  label: 'Total Drivers',
                  value: '${_drivers.length}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryChip(
                  label: 'Active Drivers',
                  value: '$_activeDriversCount',
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryChip(
                  label: 'Available Now',
                  value: '$_availableNowCount',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryChip(
                  label: 'On Delivery',
                  value: '$_onDeliveryCount',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showAddDriverSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add New Driver'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_drivers.isEmpty)
            const SizedBox(
              height: 320,
              child: EmptyStateWidget(
                icon: Icons.local_shipping_outlined,
                title: 'No drivers yet',
                subtitle: 'Add your first delivery driver to get started',
              ),
            )
          else
            ..._drivers.map(
              (driver) => _DriverCard(
                driver: driver,
                onViewOrders: () =>
                    widget.onViewDriverOrders(driver.profile.id),
                onToggleStatus: () => _toggleDriver(driver),
                onSetAvailable: () =>
                    _setShiftStatus(driver, ShiftStatus.available),
                onSetOffDuty: () => _setShiftStatus(driver, ShiftStatus.off),
                onDelete: () => _deleteDriver(driver),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final DriverWithStats driver;
  final VoidCallback onViewOrders;
  final VoidCallback onToggleStatus;
  final VoidCallback onSetAvailable;
  final VoidCallback onSetOffDuty;
  final VoidCallback onDelete;

  const _DriverCard({
    required this.driver,
    required this.onViewOrders,
    required this.onToggleStatus,
    required this.onSetAvailable,
    required this.onSetOffDuty,
    required this.onDelete,
  });

  Widget _shiftStatusPill() {
    final profile = driver.profile;
    switch (profile.shiftStatus) {
      case ShiftStatus.available:
        return _StatusPill(
          label: 'Available',
          color: AppColors.success,
          showDot: true,
        );
      case ShiftStatus.onDelivery:
        return _StatusPill(
          label: driver.shiftStatusLabel,
          color: AppColors.warning,
          showDot: true,
        );
      case ShiftStatus.off:
      default:
        return const _StatusPill(
          label: 'Off Duty',
          color: AppColors.textMuted,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = driver.profile;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: CustomerUi.cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DriverAvatar(profile: profile),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        profile.phone.isEmpty ? 'No phone' : profile.phone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusPill(
                      label: profile.isActive ? 'Active' : 'Inactive',
                      color: profile.isActive
                          ? AppColors.success
                          : AppColors.textMuted,
                    ),
                    _shiftStatusPill(),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
            onSelected: (value) {
              switch (value) {
                case 'orders':
                  onViewOrders();
                case 'toggle':
                  onToggleStatus();
                case 'set_available':
                  onSetAvailable();
                case 'set_off_duty':
                  onSetOffDuty();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'orders',
                child: Text('View Orders'),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  profile.isActive ? 'Mark Inactive' : 'Mark Active',
                ),
              ),
              const PopupMenuItem(
                value: 'set_available',
                child: Text('Set Available'),
              ),
              const PopupMenuItem(
                value: 'set_off_duty',
                child: Text('Set Off Duty'),
              ),
              if (!driver.isOnDeliveryToday)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final Profile profile;

  const _DriverAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl;
    final initials = _initials(profile.fullName);

    return ClipOval(
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (_, __) => _InitialsAvatar(initials: initials),
              errorWidget: (_, __, ___) => _InitialsAvatar(initials: initials),
            )
          : _InitialsAvatar(initials: initials),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;

  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        gradient: CustomerUi.primaryGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;

  const _StatusPill({
    required this.label,
    required this.color,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDriverSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _AddDriverSheet({required this.onCreated});

  @override
  State<_AddDriverSheet> createState() => _AddDriverSheetState();
}

class _AddDriverSheetState extends State<_AddDriverSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminService = AdminService();
  final _picker = ImagePicker();

  Uint8List? _photoBytes;
  String? _photoExtension;
  bool _obscurePassword = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final extension = image.path.split('.').last.toLowerCase();
    setState(() {
      _photoBytes = bytes;
      _photoExtension = extension == 'png' || extension == 'webp'
          ? extension
          : 'jpg';
    });
  }

  Future<void> _createDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final driverId = await _adminService.createDriver(
        fullName: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (_photoBytes != null) {
        await _adminService.uploadDriverPhoto(
          driverId: driverId,
          imageBytes: _photoBytes!,
          fileExtension: _photoExtension ?? 'jpg',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver added successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add New Driver',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: _isSaving ? null : _pickPhoto,
                  child: _photoBytes == null
                      ? Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.textMuted,
                            size: 32,
                          ),
                        )
                      : ClipOval(
                          child: Image.memory(
                            _photoBytes!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: CustomerUi.outlinedInput(
                  label: 'Full Name',
                  prefixIcon: Icons.person_outline,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: CustomerUi.outlinedInput(
                  label: 'Phone Number',
                  prefixIcon: Icons.phone_outlined,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: CustomerUi.outlinedInput(
                  label: 'Email Address',
                  prefixIcon: Icons.email_outlined,
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Required';
                  if (!email.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: CustomerUi.outlinedInput(
                  label: 'Password',
                  prefixIcon: Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Minimum 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomerUi.gradientButton(
                label: 'Create Driver',
                onPressed: _isSaving ? null : _createDriver,
                loading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
