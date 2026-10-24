import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/guest_provider.dart';
import 'empty_state.dart';

// From guest to an account: keep what was made as a guest or start fresh, then
// on to the login page. The Me tab's button, and the pages a guest cannot use
// (friends, an invite)
void showLoginChoice(BuildContext context, WidgetRef ref) {
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

// In place of a page that needs an account
class GuestLoginPrompt extends ConsumerWidget {
  final IconData icon;
  final String message;

  const GuestLoginPrompt({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) => EmptyState(
        icon: icon,
        message: message,
        actionLabel: ref.watch(stringsProvider).loginOrCreateAccount,
        onAction: () => showLoginChoice(context, ref),
      );
}
