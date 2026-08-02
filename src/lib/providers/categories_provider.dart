import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';
import '../models/future_goal.dart';
import '../utils/category_helpers.dart';

List<CategoryEntry> _defaultCategories() => [
  for (final id in FutureCategories.builtIns)
    CategoryEntry(id: id, color: defaultCatColor(id), icon: defaultCatIcon(id)),
];

class CategoriesNotifier extends StateNotifier<List<CategoryEntry>> {
  CategoriesNotifier() : super(_defaultCategories());

  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;

  bool isBuiltIn(String cat) => FutureCategories.builtIns.contains(cat);

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    try {
      final row = await _db
          .from('user_categories')
          .select('ordered_list, styles')
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null) {
        final ids = (row['ordered_list'] as List<dynamic>).cast<String>();
        final styles = (row['styles'] as Map<String, dynamic>?) ?? {};
        state = [
          for (final id in ids)
            styles[id] != null
                ? CategoryEntry.fromJson(id, styles[id] as Map<String, dynamic>)
                : CategoryEntry(id: id, color: defaultCatColor(id), icon: defaultCatIcon(id)),
        ];
      }
    } catch (_) {
      _userId = null;
    }
  }

  void reset() {
    _userId = null;
    state = _defaultCategories();
  }

  void _persist() {
    if (_userId == null) return;
    _db.from('user_categories').upsert(
      {
        'user_id': _userId,
        'ordered_list': [for (final c in state) c.id],
        'styles': {for (final c in state) c.id: c.toJson()},
      },
      onConflict: 'user_id',
    ).catchError((_) {});
  }

  void add(String name) {
    if (name.isNotEmpty && !state.any((c) => c.id == name)) {
      state = [
        ...state,
        CategoryEntry(id: name, color: defaultCatColor(name), icon: defaultCatIcon(name)),
      ];
      _persist();
    }
  }

  void remove(String cat) {
    if (!isBuiltIn(cat)) {
      state = state.where((c) => c.id != cat).toList();
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

  void updateStyle(String cat, {Color? color, IconData? icon}) {
    state = [
      for (final c in state)
        if (c.id == cat) c.copyWith(color: color, icon: icon) else c,
    ];
    _persist();
  }
}

final categoriesProvider = StateNotifierProvider<CategoriesNotifier, List<CategoryEntry>>(
  (ref) => CategoriesNotifier(),
);
