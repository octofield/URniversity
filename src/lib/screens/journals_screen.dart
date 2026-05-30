import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/journal.dart';
import '../providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import 'journal_edit_screen.dart';
import 'me_screen.dart' show JournalDetailScreen;


class JournalsScreen extends ConsumerWidget {
  const JournalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final journals = ref.watch(journalProvider);
    final showDay = ref.watch(showDayCounterProvider);

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

    return Scaffold(
      appBar: AppBar(title: Text(s.allJournals)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalEditScreen())),
        child: const Icon(Icons.edit_note),
      ),
      body: journals.isEmpty
          ? Center(child: Text(s.noJournal, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, AppSpacing.md, AppSpacing.pageHorizontal, 80),
              itemCount: journals.length,
              itemBuilder: (context, i) {
                final journal = journals[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _JournalCard(
                    journal: journal,
                    dayNumber: dayNumber(journal.date),
                    showDayCounter: showDay,
                  ),
                );
              },
            ),
    );
  }
}

class _JournalCard extends ConsumerWidget {
  final Journal journal;
  final int dayNumber;
  final bool showDayCounter;
  const _JournalCard({required this.journal, required this.dayNumber, required this.showDayCounter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider);
    final googleName = user?.userMetadata?['full_name'] as String?;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final displayName = profile?.username?.isNotEmpty == true
        ? profile!.username!
        : (googleName ?? user?.email ?? '');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final d = journal.date;
    final dateStr = '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JournalDetailScreen(journal: journal))),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(initial, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textOnPrimary))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(dateStr, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (showDayCounter) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text('Day $dayNumber', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          content: Text('${s.delete}？'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                              child: Text(s.delete),
                            ),
                          ],
                        ),
                      ) ?? false;
                      if (confirmed) ref.read(journalProvider.notifier).remove(journal.id);
                    },
                  ),
                ],
              ),
              if (journal.content != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 36),
                  child: Text(
                    journal.content!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6, color: AppColors.textPrimary),
                    maxLines: 30,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
