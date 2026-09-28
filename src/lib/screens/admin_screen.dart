import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_routes.dart';
import '../core/input_limits.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/remote_config_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/synced_list_notifier.dart' show newRowId, reportSyncErrorFromWidget;
import '../widgets/responsive_body.dart';
import '../widgets/style_picker_sheet.dart' show appStyleChoiceName;
import '../core/theme/app_motion.dart';
import '../widgets/swipe_switcher.dart';

// The admin backend (/admin, system_design.md §2-O, UC21–UC22): numbers across
// all accounts, the switches every app obeys, and the account list. Only for
// accounts in the admins table; the SQL behind it refuses anyone else anyway
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
  static const _sections = 5;
  int _tab = 0;
  // Which way the last change went, so the sections slide the matching way
  bool _forward = true;
  // The phone's tab strip, kept in step with swipes and the wide layout's rail
  late final TabController _tabs = TabController(length: _sections, vsync: this);

  @override
  void initState() {
    super.initState();
    // Touched here, not first in dispose: a late controller made while the
    // widget is leaving the tree has nothing to tick with
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && _tabs.index != _tab) _show(_tabs.index);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _show(int i) {
    if (i < 0 || i >= _sections || i == _tab) return;
    setState(() {
      _forward = i > _tab;
      _tab = i;
    });
    if (_tabs.index != i) _tabs.animateTo(i);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

    final titles = [s.adminTabOverview, s.adminTabUsage, s.adminTabSettings, s.adminTabControls, s.adminTabUsers];
    const icons = [
      Icons.dashboard_outlined,
      Icons.bar_chart_outlined,
      Icons.tune_outlined,
      Icons.toggle_on_outlined,
      Icons.people_outline,
    ];

    // A swipe to the left moves to the next section, to the right back — the
    // way the timetable and grades move — sliding in on the shared axis
    final page = SwipeSwitcher(
      onNext: _tab < _sections - 1 ? () => _show(_tab + 1) : null,
      onPrevious: _tab > 0 ? () => _show(_tab - 1) : null,
      child: PageTransitionSwitcher(
        duration: scaled(context, AppMotion.page),
        reverse: !_forward,
        transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
          animation: primary,
          secondaryAnimation: secondary,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Colors.transparent,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: switch (_tab) {
            0 => const _Overview(),
            1 => const _Usage(),
            2 => const _SettingsAndErrors(),
            3 => const _Controls(),
            _ => const _Users(),
          },
        ),
      ),
    );

    final Widget body = switch (isAdmin) {
      AsyncData(value: true) => wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: _show,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (var i = 0; i < titles.length; i++)
                      NavigationRailDestination(icon: Icon(icons[i]), label: Text(titles[i])),
                  ],
                ),
                VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: ResponsiveBody(maxWidth: 960, child: page)),
              ],
            )
          : page,
      AsyncData() => Center(child: Text(s.adminNoAccess)),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(s.adminTitle),
        leading: homeButtonIfFirst(context),
        actions: [
          if (isAdmin.value == true)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: s.adminRefresh,
              onPressed: () {
                ref.invalidate(adminStatsProvider);
                ref.invalidate(adminUsersProvider);
                ref.read(remoteConfigProvider.notifier).refresh();
              },
            ),
        ],
        // Phones: the sections as scrolling tabs under the title
        bottom: isAdmin.value == true && !wide
            ? TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: [for (final t in titles) Tab(text: t)],
              )
            : null,
      ),
      // Clear of Android's navigation bar and the iPhone's home indicator: the
      // lists set their own padding, which drops the automatic inset
      body: SafeArea(top: false, child: body),
    );
  }
}

// ── Shared pieces ─────────────────────────────────────────────────────────────

// Loads the stats once for whichever tab shows them
class _StatsView extends ConsumerWidget {
  final Widget Function(AdminStats stats, AppStrings s) builder;
  const _StatsView({required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ref.watch(adminStatsProvider).when(
          data: (stats) => builder(stats, s),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('${s.adminLoadFailed}\n$e', textAlign: TextAlign.center),
            ),
          ),
        );
  }
}

Widget _list(List<Widget> children) => ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: children,
    );

