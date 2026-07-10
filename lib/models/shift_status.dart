class ShiftStatus {
  ShiftStatus._();

  static const off = 'off';
  static const available = 'available';
  static const onDelivery = 'on_delivery';

  static String label(String status) {
    switch (status) {
      case available:
        return 'Available';
      case onDelivery:
        return 'On Delivery';
      case off:
      default:
        return 'Off Duty';
    }
  }
}
