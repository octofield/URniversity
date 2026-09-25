import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui_symbols.dart';
import '../providers/settings_provider.dart';

// What a step asks of the user, which decides what the highlight lets through
// and what moves the tour on
enum TourStepKind {
  // Points something out. Everything is blocked, the hole included
  info,
  // A field inside a sheet the user may fill in or open. The hole passes taps
  field,
  // Tap the highlighted thing. Moves on when the tap lands inside the hole
  tap,
  // Tap the highlighted thing to open a sheet or a page. Moves on when a route
  // is pushed; that route becomes the one the following steps live in
  open,
  // Ends the segment an `open` started. Moves on when that route pops. With a
  // `count`, a pop that added nothing rewinds to the `open` instead
  close,
}

class CoachMarkStep {
  // TourAnchor id to cut out of the scrim. Null shows the card with no hole
  final String? anchor;
  final TourStepKind kind;
  // Stops carry a title; the steps inside a segment borrow the segment's
  final String? title;
  final String body;
  // On an `open`: how many rows the segment is meant to add to. Read when the
  // route is pushed and again when it pops — more means the user saved
  final int Function()? count;
  // False when the step is reached skips it (an `open`, its whole segment)
  final bool Function()? when;

  const CoachMarkStep(
    this.kind, {
    this.anchor,
    this.title,
    required this.body,
    this.count,
    this.when,
  });
}

// Marks a widget the tour can point at. Ids are plain strings so a field built
// inside a sheet's builder can be marked without hoisting any state out of it
// (CLAUDE.md rule 3), and so the same id can sit on two widgets at once — a
// sheet that is still animating out and the one replacing it — without the
// duplicate-key crash a GlobalKey would throw
class TourAnchor extends StatefulWidget {
  final String id;
  final Widget child;

  const TourAnchor({super.key, required this.id, required this.child});

  // Several may share an id; the newest one that is laid out wins
  static final _registry = <String, List<_TourAnchorState>>{};

  static Rect? rectOf(String id) {
    final states = _registry[id];
    if (states == null) return null;
    for (final state in states.reversed) {
      final box = state.context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize || box.size.isEmpty) continue;
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return null;
  }

  static BuildContext? contextOf(String id) {
    final states = _registry[id];
    return states == null || states.isEmpty ? null : states.last.context;
  }

  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  late String _id = widget.id;

  @override
  void initState() {
    super.initState();
    TourAnchor._registry.putIfAbsent(_id, () => []).add(this);
  }

  @override
  void didUpdateWidget(TourAnchor old) {
    super.didUpdateWidget(old);
    if (old.id == widget.id) return;
    TourAnchor._registry[_id]?.remove(this);
    _id = widget.id;
    TourAnchor._registry.putIfAbsent(_id, () => []).add(this);
  }

  @override
  void dispose() {
    TourAnchor._registry[_id]?.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Tells the tour which route is on top, and when one is pushed or popped.
// Registered once on MaterialApp. A tour step belongs to one route; when
// something else is on top — the date picker a field opened, a dropdown menu —
// the tour steps out of the way instead of covering it
class TourRouteObserver extends NavigatorObserver with ChangeNotifier {
  Route<dynamic>? top;
  _CoachMarkViewState? _tour;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = route;
    _tour?._routePushed(route);
    notifyListeners();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = previousRoute;
    _tour?._routePopped(route);
    notifyListeners();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (top == route) top = previousRoute;
    _tour?._routePopped(route);
    notifyListeners();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (top == oldRoute) top = newRoute;
    notifyListeners();
  }
}

final tourRouteObserver = TourRouteObserver();

// A spotlight tour over the live app. The hole in the scrim is real: taps
// inside it reach the widget underneath, so the user adds their first task by
// actually tapping + and actually filling in the sheet.
class CoachMarkOverlay {
  // Returns a dismisser the caller must invoke from dispose(). An overlay entry
  // outlives the widget that inserted it, so if the screen underneath goes away
  // mid-tour — a session expiring, a recovery link arriving — the scrim would
  // stay up over whatever replaced it, eating every tap with no way out but
  // restarting the app.
  //
  // Dismissing this way deliberately does NOT call onFinished: nobody saw the
  // chapter, so it should still be waiting next time.
  static VoidCallback show(
    BuildContext context, {
    required List<CoachMarkStep> steps,
    required VoidCallback onFinished,
  }) {
    if (steps.isEmpty) {
      onFinished();
      return () {};
    }

    final baseRoute = ModalRoute.of(context);
    late final OverlayEntry entry;
    var removed = false;
    void dismiss() {
      if (removed) return;
      removed = true;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _CoachMarkView(
        steps: steps,
        baseRoute: baseRoute,
        onFinished: () {
          dismiss();
          onFinished();
        },
      ),
    );
    Overlay.of(context).insert(entry);
    return dismiss;
  }
}

class _TrackedRoute {
  final Route<dynamic>? route;
  final int openIndex;
  final int? countBefore;