Widget _heading(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

class _Number extends StatelessWidget {
  final String label;
  final int value;
  const _Number(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SizedBox(
      width: 150,
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.labelMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            Text('$value', style: theme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// Thirty days as bars, oldest on the left; the tallest day's count on top
class _Bars extends StatelessWidget {
  final List<int> values;
  const _Bars(this.values);

  @override
  Widget build(BuildContext context) {
    final most = values.fold<int>(0, (a, b) => b > a ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$most', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary)),
        SizedBox(
          height: 72,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarsPainter(values, most, AppColors.primary, AppColors.surfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<int> values;
  final int most;
  final Color bar;
  final Color base;

  _BarsPainter(this.values, this.most, this.bar, this.base);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final slot = size.width / values.length;
    canvas.drawRect(Rect.fromLTWH(0, size.height - 1, size.width, 1), Paint()..color = base);
    final paint = Paint()..color = bar;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == 0 || most == 0) continue;
      final h = size.height * values[i] / most;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * slot + slot * 0.15, size.height - h, slot * 0.7, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.values != values || old.bar != bar;
}

// A share of the whole as a labelled bar
class _Share extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  const _Share(this.label, this.count, this.total);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : count / total,
                minHeight: 8,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
              ),
            ),
          ),
          SizedBox(width: 48, child: Text('$count', textAlign: TextAlign.end, style: theme.bodySmall)),
        ],
      ),
    );
  }
}

String _date(DateTime d) => '${d.year}/${d.month}/${d.day}';
String _time(DateTime d) =>
    '${_date(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

// ── Overview ──────────────────────────────────────────────────────────────────

class _Overview extends ConsumerWidget {
  const _Overview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(effectiveNowProvider);
    return _StatsView(
      builder: (stats, s) => _list([
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _Number(s.adminUsersTotal, stats.users),
            _Number(s.adminNewToday, stats.usersToday),
            _Number(s.adminDau, stats.dau),
            _Number(s.adminWau, stats.wau),
            _Number(s.adminMau, stats.mau),
          ],
        ),
        _heading(context, s.adminNewUsersChart),
        _Card(child: _Bars(last30(stats.usersDaily, today))),
        _heading(context, s.adminActiveChart),
        _Card(child: _Bars(last30(stats.activeDaily, today))),
        _heading(context, s.adminTopSchools),
        _Card(
          child: Column(
            children: [
              for (final school in stats.schools) _Share(school.name, school.count, stats.users),
              if (stats.schools.isEmpty) const Text(kEmptyValue),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(s.adminGuestsNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
      ]),
    );
  }
}

// ── Usage ─────────────────────────────────────────────────────────────────────

class _Usage extends ConsumerWidget {
  const _Usage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(effectiveNowProvider);
    return _StatsView(builder: (stats, s) {
      final names = {
        'tasks': s.tasks,
        'semester_goals': s.targets,
        'future_goals': s.goals,
        'journals': s.adminJournals,
        'inspirations': s.inspirations,
        'courses': s.adminCourses,
        'reviews': s.reviews,
      };
      final theme = Theme.of(context).textTheme;
      return _list([
        for (final e in names.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(e.value, style: theme.titleSmall)),
                      Text(
                        s.adminUsage(stats.features[e.key]?.total ?? 0, stats.features[e.key]?.users ?? 0),
                        style: theme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _Bars(last30(stats.features[e.key]?.daily ?? const {}, today)),
                ],
              ),
            ),
          ),
      ]);
    });
  }
}

// ── Settings and errors ───────────────────────────────────────────────────────

class _SettingsAndErrors extends StatelessWidget {
  const _SettingsAndErrors();

