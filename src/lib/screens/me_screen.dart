import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/avatars.dart';
import '../core/taiwan_universities.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/inspiration.dart';
import '../models/journal.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/inspirations_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import 'inspirations_screen.dart';
import 'journal_edit_screen.dart';
import 'journals_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart' show showAddInspirationSheet;

class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal, AppSpacing.pageTop,
              AppSpacing.pageHorizontal, 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal, AppSpacing.md,
                AppSpacing.pageHorizontal, AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ProfileCard(),
                  const SizedBox(height: AppSpacing.lg),
                  _InspirationSection(),
                  const SizedBox(height: AppSpacing.lg),
                  _JournalSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _gradeLabel(int grade) {
  const labels = ['一', '二', '三', '四', '五', '六', '七'];
  final i = grade - 1;
  return i >= 0 && i < labels.length ? labels[i] : '$grade';
}

// ─── Profile Card ─────────────────────────────────────────────────────────────

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
    final googleName = isGuest ? null : user?.userMetadata?['full_name'] as String?;
    final avatarUrl = isGuest ? null : user?.userMetadata?['avatar_url'] as String?;
    final username = profile?.username;
    final displayName = username?.isNotEmpty == true
        ? username!
        : (isGuest ? '訪客' : (googleName ?? user?.email ?? ''));
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    int? displayGrade;
    if (profile?.grade != null && profile?.gradeSetYear != null) {
      displayGrade = computedGrade(profile!.grade!, profile.gradeSetYear!, effectiveNow, semSettings);
    }

    return Container(
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
                avatarUrl: avatarUrl,
                initial: initial,
                radius: 32,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: (username?.isNotEmpty == true || (!isGuest && googleName != null))
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                    if (!isGuest && user?.email != null)
                      Text(user!.email!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                    const SizedBox(height: 4),
                    // School / Department / Grade info rows
                    _InfoRow(label: s.school, value: profile?.school?.isNotEmpty == true ? profile!.school! : '—'),
                    _InfoRow(label: s.department, value: profile?.department?.isNotEmpty == true ? profile!.department! : '—'),
                    _InfoRow(label: s.grade, value: displayGrade != null ? _gradeLabel(displayGrade) : '—'),
                    if (!isGuest)
                      _InfoRow(
                        label: '登入方式',
                        value: (user?.appMetadata['provider'] as String?) == 'google' ? 'Google' : '電子郵件',
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
                label: const Text('登入 / 建立帳號'),
                onPressed: () => _showMergeChoiceDialog(context, ref),
              ),
            ),
          ],
        ],
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
  final dynamic profile;
  final WidgetRef ref;
  final dynamic s;
  final DateTime effectiveNow;
  final dynamic semSettings;
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
    final result = await _openSearchPicker(context, '選擇學校', taiwanUniversities, _school);
    if (result != null) setState(() { _school = result; _dept = ''; });
  }

  Future<void> _pickDept() async {
    final result = await _openSearchPicker(context, '選擇系所', commonDepartments, _dept);
    if (result != null) setState(() => _dept = result);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.accountSettings),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _usernameCtrl, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: s.usernameLabel)),
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
                  DropdownMenuItem<int>(value: i, child: Text(_gradeLabel(i))),
              ],
              onChanged: (v) => setState(() => _selectedGrade = v ?? 1),
            ),
            const SizedBox(height: 16),
            Text('頭像', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
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
    final active = all.where((i) => !i.isCompleted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(s.inspirations, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            // Navigate to full inspirations page
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InspirationsScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => showAddInspirationSheet(context, ref),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (active.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(s.noInspirations, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary)),
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
              if (await _confirmDelete(context, s)) {
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

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(s.inspirations,
                style: Theme.of(sheetCtx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s.titleField),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 3,
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
        Row(
          children: [
            Text(s.journal, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            // Navigate to full journals page
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalsScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalEditScreen())),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (journals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              s.noJournal,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
              ),
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

class _JournalTile extends ConsumerWidget {
  final Journal journal;
  final int dayNumber;
  final bool showDayCounter;
  const _JournalTile({required this.journal, required this.dayNumber, required this.showDayCounter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider);
    final isGuest = ref.watch(guestModeProvider);
    final googleName = isGuest ? null : user?.userMetadata?['full_name'] as String?;
    final avatarUrl = isGuest ? null : user?.userMetadata?['avatar_url'] as String?;
    final username = profile?.username;
    final displayName = username?.isNotEmpty == true
        ? username!
        : (isGuest ? '訪客' : (googleName ?? user?.email ?? ''));
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
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
                  avatarUrl: avatarUrl,
                  initial: initial,
                  radius: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showDayCounter) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'Day $dayNumber',
                      style: const TextStyle(
                        fontSize: 11,
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
                    if (await _confirmDelete(context, s)) {
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

    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider);
    final isGuest = ref.watch(guestModeProvider);
    final googleName = isGuest ? null : user?.userMetadata?['full_name'] as String?;
    final avatarUrl = isGuest ? null : user?.userMetadata?['avatar_url'] as String?;
    final username = profile?.username;
    final displayName = username?.isNotEmpty == true
        ? username!
        : (isGuest ? '訪客' : (googleName ?? user?.email ?? ''));
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

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
                  avatarUrl: avatarUrl,
                  initial: initial,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
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
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                'Day $dayNum',
                                style: const TextStyle(
                                  fontSize: 11,
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
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : Text(
                      '—',
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
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('登入 / 建立帳號'),
      content: const Text('登入後，目前的訪客資料要如何處理？'),
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
          child: const Text('捨棄資料'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(shouldMergeGuestDataProvider.notifier).state = true;
            ref.read(pendingGuestLoginProvider.notifier).state = true;
          },
          child: const Text('整合進帳號'),
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
          value.isEmpty ? '—' : value,
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
  String title,
  List<String> options,
  String current,
) async {
  String query = '';
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSt) {
          final filtered = options
              .where((o) => o.contains(query))
              .toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                    decoration: InputDecoration(
                      hintText: '搜尋 $title',
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
                        title: const Text('其他（自行輸入）'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final custom = await _showCustomInputDialog(context, title, current);
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

Future<String?> _showCustomInputDialog(BuildContext context, String title, String initial) async {
  final ctrl = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('輸入$title'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: title),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('確定'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result?.isEmpty == true ? null : result;
}

Future<bool> _confirmDelete(BuildContext context, dynamic s) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text('${s.delete}？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error),
              child: Text(s.delete),
            ),
          ],
        ),
      ) ??
      false;
}

