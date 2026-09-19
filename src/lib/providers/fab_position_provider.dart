import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Where each floating add button sits, as a fraction of the free area rather
// than pixels: the same phone in landscape, a tablet and a desktop window all
// read the same stored value without the button ending up off screen.
//
// Device-local like the notification settings and the completion effect: it is
// about how this device is held, not about the account.
const Offset kFabHomeRight = Offset(1, 1);
const Offset kFabHomeLeft = Offset(0, 1);

class FabPositionNotifier extends StateNotifier<Offset> {
  final String prefsKey;

  FabPositionNotifier(this.prefsKey, Offset home) : super(home) {
    _restore();
  }

  static Offset _clamp(Offset o) =>
      Offset(o.dx.clamp(0.0, 1.0), o.dy.clamp(0.0, 1.0));

  static String encode(Offset o) => '${o.dx},${o.dy}';

  // A value this build cannot read means "never moved", not a crash
  static Offset? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final dx = double.tryParse(parts[0]);
    final dy = double.tryParse(parts[1]);
    if (dx == null || dy == null) return null;
    return _clamp(Offset(dx, dy));
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = decode(prefs.getString(prefsKey));
    if (stored != null) state = stored;
  }

  Future<void> set(Offset fraction) async {
    state = _clamp(fraction);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, encode(state));
  }
}

// Keyed by which button it is, so the two of them are stored apart
final fabPositionProvider =
    StateNotifierProvider.family<FabPositionNotifier, Offset, String>(
  (ref, key) => FabPositionNotifier(
    'fab_pos_$key',
    key == 'inspiration' ? kFabHomeLeft : kFabHomeRight,
  ),
);
