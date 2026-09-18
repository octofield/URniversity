import 'package:flutter/material.dart';

// The colour stripe down the left edge of a task or goal row.
//
// Split top/bottom when a row carries two links of different colours — a task
// linked to both a target and a vision, or a target linked to a vision. Seeing
// two colours is what says "this belongs to something else as well"; one colour
// would leave the link invisible from the list.
class LinkColorBar extends StatelessWidget {
  final Color? top;
  final Color? bottom;
  final double width;

  const LinkColorBar({super.key, this.top, this.bottom, this.width = 6});

  @override
  Widget build(BuildContext context) {
    // Always reserve the width, so linked and unlinked rows stay aligned
    if (top == null && bottom == null) return SizedBox(width: width);
    if (bottom == null) return Container(width: width, color: top);
    if (top == null) return Container(width: width, color: bottom);
    if (top!.toARGB32() == bottom!.toARGB32()) {
      return Container(width: width, color: top);
    }
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Expanded(child: Container(color: top)),
          Expanded(child: Container(color: bottom)),
        ],
      ),
    );
  }
}
