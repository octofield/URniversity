import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';
import 'today_screen.dart' show TodayScreen, showAddTaskSheet, showAddInspirationSheet;
import 'semester_screen.dart';
import 'semester_goal_detail_screen.dart' show showAddSemesterGoalSheet;
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
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              TodayScreen(),
              SemesterScreen(),
              FutureScreen(),
            ],
          ),
          if (_index == 0)
            Positioned(
              left: 16,
              bottom: 16,
              child: Material(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(24),
                elevation: 3,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => showAddInspirationSheet(context, ref),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.cloud_outlined, size: 34, color: AppColors.primary),
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.lightbulb_outline, size: 17, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
