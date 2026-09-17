import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';

// Ticking a task off, made visible.
//
// Two layers, switchable in settings: the box itself pops, and — only when the
// day's last outstanding task goes — a short burst of confetti. Both are
// cosmetic; the write happens either way, so `off` changes nothing but the feel.

const _popDuration = Duration(milliseconds: 220);

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
    duration: _popDuration,
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _handleToggle() {
    final effect = ref.read(completionEffectProvider);
    final ticking = !widget.value;

    if (effect != TaskCompletionEffect.off && ticking) {
      _pop.forward(from: 0);
      if (effect == TaskCompletionEffect.celebrate &&
          (widget.isLastOutstanding?.call() ?? false)) {
        showCompletionConfetti(context);
      }
    }
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      // Overshoots and settles, so the tick reads as landing rather than just
      // appearing
      scale: Tween<double>(begin: 1, end: 1.35).animate(
        CurvedAnimation(parent: _pop, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
      ),
      child: Checkbox(
        visualDensity: VisualDensity.compact,
        value: widget.value,
        onChanged: (_) => _handleToggle(),
      ),
    );
  }
}

// A burst over whatever is on screen. An overlay entry rather than part of the
// row: the row is about to disappear into the completed section
void showCompletionConfetti(BuildContext context) {
  final overlay = Overlay.maybeOf(context);
  final box = context.findRenderObject() as RenderBox?;
  if (overlay == null || box == null || !box.hasSize) return;

  final origin = box.localToGlobal(box.size.center(Offset.zero));
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: IgnorePointer(
        child: _ConfettiBurst(origin: origin, onDone: () => entry.remove()),
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
  static const _colors = [
    AppColors.primary,
    AppColors.categoryExchange,
    AppColors.categoryCompetition,
    AppColors.categoryCert,
    AppColors.categoryPerformance,
  ];

  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  // Fixed at birth: recomputing per frame would make every piece jitter
  late final List<_Piece> _pieces = [
    for (var i = 0; i < 18; i++)
      () {
        final random = Random(i * 7919);
        return _Piece(
          angle: -pi / 2 + (random.nextDouble() - 0.5) * pi * 0.9,
          speed: 90 + random.nextDouble() * 110,
          spin: (random.nextDouble() - 0.5) * 8,
          color: _colors[i % _colors.length],
          size: 4 + random.nextDouble() * 4,
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
            progress: _run.value,
          ),
        ),
      );
}

class _Piece {
  final double angle;
  final double speed;
  final double spin;
  final Color color;
  final double size;

  const _Piece({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.color,
    required this.size,
  });
}

class _ConfettiPainter extends CustomPainter {
  final Offset origin;
  final List<_Piece> pieces;
  final double progress;

  _ConfettiPainter({required this.origin, required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 420.0;
    final paint = Paint();

    for (final piece in pieces) {
      final t = progress;
      final dx = cos(piece.angle) * piece.speed * t;
      final dy = sin(piece.angle) * piece.speed * t + 0.5 * gravity * t * t;
      final position = origin + Offset(dx, dy);

      paint.color = piece.color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(piece.spin * t);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 1.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
