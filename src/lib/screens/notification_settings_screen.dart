import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notification_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../providers/notification_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../widgets/responsive_body.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final supported = NotificationService.isSupported;

    Future<void> toggleMaster(bool on) async {
      if (!on) {
        await notifier.disable();
        return;
      }
      final granted = await notifier.enable();
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.notifPermissionDenied)),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.notifications)),
      body: ResponsiveBody(
        child: ListView(
          children: [
            if (!supported)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  s.notifUnsupportedPlatform,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ),
            SwitchListTile(
              title: Text(s.notifEnabled),
              subtitle: Text(s.notifEnabledHint),
              value: settings.enabled,
              activeThumbColor: AppColors.primary,
              onChanged: supported ? toggleMaster : null,
            ),
            const Divider(height: 1),

            // The three kinds stay visible but inert while the master switch is
            // off, so the user can see what they would be turning on
            _KindSection(
              title: s.notifTaskDue,
              enabled: settings.taskDueEnabled,
              masterOn: settings.enabled,
              onToggle: (v) => notifier.update(settings.copyWith(taskDueEnabled: v)),
              details: [
                (
                  label: s.notifTaskLead,
                  value: s.notifLeadMinutes(settings.taskLeadMinutes),
                  onTap: () => _pickOption<int>(
                    context: context,
                    title: s.notifTaskLead,
                    options: NotificationConstants.taskLeadMinuteOptions,
                    current: settings.taskLeadMinutes,
                    label: s.notifLeadMinutes,
                    onPicked: (v) =>
                        notifier.update(settings.copyWith(taskLeadMinutes: v)),
                  ),
                ),
                (
                  label: s.notifRecurringTime,
                  value: _hhmm(settings.recurringMinuteOfDay),
                  onTap: () => _pickTime(
                    context,
                    settings.recurringMinuteOfDay,
                    (minute) => notifier.update(
                        settings.copyWith(recurringMinuteOfDay: minute)),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),

            _KindSection(
              title: s.notifDailySummary,
              enabled: settings.dailySummaryEnabled,
              masterOn: settings.enabled,
              onToggle: (v) =>
                  notifier.update(settings.copyWith(dailySummaryEnabled: v)),
              details: [
                (
                  label: s.notifSummaryTime,
                  value: _hhmm(settings.summaryMinuteOfDay),
                  onTap: () => _pickTime(
                    context,
                    settings.summaryMinuteOfDay,
                    (minute) => notifier.update(
                        settings.copyWith(summaryMinuteOfDay: minute)),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),

            _KindSection(
              title: s.notifGoalDeadline,
              enabled: settings.goalDeadlineEnabled,
              masterOn: settings.enabled,
              onToggle: (v) =>
                  notifier.update(settings.copyWith(goalDeadlineEnabled: v)),
              details: [
                (
                  label: s.notifGoalLead,
                  value: s.notifLeadDays(settings.goalLeadDays),
                  onTap: () => _pickOption<int>(
                    context: context,
                    title: s.notifGoalLead,
                    options: NotificationConstants.goalLeadDayOptions,
                    current: settings.goalLeadDays,
                    label: s.notifLeadDays,
                    onPicked: (v) =>
                        notifier.update(settings.copyWith(goalLeadDays: v)),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),

            _KindSection(
              title: s.notifReview,
              enabled: settings.weeklyReviewEnabled,
              masterOn: settings.enabled,
              onToggle: (v) =>
                  notifier.update(settings.copyWith(weeklyReviewEnabled: v)),
              details: [
                (
                  label: s.notifReviewTime,
                  value: _hhmm(settings.weeklyReviewMinuteOfDay),
                  onTap: () => _pickTime(
                    context,
                    settings.weeklyReviewMinuteOfDay,
                    (minute) => notifier.update(
                        settings.copyWith(weeklyReviewMinuteOfDay: minute)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _hhmm(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

// A switch plus the numbers that kind needs. Pulled out because all three
// sections have exactly this shape and inlining them three times was the
// pattern the 2026-08 refactor spent a stage removing
class _KindSection extends StatelessWidget {
  final String title;
  final bool enabled;
  final bool masterOn;
  final ValueChanged<bool> onToggle;
  final List<({String label, String value, VoidCallback onTap})> details;

  const _KindSection({
    required this.title,
    required this.enabled,
    required this.masterOn,
    required this.onToggle,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(title),
          value: enabled,
          activeThumbColor: AppColors.primary,
          onChanged: masterOn ? onToggle : null,
        ),
        for (final detail in details)
          ListTile(
            enabled: masterOn && enabled,
            title: Text(detail.label),
            trailing: Text(
              detail.value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: masterOn && enabled
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
            ),
            onTap: masterOn && enabled ? detail.onTap : null,
          ),
      ],
    );
  }
}

void _pickOption<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required T current,
  required String Function(T) label,
  required ValueChanged<T> onPicked,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        for (final option in options)
          ListTile(
            title: Text(label(option)),
            leading: Icon(
              option == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: option == current ? AppColors.primary : null,
            ),
            onTap: () {
              onPicked(option);
              Navigator.pop(ctx);
            },
          ),
      ],
    ),
  );
}

Future<void> _pickTime(
  BuildContext context,
  int minuteOfDay,
  Future<void> Function(int minuteOfDay) onPicked,
) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60),
  );
  if (picked == null) return;
  await onPicked(picked.hour * 60 + picked.minute);
}

// Kept here so settings_screen.dart only needs one import for the whole feature
ListTile notificationSettingsTile(BuildContext context, AppStrings s) => ListTile(
      title: Text(s.notifications),
      leading: const Icon(Icons.notifications_outlined),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
      ),
    );
