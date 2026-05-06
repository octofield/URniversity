import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspiration.dart';

class InspirationsNotifier extends StateNotifier<List<Inspiration>> {
  InspirationsNotifier() : super([]);

  void add(String title, {String? content}) {
    state = [
      ...state,
      Inspiration(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        createdAt: DateTime.now(),
      ),
    ];
  }

  void remove(String id) {
    state = state.where((i) => i.id != id).toList();
  }
}

final inspirationsProvider =
    StateNotifierProvider<InspirationsNotifier, List<Inspiration>>(
  (ref) => InspirationsNotifier(),
);
