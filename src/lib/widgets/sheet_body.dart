import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';

// Opens a modal sheet with the transparent backdrop and free height sizing that
// every sheet here needs. Wrap the content in [SheetBody] unless the sheet
// manages its own height
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Rises with Material's emphasized curve and leaves quicker than it came
    sheetAnimationStyle: AnimationStyle(
      duration: scaled(context, AppMotion.enter),
      reverseDuration: scaled(context, AppMotion.exit),
      curve: AppMotion.enterCurve,
      reverseCurve: AppMotion.exitCurve,
    ),
    builder: builder,
  );
}

// Shared body for every modal bottom sheet.
//
// Three things it fixes that every hand-rolled sheet got wrong:
//  1. The drag handle sits OUTSIDE the scroll view. A scrollable child wins the
//     vertical drag in the gesture arena, so a handle placed inside it can never
//     dismiss the sheet once the content overflows.
//  2. Bottom padding clears the keyboard AND the system navigation bar.
//     viewInsets alone leaves the submit button under the Android nav bar.
//  3. Pulling the CONTENT down closes the sheet. Because of (1) the handle was
//     the only thing that could, and with the keyboard up the sheet covers the
//     screen — the handle is a 36px strip at the very top, which is not where a
//     thumb is. Dragging past the top of the scroll view now closes it.
class SheetBody extends StatefulWidget {
  final Widget child;
  const SheetBody({super.key, required this.child});

  @override
  State<SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<SheetBody> {
  // How far past the top the current drag has pulled
  double _pulled = 0;

  // Far enough that it cannot be a scroll that overshot, close enough that a
  // flick of the thumb does it (90 was asked to be made more sensitive)
  static const double _closeAfter = 40;

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _pulled = 0;
    } else if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.dragDetails != null) {
      _pulled -= notification.overscroll;
      if (_pulled >= _closeAfter) {
        _pulled = 0;
        // Let the keyboard go first, or it animates out over an empty screen
        FocusScope.of(context).unfocus();
        Navigator.of(context).maybePop();
      }
    }
    // Never absorbed: the scroll view still needs its own notifications
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
            child: SheetDragHandle(),
          ),
          Flexible(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: SingleChildScrollView(
                // Always scrollable, so a short sheet reports the pull down
                // the same way a long one does
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  left: AppSpacing.pageHorizontal,
                  right: AppSpacing.pageHorizontal,
                  bottom: mq.viewInsets.bottom +
                      mq.viewPadding.bottom +
                      AppSpacing.lg,
                ),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
  }
}
