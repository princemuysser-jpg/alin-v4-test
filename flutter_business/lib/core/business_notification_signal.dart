import 'package:flutter/foundation.dart';

/// Lightweight event bus: foreground push refreshes data, not widget keys.
class BusinessNotificationSignal {
  BusinessNotificationSignal._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void received() => revision.value++;
}
