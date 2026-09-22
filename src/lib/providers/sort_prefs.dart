import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A list's sort choice, remembered on this device. One class for the tasks,
// targets and visions lists: they differ only in the enum and the key
class EnumPrefNotifier<E extends Enum> extends StateNotifier<E> {
  EnumPrefNotifier(this.prefsKey, this.values, this.fallback) : super(fallback) {
    _restore();
  }

  final String prefsKey;
  final List<E> values;
  final E fallback;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey);
    if (stored == null) return;
    // A value this build does not know falls back to the default
    state = values.where((e) => e.name == stored).firstOrNull ?? fallback;
  }

  Future<void> set(E value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, value.name);
  }
}
