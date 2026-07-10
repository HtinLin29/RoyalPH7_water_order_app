class Profile {
  final String id;
  final String fullName;
  final String phone;
  final String role;
  final bool isActive;
  final String shiftStatus;
  final String? vehicleNote;
  final String? avatarUrl;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.isActive = true,
    this.shiftStatus = 'off',
    this.vehicleNote,
    this.avatarUrl,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
      shiftStatus: json['shift_status'] as String? ?? 'off',
      vehicleNote: json['vehicle_note'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'is_active': isActive,
      'shift_status': shiftStatus,
      'vehicle_note': vehicleNote,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? fullName,
    String? phone,
    bool? isActive,
    String? shiftStatus,
    String? vehicleNote,
    String? avatarUrl,
  }) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role,
      isActive: isActive ?? this.isActive,
      shiftStatus: shiftStatus ?? this.shiftStatus,
      vehicleNote: vehicleNote ?? this.vehicleNote,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';
  bool get isCustomer => role == 'customer';
}
