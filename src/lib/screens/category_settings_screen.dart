import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/categories_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/category_manager.dart';

class CategorySettingsScreen extends ConsumerWidget {
  const CategorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final cats = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.categorySettings)),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              itemCount: cats.length,
              onReorder: (o, n) =>
                  ref.read(categoriesProvider.notifier).reorder(o, n),
              itemBuilder: (tileCtx, i) => categoryManageTile(
                context: tileCtx,
                ref: ref,
                entry: cats[i],
                s: s,
              ),
            ),
          ),
          const Divider(height: 1),
          const CategoryAddRow(),
        ],
      ),
    );
  }
}
