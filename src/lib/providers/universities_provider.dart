import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/taiwan_universities.dart';

class UniversitiesState {
  final List<String> universities;
  final Map<String, List<String>> universityDepts;

  const UniversitiesState({
    required this.universities,
    required this.universityDepts,
  });

  List<String> departmentsFor(String school) {
    if (school.isNotEmpty) {
      return universityDepts[school] ?? [];
    }
    return universityDepts.values.expand((d) => d).toSet().toList()..sort();
  }
}

class UniversitiesNotifier extends StateNotifier<UniversitiesState> {
  UniversitiesNotifier() : super(UniversitiesState(
    universities: taiwanUniversities,
    universityDepts: universityDepartments,
  )) {
    _load();
  }

  static const _uniKey  = 'universities_v3';
  static const _timeKey = 'universities_cache_time_v3';
  static const _ttlMs   = 86400000; // 24 hours

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedTime = prefs.getInt(_timeKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - cachedTime;
    if (age < _ttlMs) {
      final uniJson = prefs.getString(_uniKey);
      if (uniJson != null) {
        state = UniversitiesState(
          universities: List<String>.from(jsonDecode(uniJson) as List),
          universityDepts: universityDepartments,
        );
        return;
      }
    }

    try {
      // Only fetch university names from Supabase (small list, no truncation risk).
      // Departments (5000+ rows) always use the hardcoded map compiled into the binary.
      final uniRows = await Supabase.instance.client
          .from('universities')
          .select('name')
          .order('sort_order');

      final unis = (uniRows as List).map((r) => r['name'] as String).toList();

      if (unis.isNotEmpty) {
        await prefs.setString(_uniKey, jsonEncode(unis));
        await prefs.setInt(_timeKey, DateTime.now().millisecondsSinceEpoch);
        state = UniversitiesState(universities: unis, universityDepts: universityDepartments);
      }
    } catch (_) {
      // Network error: keep hardcoded fallback
    }
  }
}

final universitiesProvider =
    StateNotifierProvider<UniversitiesNotifier, UniversitiesState>(
  (ref) => UniversitiesNotifier(),
);