  static String _language(String code, AppStrings s) => switch (code) {
        'en' => languageLabel(AppLanguage.en, s),
        'jp' => languageLabel(AppLanguage.jp, s),
        _ => languageLabel(AppLanguage.zhTw, s),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return _StatsView(builder: (stats, s) {
      final styleTotal = stats.styles.values.fold<int>(0, (a, b) => a + b);
      final languageTotal = stats.languages.values.fold<int>(0, (a, b) => a + b);
      return _list([
        _heading(context, s.adminStyles),
        _Card(
          child: Column(children: [
            for (final e in stats.styles.entries) _Share(appStyleChoiceName(e.key, s), e.value, styleTotal),
          ]),
        ),
        _heading(context, s.adminLanguages),
        _Card(
          child: Column(children: [
            for (final e in stats.languages.entries) _Share(_language(e.key, s), e.value, languageTotal),
          ]),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(s.adminCreditCategoriesOn(stats.creditCategories), style: theme.bodyMedium),
        _heading(context, s.adminErrorsByPlace),
        if (stats.errorGroups.isEmpty)
          Text(s.adminNoErrors, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary))
        else
          _Card(
            child: Column(children: [
              for (final g in stats.errorGroups)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(child: Text('${g.where}${g.code == null ? '' : '  ${g.code}'}', style: theme.bodySmall)),
                      Text('${g.count}', style: theme.labelLarge),
                    ],
                  ),
                ),
            ]),
          ),
        _heading(context, s.adminRecentErrors),
        for (final r in stats.recentErrors)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${_time(r.at)}  ${r.where}', style: theme.labelMedium),
            subtitle: SelectableText([r.message, ?r.platform].join(kDotSeparator), style: theme.bodySmall),
          ),
        if (stats.recentErrors.isEmpty) const Text(kEmptyValue),
      ]);
    });
  }
}

// ── Controls ──────────────────────────────────────────────────────────────────

class _Controls extends ConsumerStatefulWidget {
  const _Controls();

  @override
  ConsumerState<_Controls> createState() => _ControlsState();
}

