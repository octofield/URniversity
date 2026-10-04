import 'dart:math';

import 'package:flutter/material.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';

// Every page opened on top of another closes the same way (system_design.md
// §3-Q, 2026-10-04): pull it down from the top, or swipe it to the right, and
// it follows the finger — shrinking a little, corners rounding — with the page
// beneath showing through, like iOS's swipe back and Material 3's predictive
// back. Let go past the threshold moving onward, or flick, and it carries on
// out; move back first and it settles where it was.
//
// [AppPage] is the template a page wraps its Scaffold in. Opened with
// [AppPageRoute] (or [GesturePage] in the router) the finger drives the
// route's own transition; under any other route — a card's container
// transform — the page moves itself and then pops

// Pixels of finger travel, and a flick in pixels per second
const double _kThreshold = 120;
const double _kFlingVelocity = 700;

// How far the page has gone, 0 to 1, drawn the same way by the route and by a
// page moving itself: along the finger, slightly smaller, corners rounding
Widget _followFinger(BuildContext context, AxisDirection? direction, double progress, Widget child) {
  final p = direction == null ? 0.0 : progress.clamp(0.0, 1.0);
  final size = MediaQuery.sizeOf(context);
  final offset = direction == AxisDirection.right ? Offset(p * size.width, 0) : Offset(0, p * size.height);
  // The same widgets at rest and while moving, so nothing under them rebuilds
  return Transform.translate(
    offset: offset,
    child: Transform.scale(
      scale: 1 - 0.06 * p,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl * min(1.0, p * 6)),
        clipBehavior: p == 0 ? Clip.none : Clip.antiAlias,
        child: child,
      ),
    ),
  );
}

// A MaterialPageRoute whose transition a finger can drive. At rest it is the
// theme's own transition (predictive back, Cupertino, fade-forwards); while a
// finger drives it the theme's transition is held fully shown and the page
// follows the finger instead, so swapping between the two never changes the
// widget tree under the page
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.barrierDismissible,
  });

  final ValueNotifier<AxisDirection?> _drag = ValueNotifier(null);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ValueListenableBuilder<AxisDirection?>(
      valueListenable: _drag,
      builder: (context, direction, _) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) => _followFinger(
          context,
          direction,
          1 - animation.value,
          super.buildTransitions(
            context,
            direction == null ? animation : kAlwaysCompleteAnimation,
            secondaryAnimation,
            child,
          ),
        ),
      ),
    );
  }

  void _start(AxisDirection direction) {
    _drag.value = direction;
    navigator!.didStartUserGesture();
  }

  // The page below is revealed as the controller leaves 1: the route stops
  // being opaque the moment its animation is no longer complete
  void _update(double progress) => controller!.value = 1 - progress.clamp(0.0, 1.0);

  void _end({required bool close, required double motion}) {
    final navigator = this.navigator!;
    if (close) {
      // The pop reverses the controller from where the finger left it
      navigator.pop();
      if (motion == 0) controller!.value = 0;
    } else if (motion == 0) {
      controller!.value = 1;
      _drag.value = null;
    } else {
      controller!
          .animateTo(1, duration: AppMotion.move * motion, curve: AppMotion.moveCurve)
          .whenCompleteOrCancel(() => _drag.value = null);
    }
    // As the iOS back gesture does: the gesture is over once the page has
    // finished going or coming back
    if (controller!.isAnimating) {
      late final AnimationStatusListener done;
      done = (status) {
        navigator.didStopUserGesture();
        controller!.removeStatusListener(done);
      };
      controller!.addStatusListener(done);
    } else {
      navigator.didStopUserGesture();
    }
  }

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }
}

// An [AppPageRoute] for a router page (go_router's pageBuilder). It reads the
// page each time it builds, so a page the router replaces shows its new child
class GesturePage<T> extends Page<T> {
  final Widget child;
  const GesturePage({super.key, super.name, required this.child});

  @override
  Route<T> createRoute(BuildContext context) => _PageBasedAppPageRoute<T>(this);
}

class _PageBasedAppPageRoute<T> extends AppPageRoute<T> {
  _PageBasedAppPageRoute(GesturePage<T> page) : super(settings: page, builder: (_) => page.child);

  @override
  Widget buildContent(BuildContext context) => (settings as GesturePage<T>).child;
}

class AppPage extends StatefulWidget {
  // The page itself, usually its Scaffold
  final Widget child;
  // False where sideways swipes already move between the page's own views
  // (timetable and grades, the history's day/week/month, the backend's tabs)
  final bool swipeBack;

