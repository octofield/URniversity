import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../core/theme/app_motion.dart';

// Changing style dissolves the old look into the new one instead of every
// colour jumping at once (system_design.md §3-R). The last frame of the old
// style is snapshotted, laid over the rebuilt app, and faded out
class StyleCrossfade extends StatefulWidget {
  final Widget child;

  const StyleCrossfade({super.key, required this.child});

  @override
  State<StyleCrossfade> createState() => StyleCrossfadeState();
}

class StyleCrossfadeState extends State<StyleCrossfade> with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  ui.Image? _before;
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    // Made here, not lazily: a lazy one would first be created in dispose()
    _fade = AnimationController(vsync: this, duration: AppMotion.page)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _clear();
      });
  }

  // Call just before the new style is applied, while the screen still shows
  // the old one. With the system asking for no motion it simply switches
  void snapshot() {
    if (motionScale(context) == 0) return;
    final boundary = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    // Nothing laid out yet (first frame) means nothing to fade from
    if (boundary == null || !boundary.attached || !boundary.hasSize) return;
    _clear();
    setState(() => _before = boundary.toImageSync(pixelRatio: MediaQuery.devicePixelRatioOf(context)));
    _fade.forward(from: 0);
  }

  void _clear() {
    final image = _before;
    if (image == null) return;
    if (mounted) setState(() => _before = null);
    image.dispose();
  }

  @override
  void dispose() {
    _fade.dispose();
    _before?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final before = _before;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (before != null)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: ReverseAnimation(CurvedAnimation(parent: _fade, curve: AppMotion.moveCurve)),
                child: RawImage(image: before, fit: BoxFit.fill),
              ),
            ),
          ),
      ],
    );
  }
}