class _ControlsState extends ConsumerState<_Controls> {
  late RemoteConfig _draft = ref.read(remoteConfigProvider);
  late final _text = TextEditingController(text: _draft.announcement?.text ?? '');
  late final _message = TextEditingController(text: _draft.maintenanceMessage);
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _message.dispose();
    super.dispose();
  }

  String _featureName(String key, AppStrings s) => switch (key) {
        'timetable' => s.featureTimetable,
        'catalog_search' => s.featureCatalogSearch,
        'credit_categories' => s.featureCreditCategories,
        'reviews' => s.featureReviews,
        'onboarding_tour' => s.featureOnboardingTour,
        _ => s.featureGoalTemplates,
      };

  Future<DateTime?> _pickDay(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2024),
        lastDate: DateTime(2035),
      );

  Future<void> _save(AppStrings s) async {
    final old = _draft.announcement;
    final text = _text.text.trim();
    // A changed text is a new announcement, which shows again to those who
    // dismissed the last one
    final announcement = text.isEmpty
        ? null
        : Announcement(
            id: old != null && old.text == text ? old.id : newRowId(),
            text: text,
            level: old?.level ?? 'info',
            startsAt: old?.startsAt,
            endsAt: old?.endsAt,
          );
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(remoteConfigProvider.notifier).save(
            _draft.copyWith(announcement: () => announcement, maintenanceMessage: _message.text.trim()),
            ref.read(currentUserProvider)?.email ?? '',
          );
      messenger.showSnackBar(SnackBar(content: Text(s.adminSaved)));
    } catch (e) {
      reportSyncErrorFromWidget(ref, e, where: 'app_config save');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setAnnouncement(Announcement Function(Announcement a) change) {
    final a = _draft.announcement ?? Announcement(id: newRowId(), text: _text.text.trim());
    setState(() => _draft = _draft.copyWith(announcement: () => change(a)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final live = ref.watch(remoteConfigProvider);
    final a = _draft.announcement;
    return _list([
      Text(s.adminFeatures, style: theme.titleMedium),
      Text(s.adminFeaturesHint, style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      for (final key in kRemoteFeatures)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_featureName(key, s)),
          value: _draft.on(key),
          onChanged: (on) => setState(() => _draft = _draft.copyWith(flags: {..._draft.flags, key: on})),
        ),
      _heading(context, s.adminAnnouncement),
      TextField(
        controller: _text,
        maxLength: InputLimits.announcement,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(labelText: s.adminAnnouncementText),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(s.adminAnnouncementWarning),
        value: a?.level == 'warning',
        onChanged: (v) => _setAnnouncement((x) => Announcement(
              id: x.id, text: x.text, level: v == true ? 'warning' : 'info', startsAt: x.startsAt, endsAt: x.endsAt)),
      ),
      Wrap(
        spacing: AppSpacing.sm,
        children: [
          ActionChip(
            avatar: const Icon(Icons.event_outlined, size: 18),
            label: Text('${s.adminStartsAt} ${a?.startsAt == null ? s.adminAnyTime : _date(a!.startsAt!)}'),
            onPressed: () async {
              final d = await _pickDay(a?.startsAt);
              _setAnnouncement((x) => Announcement(id: x.id, text: x.text, level: x.level, startsAt: d, endsAt: x.endsAt));
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.event_busy_outlined, size: 18),
            label: Text('${s.adminEndsAt} ${a?.endsAt == null ? s.adminAnyTime : _date(a!.endsAt!)}'),
            onPressed: () async {
              final d = await _pickDay(a?.endsAt);
              _setAnnouncement((x) => Announcement(id: x.id, text: x.text, level: x.level, startsAt: x.startsAt, endsAt: d));
            },
          ),
        ],
      ),
      _heading(context, s.adminMaintenance),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(s.adminMaintenance),
        subtitle: Text(s.adminMaintenanceHint),
        value: _draft.maintenance,
        onChanged: (on) => setState(() => _draft = _draft.copyWith(maintenance: on)),
      ),
      TextField(
        controller: _message,
        maxLength: InputLimits.maintenanceMessage,
        decoration: InputDecoration(labelText: s.adminMaintenanceMessage),
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton(onPressed: _saving ? null : () => _save(s), child: Text(s.save)),
      if (live.updatedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(s.adminLastUpdated(_time(live.updatedAt!), live.updatedBy ?? kEmptyValue),
              style: theme.bodySmall?.copyWith(color: AppColors.textTertiary)),
        ),
    ]);
  }
}

// ── Accounts ──────────────────────────────────────────────────────────────────

class _Users extends ConsumerStatefulWidget {
  const _Users();

  @override
  ConsumerState<_Users> createState() => _UsersState();
}

class _UsersState extends ConsumerState<_Users> {
  final _search = TextEditingController();
  String _query = '';
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggle(AdminUser u, AppStrings s) async {
    final who = u.email ?? u.username ?? u.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(u.disabled ? s.adminEnableConfirm(who) : s.adminDisableConfirm(who)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(u.disabled ? s.adminEnable : s.adminDisable)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminSourceProvider).setDisabled(u.id, !u.disabled);
      ref.invalidate(adminUsersProvider);
    } catch (e) {
      reportSyncErrorFromWidget(ref, e, where: 'admin_set_user_disabled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final users = ref.watch(adminUsersProvider((search: _query, page: _page)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, AppSpacing.sm, AppSpacing.pageHorizontal, 0),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(hintText: s.adminSearchUsers, prefixIcon: const Icon(Icons.search)),
            onSubmitted: (v) => setState(() {
              _query = v.trim();
              _page = 0;
            }),
          ),
        ),
        Expanded(
          child: users.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('${s.adminLoadFailed}\n$e', textAlign: TextAlign.center)),
            data: (list) => ListView(
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              children: [
                for (final u in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(u.email ?? u.username ?? u.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        [?u.username, ?u.school, ?u.department].join(kDotSeparator),
                        s.adminAccountDates(_date(u.createdAt), u.lastSignInAt == null ? kEmptyValue : _date(u.lastSignInAt!)),
                      ].where((x) => x.isNotEmpty).join('\n'),
                      style: theme.bodySmall,
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (u.disabled) Text(s.adminDisabled, style: theme.labelSmall?.copyWith(color: AppColors.error)),
                        TextButton(
                          onPressed: () => _toggle(u, s),
                          child: Text(u.disabled ? s.adminEnable : s.adminDisable),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _page == 0 ? null : () => setState(() => _page--),
                      child: Text(s.adminPrevious),
                    ),
                    TextButton(
                      // A full page means there may be more
                      onPressed: list.length < 50 ? null : () => setState(() => _page++),
                      child: Text(s.adminNext),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
