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
          .from('users')
          .select('username, school, department, grade, grade_set_year')
          .eq('id', userId)
          .maybeSingle();
      state = row != null ? UserProfile.fromRow(row) : null;
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

  Future<void> updateUsername(String username) async {
    if (_userId == null) return;
    state = (state ?? const UserProfile()).copyWith(username: username);
    if (_isGuest) {
      _persistLocally();
      return;
    }
    await _db
        .from('users')
        .upsert({'id': _userId, 'username': username})
        .catchError((_) {});
  }

  Future<void> updateInfo({
    required String username,
    required String school,
    required String department,
    required int? grade,
    required int? gradeSetYear,
  }) async {
    if (_userId == null) return;
    final updated = UserProfile(
      username: username.isEmpty ? null : username,
      school: school.isEmpty ? null : school,
      department: department.isEmpty ? null : department,
      grade: grade,
      gradeSetYear: gradeSetYear,
    );
    state = updated;
    if (_isGuest) {
      _persistLocally();
      return;
    }
    await _db
        .from('users')
        .upsert(updated.toRow(_userId!))
        .catchError((_) {});
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile?>(
  (ref) => ProfileNotifier(),
);
