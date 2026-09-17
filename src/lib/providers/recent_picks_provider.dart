import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/recent_picks.dart';

// The targets and due times this device has used lately, so the task sheet can
// offer them as one-tap chips (D16).
//
// Device-local on purpose: it is a convenience built from what was done on this
// phone, not data worth syncing, and a guest gets it without an account.
class RecentPicks {
  final List<String> targetIds;
  final List<String> times;

  const RecentPicks({this.targetIds = const [], this.times = const []});

  static const empty = RecentPicks();

  RecentPicks copyWith({List<String>? targetIds, List<String>? times}) =>
      RecentPicks(targetIds: targetIds ?? this.targetIds, times: times ?? this.times);

  Map<String, dynamic> toJson() => {'targets': targetIds, 'times': times};

  static RecentPicks fromJson(Map<String, dynamic> json) => RecentPicks(
        targetIds: (json['targets'] as List?)?.cast<String>() ?? const [],
        times: (json['times'] as List?)?.cast<String>() ?? const [],
      );
}

class RecentPicksNotifier extends StateNotifier<RecentPicks> {
  RecentPicksNotifier() : super(RecentPicks.empty) {
    _restore();
  }

  static const prefsKey = 'recent_picks';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null) return;
    try {
      state = RecentPicks.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // A parse fallback, not a swallowed write: losing the suggestions is not
      // worth failing over
      debugPrint('[recent] could not read the stored picks: $e');
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(state.toJson()));
  }

  // Called wherever a target is actually used: linking a task to it, and adding
  // or editing the goal itself
  Future<void> rememberTarget(String? targetId) async {
    if (targetId == null) return;
    state = state.copyWith(targetIds: withRecentPick(state.targetIds, targetId));
    await _save();
  }

  Future<void> rememberTime(DateTime? dueTime) async {
    if (dueTime == null) return;
    state = state.copyWith(times: withRecentPick(state.times, formatClock(dueTime)));
    await _save();
  }
}

final recentPicksProvider =
    StateNotifierProvider<RecentPicksNotifier, RecentPicks>((ref) => RecentPicksNotifier());
