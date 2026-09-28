import 'dart:math';

import 'package:flutter/material.dart';
import '../core/theme/app_motion.dart';

// Pulling a page down past its top closes it (system_design.md §2-N). The page
// follows the finger at half speed, then either goes — pulled far enough, or
// flung — or settles back. Only a pull beyond the top of the page's own scroll
// view counts, so scrolling the content is untouched; a [PullToCloseHandle]
// (the page header, say) can be dragged down directly
class PullToClose extends StatefulWidget {
  final Widget child;
  const PullToClose({super.key, required this.child});

  @override
  State<PullToClose> createState() => _PullToCloseState();
}

class _PullToCloseState extends State<PullToClose> with SingleTickerProviderStateMixin {
  // Pixels of finger travel, and a downward fling in pixels per second
  static const _threshold = 120.0;
  static const _flingVelocity = 700.0;

  double _pull = 0;
  double _settleFrom = 0;
  // Made in initState, not lazily: a lazy one first touched in dispose would
  // be created on a widget already leaving the tree
  late final AnimationController _settle;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this)
      ..addListener(() => setState(() => _pull = _settleFrom * (1 - AppMotion.moveCurve.transform(_settle.value))));
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _drag(double delta) {
    _settle.stop();
    setState(() => _pull = max(0, _pull + delta));
  }

  void _release(double velocity) {
    if (_pull <= 0) return;
    if (_pull >= _threshold || velocity > _flingVelocity) {
      Navigator.of(context).maybePop();
      return;
    }
    _settleFrom = _pull;
    _settle.duration = scaled(context, AppMotion.move);
    _settle.forward(from: 0);
  }

  bool _onScroll(ScrollNotification n) {
    // The page's own vertical list, not a sideways strip inside it
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is OverscrollNotification && n.dragDetails != null && n.overscroll < 0) {
      // Android: the list is at its top and the finger keeps going down
      _drag(-n.overscroll);
    } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
      final beyond = n.metrics.minScrollExtent - n.metrics.pixels;
      if (beyond > 0) {
        // iOS: the list itself bounces past its top
        _settle.stop();
        setState(() => _pull = beyond);
      } else if (_pull > 0 && (n.scrollDelta ?? 0) > 0) {
        // Changing its mind: back up before the list scrolls on
        _drag(-n.scrollDelta!);
      }
    } else if (n is ScrollEndNotification) {
      _release(n.dragDetails?.primaryVelocity ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Transform.translate(offset: Offset(0, _pull / 2), child: widget.child),
      );
}

// A part of the page that can be dragged down to close it without scrolling
// anything first — the header above the list
class PullToCloseHandle extends StatelessWidget {
  final Widget child;
  const PullToCloseHandle({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final pull = context.findAncestorStateOfType<_PullToCloseState>();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: pull == null ? null : (d) => pull._drag(d.delta.dy),
      onVerticalDragEnd: pull == null ? null : (d) => pull._release(d.primaryVelocity ?? 0),
      child: child,
    );
  }
}
