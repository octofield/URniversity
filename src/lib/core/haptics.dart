import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

// The few moments that buzz, each at the weight it deserves (system_design.md
// §3-Q). Nothing else in the app vibrates: a buzz on every tap stops meaning
// anything. Desktop and web have no motor, and HapticFeedback is a no-op there
enum HapticKind {
  // A task ticked off
  tick,
  // Ticked back on, or a dragged row dropped into place
  select,
  // The day's last task done
  allDone,
}

void haptic(WidgetRef ref, HapticKind kind) {
  if (!ref.read(hapticsProvider)) return;
  switch (kind) {
    case HapticKind.tick:
      HapticFeedback.lightImpact();
    case HapticKind.select:
      HapticFeedback.selectionClick();
    case HapticKind.allDone:
      HapticFeedback.mediumImpact();
  }
}