  const AppPage({super.key, required this.child, this.swipeBack = true});

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> with SingleTickerProviderStateMixin {
  // The way the finger is taking the page, null when it is not
  AxisDirection? _direction;
  // Pixels of travel that way, and whether the last movement went onward: a
  // drag that came back does not close, however far it had gone
  double _pull = 0;
  bool _onward = true;
  AppPageRoute<dynamic>? _route;

  // Only for a page moving itself: its settle back after letting go. Made in
  // initState, not lazily: a lazy one first touched in dispose would be
  // created on a widget already leaving the tree
  late final AnimationController _settle;
  double _settleFrom = 0;
  AxisDirection? _settling;

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

  double _extent(AxisDirection direction) {
    final size = MediaQuery.sizeOf(context);
    return direction == AxisDirection.right ? size.width : size.height;
  }

  bool _begin(AxisDirection direction) {
    if (_direction != null) return _direction == direction;
    final route = ModalRoute.of(context);
    // Nothing to go back to, a page that asks before leaving, or one still
    // arriving: no gesture at all
    if (route == null || !route.popGestureEnabled) return false;
    _settle.stop();
    _direction = direction;
    _settling = null;
    _pull = 0;
    _onward = true;
    _route = route is AppPageRoute ? route : null;
    _route?._start(direction);
    return true;
  }

  void _move(double delta) {
    if (_direction == null || delta == 0) return;
    _onward = delta > 0;
    _show(max(0, _pull + delta));
  }

  void _moveTo(double value) {
    if (_direction == null || value == _pull) return;
    _onward = value > _pull;
    _show(value);
  }

  void _show(double pull) {
    _pull = pull;
    final route = _route;
    if (route != null) {
      route._update(pull / _extent(_direction!));
    } else {
      setState(() {});
    }
  }

  void _release(double velocity) {
    final direction = _direction;
    if (direction == null) return;
    final close = velocity > _kFlingVelocity || (_pull >= _kThreshold && _onward && velocity >= 0);
    final motion = motionScale(context);
    final route = _route;
    _direction = null;
    _route = null;
    if (route != null) {
      route._end(close: close, motion: motion);
      return;
    }
    // Moving itself: back to where it was — under a container transform the
    // pop then shrinks it into the card it came from
    _settling = direction;
    _settleFrom = _pull;
    _settle.duration = scaled(context, AppMotion.move);
    _settle.forward(from: 0);
    if (close) Navigator.of(context).maybePop();
  }

  bool _onScroll(ScrollNotification n) {
    // The page's own vertical list, not a sideways strip or a list within it
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (_direction == AxisDirection.right) return false;
    if (n is OverscrollNotification && n.dragDetails != null && (n.overscroll < 0 || _pull > 0)) {
      // Android: the list is at its top and the finger keeps going down — or,
      // in a list too short to scroll, comes back up
      if (n.overscroll < 0 && !_begin(AxisDirection.down)) return false;
      _move(-n.overscroll);
    } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
      final beyond = n.metrics.minScrollExtent - n.metrics.pixels;
      if (beyond > 0) {
        // iOS: the list itself bounces past its top
        if (_begin(AxisDirection.down)) _moveTo(beyond);
      } else if (_pull > 0 && (n.scrollDelta ?? 0) > 0) {
        // Changing its mind: back up before the list scrolls on
        _move(-n.scrollDelta!);
      }
    } else if (n is ScrollEndNotification) {
      _release(n.dragDetails?.primaryVelocity ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Under an AppPageRoute the route draws the movement; a page moving
    // itself draws it here
    final moving = _route == null ? (_direction ?? _settling) : null;
    final page = _followFinger(
      context,
      moving,
      moving == null ? 0 : _pull / _extent(moving),
      widget.child,
    );
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      // Parts of the page that do not scroll — the app bar, a short page's
      // empty space — are dragged directly. A list inside wins its own drags
      // and reaches this through _onScroll instead
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (d) {
          if (_direction == null && (d.delta.dy <= 0 || !_begin(AxisDirection.down))) return;
          if (_direction == AxisDirection.down) _move(d.delta.dy);
        },
        onVerticalDragEnd: (d) {
          if (_direction == AxisDirection.down) _release(d.primaryVelocity ?? 0);
        },
        onHorizontalDragUpdate: widget.swipeBack
            ? (d) {
                if (_direction == null && (d.delta.dx <= 0 || !_begin(AxisDirection.right))) return;
                if (_direction == AxisDirection.right) _move(d.delta.dx);
              }
            : null,
        onHorizontalDragEnd: widget.swipeBack
            ? (d) {
                if (_direction == AxisDirection.right) _release(d.primaryVelocity ?? 0);
              }
            : null,
        child: page,
      ),
    );
  }
}
