import 'package:flutter/material.dart';
import '../core/theme/app_motion.dart';

// Text whose change is seen: the new value rises into place as the old one
// rises out, like a counter turning over. For headings that carry a count
// ("Tasks (3)"), so ticking one off visibly moves the number
class FlipText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const FlipText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: scaled(context, AppMotion.move),
      switchInCurve: AppMotion.enterCurve,
      switchOutCurve: AppMotion.exitCurve,
      // Left-aligned and sized to the incoming text, so a heading does not
      // shuffle sideways while the two overlap
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(text);
        final offset = Tween<Offset>(
          begin: Offset(0, incoming ? 0.5 : -0.5),
          end: Offset.zero,
        ).animate(animation);
        return ClipRect(
          child: SlideTransition(
            position: offset,
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}
