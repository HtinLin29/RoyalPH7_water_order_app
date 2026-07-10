import 'profile.dart';
import 'shift_status.dart';

class DriverWithStats {
  final Profile profile;
  final int activeOrdersToday;

  const DriverWithStats({
    required this.profile,
    required this.activeOrdersToday,
  });

  bool get isOnDeliveryToday =>
      profile.shiftStatus == ShiftStatus.onDelivery || activeOrdersToday > 0;

  String get availabilityLabel {
    if (!profile.isActive) return 'Inactive';
    switch (profile.shiftStatus) {
      case ShiftStatus.off:
        return 'Off Duty';
      case ShiftStatus.onDelivery:
        if (activeOrdersToday <= 0) return 'On Delivery';
        return activeOrdersToday == 1
            ? 'On Delivery (1 order)'
            : 'On Delivery ($activeOrdersToday orders)';
      case ShiftStatus.available:
      default:
        return 'Available';
    }
  }

  String get shiftStatusLabel {
    switch (profile.shiftStatus) {
      case ShiftStatus.available:
        return 'Available';
      case ShiftStatus.onDelivery:
        if (activeOrdersToday <= 0) return 'On Delivery';
        return 'On Delivery ($activeOrdersToday)';
      case ShiftStatus.off:
      default:
        return 'Off Duty';
    }
  }
}
