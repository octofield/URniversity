import 'package:flutter/material.dart';
import '../core/theme/app_motion.dart';

// A title that gets crossed out as it happens (system_design.md §3-Q): the line
// is drawn left to right across each line of text in turn, and the text fades
// to [struckColor] with it. A title that was already done when it appeared is
// simply shown crossed out — only the moment of ticking is animated.
//
// Painted over the text rather than using TextDecoration.lineThrough, which
// can only be on or off
class AnimatedStrikeText extends StatefulWidget {
  final String text;
  final bool struck;
  final Color struckColor;
  final TextStyle? style;
  final int? maxLines;

  const AnimatedStrikeText({
    super.key,
    required this.text,
    required this.struck,
    required this.struckColor,
    this.style,
    this.maxLines,
  });

  @override
  State<AnimatedStrikeText> createState() => _AnimatedStrikeTextState();
}

class _AnimatedStrikeTextState extends State<AnimatedStrikeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: AppMotion.move,
    value: widget.struck ? 1 : 0,
  );

  @override
  void didUpdateWidget(AnimatedStrikeText old) {
    super.didUpdateWidget(old);
    if (old.struck == widget.struck) return;
    final scale = motionScale(context);
    if (widget.struck) {
      _run.duration = AppMotion.move * scale;
      _run.forward();
    } else {
      _run.reverseDuration = AppMotion.exit * scale;
      _run.reverse();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return AnimatedBuilder(
      animation: _run,
      builder: (context, _) {
        final t = AppMotion.moveCurve.transform(_run.value);
        final style = base.copyWith(color: Color.lerp(base.color, widget.struckColor, t));
        return CustomPaint(
          foregroundPainter: t == 0
              ? null
              : _StrikePainter(
                  text: widget.text,
                  style: style,
                  scaler: scaler,
                  direction: direction,
                  progress: t,
                  color: widget.struckColor,
                  maxLines: widget.maxLines,
                ),
          child: Text(
            widget.text,
            style: style,
            maxLines: widget.maxLines,
            overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

class _StrikePainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final double progress;
  final Color color;
  final int? maxLines;

  _StrikePainter({
    required this.text,
    required this.style,
    required this.scaler,
    required this.direction,
    required this.progress,
    required this.color,
    required this.maxLines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Laid out the same way the Text below is, to find where each line sits
    final layout = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '\u2026',
    )..layout(maxWidth: size.width);
    final lines = layout.computeLineMetrics();
    layout.dispose();

    final total = lines.fold(0.0, (sum, l) => sum + l.width);
    var remaining = total * progress;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (final line in lines) {
      if (remaining <= 0) break;
      final length = remaining.clamp(0.0, line.width);
      // Through the middle of the lower-case letters, not the full height
      final y = line.baseline - line.ascent * 0.32;
      canvas.drawLine(Offset(line.left, y), Offset(line.left + length, y), paint);
      remaining -= line.width;
    }
  }

  @override
  bool shouldRepaint(_StrikePainter old) =>
      old.progress != progress || old.text != text || old.style != style || old.color != color;
}
