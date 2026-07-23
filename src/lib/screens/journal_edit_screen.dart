import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/avatars.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/journal.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';

class JournalEditScreen extends ConsumerStatefulWidget {
  // null = add mode, non-null = edit mode
  final Journal? existingJournal;
  const JournalEditScreen({this.existingJournal, super.key});

  @override
  ConsumerState<JournalEditScreen> createState() => _JournalEditScreenState();
}

class _JournalEditScreenState extends ConsumerState<JournalEditScreen> {
  late DateTime _date;
  late TextEditingController _contentCtrl;

  bool get _isEdit => widget.existingJournal != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingJournal;
    final effectiveNow = ref.read(effectiveNowProvider);
    _date = existing?.date ?? effectiveNow;
    _contentCtrl = TextEditingController(text: existing?.content ?? '');
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final content = _contentCtrl.text.trim();
    if (_isEdit) {
      ref.read(journalProvider.notifier).update(
        widget.existingJournal!.copyWith(
          date: _date,
          content: content.isEmpty ? null : content,
        ),
      );
    } else {
      ref.read(journalProvider.notifier).add(
        _date,
        content: content.isEmpty ? null : content,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final dateStr =
        '${_date.year}/${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}';

    final profile = ref.watch(profileProvider);
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(guestModeProvider);
    final googleName = isGuest ? null : user?.userMetadata?['full_name'] as String?;
    final avatarUrl = isGuest ? null : user?.userMetadata?['avatar_url'] as String?;
    final username = profile?.username;
    final displayName = username?.isNotEmpty == true
        ? username!
        : (isGuest ? '訪客' : (googleName ?? user?.email ?? ''));
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Threads-style compose bar: cancel pinned left, title centered
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    _isEdit ? s.editJournal : s.addJournal,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatars.build(
                      avatarIndex: profile?.avatarIndex,
                      avatarUrl: avatarUrl,
                      initial: initial,
                      radius: 20,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right,
                                  size: 16, color: AppColors.textTertiary),
                              const SizedBox(width: 2),
                              InkWell(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                onTap: _pickDate,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 2),
                                  child: Text(
                                    dateStr,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextField(
                            controller: _contentCtrl,
                            autofocus: true,
                            minLines: 6,
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.7,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: s.journalContent,
                              hintStyle:
                                  const TextStyle(color: AppColors.textTertiary),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Bottom bar: live character count left, prominent post button right
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal, vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _contentCtrl,
                    builder: (_, value, _) => Text(
                      '${value.text.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: 12),
                    ),
                    child: Text(
                      _isEdit ? s.save : s.add,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
