import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inspiration.dart';

class InspirationsNotifier extends StateNotifier<List<Inspiration>> {
  InspirationsNotifier() : super([]);

  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;
  static const _localKey = 'guest_inspirations';
  bool get _isGuest => _userId == 'guest';

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    try {
      final rows = await _db
          .from('inspirations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      state = (rows as List<dynamic>)
          .map((r) => Inspiration.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _userId = null;
    }
  }

  Future<void> loadGuest() async {
    _userId = 'guest';
    final p = await SharedPreferences.getInstance();
    final json = p.getString(_localKey);
    if (json != null) {
      state = (jsonDecode(json) as List)
          .map((j) => Inspiration.fromJson(j as Map<String, dynamic>))
          .toList();
    } else {
      state = [];
    }
  }

  void _persistLocally() {
    SharedPreferences.getInstance().then((p) {
      p.setString(_localKey, jsonEncode(state.map((i) => i.toJson()).toList()));
    });
  }

  void clear() {
    _userId = null;
    state = [];
  }

  void add(String title, {String? content}) {
    final item = Inspiration(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: DateTime.now(),
    );
    state = [item, ...state];
    if (_isGuest) {
      _persistLocally();
    } else if (_userId != null) {
      _db.from('inspirations')
          .upsert({...item.toJson(), 'user_id': _userId})
          .catchError((_) {});
    }
  }

  void update(Inspiration updated) {
    state = [
      for (final i in state)
        if (i.id == updated.id) updated else i,
    ];
    if (_isGuest) {
      _persistLocally();
    } else if (_userId != null) {
      _db.from('inspirations')
          .upsert({...updated.toJson(), 'user_id': _userId})
          .catchError((_) {});
    }
  }

  void toggleCompleted(String id) {
    final item = state.firstWhere((i) => i.id == id);
    update(item.copyWith(isCompleted: !item.isCompleted));
  }

  void remove(String id) {
    state = state.where((i) => i.id != id).toList();
    if (_isGuest) {
      _persistLocally();
    } else if (_userId != null) {
      _db.from('inspirations').delete().eq('id', id).catchError((_) {});
    }
  }
}

final inspirationsProvider =
    StateNotifierProvider<InspirationsNotifier, List<Inspiration>>(
  (ref) => InspirationsNotifier(),
);
