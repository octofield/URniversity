import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/future_goal.dart';

class CategoriesNotifier extends StateNotifier<List<String>> {
  CategoriesNotifier() : super([...FutureCategories.builtIns]);

  bool isBuiltIn(String cat) => FutureCategories.builtIns.contains(cat);

  void add(String cat) {
    if (cat.isNotEmpty && !state.contains(cat)) state = [...state, cat];
  }

  void remove(String cat) {
    if (!isBuiltIn(cat)) state = state.where((c) => c != cat).toList();
  }

  void reorder(int oldIndex, int newIndex) {
    final list = [...state];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
  }
}

final categoriesProvider = StateNotifierProvider<CategoriesNotifier, List<String>>(
  (ref) => CategoriesNotifier(),
);
