import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course.dart';
import '../utils/category_helpers.dart' show categoryColorPresets;
import 'synced_list_notifier.dart';

// The courses (D27). Each row carries its own weekly meetings, so adding,
// editing and deleting a course is always one write
class CoursesNotifier extends SyncedListNotifier<Course> {
  CoursesNotifier(super.ref)
      : super(table: 'courses', localKey: 'guest_courses', orderColumn: 'created_at');

  @override
  Course fromJson(Map<String, dynamic> json) => Course.fromJson(json);

  @override
  Map<String, dynamic> toJson(Course item) => item.toJson();

  @override
  String idOf(Course item) => item.id;

  // A colour not yet taken this semester, so two courses side by side on the
  // grid are told apart; cycles once all are used
  int nextColor(String semester) {
    final used = {for (final c in state) if (c.semester == semester) c.color};
    final free = categoryColorPresets.where((c) => !used.contains(c.toARGB32())).firstOrNull;
    return (free ?? categoryColorPresets[used.length % categoryColorPresets.length]).toARGB32();
  }

  Course add({
    required String semester,
    required String title,
    String? teacher,
    String? courseCode,
    String? serialNo,
    double credits = 0,
    int? color,
    String? catalogId,
    List<CourseSession> sessions = const [],
  }) {
    final course = Course(
      id: newRowId(),
      semester: semester,
      title: title,
      teacher: teacher,
      courseCode: courseCode,
      serialNo: serialNo,
      credits: credits,
      color: color ?? nextColor(semester),
      catalogId: catalogId,
      sessions: sessions,
      createdAt: DateTime.now(),
    );
    state = [...state, course];
    upsert(course);
    return course;
  }

  void update(Course course) {
    state = [for (final c in state) if (c.id == course.id) course else c];
    upsert(course);
  }

  // Returns what was removed, for the trash
  Course? remove(String id) {
    final gone = state.where((c) => c.id == id).firstOrNull;
    if (gone == null) return null;
    state = state.where((c) => c.id != id).toList();
    deleteRow(id);
    return gone;
  }
}

final coursesProvider = StateNotifierProvider<CoursesNotifier, List<Course>>(
  (ref) => CoursesNotifier(ref),
);

// ── The first day of classes, per semester ────────────────────────────────────
//
// Decides "week 5" on the timetable and when class reminders run. Asked once
// per semester (NTU's academic calendar cannot be read automatically), kept on
// the device (term_starts, D30) and, for an account, in user_settings.term_starts
// (D8-B) — read and written by sync_provider on their own, like the app style
class TermInfo {
  final DateTime firstDay;
  // Teaching weeks; reminders stop after the last one
  final int weeks;

  const TermInfo(this.firstDay, [this.weeks = defaultWeeks]);

  static const defaultWeeks = 16;

  factory TermInfo.fromJson(Map<String, dynamic> j) => TermInfo(
        DateTime.parse(j['first_day'] as String),
        (j['weeks'] as num?)?.toInt() ?? defaultWeeks,
      );

  Map<String, dynamic> toJson() => {
        'first_day':
            '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}',
        'weeks': weeks,
      };
}

Map<String, TermInfo> decodeTerms(Object? raw) {
  if (raw is String) raw = jsonDecode(raw);
  if (raw is! Map) return {};
  final out = <String, TermInfo>{};
  for (final e in raw.entries) {
    try {
      out[e.key as String] = TermInfo.fromJson((e.value as Map).cast<String, dynamic>());
    } catch (e) {
      // Parse fallback: an entry this build cannot read is dropped, and the
      // timetable simply asks for that semester again
      debugPrint('[terms] unreadable entry skipped - $e');
    }
  }
  return out;
}

String encodeTerms(Map<String, TermInfo> terms) =>
    jsonEncode({for (final e in terms.entries) e.key: e.value.toJson()});

class TermsNotifier extends StateNotifier<Map<String, TermInfo>> {
  static const key = 'term_starts';

  TermsNotifier(this.ref) : super(const {}) {
    _restore();
  }

  final Ref ref;

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final stored = decodeTerms(p.getString(key));
    // Only if nothing was set meanwhile: a set() must not be undone by a
    // restore that finishes after it
    if (state.isEmpty) state = stored;
  }

  Future<void> set(String semester, TermInfo info) async {
    state = {...state, semester: info};
    await _persist();
  }

  // What the account holds, read at sign-in; the device's own entries stay
  // for semesters the account has not got
  Future<void> merge(Map<String, TermInfo> fromCloud) async {
    state = {...state, ...fromCloud};
    await _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, encodeTerms(state));
  }
}

final termsProvider = StateNotifierProvider<TermsNotifier, Map<String, TermInfo>>(
  (ref) => TermsNotifier(ref),
);

// Loads the account's term starts; a missing column (supabase/courses.sql not
// run yet) is reported, not fatal
Future<Map<String, TermInfo>> fetchCloudTerms(String uid) async {
  final row = await Supabase.instance.client
      .from('user_settings')
      .select('term_starts')
      .eq('user_id', uid)
      .maybeSingle();
  return decodeTerms(row?['term_starts']);
}
