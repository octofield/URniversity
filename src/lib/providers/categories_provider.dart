import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/future_goal.dart';

class CategoriesNotifier extends StateNotifier<List<String>> {
  CategoriesNotifier() : super([...FutureCategories.builtIns]);

  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;

  bool isBuiltIn(String cat) => FutureCategories.builtIns.contains(cat);

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    try {
      final rows = await _db
          .from('user_categories')
          .select('ordered_list')
          .eq('user_id', userId)
          .maybeSingle();
      if (rows != null) {
        state = (rows['ordered_list'] as List<dynamic>).cast<String>();
      }
    } catch (_) {
      _userId = null;
    }
  }

  void reset() {
    _userId = null;
    state = [...FutureCategories.builtIns];
  }

  void _persist() {
    if (_userId == null) return;
    _db.from('user_categories').upsert(
      {'user_id': _userId, 'ordered_list': state},
      onConflict: 'user_id',
    ).catchError((_) {});
  }

  void add(String cat) {
    if (cat.isNotEmpty && !state.contains(cat)) {
      state = [...state, cat];
      _persist();
    }
  }

  void remove(String cat) {
    if (!isBuiltIn(cat)) {
      state = state.where((c) => c != cat).toList();
      _persist();
    }
  }

  void reorder(int oldIndex, int newIndex) {
    final list = [...state];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    _persist();
  }
}

final categoriesProvider = StateNotifierProvider<CategoriesNotifier, List<String>>(
  (ref) => CategoriesNotifier(),
);
