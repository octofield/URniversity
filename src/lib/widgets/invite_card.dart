import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/friend_code.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../providers/friends_provider.dart';
import '../providers/settings_provider.dart';

// "My invite" on the friends page (system_design.md §2-P): the link as a QR
// code a classmate's phone camera reads, the code itself, and ways to send it
class InviteCard extends ConsumerWidget {
  const InviteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final code = ref.watch(myFriendCodeProvider);
    // Dark modules on a light ground in every style: a camera reads an
    // inverted code less reliably
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? AppColors.background : AppColors.textPrimary;
    final paper = dark ? AppColors.textPrimary : AppColors.surface;

    final value = code.valueOrNull;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.myInvite, style: theme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(s.myInviteHint, style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          if (value == null)
            SizedBox(
              height: 160,
              child: Center(
                child: code.hasError
                    ? Text(s.inviteCodeLoadFailed, textAlign: TextAlign.center, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary))
                    : const CircularProgressIndicator(),
              ),
            )
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: QrImageView(
                  data: inviteLink(value),
                  size: 160,
                  padding: EdgeInsets.zero,
                  backgroundColor: paper,
                  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
                  dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ink),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              groupedFriendCode(value),
              key: const ValueKey('friendCode'),
              textAlign: TextAlign.center,
              style: theme.headlineSmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(s.copyInviteLink),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteLink(value)));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.inviteLinkCopied)));
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text(s.shareInvite),
                  onPressed: () => _share(context, s.inviteShareText(inviteLink(value)), inviteLink(value), s.inviteLinkCopied),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context, String text, String link, String copied) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      // No share sheet here (a desktop, an older browser): the link is copied
      // instead, which is what sharing it would have been for. Nothing written
      debugPrint('[friends] share unavailable: $e');
      await Clipboard.setData(ClipboardData(text: link));
      messenger.showSnackBar(SnackBar(content: Text(copied)));
    }
  }
}
