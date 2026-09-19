import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/fab_position_provider.dart';

// A floating add button the user can drag anywhere on the page.
//
// The two buttons sat in opposite bottom corners, which is where they covered
// whatever the user was reading. Where they belong depends on the hand holding
// the phone, so it is theirs to decide; the position is remembered per device
// (see fabPositionProvider).
class DraggableFab extends ConsumerStatefulWidget {
  // Which button this is: also the storage key ('main', 'inspiration')
  final String storageKey;
  final Widget child;

  const DraggableFab({
    super.key,
    required this.storageKey,
    required this.child,
  });

  static const double size = 64;
  static const double margin = 16;

  @override
  ConsumerState<DraggableFab> createState() => _DraggableFabState();
}

class _DraggableFabState extends ConsumerState<DraggableFab> {
  // Set while a drag is in flight, so the stored value is written once at the
  // end rather than on every frame
  Offset? _dragging;

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(fabPositionProvider(widget.storageKey));
    final fraction = _dragging ?? stored;

    // Fills the page so the fraction has something to be a fraction of. A Stack
    // only hit-tests its actual children, so this does not swallow taps meant
    // for the page underneath
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final span = Size(
            (constraints.maxWidth - DraggableFab.size - DraggableFab.margin * 2)
                .clamp(0.0, double.infinity),
            (constraints.maxHeight - DraggableFab.size - DraggableFab.margin * 2)
                .clamp(0.0, double.infinity),
          );

          return Stack(
            children: [
              Positioned(
                left: DraggableFab.margin + fraction.dx * span.width,
                top: DraggableFab.margin + fraction.dy * span.height,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (span.width == 0 || span.height == 0) return;
                    setState(() {
                      _dragging = Offset(
                        (fraction.dx + details.delta.dx / span.width).clamp(0.0, 1.0),
                        (fraction.dy + details.delta.dy / span.height).clamp(0.0, 1.0),
                      );
                    });
                  },
                  onPanEnd: (_) {
                    final moved = _dragging;
                    setState(() => _dragging = null);
                    if (moved != null) {
                      ref
                          .read(fabPositionProvider(widget.storageKey).notifier)
                          .set(moved);
                    }
                  },
                  child: widget.child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
