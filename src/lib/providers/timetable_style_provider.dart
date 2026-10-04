import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sort_prefs.dart';

// How the week is drawn (system_design.md §3-S, 2026-10-04), picked in the
// timetable's app bar. The same courses, the same colours; only the drawing:
// standard — tinted blocks with a coloured edge on a light grid (the original)
// solid     — blocks filled with the course colour, no grid lines
// outline   — white cards outlined in the course colour, dashed hour lines
// paper     — a ruled table like a printed timetable, text centred
// agenda    — not a grid: a day at a time, its classes down a time line
enum TimetableStyle { standard, solid, outline, paper, agenda }

// Remembered on the device (D39 timetable_style) and, signed in, with the
// account (user_settings.timetable_style)
final timetableStyleProvider = StateNotifierProvider<EnumPrefNotifier<TimetableStyle>, TimetableStyle>(
  (ref) => EnumPrefNotifier('timetable_style', TimetableStyle.values, TimetableStyle.standard),
);

// Stored as the enum's name; a name this build does not know is the original
TimetableStyle timetableStyleFromName(String? name) =>
    TimetableStyle.values.where((s) => s.name == name).firstOrNull ?? TimetableStyle.standard;
