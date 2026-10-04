import 'package:flutter/foundation.dart' show kDebugMode;
import '../core/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../widgets/coach_mark.dart';
import '../widgets/draggable_fab.dart';
import '../providers/settings_provider.dart';
import '../providers/date_provider.dart';
import '../providers/home_tab_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/synced_list_notifier.dart';
import 'today_screen.dart' show TodayScreen, showTaskSheet, showAddInspirationSheet;

import 'semester_screen.dart';
import 'semester_goal_detail_screen.dart' show showSemesterGoalSheet;
import 'future_screen.dart';
import 'me_screen.dart';
import 'journal_edit_screen.dart';
import 'home_tour.dart';
import 'timetable_screen.dart';
import '../providers/remote_config_provider.dart';
import '../widgets/announcement_banner.dart';
import '../widgets/app_page.dart';
import '../providers/admin_provider.dart' show isAdminProvider;
import 'admin_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  // Which tab to show, from the address (/tasks, /targets …, CLAUDE.md §13)
  final int tab;
  const HomeScreen({super.key, this.tab = 0});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _index = widget.tab;

  // Set while a tour chapter is up. The overlay it inserts outlives this
  // widget, so it has to come down with the screen it is explaining —
  // otherwise signing out mid-tour leaves an unclickable scrim over the login page
  VoidCallback? _dismissTour;

  // Every tab change goes through the address, so Back and Forward in a
  // browser move between tabs and a reload stays on the one showing. The
  // index is set at once too; the router then rebuilds this with the same tab.
  // With a page open on top — the graph's "see the tasks" — only the index
  // changes: go() would rebuild the stack and close that page. The address
  // follows once the page is gone (_syncAddress)
  void _select(int i) {
    setState(() => _index = i);
    if (ModalRoute.of(context)?.isCurrent ?? true) _syncAddress();
  }

  void _syncAddress() {
    if (!mounted || GoRouter.maybeOf(context) == null) return;
    if (ModalRoute.of(context)?.isCurrent != true || widget.tab == _index) return;
    context.go(AppRoutes.tabs[_index]);
  }

  // A page closing is when a tab picked underneath it reaches the address
  void _syncAddressLater() => WidgetsBinding.instance.addPostFrameCallback((_) => _syncAddress());

  void _onDestinationSelected(int i) {
    _select(i);
    _scheduleChapterCheck();
  }

  // The address changed from outside: the browser's Back or Forward, or a link
  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab && widget.tab != _index) {
      setState(() => _index = widget.tab);
      _scheduleChapterCheck();
    }
  }

  @override
  void initState() {
    super.initState();
    // A sheet or page closing is when a postponed chapter gets its turn — the
    // task sheet a notification opened on a cold start, say
    tourRouteObserver.addListener(_scheduleChapterCheck);
    tourRouteObserver.addListener(_syncAddressLater);
    // After the first frame: the anchors have to be laid out before anything
    // can be measured, and _AuthGate has already decided this screen is the one
    _scheduleChapterCheck();
  }

  @override
  void dispose() {
    tourRouteObserver.removeListener(_scheduleChapterCheck);
    tourRouteObserver.removeListener(_syncAddressLater);
    _dismissTour?.call();
    super.dispose();
  }

  // Each tab has a chapter that plays the first time the tab is shown. [force]
  // replays one that has already run, for the guide in Settings
  void _scheduleChapterCheck([String? force]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dismissTour != null) return;
      // Never over a sheet or a page: a chapter points at this screen
      if (ModalRoute.of(context)?.isCurrent != true) return;
      final chapter = kTourChapters[_index];
      if (force != chapter && ref.read(onboardingProvider).contains(chapter)) return;
      // Switched off from the admin backend: no chapter starts by itself; the
      // guide in Settings can still replay one
      if (force != chapter && !ref.read(featureOnProvider('onboarding_tour'))) return;
      _dismissTour = CoachMarkOverlay.show(
        context,
        steps: tourChapter(chapter, ref, ref.read(stringsProvider)),
        onFinished: () {
          _dismissTour = null;
          ref.read(onboardingProvider.notifier).markDone(chapter);
          // Ending on "tap the next tab" lands on a tab whose chapter may be due
          _scheduleChapterCheck();
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.desktop;

    // When dev mode changes the effective date, sync the task-date calendar
    ref.listen<DateTime>(effectiveNowProvider, (_, next) {
      ref.read(dateProvider.notifier).goToToday(next);
    });

    // Something outside the tab bar asked for a tab — the graph's "see the
    // tasks" button, which sets the filter and then has to land the user on it
    ref.listen<int?>(pendingTabProvider, (_, tab) {
      if (tab == null) return;
      _select(tab);
      ref.read(pendingTabProvider.notifier).state = null;
      _scheduleChapterCheck();
    });

    // The guide in Settings asked to replay a chapter: whatever is running
    // gives way, and the chapter's own tab comes up first
    ref.listen<String?>(tourReplayProvider, (_, chapter) {
      if (chapter == null) return;
      ref.read(tourReplayProvider.notifier).state = null;
      _dismissTour?.call();
      _dismissTour = null;
      _select(kTourChapters.indexOf(chapter));
      _scheduleChapterCheck(chapter);
    });

    // Surface writes that never reached Supabase. Without this the screen shows
    // the change as saved while the row was silently dropped
    ref.listen<Object?>(syncErrorProvider, (_, error) {
      if (error == null) return;
      // Debug builds show which column or policy rejected the write; a release
      // user can do nothing with a PostgREST code, so they get the plain message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kDebugMode
                ? '${s.syncFailed} — ${describeSyncError(error)}'
                : s.syncFailed,
          ),
          duration: const Duration(seconds: kDebugMode ? 10 : 4),
        ),
      );
      ref.read(syncErrorProvider.notifier).state = null;
    });

    // Shared destination data for both NavigationBar and NavigationRail
    final destinations = [
      (icon: Icons.today_outlined, selectedIcon: Icons.today, label: s.tasks),
      (icon: Icons.school_outlined, selectedIcon: Icons.school, label: s.targets),
      (icon: Icons.flag_outlined, selectedIcon: Icons.flag, label: s.goals),
      (icon: Icons.person_outlined, selectedIcon: Icons.person, label: s.me),
    ];

    void openTimetable() => openPage(context, AppRoutes.timetable, () => const TimetableScreen());
    // Switched off from the admin backend (kRemoteFeatures): no way in
    final timetableOn = ref.watch(featureOnProvider('timetable'));
    // Below the timetable, only for accounts in the admins table
    // (supabase/admin.sql); moved here from Settings on 2026-10-04
    void openAdmin() => openPage(context, AppRoutes.admin, () => const AdminScreen());
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    final addButton = switch (_index) {
      1 => _VividFab(
          color: AppColors.categoryIntern,
          tooltip: s.addTarget,
          onPressed: () => showSemesterGoalSheet(context, ref),
          child: const Icon(Icons.add, color: AppColors.textOnPrimary, size: 30)),
      2 => _VividFab(
          color: AppColors.categoryCert,
          tooltip: s.addGoal,
          onPressed: () => showFutureGoalSheet(context, ref),
          child: const Icon(Icons.add, color: AppColors.textOnPrimary, size: 30)),
      3 => _VividFab(
          color: AppColors.categoryPerformance,
          tooltip: s.addJournal,
          onPressed: () => Navigator.push(
            context,
            AppPageRoute(builder: (_) => const JournalEditScreen()),
          ),
          child: const Icon(Icons.edit_note, color: AppColors.textOnPrimary, size: 30)),
      _ => _VividFab(
          color: AppColors.categoryCompetition,
          tooltip: s.addTask,
          onPressed: () => showTaskSheet(context, ref),
          child: const Icon(Icons.add, color: AppColors.textOnPrimary, size: 30)),
    };

    final tabs = Stack(
      children: [
        // Soft top gradient so the page background is not one flat color
        Positioned(
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
        _TabFade(
          index: _index,
          child: IndexedStack(
            index: _index,
            children: const [
              TodayScreen(),
              SemesterScreen(),
              FutureScreen(),
              MeScreen(),
            ],
          ),
        ),
        // Both add buttons live in the page stack so they can be dragged
        // anywhere on it; the Scaffold's own floatingActionButton slot is
        // fixed to one corner
        // The inspiration button shrinks away on the journal tab rather than
        // vanishing, and stays in the tree so its dragged position is kept
        DraggableFab(
          storageKey: 'inspiration',
          child: _FabPresence(
            visible: _index < 3,
            child: TourAnchor(id: 'fab.inspiration', child: _VividFab(
              color: AppColors.categoryExchange,
              tooltip: s.addInspiration,
              onPressed: () => showAddInspirationSheet(context, ref),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.cloud_outlined, size: 30, color: AppColors.textOnPrimary),
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.lightbulb_outline, size: 15, color: AppColors.textOnPrimary),
                  ),
                ],
              ),
            )),
          ),
        ),
        DraggableFab(storageKey: 'main', child: TourAnchor(id: 'fab.add', child: addButton)),
      ],
    );


    // The admin backend's announcement, across the top of every tab. The tabs
    // below then leave the status bar to it
    final announcement = ref.watch(visibleAnnouncementProvider);
    final body = announcement == null
        ? tabs
        : Column(
            children: [
              AnnouncementBanner(announcement: announcement),
              Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: tabs)),
            ],
          );

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
                for (var i = 0; i < destinations.length; i++)
                  NavigationRailDestination(
                    icon: TourAnchor(id: 'nav.$i', child: Icon(destinations[i].icon)),
                    selectedIcon: TourAnchor(
                      id: 'nav.$i',
                      child: Icon(destinations[i].selectedIcon,
                          color: AppColors.primary),
                    ),
                    label: Text(destinations[i].label),
                  ),
              ],
              // Same divider as the mobile drawer — secondary features sit
              // below the four main destinations and open as pages.
              // NavigationRail centers trailing in an unbounded-width Column,
              // so the Divider needs an explicit finite width (matching the
              // rail's own current width) rather than double.infinity, which
              // crashes hit-testing when the incoming constraint is unbounded.
              trailing: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: SizedBox(
                      width: railWidth - AppSpacing.sm * 2,
                      child: Divider(color: AppColors.border),
                    ),
                  ),
                  if (timetableOn)
                    _RailEntry(
                      icon: Icons.calendar_view_week_outlined,
                      label: s.timetable,
                      extended: extended,
                      width: railWidth - AppSpacing.sm * 2,
                      onTap: openTimetable,
                    ),
                  if (isAdmin)
                    _RailEntry(
                      icon: Icons.admin_panel_settings_outlined,
                      label: s.adminTitle,
                      extended: extended,
                      width: railWidth - AppSpacing.sm * 2,
                      onTap: openAdmin,
                    ),
                ],
              ),
            ),
            VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
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
              if (timetableOn)
                ListTile(
                  leading: const Icon(Icons.calendar_view_week_outlined),
                  title: Text(s.timetable),
                  onTap: () {
                    Navigator.pop(context);
                    openTimetable();
                  },
                ),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: Text(s.adminTitle),
                  onTap: () {
                    Navigator.pop(context);
                    openAdmin();
                  },
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          for (var i = 0; i < destinations.length; i++)
            NavigationDestination(
              icon: TourAnchor(id: 'nav.$i', child: Icon(destinations[i].icon)),
              selectedIcon: TourAnchor(
                id: 'nav.$i',
                child: Icon(destinations[i].selectedIcon,
                    color: AppColors.primary),
              ),
              label: destinations[i].label,
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
  // Touch has no hover, so pressing is the feedback a phone gets
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        // The raw pointer, not onTapDown: the button can also be dragged, so a
        // tap is only recognised after the press timeout — too late for the
        // press to be felt on a quick tap
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedScale(
              scale: _pressed ? 0.92 : _hovered ? 1.08 : 1.0,
              duration: scaled(context, AppMotion.quick),
              curve: _pressed ? AppMotion.exitCurve : AppMotion.enterCurve,
              // Switching tabs changes the colour; it blends rather than jumps
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: widget.color),
                duration: scaled(context, AppMotion.move),
                curve: AppMotion.moveCurve,
                builder: (context, color, child) => AnimatedContainer(
                  duration: scaled(context, AppMotion.quick),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(color, Colors.white, 0.18)!,
                        color!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: _hovered ? 0.55 : 0.35),
                        blurRadius: _hovered ? 26 : 14,
                        offset: Offset(0, _hovered ? 10 : 6),
                      ),
                    ],
                  ),
                  child: child,
                ),
                // A new tab means a new action: the icon turns in, keyed on the
                // colour because every tab's button has its own
                child: Center(
                  child: AnimatedSwitcher(
                    duration: scaled(context, AppMotion.move),
                    switchInCurve: AppMotion.enterCurve,
                    switchOutCurve: AppMotion.exitCurve,
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween(begin: -0.25, end: 0.0).animate(animation),
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: KeyedSubtree(key: ValueKey(widget.color), child: widget.child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Material 3's quick fade for top-level destinations: the page arriving fades
// and settles up from 98%. Deliberately no slide — the tabs are not a sequence,
// and motion that implies one would say they were. The IndexedStack stays
// underneath, so every tab keeps its state and scroll position
class _TabFade extends StatefulWidget {
  final int index;
  final Widget child;

  const _TabFade({required this.index, required this.child});

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: AppMotion.page,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(parent: _run, curve: AppMotion.enterCurve);

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    _run.duration = scaled(context, AppMotion.page);
    _run.forward(from: 0);
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(_curve),
          child: widget.child,
        ),
      );
}

// Grows in and shrinks away instead of popping, and takes no taps while gone
class _FabPresence extends StatelessWidget {
  final bool visible;
  final Widget child;

  const _FabPresence({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        ignoring: !visible,
        child: AnimatedScale(
          scale: visible ? 1 : 0,
          duration: scaled(context, visible ? AppMotion.enter : AppMotion.exit),
          curve: visible ? AppMotion.enterCurve : AppMotion.exitCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: scaled(context, AppMotion.exit),
            child: child,
          ),
        ),
      );
}

// A page below the rail's divider (the timetable, the backend). Laid out like
// the destinations above, not as a ListTile: extended, the icon centred on
// their icon column (half the rail's 80-pixel minWidth) and the label starting
// where theirs do, in the rail's own icon size and label style; collapsed, an
// icon with a tooltip
class _RailEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool extended;
  final double width;
  final VoidCallback onTap;

  const _RailEntry({
    required this.icon,
    required this.label,
    required this.extended,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rail = NavigationRailTheme.of(context);
    if (!extended) {
      return IconButton(
        icon: Icon(icon),
        iconSize: rail.unselectedIconTheme?.size,
        tooltip: label,
        onPressed: onTap,
      );
    }
    return SizedBox(
      width: width,
      height: 56,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Row(
          children: [
            SizedBox(
              width: 80 - AppSpacing.sm * 2,
              child: Icon(icon, size: rail.unselectedIconTheme?.size),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: rail.unselectedLabelTextStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

