import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/input_limits.dart';
import '../core/avatars.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/tasks_provider.dart';
import '../core/me_stats.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../models/inspiration.dart';
import '../models/journal.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/inspirations_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/universities_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/sheet_body.dart';
import '../widgets/empty_state.dart';
import '../widgets/hover_lift.dart';
import '../widgets/page_header.dart';
import 'inspirations_screen.dart';
import 'journal_edit_screen.dart';
import 'journals_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart' show showAddInspirationSheet;
import '../widgets/sheet_fields.dart' show nearLimitCounter;
import '../widgets/coach_mark.dart';

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    // Layout follows screen width, not platform, so narrow web windows get the mobile UI
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final isWide = width >= AppBreakpoints.wide;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: s.me,
          actions: [
            TourAnchor(id: 'me.settings', child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            )),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal, AppSpacing.md,
              AppSpacing.pageHorizontal, AppSpacing.xl,
            ),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main block: inspirations and journal
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InspirationSection(),
                            const SizedBox(height: AppSpacing.lg),
                            _JournalSection(),
                          ],
                        ),
                      ),
                      SizedBox(width: isWide ? AppSpacing.xl : AppSpacing.lg),
                      // Secondary block: profile summary; header keeps card tops aligned
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 40,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  s.profile,
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const _ProfileCard(),
                            const SizedBox(height: AppSpacing.sm),
                            const TourAnchor(id: 'me.summary', child: _SummaryTiles()),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ProfileCard(),
                      const SizedBox(height: AppSpacing.sm),
                      const TourAnchor(id: 'me.summary', child: _SummaryTiles()),
                      const SizedBox(height: AppSpacing.lg),
                      _InspirationSection(),
                      const SizedBox(height: AppSpacing.lg),
                      _JournalSection(),
                    ],
                  ),
          ),
        ),
      ],
    );

    if (isDesktop) {
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Two-column cap: roomier on wide screens so side gaps stay balanced
            constraints: BoxConstraints(maxWidth: isWide ? 1100 : 900),
            child: content,
          ),
        ),
      );
    }

    return SafeArea(child: content);
  }
}

// ─── Profile Card ─────────────────────────────────────────────────────────────

// The three numbers from the redesign's B direction, kept in A's layout: what
// the page is about at a glance, above the two lists it is made of.
class _SummaryTiles extends ConsumerWidget {
  const _SummaryTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final today = DateUtils.dateOnly(ref.watch(effectiveNowProvider));
    // What is still open, not what was ever created: a count that only grows
    // says nothing about how the semester is going
    final tasks = ref.watch(tasksProvider).where((t) => !t.isCompletedOn(today)).length;
    final semester = ref.watch(selectedSemesterProvider);
    final targets = ref
        .watch(semesterGoalsProvider)
        .where((g) => g.semester == semester && g.parentId == null && !g.isDone)
        .length;
    final visions = ref
        .watch(futureGoalsProvider)
        .where((g) => g.parentId == null && !g.isDone)
        .length;
    final inspirations = ref.watch(inspirationsProvider).where((i) => !i.isCompleted && !i.isArchived).length;

