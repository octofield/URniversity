import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomCategoriesNotifier extends StateNotifier<List<String>> {
  CustomCategoriesNotifier() : super([]);

  void add(String name) {
    if (name.isNotEmpty && !state.contains(name)) {
      state = [...state, name];
    }
  }

  void remove(String name) {
    state = state.where((c) => c != name).toList();
  }
}

final customCategoriesProvider =
    StateNotifierProvider<CustomCategoriesNotifier, List<String>>(
  (ref) => CustomCategoriesNotifier(),
);
