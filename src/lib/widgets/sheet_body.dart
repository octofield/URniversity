import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';

// Shared body for every modal bottom sheet.
//
// Two things it fixes that every hand-rolled sheet got wrong:
//  1. The drag handle sits OUTSIDE the scroll view. A scrollable child wins the
//     vertical drag in the gesture arena, so a handle placed inside it can never
//     dismiss the sheet once the content overflows.
//  2. Bottom padding clears the keyboard AND the system navigation bar.
//     viewInsets alone leaves the submit button under the Android nav bar.
class SheetBody extends StatelessWidget {
  final Widget child;
  const SheetBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      decoration: const BoxDecoration(
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
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: AppSpacing.pageHorizontal,
                right: AppSpacing.pageHorizontal,
                bottom:
                    mq.viewInsets.bottom + mq.viewPadding.bottom + AppSpacing.lg,
              ),
              child: child,
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
