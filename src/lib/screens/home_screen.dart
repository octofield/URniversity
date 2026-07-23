import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';
import '../providers/date_provider.dart';
import 'today_screen.dart' show TodayScreen, showAddTaskSheet, showAddInspirationSheet;

import 'semester_screen.dart';
import 'semester_goal_detail_screen.dart' show showAddSemesterGoalSheet;
import 'future_screen.dart';
import 'me_screen.dart';
import 'journal_edit_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  void _onDestinationSelected(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.desktop;

    // When dev mode changes the effective date, sync the task-date calendar
    ref.listen<DateTime>(effectiveNowProvider, (_, next) {
      ref.read(dateProvider.notifier).goToToday(next);
    });

    // Shared destination data for both NavigationBar and NavigationRail
    final destinations = [
      (icon: Icons.today_outlined, selectedIcon: Icons.today, label: s.tasks),
      (icon: Icons.school_outlined, selectedIcon: Icons.school, label: s.targets),
      (icon: Icons.flag_outlined, selectedIcon: Icons.flag, label: s.goals),
      (icon: Icons.person_outlined, selectedIcon: Icons.person, label: s.me),
    ];

    final body = Stack(
      children: [
        // Top gradient so the page background is not one flat color
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 320,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.30),
                    AppColors.primaryLight,
                    AppColors.background,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
        IndexedStack(
          index: _index,
          children: const [
            TodayScreen(),
            SemesterScreen(),
            FutureScreen(),
            MeScreen(),
          ],
        ),
        if (_index < 3)
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
    );

    final floatingActionButton = switch (_index) {
      0 => _VividFab(
          color: AppColors.categoryCompetition,
          icon: Icons.add,
          tooltip: s.addTask,
          onPressed: () => showAddTaskSheet(context, ref)),
      1 => _VividFab(
          color: AppColors.categoryIntern,
          icon: Icons.add,
          tooltip: s.addTarget,
          onPressed: () => showAddSemesterGoalSheet(context, ref)),
      2 => _VividFab(
          color: AppColors.categoryCert,
          icon: Icons.add,
          tooltip: s.addGoal,
          onPressed: () => showAddFutureGoalSheet(context, ref)),
      3 => _VividFab(
          color: AppColors.categoryPerformance,
          icon: Icons.edit_note,
          tooltip: s.addJournal,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const JournalEditScreen()),
          )),
      _ => null,
    };

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _onDestinationSelected,
              extended: width >= AppBreakpoints.wide,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon, color: AppColors.primary),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon, color: AppColors.primary),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

// Larger, colorful floating action button with a hover glow on desktop
class _VividFab extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _VividFab({
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_VividFab> createState() => _VividFabState();
}

class _VividFabState extends State<_VividFab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _hovered ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(widget.color, Colors.white, 0.18)!,
                    widget.color,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: _hovered ? 0.55 : 0.35),
                    blurRadius: _hovered ? 26 : 14,
                    offset: Offset(0, _hovered ? 10 : 6),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}