    return Row(
      children: [
        _StatTile(label: s.tasks, value: tasks),
        const SizedBox(width: AppSpacing.sm),
        _StatTile(label: s.targets, value: targets),
        const SizedBox(width: AppSpacing.sm),
        _StatTile(label: s.goals, value: visions),
        const SizedBox(width: AppSpacing.sm),
        _StatTile(label: s.inspirations, value: inspirations),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final profile = ref.watch(profileProvider);
    final user = ref.watch(currentUserProvider);
    final effectiveNow = ref.watch(effectiveNowProvider);
    final semSettings = ref.watch(semesterSettingsProvider);

    final isGuest = ref.watch(guestModeProvider);
    final identity = ref.watch(displayIdentityProvider);

    int? displayGrade;
    if (profile?.grade != null && profile?.gradeSetYear != null) {
      displayGrade = computedGrade(profile!.grade!, profile.gradeSetYear!, effectiveNow, semSettings);
    }

    return HoverLift(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatars.build(
                  avatarIndex: profile?.avatarIndex,
                  avatarUrl: identity.avatarUrl,
                  initial: identity.initial,
                  radius: 32,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        identity.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: identity.hasRealName
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                      if (!isGuest && user?.email != null)
                        Text(user!.email!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                      const SizedBox(height: AppSpacing.xs),
                      // School / Department / Grade info rows
                      _InfoRow(label: s.school, value: profile?.school?.isNotEmpty == true ? profile!.school! : kEmptyValue),
                      _InfoRow(label: s.department, value: profile?.department?.isNotEmpty == true ? profile!.department! : kEmptyValue),
                      _InfoRow(label: s.grade, value: displayGrade != null ? s.gradeLabel(displayGrade) : kEmptyValue),
                      if (!isGuest)
                        _InfoRow(
                          label: s.loginMethod,
                          value: (user?.identities?.any((i) => i.provider == 'google') ?? false) ? 'Google' : s.emailLabel,
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _EditProfileDialog(profile: profile, ref: ref, s: s, effectiveNow: effectiveNow, semSettings: semSettings),
                  ),
                  child: Text(s.accountSettings),
                ),
              ],
            ),
            if (isGuest) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(s.loginOrCreateAccount),
                  onPressed: () => _showMergeChoiceDialog(context, ref),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          children: [
            TextSpan(text: '$label  ', style: const TextStyle(fontWeight: FontWeight.w500)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final UserProfile? profile;
  final WidgetRef ref;
  final AppStrings s;
  final DateTime effectiveNow;
  final SemesterSettings semSettings;
  const _EditProfileDialog({required this.profile, required this.ref, required this.s, required this.effectiveNow, required this.semSettings});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _usernameCtrl;
  late String _school;
  late String _dept;
  late int _selectedGrade;
  int? _selectedAvatar;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _usernameCtrl = TextEditingController(text: p?.username ?? '');
    _school = p?.school ?? '';
    _dept = p?.department ?? '';
    _selectedGrade = p?.grade ?? 1;
    _selectedAvatar = p?.avatarIndex;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.ref.read(profileProvider.notifier).updateInfo(
      username: _usernameCtrl.text.trim(),
      school: _school,
      department: _dept,
      grade: _selectedGrade,
      gradeSetYear: academicYear(widget.effectiveNow, widget.semSettings),
      avatarIndex: _selectedAvatar,
    );
    Navigator.pop(context);
  }

  Future<void> _pickSchool() async {
    final unis = widget.ref.read(universitiesProvider).universities;
    final result = await _openSearchPicker(context, widget.s, widget.s.school, unis, _school);
    if (result != null) setState(() { _school = result; _dept = ''; });
  }

  Future<void> _pickDept() async {
    final depts = widget.ref.read(universitiesProvider).departmentsFor(_school);
    final result = await _openSearchPicker(context, widget.s, widget.s.department, depts, _dept);
    if (result != null) setState(() => _dept = result);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.accountSettings),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _usernameCtrl, maxLength: InputLimits.username, buildCounter: nearLimitCounter, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: s.usernameLabel)),
            const SizedBox(height: 12),
            _PickerTile(label: s.school, value: _school, onTap: _pickSchool),
            const SizedBox(height: 12),
            _PickerTile(label: s.department, value: _dept, onTap: _pickDept),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedGrade,
              decoration: InputDecoration(labelText: s.grade),
              items: [
                for (int i = 1; i <= 7; i++)
                  DropdownMenuItem<int>(value: i, child: Text(s.gradeLabel(i))),
              ],
              onChanged: (v) => setState(() => _selectedGrade = v ?? 1),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(s.avatar, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // First option = no preset (uses Google avatar or initials)
                GestureDetector(
                  onTap: () => setState(() => _selectedAvatar = null),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedAvatar == null ? AppColors.primary : AppColors.border,
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(Icons.person_outline, size: 22, color: AppColors.textTertiary),
                  ),
                ),
                for (int i = 0; i < AppAvatars.presets.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _selectedAvatar = i),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedAvatar == i ? AppColors.primary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: AppAvatars.build(avatarIndex: i, avatarUrl: null, initial: '', radius: 18),
                    ),
                  ),
              ],
            ),
          ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton(onPressed: _save, child: Text(s.save)),
      ],
    );
  }
}

// ─── Inspiration Section ──────────────────────────────────────────────────────

