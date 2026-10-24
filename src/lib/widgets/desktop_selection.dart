import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show Selectable, SelectionRegistrar;

// On a computer, any text in the app can be selected with the mouse and copied
// (Ctrl+C, or the right-click menu) — 2026-10-24, system_design.md §3-F.
// Phones are left alone: there a long press already drags rows around and a
// drag pulls pages closed. A browser on a computer reports the computer's own
// platform, so the web build on a laptop selects too, the one on a phone not
bool selectsWithMouse(TargetPlatform platform) =>
    platform == TargetPlatform.windows || platform == TargetPlatform.macOS || platform == TargetPlatform.linux;

// The devices a page's own drags answer to: pulling a page closed, swiping
// it back or across. On a computer a mouse drag selects text instead, as it
// does everywhere else on a computer; buttons do those jobs there. Null is
// every device
Set<PointerDeviceKind>? pageDragDevices() => selectsWithMouse(defaultTargetPlatform)
    ? {for (final kind in PointerDeviceKind.values) if (kind != PointerDeviceKind.mouse) kind}
    : null;

class DesktopSelection extends StatefulWidget {
  final Widget child;

  const DesktopSelection({super.key, required this.child});

  @override
  State<DesktopSelection> createState() => _DesktopSelectionState();
}

class _DesktopSelectionState extends State<DesktopSelection> {
  // The selection's handles and right-click menu are drawn in an Overlay, and
  // this sits above the Navigator's own; so it brings one. The entry is kept
  // and rebuilt with the page under it, never made again
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => SelectionArea(child: widget.child));

  @override
  void didUpdateWidget(DesktopSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    // Never inserted on a phone
    if (_entry.mounted) _entry.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!selectsWithMouse(defaultTargetPlatform)) return widget.child;
    return Overlay(initialEntries: [_entry]);
  }
}

// A tab kept alive but not showing (HomeScreen's IndexedStack) still lays its
// text out where the shown tab is; left in the selection, a drag over the task
// list ended up in a hidden tab and copied nothing. A hidden tab hands its
// text to a registrar that keeps none. The same widget either way, so
// switching tabs never rebuilds a tab's state, only what its text registers with
class TabSelectionScope extends StatelessWidget {
  final bool showing;
  final Widget child;

  const TabSelectionScope({super.key, required this.showing, required this.child});

  @override
  Widget build(BuildContext context) {
    final registrar = SelectionContainer.maybeOf(context);
    if (registrar == null) return child;
    return SelectionRegistrarScope(registrar: showing ? registrar : const _NoSelection(), child: child);
  }
}

class _NoSelection implements SelectionRegistrar {
  const _NoSelection();

  @override
  void add(Selectable selectable) {}

  @override
  void remove(Selectable selectable) {}
}
