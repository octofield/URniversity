import 'package:flutter/material.dart';

// Swipe the page body sideways to move to the next or previous thing: the
// three task views on the today page, the semesters on the targets page.
//
// A fling, not a drag: the threshold keeps a vertical scroll that wandered
// sideways from switching the page under the user. Null means "there is
// nothing that way" — the first semester does not wrap round to the last.
class SwipeSwitcher extends StatelessWidget {
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final Widget child;

  const SwipeSwitcher({
    super.key,
    this.onNext,
    this.onPrevious,
    required this.child,
  });

  // Pixels per second. Below this it was not a deliberate sideways gesture
  static const double _minVelocity = 250;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Translucent, not opaque: the rows underneath keep their own taps and
      // long-press drags
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < _minVelocity) return;
        // Dragging leftwards moves forward, the way a page turns
        if (velocity < 0) {
          onNext?.call();
        } else {
          onPrevious?.call();
        }
      },
      child: child,
    );
  }
}
