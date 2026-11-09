import 'package:flutter/foundation.dart';

/// Holds the unread notification total displayed by the shared app bell.
abstract final class NotificationUnreadCount {
  static final ValueNotifier<int> value = ValueNotifier<int>(0);

  static void update(int count) {
    value.value = count.clamp(0, 999);
  }
}
