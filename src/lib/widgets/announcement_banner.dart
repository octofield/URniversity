import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../providers/remote_config_provider.dart';
import '../providers/settings_provider.dart';

// The announcement dismissed on this device, by id (D38 dismissed_announcement):
// a new announcement has a new id and shows again
class DismissedAnnouncementNotifier extends StateNotifier<String?> {
  static const key = 'dismissed_announcement';

  DismissedAnnouncementNotifier() : super(null) {
    SharedPreferences.getInstance().then((p) {
      if (mounted) state = p.getString(key);
    });
  }

  Future<void> dismiss(String id) async {
    state = id;
    await (await SharedPreferences.getInstance()).setString(key, id);
  }
}

final dismissedAnnouncementProvider = StateNotifierProvider<DismissedAnnouncementNotifier, String?>(
  (ref) => DismissedAnnouncementNotifier(),
);

// The admin backend's announcement, while it runs and until dismissed here
final visibleAnnouncementProvider = Provider<Announcement?>((ref) {
  final a = ref.watch(remoteConfigProvider).announcement;
  if (a == null || !a.showingAt(ref.watch(effectiveNowProvider))) return null;
  if (a.id == ref.watch(dismissedAnnouncementProvider)) return null;
  return a;
});

// A strip across the top of the tabs (system_design.md §3-U)
class AnnouncementBanner extends ConsumerWidget {
  final Announcement announcement;
  const AnnouncementBanner({super.key, required this.announcement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final warning = announcement.level == 'warning';
    final color = warning ? AppColors.warning : AppColors.primary;
    return Material(
      color: color.withValues(alpha: 0.14),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
          child: Row(
            children: [
              Icon(warning ? Icons.warning_amber_rounded : Icons.campaign_outlined, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(announcement.text, style: Theme.of(context).textTheme.bodyMedium)),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: s.dismissAnnouncement,
                visualDensity: VisualDensity.compact,
                onPressed: () => ref.read(dismissedAnnouncementProvider.notifier).dismiss(announcement.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
