import 'package:flutter/material.dart';
import '../core/theme/app_breakpoints.dart';

// Caps a single-column screen's width on desktop, per system_design.md §3-F:
// below the desktop breakpoint the content keeps the full width, at or above it
// the same content is centered inside a fixed cap so rows do not stretch across
// an ultrawide window.
//
// Only for single-column screens. The tab pages use a two-column layout with a
// different cap and build their own structure.
class ResponsiveBody extends StatelessWidget {
  // Login-style forms read better narrower than list and detail screens
  static const formWidth = 420.0;
  static const contentWidth = 640.0;

  final double maxWidth;
  final Widget child;

  const ResponsiveBody({
    required this.child,
    this.maxWidth = contentWidth,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Width, not platform: a narrow web window should get the mobile layout
    if (MediaQuery.of(context).size.width < AppBreakpoints.desktop) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