class _InspirationSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final all = ref.watch(inspirationsProvider);
    final active = all.where((i) => !i.isCompleted && !i.isArchived).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Text(s.inspirations, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              // Navigate to full inspirations page
              TourAnchor(id: 'me.inspirations.open', child: IconButton(
                icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InspirationsScreen())),
              )),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () => showAddInspirationSheet(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (active.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: EmptyState(
              icon: Icons.lightbulb_outline,
              message: s.noInspirations,
              actionLabel: s.addInspiration,
              onAction: () => showAddInspirationSheet(context, ref),
              compact: true,
            ),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < active.length; i++) ...[
                  _InspirationTile(item: active[i]),
                  if (i < active.length - 1) const Divider(height: 1, indent: 40),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _InspirationTile extends ConsumerWidget {
  final Inspiration item;
  const _InspirationTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);

    return InkWell(
      onTap: () => _showEditInspirationSheet(context, ref, item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: item.isCompleted,
            activeColor: AppColors.primary,
            onChanged: (_) => ref.read(inspirationsProvider.notifier).toggleCompleted(item.id),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                      color: item.isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
                    ),
                  ),
                  if (item.content != null)
                    Text(
                      item.content!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () async {
              if (await confirmDelete(context, s)) {
                ref.read(inspirationsProvider.notifier).remove(item.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

void _showEditInspirationSheet(
    BuildContext context, WidgetRef ref, Inspiration item) {
  final titleCtrl = TextEditingController(text: item.title);
  final contentCtrl = TextEditingController(text: item.content ?? '');
  final s = ref.read(stringsProvider);

  showAppSheet(
    context,
    builder: (sheetCtx) => SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.inspirations,
              style: Theme.of(sheetCtx).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: titleCtrl,
            autofocus: true,
            maxLength: InputLimits.title,
            buildCounter: nearLimitCounter,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.titleField),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentCtrl,
            maxLines: 3,
            maxLength: InputLimits.body,
            buildCounter: nearLimitCounter,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.inspirationDetails),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                ref.read(inspirationsProvider.notifier).update(
                  item.copyWith(
                    title: title,
                    content: contentCtrl.text.trim().isEmpty
                        ? null
                        : contentCtrl.text.trim(),
                  ),
                );
                Navigator.pop(sheetCtx);
              },
              child: Text(s.save),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Journal Section ──────────────────────────────────────────────────────────

class _JournalSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final journals = ref.watch(journalProvider);
    final showDay = ref.watch(showDayCounterProvider);
    final streak = journalStreak(
      journals,
      ref.watch(effectiveNowProvider),
      written: JournalNotifier.isWrittenByUser,
    );

    // Journals are sorted desc; last entry is the earliest (Day 1)
    DateTime? earliest;
    if (journals.isNotEmpty) {
      final e = journals.last.date;
      earliest = DateTime(e.year, e.month, e.day);
    }

    int dayNumber(DateTime date) {
      if (earliest == null) return 1;
      final d = DateTime(date.year, date.month, date.day);
      return d.difference(earliest).inDays + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Text(s.journal, style: Theme.of(context).textTheme.titleLarge),
              if (streak > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                _StreakChip(days: streak),
              ],
              const Spacer(),
              // Navigate to full journals page
              TourAnchor(id: 'me.journals.open', child: IconButton(
                icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalsScreen())),
              )),
              TourAnchor(id: 'me.journal.add', child: IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalEditScreen())),
              )),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (journals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: EmptyState(
              icon: Icons.edit_note,
              message: s.noJournal,
              actionLabel: s.writeJournal,
              onAction: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const JournalEditScreen())),
              compact: true,
            ),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < journals.length; i++) ...[
                  _JournalTile(
                    journal: journals[i],
                    dayNumber: dayNumber(journals[i].date),
                    showDayCounter: showDay,
                  ),
                  if (i < journals.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// How many days in a row the user has written something themselves. Sits by
// the journal because that is the only place it means anything
class _StreakChip extends ConsumerWidget {
  final int days;

  const _StreakChip({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 14, color: AppColors.primary),
          const SizedBox(width: 2),
          Text(
            s.journalStreakDays(days),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _JournalTile extends ConsumerWidget {
  final Journal journal;
  final int dayNumber;
  final bool showDayCounter;
  const _JournalTile({required this.journal, required this.dayNumber, required this.showDayCounter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final profile = ref.watch(profileProvider);
    final identity = ref.watch(displayIdentityProvider);
    final d = journal.date;
    final dateStr =
        '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JournalDetailScreen(journal: journal)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatars.build(
                  avatarIndex: profile?.avatarIndex,
                  avatarUrl: identity.avatarUrl,
                  initial: identity.initial,
                  radius: 14,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showDayCounter) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'Day $dayNumber',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    if (await confirmDelete(context, s)) {
                      ref.read(journalProvider.notifier).remove(journal.id);
                    }
                  },
                ),
              ],
            ),
            if (journal.content != null)
              Padding(
                // Indent to align with text after avatar (28px diameter + 8px gap)
                padding: const EdgeInsets.only(top: 8, left: 36),
                child: Text(
                  journal.content!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 30,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Journal Detail Screen ────────────────────────────────────────────────────

class JournalDetailScreen extends ConsumerWidget {
  final Journal journal;
  const JournalDetailScreen({required this.journal, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(journalProvider);
    final showDay = ref.watch(showDayCounterProvider);

    // Watch the live version so edits are reflected immediately
    Journal live = journal;
    for (final j in journals) {
      if (j.id == journal.id) { live = j; break; }
    }

    final profile = ref.watch(profileProvider);
    final identity = ref.watch(displayIdentityProvider);

    // Compute day number
    DateTime? earliest;
    if (journals.isNotEmpty) {
      final e = journals.last.date;
      earliest = DateTime(e.year, e.month, e.day);
    }
    final jDay = DateTime(live.date.year, live.date.month, live.date.day);
    final dayNum = earliest != null ? jDay.difference(earliest).inDays + 1 : 1;

    final d = live.date;
    final dateStr =
        '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JournalEditScreen(existingJournal: live))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal, 0,
          AppSpacing.pageHorizontal, 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatars.build(
                  avatarIndex: profile?.avatarIndex,
                  avatarUrl: identity.avatarUrl,
                  initial: identity.initial,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        identity.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (showDay) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                'Day $dayNum',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Content indented to align under username (48px avatar + 12px gap)
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: live.content != null
                  ? Text(
                      live.content!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.8,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : Text(
                      kEmptyValue,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

void _showMergeChoiceDialog(BuildContext context, WidgetRef ref) {
  final s = ref.read(stringsProvider);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.loginOrCreateAccount),
      content: Text(s.mergeGuestDataQuestion),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(shouldMergeGuestDataProvider.notifier).state = false;
            ref.read(pendingGuestLoginProvider.notifier).state = true;
          },
          child: Text(s.discardGuestData),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(shouldMergeGuestDataProvider.notifier).state = true;
            ref.read(pendingGuestLoginProvider.notifier).state = true;
          },
          child: Text(s.mergeGuestData),
        ),
      ],
    ),
  );
}

// ─── Search Picker ────────────────────────────────────────────────────────────

class _PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _PickerTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value.isEmpty ? kEmptyValue : value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: value.isEmpty ? AppColors.textTertiary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

Future<String?> _openSearchPicker(
  BuildContext context,
  AppStrings s,
  String field,
  List<String> options,
  String current,
) async {
  String query = '';
  final result = await showAppSheet<String>(
    context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSt) {
          final filtered = options
              .where((o) => o.contains(query))
              .toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    autofocus: true,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(InputLimits.search),
                    ],
                    decoration: InputDecoration(
                      hintText: s.pickerSearchHint(field),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (v) => setSt(() => query = v),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final option in filtered)
                        ListTile(
                          title: Text(option),
                          trailing: option == current ? const Icon(Icons.check, color: AppColors.primary) : null,
                          onTap: () => Navigator.pop(ctx, option),
                        ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(s.pickerOther),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final custom = await _showCustomInputDialog(context, s, field, current);
                          if (custom != null && context.mounted) {
                            Navigator.pop(context, custom);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
  return result;
}

Future<String?> _showCustomInputDialog(
  BuildContext context,
  AppStrings s,
  String field,
  String initial,
) async {
  final ctrl = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.pickerCustomInput(field)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: InputLimits.customPicker,
        buildCounter: nearLimitCounter,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: field),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: Text(s.confirm),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result?.isEmpty == true ? null : result;
}

