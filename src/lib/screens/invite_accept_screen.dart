import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_routes.dart';
import '../core/friend_code.dart';
import '../core/friend_failure.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../providers/friends_provider.dart';
import '../providers/realtime_sync.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_page.dart';
import '../widgets/empty_state.dart';
import '../widgets/guest_login_prompt.dart';
import '../widgets/responsive_body.dart';
import 'friends_screen.dart' show FriendsScreen, friendAvatar, showFriendFailure;

// /invite/<code> (system_design.md §2-P, UC23): where a scanned QR code or a
// tapped invite link lands, in the app (Android App Link) or on the web. It
// shows whose code it is and sends them a request; they become friends once
// the owner accepts it, since a link can be passed on to anyone
class InviteAcceptScreen extends ConsumerStatefulWidget {
  final String code;

  const InviteAcceptScreen({super.key, required this.code});

  @override
  ConsumerState<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends ConsumerState<InviteAcceptScreen> {
  bool _sending = false;
  // 'pending' or 'accepted' once sent
  String? _result;

  late final String _code = normalizeFriendCode(widget.code);

  void _toFriends() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(AppRoutes.friends);
    } else {
      Navigator.pushReplacement(context, AppPageRoute(builder: (_) => const FriendsScreen()));
    }
  }

  Future<void> _send() async {
    final s = ref.read(stringsProvider);
    setState(() => _sending = true);
    try {
      final result = await ref.read(friendActionsProvider).request(_code);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      // Already friends, or already asked: nothing left to do here
      if (friendFailureFrom(e) == FriendFailure.already) {
        setState(() => _result = 'already');
      } else {
        showFriendFailure(context, e, s);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;

    Widget message(IconData icon, String text) => EmptyState(
          icon: icon,
          message: text,
          actionLabel: s.goToFriends,
          onAction: _toFriends,
        );

    final Widget body;
    if (!ref.watch(canSyncProvider)) {
      body = GuestLoginPrompt(icon: Icons.group_add_outlined, message: s.friendsGuestPrompt);
    } else if (!ref.watch(friendsAvailableProvider)) {
      body = EmptyState(icon: Icons.group_off_outlined, message: s.friendsOff);
    } else if (!isValidFriendCode(_code)) {
      body = message(Icons.link_off, s.friendCodeNotFound);
    } else {
      final preview = ref.watch(friendPreviewProvider(_code));
      final owner = preview.valueOrNull;
      if (preview.isLoading && owner == null) {
        body = const Center(child: CircularProgressIndicator());
      } else if (preview.hasError) {
        body = message(Icons.cloud_off_outlined, s.friendFailed);
      } else if (owner == null) {
        body = message(Icons.link_off, s.friendCodeNotFound);
      } else if (owner.isSelf) {
        body = message(Icons.person_outline, s.friendCodeIsYours);
      } else {
        final name = (owner.name == null || owner.name!.isEmpty) ? s.unnamedFriend : owner.name!;
        final done = switch (_result) {
          'pending' => s.friendRequestSentTo(name),
          'accepted' => s.friendNowFriendsWith(name),
          'already' => s.friendAlready,
          _ => null,
        };
        body = SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),
              friendAvatar(owner.name, owner.avatarIndex, owner.avatarUrl, radius: 40),
              const SizedBox(height: AppSpacing.md),
              Text(
                done ?? s.inviteAddQuestion(name),
                textAlign: TextAlign.center,
                style: theme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (done == null)
                Text(s.inviteAddHint, textAlign: TextAlign.center, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              if (done == null)
                FilledButton(
                  onPressed: _sending ? null : _send,
                  child: Text(s.sendFriendRequest),
                )
              else
                OutlinedButton(onPressed: _toFriends, child: Text(s.goToFriends)),
            ],
          ),
        );
      }
    }

    return AppPage(child: Scaffold(
      appBar: AppBar(leading: homeButtonIfFirst(context), title: Text(s.inviteTitle)),
      body: ResponsiveBody(maxWidth: ResponsiveBody.formWidth, child: body),
    ));
  }
}
