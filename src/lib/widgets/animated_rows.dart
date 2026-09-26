import 'package:flutter/material.dart';
import '../core/theme/app_motion.dart';

// A column whose rows arrive and leave instead of popping (system_design.md
// §3-Q). Rows are matched between builds by their key:
//
//  - a key that is gone keeps its last widget on screen, waits [holdFor] (so a
//    ticked task's strike-through is seen), then fades and folds its height
//    away while the rows below slide up into the gap
//  - a new key unfolds into place, after [enterDelayFor] — the "all done"
//    placeholder waits for the last row to finish leaving
//  - a key that stays is left alone, state and all
//
// The first build shows everything at once: arriving on a screen is not an
// event. With the system's animations switched off, rows simply appear and go
class AnimatedRows extends StatefulWidget {
  // Every child needs a key that is stable for what it shows
  final List<Widget> children;
  // Drawn above every row but the first, and folds away with its row. Null
  // for a row that takes none
  final Widget? Function(BuildContext context, Key key)? separatorBuilder;
  // How long a leaving row stays before it folds
  final Duration Function(Key key)? holdFor;
  // How long a new row waits before it unfolds
  final Duration Function(Key key)? enterDelayFor;

  const AnimatedRows({
    super.key,
    required this.children,
    this.separatorBuilder,
    this.holdFor,
    this.enterDelayFor,
  });

  @override
  State<AnimatedRows> createState() => _AnimatedRowsState();
}

class _Row {
  final Key key;
  Widget widget;
  final AnimationController run;
  // Mapped from run: 0 folded away, 1 fully there
  late Animation<double> presence;
  bool leaving = false;

  _Row(this.key, this.widget, this.run);
}

class _AnimatedRowsState extends State<AnimatedRows> with TickerProviderStateMixin {
  final _rows = <_Row>[];

  @override
  void initState() {
    super.initState();
    for (final child in widget.children) {
      final row = _Row(child.key!, child, AnimationController(vsync: this, value: 1));
      row.presence = row.run;
      _rows.add(row);
    }
  }

  @override
  void didUpdateWidget(AnimatedRows old) {
    super.didUpdateWidget(old);
    final scale = motionScale(context);
    final incoming = {for (final c in widget.children) c.key!: c};
    final byKey = {for (final r in _rows) r.key: r};

    // Rows on their way out keep their place relative to the row they
    // followed, so the gap closes where the row was
    final next = <_Row>[];
    for (final child in widget.children) {
      final existing = byKey[child.key];
      if (existing != null) {
        existing.widget = child;
        if (existing.leaving) _revive(existing);
        next.add(existing);
      } else {
        next.add(_arrive(child, scale));
      }
    }
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (incoming.containsKey(row.key)) continue;
      if (!row.leaving) _leave(row, scale);
      if (row.run.isDismissed && row.leaving && scale == 0) {
        row.run.dispose();
        continue;
      }
      // After whichever row preceded it before, or first
      final before = i == 0 ? null : _rows[i - 1];
      final at = before == null ? 0 : next.indexOf(before) + 1;
      next.insert(at.clamp(0, next.length), row);
    }
    _rows
      ..clear()
      ..addAll(next);
  }

  _Row _arrive(Widget child, double scale) {
    final delay = (widget.enterDelayFor?.call(child.key!) ?? Duration.zero) * scale;
    final total = delay + AppMotion.enter * scale;
    final row = _Row(child.key!, child, AnimationController(vsync: this, duration: total));
    row.presence = total == Duration.zero
        ? row.run
        : CurvedAnimation(
            parent: row.run,
            curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1, curve: AppMotion.enterCurve),
          );
    if (total == Duration.zero) {
      row.run.value = 1;
    } else {
      row.run.forward();
    }
    return row;
  }

  void _leave(_Row row, double scale) {
    row.leaving = true;
    final hold = (widget.holdFor?.call(row.key) ?? Duration.zero) * scale;
    final total = hold + AppMotion.exit * scale;
    if (total == Duration.zero) {
      row.run.value = 0;
      return;
    }
    // One controller runs the wait and the fold: the fold is the tail of it
    row.run
      ..duration = total
      ..value = 0;
    row.presence = ReverseAnimation(CurvedAnimation(
      parent: row.run,
      curve: Interval(hold.inMicroseconds / total.inMicroseconds, 1, curve: AppMotion.exitCurve),
    ));
    row.run.forward().whenCompleteOrCancel(() {
      if (!mounted || !row.leaving) return;
      setState(() {
        _rows.remove(row);
        row.run.dispose();
      });
    });
  }

  // Back before it had gone — unticked again straight away
  void _revive(_Row row) {
    row.leaving = false;
    row.run.stop();
    row.run.value = 1;
    row.presence = row.run;
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.run.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final separator = widget.separatorBuilder;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _rows.length; i++)
          KeyedSubtree(
            key: _rows[i].key,
            child: SizeTransition(
              sizeFactor: _rows[i].presence,
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: _rows[i].presence,
                // A row on its way out is only a picture of what it was
                child: IgnorePointer(
                  ignoring: _rows[i].leaving,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (i > 0) ?separator?.call(context, _rows[i].key),
                      _rows[i].widget,
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
