import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';
import 'today_screen.dart' show TodayScreen, showAddTaskSheet;
import 'semester_screen.dart';
import 'future_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          TodayScreen(),
          SemesterScreen(),
          FutureScreen(),
        ],
      ),
      floatingActionButton: switch (_index) {
        0 => FloatingActionButton(
            onPressed: () => showAddTaskSheet(context, ref),
            tooltip: s.addTask,
            child: const Icon(Icons.add)),
        1 => FloatingActionButton(
            onPressed: () => showAddSemesterGoalSheet(context, ref),
            child: const Icon(Icons.add)),
        2 => FloatingActionButton(
            onPressed: () => showAddFutureGoalSheet(context, ref),
            child: const Icon(Icons.add)),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today, color: AppColors.primary),
            label: s.tasks,
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school, color: AppColors.primary),
            label: s.targets,
          ),
          NavigationDestination(
            icon: const Icon(Icons.flag_outlined),
            selectedIcon: const Icon(Icons.flag, color: AppColors.primary),
            label: s.goals,
          ),
        ],
      ),
    );
  }
}
