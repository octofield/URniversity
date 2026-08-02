import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
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
        // Soft top gradient so the page background is not one flat color
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 180,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryLight, AppColors.background],
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
            child: _VividFab(
              color: AppColors.categoryExchange,
              tooltip: s.addInspiration,
              onPressed: () => showAddInspirationSheet(context, ref),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.cloud_outlined, size: 30, color: Colors.white),
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.lightbulb_outline, size: 15, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    final floatingActionButton = switch (_index) {
      0 => _VividFab(
          color: AppColors.categoryCompetition,
          tooltip: s.addTask,
          onPressed: () => showAddTaskSheet(context, ref),
          child: const Icon(Icons.add, color: Colors.white, size: 30)),
      1 => _VividFab(
          color: AppColors.categoryIntern,
          tooltip: s.addTarget,
          onPressed: () => showAddSemesterGoalSheet(context, ref),
          child: const Icon(Icons.add, color: Colors.white, size: 30)),
      2 => _VividFab(
          color: AppColors.categoryCert,
          tooltip: s.addGoal,
          onPressed: () => showAddFutureGoalSheet(context, ref),
          child: const Icon(Icons.add, color: Colors.white, size: 30)),
      3 => _VividFab(
          color: AppColors.categoryPerformance,
          tooltip: s.addJournal,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const JournalEditScreen()),
          ),
          child: const Icon(Icons.edit_note, color: Colors.white, size: 30)),
      _ => null,
    };

    if (isDesktop) {
      final extended = width >= AppBreakpoints.wide;
      // NavigationRail's own collapsed/extended widths (Material defaults it
      // falls back to since the theme doesn't override minWidth/minExtendedWidth)
      final railWidth = extended ? 256.0 : 72.0;

      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _onDestinationSelected,
              extended: extended,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon, color: AppColors.primary),
                    label: Text(d.label),
                  ),
              ],
              // Same divider as the mobile drawer — marks room for future
              // secondary features below the four main destinations.
              // NavigationRail centers trailing in an unbounded-width Column,
              // so the Divider needs an explicit finite width (matching the
              // rail's own current width) rather than double.infinity, which
              // crashes hit-testing when the incoming constraint is unbounded.
              trailing: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: SizedBox(
                  width: railWidth - AppSpacing.sm * 2,
                  child: const Divider(color: AppColors.border),
                ),
              ),
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
      // Hamburger menu (opened from each screen's header) — houses the main
      // destinations today and leaves room to grow secondary features below
      // the divider later. Desktop already shows a permanent NavigationRail.
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal),
                child: Text(
                  s.appName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (var i = 0; i < destinations.length; i++)
                ListTile(
                  leading: Icon(
                    i == _index
                        ? destinations[i].selectedIcon
                        : destinations[i].icon,
                    color: i == _index ? AppColors.primary : null,
                  ),
                  title: Text(
                    destinations[i].label,
                    style: TextStyle(
                      fontWeight:
                          i == _index ? FontWeight.w600 : FontWeight.normal,
                      color: i == _index ? AppColors.primary : null,
                    ),
                  ),
                  selected: i == _index,
                  selectedTileColor: AppColors.primaryLight,
                  onTap: () {
                    _onDestinationSelected(i);
                    Navigator.pop(context);
                  },
                ),
              const Divider(
                indent: AppSpacing.pageHorizontal,
                endIndent: AppSpacing.pageHorizontal,
              ),
            ],
          ),
        ),
      ),
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
  final Widget child;
  final String tooltip;
  final VoidCallback onPressed;

  const _VividFab({
    required this.color,
    required this.child,
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
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