  const _TrackedRoute(this.route, this.openIndex, this.countBefore);
}

class _CoachMarkView extends ConsumerStatefulWidget {
  final List<CoachMarkStep> steps;
  final Route<dynamic>? baseRoute;
  final VoidCallback onFinished;

  const _CoachMarkView({
    required this.steps,
    required this.baseRoute,
    required this.onFinished,
  });

  @override
  ConsumerState<_CoachMarkView> createState() => _CoachMarkViewState();
}

class _CoachMarkViewState extends ConsumerState<_CoachMarkView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _index = 0;
  Rect? _hole;
  // Routes the tour opened, innermost last. The first is the screen it started on
  late final List<_TrackedRoute> _routes = [_TrackedRoute(widget.baseRoute, -1, null)];
  // Back never crosses this: it would mean un-opening a sheet or un-saving a row
  int _backFloor = 0;
  // The user closed a sheet without saving; the rewound card says so
  bool _retry = false;
  // The segment just ended with a save; the next card says so
  bool _saved = false;
  // Set when the tour closes a sheet itself, so the pop is not read as the user
  // giving up
  bool _expectPop = false;
  bool _finished = false;
  // Frame-by-frame measuring, until the target stops moving
  int _settleFrames = 0;
  Rect? _lastMeasured;
  int _stableFrames = 0;
  // A step that needs a tap is passed by if its target never turns up. Kept
  // here rather than passed along, so a step entered while a previous
  // measurement is still settling does not inherit that one's answer
  bool _skipIfMissing = false;

