import 'package:flutter/material.dart';

import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_spacing.dart';

// The title block at the top of the four main pages.
//
// Each page used to build its own, and they drifted: the drawer button ended up
// a few pixels higher on the targets page than on the other three, because that
// header's row happened to be a different height. One fixed-height title row
// here means the button cannot move between pages again.
class PageHeader extends StatelessWidget {
  final String title;
  // Second line under the title, e.g. the today page's date and task count
  final Widget? subtitle;
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  // Height of the title row. Big enough for an IconButton's touch target and
  // for the headline, so neither stretches the row past the other
  static const double rowHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    // Desktop has the permanent NavigationRail, so no drawer button there
    final isDesktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.pageTop,
        AppSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                if (!isDesktop) ...[
                  IconButton(
                    icon: const Icon(Icons.menu),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...actions,
              ],
            ),
          ),
          ?subtitle,
        ],
      ),
    );
  }
}
