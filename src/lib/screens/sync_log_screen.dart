import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../providers/settings_provider.dart';
import '../providers/synced_list_notifier.dart';
import '../widgets/responsive_body.dart';

// Developer mode: the last failed syncs, newest first, with where each one
// happened and the full error (system_design.md §2-O). "Sync failed" came and
// went with nothing to trace; this is what to copy into a bug report
class SyncLogScreen extends ConsumerWidget {
  const SyncLogScreen({super.key});

  static String _time(DateTime t) =>
      '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  static String _line(SyncFailure f) => '${_time(f.at)}  ${describeSyncError(f)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final log = ref.watch(syncLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.syncLog),
        actions: [
          if (log.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: s.syncLogCopy,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: log.map(_line).join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.syncLogCopied)));
              },
            ),
        ],
      ),
      body: ResponsiveBody(
        child: log.isEmpty
            ? Center(
                child: Text(s.syncLogEmpty, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                itemCount: log.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, i) {
                  final f = log[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_time(f.at)}  ${f.where.isEmpty ? '?' : f.where}',
                        style: theme.labelLarge?.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SelectableText(describeSyncError(f.error), style: theme.bodySmall),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
