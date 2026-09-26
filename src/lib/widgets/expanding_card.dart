import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';

// A card that grows into its detail page and shrinks back into place on the
// way out — Material's container transform (system_design.md §3-Q), so the
// page is visibly the card, opened.
//
// Only the card's own header row opens it this way. The rows inside it (a
// target's milestones) open their own pages with the ordinary transition, so
// the header asks for the opener by id through [ExpandingCard.openerOf]
class ExpandingCard extends StatelessWidget {
  final String id;
  final Widget card;
  final Widget detail;

  const ExpandingCard({
    super.key,
    required this.id,
    required this.card,
    required this.detail,
  });

  // The opener for the card showing [id], when that row is the card's header
  static VoidCallback? openerOf(BuildContext context, String id) {
    final scope = context.dependOnInheritedWidgetOfExactType<_Opener>();
    return scope != null && scope.id == id ? scope.open : null;
  }

  @override
  Widget build(BuildContext context) {
    return OpenContainer(
      tappable: false,
      closedElevation: 0,
      openElevation: 0,
      closedColor: AppColors.surface,
      middleColor: AppColors.surface,
      openColor: AppColors.background,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      transitionDuration: scaled(context, AppMotion.page),
      openBuilder: (_, _) => detail,
      closedBuilder: (_, open) => _Opener(id: id, open: open, child: card),
    );
  }
}

class _Opener extends InheritedWidget {
  final String id;
  final VoidCallback open;

  const _Opener({required this.id, required this.open, required super.child});

  @override
  bool updateShouldNotify(_Opener old) => old.id != id || old.open != open;
}
