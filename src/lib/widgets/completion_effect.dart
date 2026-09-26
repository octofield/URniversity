import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/haptics.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../providers/settings_provider.dart';
import 'coach_mark.dart' show TourAnchor;

// Ticking a task off, made visible (system_design.md §3-Q).
//
// The row itself does most of the work now — its title is struck through and
// it folds out of the list (AnimatedRows). This adds the two optional layers
// the completion-effect setting controls: the box gives under the thumb and
// springs back, and — only when the day's last outstanding task goes — a burst
// of confetti from the progress ring. Both are cosmetic; the write happens
// either way. Haptics have their own switch (core/haptics.dart)

class TaskCheckbox extends ConsumerStatefulWidget {
  final bool value;
  final VoidCallback onToggle;
  // Whether finishing this one empties the day's list. Read before the write,
  // because afterwards there is nothing left to count
  final bool Function()? isLastOutstanding;

  const TaskCheckbox({
    super.key,
    required this.value,
    required this.onToggle,
    this.isLastOutstanding,
  });

  @override
  ConsumerState<TaskCheckbox> createState() => _TaskCheckboxState();
}

class _TaskCheckboxState extends ConsumerState<TaskCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: AppMotion.move,
  );

  // Pressed in, a touch past full size, then settled — out and back in one
  // pass, so the box can never be left at another size
  late final Animation<double> _scale = _pop.drive(TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.9).chain(CurveTween(curve: AppMotion.exitCurve)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.9, end: 1.08).chain(CurveTween(curve: AppMotion.enterCurve)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.08, end: 1.0).chain(CurveTween(curve: AppMotion.moveCurve)),
      weight: 35,
    ),
  ]));

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _handleToggle() {
    final effect = ref.read(completionEffectProvider);
    final ticking = !widget.value;
    final last = ticking && (widget.isLastOutstanding?.call() ?? false);

    haptic(ref, !ticking ? HapticKind.select : last ? HapticKind.allDone : HapticKind.tick);
    if (effect != TaskCompletionEffect.off && ticking) {
      _pop.duration = scaled(context, AppMotion.move);
      _pop.forward(from: 0);
      if (effect == TaskCompletionEffect.celebrate && last) {
        showCompletionConfetti(context);
      }
    }
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Checkbox(
        visualDensity: VisualDensity.compact,
        value: widget.value,
        onChanged: (_) => _handleToggle(),
      ),
    );
  }
}

// A burst over whatever is on screen, from the day's progress ring when it is
// in view — finishing the day belongs to the day, not to one row — and from
// the box otherwise. An overlay entry, since the row is about to leave
void showCompletionConfetti(BuildContext context) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null || motionScale(context) == 0) return;
  final ring = TourAnchor.rectOf('today.ring');
  final box = context.findRenderObject() as RenderBox?;
  final origin = ring?.center ??
      (box != null && box.hasSize ? box.localToGlobal(box.size.center(Offset.zero)) : null);
  if (origin == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: _ConfettiBurst(
          origin: origin,
          // The row it came from may be long gone by now
          onDone: () {
            if (entry.mounted) entry.remove();
          },
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

class _ConfettiBurst extends StatefulWidget {
  final Offset origin;
  final VoidCallback onDone;

  const _ConfettiBurst({required this.origin, required this.onDone});

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  static final _colors = [
    AppColors.primary,
    AppColors.categoryExchange,
    AppColors.categoryCompetition,
    AppColors.categoryCert,
    AppColors.categoryPerformance,
    AppColors.warning,
  ];

  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  // Fixed at birth: recomputing per frame would make every piece jitter
  late final List<_Piece> _pieces = [
    for (var i = 0; i < 28; i++)
      () {
        final random = Random(i * 7919);
        return _Piece(
          // A fountain: mostly upward, fanned about 120 degrees
          angle: -pi / 2 + (random.nextDouble() - 0.5) * pi * 0.66,
          speed: 260 + random.nextDouble() * 260,
          spin: (random.nextDouble() - 0.5) * 10,
          flip: 6 + random.nextDouble() * 10,
          color: _colors[i % _colors.length],
          size: 5 + random.nextDouble() * 4,
          round: i % 4 == 0,
        );
      }(),
  ];

  @override
  void initState() {
    super.initState();
    _run.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _run,
        builder: (_, _) => CustomPaint(
          painter: _ConfettiPainter(
            origin: widget.origin,
            pieces: _pieces,
            // In seconds, for the physics below
            time: _run.value * 1.1,
            progress: _run.value,
          ),
        ),
      );
}

class _Piece {
  final double angle;
  final double speed;
  final double spin;
  // How fast it tumbles end over end, faked by squashing its width
  final double flip;
  final Color color;
  final double size;
  final bool round;

  const _Piece({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.flip,
    required this.color,
    required this.size,
    required this.round,
  });
}

class _ConfettiPainter extends CustomPainter {
  final Offset origin;
  final List<_Piece> pieces;
  final double time;
  final double progress;

  _ConfettiPainter({
    required this.origin,
    required this.pieces,
    required this.time,
    required this.progress,
  });

  // Paper in air: quickly slowed by drag, then drifting down under gravity at a
  // gentle terminal speed. Integrated in closed form so every frame agrees
  static const _drag = 3.2;
  static const _gravity = 900.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final decay = (1 - exp(-_drag * time)) / _drag;
    // The last 30% fades out
    final alpha = progress < 0.7 ? 1.0 : (1 - (progress - 0.7) / 0.3).clamp(0.0, 1.0);

    for (final piece in pieces) {
      final vx = cos(piece.angle) * piece.speed;
      final vy = sin(piece.angle) * piece.speed;
      final dx = vx * decay;
      final dy = vy * decay + _gravity / _drag * (time - decay);
      final position = origin + Offset(dx, dy);

      paint.color = piece.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(piece.spin * time);
      // A card turning over shows its edge: width follows cos of its tumble
      canvas.scale(cos(piece.flip * time).abs().clamp(0.15, 1.0), 1);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 1.6),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
