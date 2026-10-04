import 'dart:math';

import 'package:flutter/material.dart';
import '../core/theme/app_motion.dart';

// Pulling a page down past its top closes it (system_design.md §3-Q). The page
// follows the finger at half speed. Let go while still pulling down past the
// threshold, or flick down, and it slides off the bottom and fades before the
// route pops; move back up first and it settles where it was — the finger
// changed its mind (2026-10-03). Only a pull beyond the top of the page's own
// scroll view counts, so scrolling the content is untouched; a
// [PullToCloseHandle] (the page header, say) can be dragged down directly
class PullToClose extends StatefulWidget {
  final Widget child;
  const PullToClose({super.key, required this.child});

  @override
  State<PullToClose> createState() => _PullToCloseState();
}

class _PullToCloseState extends State<PullToClose> with TickerProviderStateMixin {
  // Pixels of finger travel, and a downward flick in pixels per second
  static const _threshold = 120.0;
  static const _flingVelocity = 700.0;

  double _pull = 0;
  // Whether the last movement was downward: a pull that went back up does
  // not close, however far it had gone
  bool _down = true;
  double _settleFrom = 0;
  // Made in initState, not lazily: a lazy one first touched in dispose would
  // be created on a widget already leaving the tree
  late final AnimationController _settle;
  late final AnimationController _leave;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this)
      ..addListener(() => setState(() => _pull = _settleFrom * (1 - AppMotion.moveCurve.transform(_settle.value))));
    _leave = AnimationController(vsync: this)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) Navigator.of(context).maybePop();
      });
  }

  @override
  void dispose() {
    _settle.dispose();
    _leave.dispose();
    super.dispose();
  }

  bool get _leaving => _leave.isAnimating || _leave.isCompleted;

  void _drag(double delta) {
    if (_leaving || delta == 0) return;
    _settle.stop();
    _down = delta > 0;
    setState(() => _pull = max(0, _pull + delta));
  }

  void _pullTo(double value) {
    if (_leaving || value == _pull) return;
    _settle.stop();
    _down = value > _pull;
    setState(() => _pull = value);
  }

  void _release(double velocity) {
    if (_leaving || _pull <= 0) return;
    final close = velocity > _flingVelocity || (_pull >= _threshold && _down && velocity >= 0);
    if (!close) {
      _settleFrom = _pull;
      _settle.duration = scaled(context, AppMotion.move);
      _settle.forward(from: 0);
      return;
    }
    // Reduce motion: straight to the pop, no slide
    if (motionScale(context) == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    _leave.duration = scaled(context, AppMotion.exit);
    _leave.forward(from: 0);
  }

  bool _onScroll(ScrollNotification n) {
    // The page's own vertical list, not a sideways strip inside it
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is OverscrollNotification && n.dragDetails != null && (n.overscroll < 0 || _pull > 0)) {
      // Android: the list is at its top and the finger keeps going down — or,
      // in a list too short to scroll, comes back up
      _drag(-n.overscroll);
    } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
      final beyond = n.metrics.minScrollExtent - n.metrics.pixels;
      if (beyond > 0) {
        // iOS: the list itself bounces past its top
        _pullTo(beyond);
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
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final t = AppMotion.exitCurve.transform(_leave.value);
    final offset = _pull / 2 + (height - _pull / 2) * t;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Opacity(
        opacity: 1 - t,
        child: Transform.translate(offset: Offset(0, offset), child: widget.child),
      ),
    );
  }
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
