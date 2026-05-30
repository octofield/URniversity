import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class ProfileNotifier extends StateNotifier<UserProfile?> {
  ProfileNotifier() : super(null);

  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;
  static const _localKey = 'guest_profile';
  bool get _isGuest => _userId == 'guest';

  Future<void> load(String userId) async {
    _userId = userId;
    try {
      final row = await _db
          .from('user_settings')
          .select('username, school, department, grade, grade_set_year, avatar_index')
          .eq('user_id', userId)
          .maybeSingle();
      // null state = not loaded; const UserProfile() = loaded but no DB row (new user)
      state = row != null ? UserProfile.fromRow(row) : const UserProfile();
    } catch (_) {}
  }

  Future<void> loadGuest() async {
    _userId = 'guest';
    final p = await SharedPreferences.getInstance();
    final json = p.getString(_localKey);
    state = json != null
        ? UserProfile.fromRow(jsonDecode(json) as Map<String, dynamic>)
        : const UserProfile();
  }

  void _persistLocally() {
    if (state == null) return;
    SharedPreferences.getInstance().then((p) {
      p.setString(_localKey, jsonEncode(state!.toRow('guest')));
    });
  }

  void clear() {
    _userId = null;
    state = null;
  }

  Future<void> mergeToUser(String userId) async {
    _userId = userId;
    if (state != null) {
      try {
        await _db.from('user_settings').upsert(state!.toRow(userId));
      } catch (_) {}
    }
  }

  Future<void> updateUsername(String username) async {
    if (_userId == null) return;
    state = (state ?? const UserProfile()).copyWith(username: username);
    if (_isGuest) {
      _persistLocally();
      return;
    }
    await _db
        .from('user_settings')
        .upsert({'user_id': _userId, 'username': username})
        .catchError((_) {});
  }

  // Called from SetupProfileScreen — only sets username and avatar, preserves rest.
  Future<void> setupProfile(String username, int? avatarIndex) async {
    if (_userId == null) return;
    state = UserProfile(
      username: username.isNotEmpty ? username : null,
      school: state?.school,
      department: state?.department,
      grade: state?.grade,
      gradeSetYear: state?.gradeSetYear,
      avatarIndex: avatarIndex,
    );
    if (_isGuest) {
      _persistLocally();
      return;
    }
    await _db.from('user_settings').upsert({
      'user_id': _userId,
      'username': username.isNotEmpty ? username : null,
      'avatar_index': avatarIndex,
    }).catchError((_) {});
  }

  Future<void> updateInfo({
    required String username,
    required String school,
    required String department,
    required int? grade,
    required int? gradeSetYear,
    required int? avatarIndex,
  }) async {
    if (_userId == null) return;
    final updated = UserProfile(
      username: username.isEmpty ? null : username,
      school: school.isEmpty ? null : school,
      department: department.isEmpty ? null : department,
      grade: grade,
      gradeSetYear: gradeSetYear,
      avatarIndex: avatarIndex,
    );
    state = updated;
    if (_isGuest) {
      _persistLocally();
      return;
    }
    await _db
        .from('user_settings')
        .upsert(updated.toRow(_userId!))
        .catchError((_) {});
  }

  Future<void> deleteAllData(String userId) async {
    final tables = ['tasks', 'future_goals', 'semester_goals', 'inspirations',
        'journals', 'trash_items', 'user_categories'];
    for (final table in tables) {
      try {
        await _db.from(table).delete().eq('user_id', userId);
      } catch (_) {}
    }
    try {
      await _db.from('user_settings').delete().eq('user_id', userId);
    } catch (_) {}
    clear();
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile?>(
  (ref) => ProfileNotifier(),
);
