import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../providers/remote_config_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/responsive_body.dart';

// Maintenance mode from the admin backend (system_design.md §3-U): in place of
// every page, so nothing the user could change is written meanwhile. The
// login page stays reachable, which is how an admin gets past this
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final message = ref.watch(remoteConfigProvider).maintenanceMessage;
    return Scaffold(
      body: ResponsiveBody(
        maxWidth: ResponsiveBody.formWidth,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.construction_outlined, size: 56, color: AppColors.primary),
                const SizedBox(height: AppSpacing.md),
                Text(s.maintenanceTitle, style: theme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message.isEmpty ? s.maintenanceDefault : message,
                  style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: () => ref.read(remoteConfigProvider.notifier).refresh(),
                  child: Text(s.maintenanceRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
