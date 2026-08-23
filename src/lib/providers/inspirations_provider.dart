import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inspiration.dart';
import 'synced_list_notifier.dart';

class InspirationsNotifier extends SyncedListNotifier<Inspiration> {
  InspirationsNotifier(super.ref)
      : super(
          table: 'inspirations',
          localKey: 'guest_inspirations',
          orderColumn: 'created_at',
          orderAscending: false,
        );

  @override
  Inspiration fromJson(Map<String, dynamic> json) => Inspiration.fromJson(json);

  @override
  Map<String, dynamic> toJson(Inspiration item) => item.toJson();

  @override
  String idOf(Inspiration item) => item.id;

  void add(String title, {String? content}) {
    final item = Inspiration(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: DateTime.now(),
    );
    state = [item, ...state];
    upsert(item);
  }

  void update(Inspiration updated) {
    state = [
      for (final i in state)
        if (i.id == updated.id) updated else i,
    ];
    upsert(updated);
  }

  void toggleCompleted(String id) {
    final item = state.firstWhere((i) => i.id == id);
    update(item.copyWith(isCompleted: !item.isCompleted));
  }

  void remove(String id) {
    state = state.where((i) => i.id != id).toList();
    deleteRow(id);
  }
}

final inspirationsProvider =
    StateNotifierProvider<InspirationsNotifier, List<Inspiration>>(
  (ref) => InspirationsNotifier(ref),
);