  // A ring that swells out of the highlight and fades, a few times per step,
  // on steps that ask for a tap — the eye goes to movement. It stops after
  // three so a user reading the card is not nagged by it
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed && ++_pulses < 3) _pulse.forward(from: 0);
    });
  int _pulses = 0;

  List<CoachMarkStep> get _steps => widget.steps;
  CoachMarkStep get _step => _steps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tourRouteObserver._tour = this;
    tourRouteObserver.addListener(_onRoutesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _enter(_index));
  }

  @override
  void dispose() {
    _pulse.dispose();
    WidgetsBinding.instance.removeObserver(this);
    tourRouteObserver.removeListener(_onRoutesChanged);
    if (tourRouteObserver._tour == this) tourRouteObserver._tour = null;
    super.dispose();
  }

  // Rotating the phone, resizing the window or the keyboard coming up all move
  // the target; the hole was measured against the old layout
  @override
  void didChangeMetrics() => _measureSoon();

  void _onRoutesChanged() {
    if (!mounted) return;
    _later(() => setState(() {}));
    if (_visible) _measureSoon();
  }

  // Navigator callbacks and pointer events can arrive mid-frame
  void _later(VoidCallback fn) {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fn();
      });
    } else {
      fn();
    }
  }

  Route<dynamic>? get _stepRoute => _routes.last.route;

  // Hidden while a route the tour did not open sits on top, so a date picker or
  // a dropdown opened from a highlighted field is usable rather than covered.
  // With no observer registered (some widget tests) there is nothing to hide for
  bool get _visible {
    final top = tourRouteObserver.top;
    return top == null || _stepRoute == null || top == _stepRoute;
  }

  // ---- Structure ----------------------------------------------------------

  int _closeOf(int openIndex) {
    var depth = 0;
    for (var i = openIndex; i < _steps.length; i++) {
      if (_steps[i].kind == TourStepKind.open) depth++;
      if (_steps[i].kind == TourStepKind.close && --depth == 0) return i;
    }
    return _steps.length - 1;
  }

  // Indices where a top-level stop begins. A whole open…close segment is one
  // stop, so the counter reads "2 / 5" however many fields the sheet has
  List<int> get _stopStarts {
    final starts = <int>[];
    var depth = 0;
    for (var i = 0; i < _steps.length; i++) {
      final kind = _steps[i].kind;
      if (depth == 0 && kind != TourStepKind.close) starts.add(i);
      if (kind == TourStepKind.open) depth++;
      if (kind == TourStepKind.close) depth--;
    }
    return starts;
  }

  // ---- Moving -------------------------------------------------------------

  void _enter(int index) {
    if (!mounted || _finished) return;
    var i = index;
    // Steps whose precondition is gone are passed over — an `open` takes its
    // whole segment with it, since nothing inside it could be shown
    while (i < _steps.length) {
      final when = _steps[i].when;
      if (when == null || when()) break;
      i = _steps[i].kind == TourStepKind.open ? _closeOf(i) + 1 : i + 1;
    }
    if (i >= _steps.length) {
      _finish();
      return;
    }
    setState(() => _index = i);
    _pulses = 0;
    _pulse.forward(from: 0);
    _reveal();
    _measureSoon(skipIfMissing: true);
  }

  void _next({bool saved = false}) {
    _retry = false;
    _saved = saved;
    _enter(_index + 1);
  }

  void _back() {
    _retry = false;
    _saved = false;
    _enter(_index - 1);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  // Past the segment this step belongs to (or the one it opens), for "skip this step"
  void _skipStep() {
    final step = _step;
    _retry = false;
    _saved = false;
    switch (step.kind) {
      case TourStepKind.open:
        _backFloor = _closeOf(_index) + 1;
        _enter(_closeOf(_index) + 1);
      case TourStepKind.close:
        final tracked = _routes.last;
        final route = tracked.route;
        if (route != null && route.isActive) {
          // The pop handler sees this flag and moves past the segment
          _expectPop = true;
          route.navigator?.removeRoute(route);
        } else {
          _backFloor = _index + 1;
          _enter(_index + 1);
        }
      default:
        _backFloor = _index + 1;
        _enter(_index + 1);
    }
  }

  void _routePushed(Route<dynamic> route) {
    if (_finished || _step.kind != TourStepKind.open) return;
    // Only a push from the route this step lives on counts as "the user opened it"
    final openIndex = _index;
    _routes.add(_TrackedRoute(route, openIndex, _step.count?.call()));
    _backFloor = openIndex + 1;
    _later(() => _next());
  }

  void _routePopped(Route<dynamic> route) {
    if (_finished) return;
    final at = _routes.indexWhere((t) => t.route == route);
    // Not one the tour opened: a dialog or a picker. Nothing to do
    if (at <= 0) return;
    // The outermost segment that closed decides, if several went at once
    final tracked = _routes[at];
    _routes.removeRange(at, _routes.length);
    final closeIndex = _closeOf(tracked.openIndex);

    if (_expectPop) {
      _expectPop = false;
      _backFloor = closeIndex + 1;
      _later(() {
        _retry = false;
        _saved = false;
        _enter(closeIndex + 1);
      });
      return;
    }

    final before = tracked.countBefore;
    final count = _steps[tracked.openIndex].count;
    final saved = before == null || count == null || count() > before;
    _later(() {
      if (saved) {
        _backFloor = closeIndex + 1;
        _retry = false;
        _saved = before != null;
        _enter(closeIndex + 1);
      } else {
        // Closed without saving: back to the button, with a line saying it is fine
        _backFloor = tracked.openIndex;
        _saved = false;
        _retry = true;
        _enter(tracked.openIndex);
      }
    });
  }

  // Pops the page a look-around step is on, for its "back" button
  void _leavePage() {
    final route = _routes.last.route;
    if (route != null && route.isCurrent) route.navigator?.pop();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_visible || _finished) return;
    final hole = _hole;
    if (_step.kind == TourStepKind.tap && hole != null && hole.contains(event.position)) {
      // After this frame: the real widget handles the tap first
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _step.kind != TourStepKind.tap) return;
        _backFloor = _index + 1;
        _next();
      });
      return;
    }
    // A drag of the add button, a scroll: the target may have moved
    _measureSoon();
  }

  // ---- Measuring ----------------------------------------------------------

  // Brings a target that is scrolled away — the journal section on a phone, a
  // sheet field under the keyboard — into view before measuring it
  void _reveal() {
    final anchor = _step.anchor;
    if (anchor == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = TourAnchor.contextOf(anchor);
      if (ctx == null || !ctx.mounted || Scrollable.maybeOf(ctx) == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  // Measures every frame until the target has held still for two in a row, so
  // a route sliding in, a scroll settling or the keyboard rising all end with
  // the hole where the target finally is. Capped, so a target that never stops
  // moving cannot keep frames coming forever
  void _measureSoon({bool skipIfMissing = false}) {
    if (skipIfMissing) _skipIfMissing = true;
    final restart = _settleFrames == 0;
    _settleFrames = 40;
    _stableFrames = 0;
    if (restart) _measureFrame();
  }

  void _measureFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finished) {
        _settleFrames = 0;
        return;
      }
      final anchor = _step.anchor;
      final rect = anchor == null ? null : TourAnchor.rectOf(anchor);
      _stableFrames = rect == _lastMeasured ? _stableFrames + 1 : 0;
      _lastMeasured = rect;
      if (rect != _hole) setState(() => _hole = rect);

      final settled = _stableFrames >= 2;
      if (settled || --_settleFrames <= 0) {
        _settleFrames = 0;
        final skipIfMissing = _skipIfMissing;
        _skipIfMissing = false;
        // Nothing to tap: a step that needs a tap cannot be done, so pass it by
        // rather than leave the user staring at a hole over nothing
        if (skipIfMissing && anchor != null && rect == null && _visible) {
          final kind = _step.kind;
          if (kind == TourStepKind.tap || kind == TourStepKind.open) _skipStep();
        }
        return;
      }
      _measureFrame();
      SchedulerBinding.instance.scheduleFrame();
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  // ---- Building -----------------------------------------------------------

  // Taps inside the hole reach the app on every step but `info`, and on a
  // look-around step (a `close` with nothing to save)
  bool get _passThrough {
    final step = _step;
    if (step.kind == TourStepKind.info) return false;
    if (step.kind == TourStepKind.close && _isPageVisit(_index)) return false;
    return true;
  }

  bool get _invitesTap {
    final kind = _step.kind;
    if (kind == TourStepKind.tap || kind == TourStepKind.open) return true;
    return kind == TourStepKind.close && !_isPageVisit(_index);
  }

  bool _isPageVisit(int closeIndex) {
    final open = _routes.last.openIndex;
    return open >= 0 && _steps[open].count == null && _closeOf(open) == closeIndex;
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _finished) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final screen = media.size;
    // The keyboard takes the bottom of the screen; the card has to fit above it
    final visibleHeight = screen.height - media.viewInsets.bottom;
    final hole = _hole?.inflate(AppSpacing.xs);

    final blockers = <Widget>[];
    if (hole == null || !_passThrough) {
      blockers.add(const Positioned.fill(child: _Blocker()));
    } else {
      blockers.addAll([
        Positioned(left: 0, right: 0, top: 0, height: hole.top.clamp(0, screen.height), child: const _Blocker()),
        Positioned(left: 0, right: 0, top: hole.bottom, bottom: 0, child: const _Blocker()),
        Positioned(left: 0, width: hole.left.clamp(0, screen.width), top: hole.top, height: hole.height, child: const _Blocker()),
        Positioned(left: hole.right, right: 0, top: hole.top, height: hole.height, child: const _Blocker()),
      ]);
    }

    final spaceBelow = hole == null ? 0.0 : visibleHeight - hole.bottom;
    final spaceAbove = hole == null ? 0.0 : hole.top;
    final cardBelow = hole != null && spaceBelow >= spaceAbove;
    final maxCardHeight = visibleHeight * 0.4;
    final cardWidth = (screen.width - AppSpacing.pageHorizontal * 2).clamp(0.0, 480.0);
    // Where along the card's edge the arrow sits: under the target's centre,
    // kept off the rounded corners
    final arrowX = hole == null
        ? 0.0
        : (hole.center.dx - AppSpacing.pageHorizontal).clamp(24.0, cardWidth - 24.0);
    final pulsing = _invitesTap;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: _onPointerUp,
      child: Stack(
        children: [
          // A painter counts as hit by default, which would swallow the taps
          // the hole is meant to let through
          Positioned.fill(
            child: IgnorePointer(
              child: hole == null
                  ? const CustomPaint(painter: SpotlightPainter(null))
                  // Glides from the last target to this one rather than jumping
                  : TweenAnimationBuilder<Rect?>(
                      tween: RectTween(end: hole),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      builder: (context, rect, _) => AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => CustomPaint(
                          painter: SpotlightPainter(
                            rect,
                            pulse: pulsing ? _pulse.value : null,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          ...blockers,
          Positioned(
            left: AppSpacing.pageHorizontal,
            right: AppSpacing.pageHorizontal,
            top: hole == null
                ? visibleHeight / 3
                : (cardBelow ? hole.bottom + AppSpacing.xs : null),
            bottom: hole == null || cardBelow
                ? null
                : screen.height - hole.top + AppSpacing.xs,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxCardHeight, maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hole != null && cardBelow) _Arrow(x: arrowX, up: true),
                  Flexible(child: _card(context)),
                  if (hole != null && !cardBelow) _Arrow(x: arrowX, up: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final step = _step;
    final stops = _stopStarts;
    final stop = stops.where((i) => i <= _index).length;
    final segmentStart = stops.lastWhere((i) => i <= _index, orElse: () => 0);
    final inSegment = _index > segmentStart && _steps[segmentStart].kind == TourStepKind.open;
    final title = step.title ?? (inSegment ? _steps[segmentStart].title : null);

    final pageVisit = step.kind == TourStepKind.close && _isPageVisit(_index);
    final isLast = _index == _steps.length - 1;
    final waitsForUser = !pageVisit &&
        (step.kind == TourStepKind.tap ||
            step.kind == TourStepKind.open ||
            step.kind == TourStepKind.close);
    final canBack = _index - 1 >= _backFloor &&
        _index > 0 &&
        const {TourStepKind.info, TourStepKind.field}.contains(_steps[_index - 1].kind) &&
        !pageVisit;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$stop / ${stops.length}',
                  style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary),
                ),
                if (inSegment) ...[
                  Text(kDotSeparator,
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textTertiary)),
                  Text(
                    '${_index - segmentStart} / ${_closeOf(segmentStart) - segmentStart}',
                    style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textTertiary),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: s.tourCloseChapter,
                  visualDensity: VisualDensity.compact,
                  onPressed: _finish,
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_saved)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          s.tourSaved,
                          style: theme.textTheme.labelLarge?.copyWith(color: AppColors.success),
                        ),
                      ),
                    if (title != null)
                      Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    if (_retry)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          s.tourRetry,
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.primary),
                        ),
                      ),
                    Text(
                      step.body,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    if (waitsForUser && step.kind != TourStepKind.close) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(Icons.touch_app_outlined, size: 18, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              s.tourTryIt,
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (canBack)
                  TextButton(onPressed: _back, child: Text(s.tourBack)),
                const Spacer(),
                if (waitsForUser)
                  TextButton(onPressed: _skipStep, child: Text(s.tourSkipStep))
                else if (pageVisit)
                  FilledButton(onPressed: _leavePage, child: Text(s.tourGoBack))
                else
                  FilledButton(
                    onPressed: isLast ? _finish : _next,
                    child: Text(isLast ? s.tourFinish : s.tourGotIt),
                  ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Swallows taps outside the hole without doing anything with them
class _Blocker extends StatelessWidget {
  const _Blocker();

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
      );
}

// Public so a test can read back where the hole landed — that the spotlight
// actually sits on the thing the step is describing is the one part of this
// that text assertions cannot reach
class SpotlightPainter extends CustomPainter {
  final Rect? hole;
  // 0–1 through one swell of the attention ring; null draws none
  final double? pulse;

  const SpotlightPainter(this.hole, {this.pulse});

  static const _radius = Radius.circular(AppRadius.md);

  @override
  void paint(Canvas canvas, Size size) {
    // Dark enough to pull the eye, light enough that the screen stays readable
    // behind it — the page is what the step is explaining
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final target = hole;
    if (target == null) {
      canvas.drawRect(Offset.zero & size, scrim);
      return;
    }
    // Even-odd fill: the rounded rect inside the full rect is left unpainted,
    // so the target shows at full brightness. Subtracting one path from the
    // other with Path.combine left the target dimmed on a real device — only
    // the outline marked it
    final cutOut = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(target, _radius));
    canvas.drawPath(cutOut, scrim);

    canvas.drawRRect(
      RRect.fromRectAndRadius(target, _radius),
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final swell = pulse;
    if (swell != null && swell > 0) {
      final ring = target.inflate(4 + swell * 14);
      canvas.drawRRect(
        RRect.fromRectAndRadius(ring, const Radius.circular(AppRadius.md + 8)),
        Paint()
          ..color = AppColors.primary.withValues(alpha: (1 - swell) * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(SpotlightPainter old) => old.hole != hole || old.pulse != pulse;
}

// The notch on the card's edge that points at the highlight
class _Arrow extends StatelessWidget {
  final double x;
  final bool up;

  const _Arrow({required this.x, required this.up});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: x - 9),
        child: CustomPaint(size: const Size(18, 9), painter: _ArrowPainter(up)),
      );
}

class _ArrowPainter extends CustomPainter {
  final bool up;

  const _ArrowPainter(this.up);

  @override
  void paint(Canvas canvas, Size size) {
    final path = up
        ? (Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height))
        : (Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0));
    canvas.drawPath(path..close(), Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.up != up;
}
