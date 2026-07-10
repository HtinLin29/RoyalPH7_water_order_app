import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/address.dart';
import '../../providers/auth_provider.dart';
import '../../services/address_service.dart';
import '../../services/location_service.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_error_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_shimmer.dart';
import 'customer_ui.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _addressService = AddressService();
  Future<List<Address>> _addressesFuture = Future.value([]);
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAddresses());
  }

  void _loadAddresses() {
    final userId = context.read<AuthProvider>().currentProfile?.id;
    if (userId == null) return;
    _loadedUserId = userId;
    setState(() {
      _addressesFuture = _addressService.getAddresses(userId);
    });
  }

  Future<void> _setDefault(Address address) async {
    final userId = context.read<AuthProvider>().currentProfile?.id;
    if (userId == null) return;

    try {
      await _addressService.setDefault(address.id, userId);
      if (mounted) {
        showSuccessSnackBar(context, 'Default address updated');
        _loadAddresses();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to update default address');
      }
    }
  }

  Future<void> _deleteAddress(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove "${address.label}" address?'),
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
      await _addressService.deleteAddress(address.id);
      if (mounted) {
        showSuccessSnackBar(context, 'Address deleted');
        _loadAddresses();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void _showAddAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddAddressSheet(
        onSaved: () {
          Navigator.pop(ctx);
          _loadAddresses();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().currentProfile?.id;
    if (userId != null && userId != _loadedUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAddresses();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: CustomerUi.primaryGradient,
          ),
        ),
        title: const Text(
          'My Addresses',
          style: AppTextStyles.appBarTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddAddressSheet,
          ),
        ],
      ),
      body: userId == null
          ? const Center(child: Text('Please log in to manage addresses'))
          : FutureBuilder<List<Address>>(
              future: _addressesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AddressListShimmer(itemCount: 2);
                }

                if (snapshot.hasError) {
                  return AppErrorWidget(
                    message: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    onRetry: _loadAddresses,
                  );
                }

                final addresses = snapshot.data ?? [];

                if (addresses.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.location_on_outlined,
                    title: 'No addresses yet',
                    subtitle: 'Add a delivery address to place orders',
                    buttonText: 'Add Address',
                    onButton: _showAddAddressSheet,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    return _AddressCard(
                      address: address,
                      onSetDefault: address.isDefault
                          ? null
                          : () => _setDefault(address),
                      onDelete: () => _deleteAddress(address),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Address address;
  final VoidCallback? onSetDefault;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    this.onSetDefault,
    required this.onDelete,
  });

  Color _labelColor() {
    switch (address.label.toLowerCase()) {
      case 'home':
        return AppColors.primary;
      case 'office':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _labelIcon() {
    switch (address.label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'office':
        return Icons.business_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _labelColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: CustomerUi.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_labelIcon(), color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                address.label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (address.isDefault) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Default',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                address.recipientName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
              Text(
                address.phone,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            address.fullAddress,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          if (address.landmarkNote != null &&
              address.landmarkNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warningBanner,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                address.landmarkNote!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warningText,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (onSetDefault != null)
                TextButton(
                  onPressed: onSetDefault,
                  child: const Text('Set as Default'),
                ),
              const Spacer(),
              TextButton(
                onPressed: onDelete,
                child: const Text(
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

class _AddAddressSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const _AddAddressSheet({required this.onSaved});

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController(text: 'Home');
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _addressService = AddressService();
  final _locationService = LocationService();

  bool _isDefault = true;
  bool _isSaving = false;
  bool _isLocating = false;
  String _selectedLabel = 'Home';

  static const _labels = ['Home', 'Office', 'Other'];

  @override
  void dispose() {
    _labelController.dispose();
    _recipientController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _selectLabel(String label) {
    setState(() {
      _selectedLabel = label;
      _labelController.text = label;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      final address = await _locationService.getCurrentAddress();
      if (mounted) {
        _addressController.text = address;
        showSuccessSnackBar(context, 'Address filled from your location');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = context.read<AuthProvider>().currentProfile?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      await _addressService.addAddress(
        userId: userId,
        label: _labelController.text.trim(),
        recipientName: _recipientController.text.trim(),
        phone: PhoneFormatter.storageValue(_phoneController.text),
        fullAddress: _addressController.text.trim(),
        landmarkNote: _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),
        isDefault: _isDefault,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Address added successfully');
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to add address');
      }
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
            mainAxisSize: MainAxisSize.min,
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
                'Add New Address',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: _labels.map((label) {
                  final selected = _selectedLabel == label;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: label != _labels.last ? 8 : 0,
                      ),
                      child: GestureDetector(
                        onTap: () => _selectLabel(label),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recipientController,
                textCapitalization: TextCapitalization.words,
                decoration: CustomerUi.outlinedInput(
                  label: 'Recipient Name',
                  prefixIcon: Icons.person_outline,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: CustomerUi.outlinedInput(
                  label: 'Phone Number',
                  prefixIcon: Icons.phone_outlined,
                ),
                onChanged: (value) {
                  final formatted = PhoneFormatter.formatThai(value);
                  if (formatted != value) {
                    _phoneController.value = TextEditingValue(
                      text: formatted,
                      selection:
                          TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                },
                validator: (v) {
                  final digits = PhoneFormatter.stripNonDigits(v ?? '');
                  if (digits.length < 9) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _addressController,
                      maxLines: 3,
                      decoration: CustomerUi.outlinedInput(
                        label: 'Full Address',
                        prefixIcon: Icons.location_on_outlined,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed:
                        _isLocating || _isSaving ? null : _useCurrentLocation,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _landmarkController,
                decoration: CustomerUi.outlinedInput(
                  label: 'Landmark Note (optional)',
                  prefixIcon: Icons.notes_outlined,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text('Set as default address'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              CustomerUi.gradientButton(
                label: 'Save Address',
                onPressed: _isSaving ? null : _save,
                loading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
