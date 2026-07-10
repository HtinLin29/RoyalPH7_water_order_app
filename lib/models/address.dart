class Address {
  final String id;
  final String userId;
  final String label;
  final String recipientName;
  final String phone;
  final String fullAddress;
  final String? landmarkNote;
  final bool isDefault;
  final DateTime createdAt;

  const Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.fullAddress,
    this.landmarkNote,
    this.isDefault = false,
    required this.createdAt,
  });

  String get shortAddress {
    if (fullAddress.length <= 40) return fullAddress;
    return '${fullAddress.substring(0, 40)}...';
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: json['label'] as String? ?? 'Home',
      recipientName: json['recipient_name'] as String,
      phone: json['phone'] as String,
      fullAddress: json['full_address'] as String,
      landmarkNote: json['landmark_note'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'full_address': fullAddress,
      'landmark_note': landmarkNote,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
