import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

// GPA semester by semester (UC20): enough to see the trend, nothing more. The
// scale is fixed to 0–4.3 with a line at every whole point, so two charts can
// be compared by eye
class GpaTrendChart extends StatelessWidget {
  final List<(String label, double gpa)> points;

  const GpaTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary);
    return SizedBox(
      height: 150,
      child: CustomPaint(
        painter: _TrendPainter(
          points: points,
          line: AppColors.primary,
          grid: AppColors.border,
          labelStyle: style ?? const TextStyle(),
          direction: Directionality.of(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<(String, double)> points;
  final Color line;
  final Color grid;
  final TextStyle labelStyle;
  final TextDirection direction;

  _TrendPainter({
    required this.points,
    required this.line,
    required this.grid,
    required this.labelStyle,
    required this.direction,
  });

  static const _max = 4.3;
  static const _left = 28.0;
  static const _bottom = 18.0;

  void _text(Canvas canvas, String text, Offset at, {bool centre = false}) {
    final p = TextPainter(text: TextSpan(text: text, style: labelStyle), textDirection: direction)..layout();
    p.paint(canvas, centre ? at - Offset(p.width / 2, 0) : at - Offset(0, p.height / 2));
    p.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(_left, 6, size.width - 8, size.height - _bottom);
    double yOf(double gpa) => plot.bottom - gpa / _max * plot.height;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var g = 0; g <= 4; g++) {
      canvas.drawLine(Offset(plot.left, yOf(g.toDouble())), Offset(plot.right, yOf(g.toDouble())), gridPaint);
      _text(canvas, '$g', Offset(0, yOf(g.toDouble())));
    }
    if (points.isEmpty) return;

    final step = points.length == 1 ? 0.0 : plot.width / (points.length - 1);
    Offset at(int i) => Offset(points.length == 1 ? plot.center.dx : plot.left + step * i, yOf(points[i].$2));

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = line;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(at(i), 4, dot);
      _text(canvas, points[i].$1, Offset(at(i).dx, plot.bottom + 4), centre: true);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.points != points || old.line != line;
}
