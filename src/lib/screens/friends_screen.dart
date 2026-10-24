import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_routes.dart';
import '../core/avatars.dart';
import '../core/friend_code.dart';
import '../core/friend_failure.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../models/friend.dart';
import '../providers/friends_provider.dart';
import '../providers/realtime_sync.dart';
import '../providers/settings_provider.dart';
import '../widgets/animated_rows.dart';
import '../widgets/app_page.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/guest_login_prompt.dart';
import '../widgets/invite_card.dart';
import '../widgets/responsive_body.dart';
import '../widgets/sync_controls.dart';
import 'friend_screen.dart';

// /friends (system_design.md §2-P, UC23): the user's invite, a box for
// someone else's code, the three things they share, and their friends and
// requests. A guest is asked to make an account first
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the page is a reason to look for new requests
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(friendsAvailableProvider)) ref.invalidate(friendListProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final Widget body;
    if (!ref.watch(canSyncProvider)) {
      body = GuestLoginPrompt(icon: Icons.group_outlined, message: s.friendsGuestPrompt);
    } else if (!ref.watch(friendsAvailableProvider)) {
      body = EmptyState(icon: Icons.group_off_outlined, message: s.friendsOff);
    } else {
      body = PullToSync(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, AppSpacing.md, AppSpacing.pageHorizontal, AppSpacing.xl),
          children: const [
            InviteCard(),
            SizedBox(height: AppSpacing.md),
            _CodeEntry(),
            SizedBox(height: AppSpacing.md),
            _ShareSettings(),
            SizedBox(height: AppSpacing.sectionGap),
            _FriendLists(),
          ],
        ),
      );
    }
    return AppPage(child: Scaffold(
      appBar: AppBar(leading: homeButtonIfFirst(context), title: Text(s.friends)),
      body: ResponsiveBody(child: body),
    ));
  }
}

// What a failed request or answer says, as a snackbar
void showFriendFailure(BuildContext context, Object error, AppStrings s) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(friendFailureMessage(friendFailureFrom(error), s))),
  );
}

// ─── Someone else's code ──────────────────────────────────────────────────────

class _CodeEntry extends ConsumerStatefulWidget {
  const _CodeEntry();

  @override
  ConsumerState<_CodeEntry> createState() => _CodeEntryState();
}

class _CodeEntryState extends ConsumerState<_CodeEntry> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final code = normalizeFriendCode(_controller.text);
    if (!isValidFriendCode(code)) {
      messenger.showSnackBar(SnackBar(content: Text(s.friendCodeInvalid)));
      return;
    }
    setState(() => _sending = true);
    try {
      final result = await ref.read(friendActionsProvider).request(code);
      _controller.clear();
      messenger.showSnackBar(SnackBar(
        content: Text(result == 'accepted' ? s.friendBecameFriends : s.friendRequestSent),
      ));
    } catch (e) {
      if (mounted) showFriendFailure(context, e, s);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.enterFriendCode, style: theme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('friendCodeField'),
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                // Room for a pasted message holding the link; only the code
                // is kept from it
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                decoration: InputDecoration(hintText: s.friendCodeHint, isDense: true),
                onSubmitted: (_) => _sending ? null : _send(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: Text(s.sendFriendRequest),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── What the user shares ─────────────────────────────────────────────────────

class _ShareSettings extends ConsumerWidget {
  const _ShareSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final async = ref.watch(shareSettingsProvider);
    final shares = async.valueOrNull ?? const FriendShares();
    final ready = async.hasValue;
    void set(FriendShares next) => ref.read(shareSettingsProvider.notifier).set(next);

    Widget tile(String key, String title, String hint, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
          key: ValueKey('share.$key'),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          title: Text(title),
          subtitle: Text(hint, style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          value: value,
          onChanged: ready ? onChanged : null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.shareWithFriends, style: theme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(s.shareWithFriendsHint, style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        // A Material, not a decorated box: the switches' ink shows on it
        Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              tile('timetable', s.timetable, s.shareTimetableHint, shares.timetable,
                  (v) => set(shares.copyWith(timetable: v))),
              // Friends see these two from Phase 7-2 on; the switch is kept
              // now so the choice is made once
              tile('rates', s.shareRates, '${s.shareRatesHint}$kDotSeparator${s.shareComingSoon}', shares.rates,
                  (v) => set(shares.copyWith(rates: v))),
              tile('graph', s.overview, '${s.shareGraphHint}$kDotSeparator${s.shareComingSoon}', shares.graph,
                  (v) => set(shares.copyWith(graph: v))),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Friends and requests ─────────────────────────────────────────────────────

class _FriendLists extends ConsumerWidget {
  const _FriendLists();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final async = ref.watch(friendListProvider);
    final list = async.valueOrNull;
    if (list == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: async.hasError
              ? Text(s.friendsLoadFailed, textAlign: TextAlign.center, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary))
              : const CircularProgressIndicator(),
        ),
      );
    }
    final incoming = [for (final f in list) if (f.status == FriendStatus.incoming) f];
    final outgoing = [for (final f in list) if (f.status == FriendStatus.outgoing) f];
    final friends = [for (final f in list) if (f.status == FriendStatus.friend) f];

    Widget section(String title, List<FriendEntry> entries) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              AnimatedRows(
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                children: [for (final f in entries) _FriendRow(key: ValueKey(f.friendshipId), entry: f)],
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (incoming.isNotEmpty) section(s.friendRequestsIncoming, incoming),
        if (outgoing.isNotEmpty) section(s.friendRequestsOutgoing, outgoing),
        if (friends.isEmpty)
          Text(s.noFriendsYet, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary))
        else
          section(s.friends, friends),
      ],
    );
  }
}

String friendName(FriendEntry f, AppStrings s) => (f.name == null || f.name!.isEmpty) ? s.unnamedFriend : f.name!;

Widget friendAvatar(String? name, int? avatarIndex, String? avatarUrl, {double radius = 20}) => AppAvatars.build(
      avatarIndex: avatarIndex,
      avatarUrl: avatarUrl,
      initial: (name == null || name.isEmpty) ? '?' : name.characters.first.toUpperCase(),
      radius: radius,
    );

class _FriendRow extends ConsumerWidget {
  final FriendEntry entry;

  const _FriendRow({super.key, required this.entry});

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    final s = ref.read(stringsProvider);
    try {
      await action();
    } catch (e) {
      if (context.mounted) showFriendFailure(context, e, s);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final actions = ref.read(friendActionsProvider);
    final name = friendName(entry, s);
    final shared = [
      if (entry.shares.timetable) s.timetable,
      if (entry.shares.rates) s.shareRates,
      if (entry.shares.graph) s.overview,
    ];

    final Widget trailing = switch (entry.status) {
      FriendStatus.incoming => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _run(context, ref, () => actions.respond(entry.friendshipId, false)),
              child: Text(s.declineFriend),
            ),
            FilledButton(
              onPressed: () => _run(context, ref, () => actions.respond(entry.friendshipId, true)),
              child: Text(s.acceptFriend),
            ),
          ],
        ),
      FriendStatus.outgoing => TextButton(
          onPressed: () async {
            if (!await confirmAction(context, message: s.cancelFriendRequestConfirm(name), action: s.cancelFriendRequest)) return;
            if (context.mounted) await _run(context, ref, () => actions.remove(entry.friendshipId));
          },
          child: Text(s.cancelFriendRequest),
        ),
      FriendStatus.friend => PopupMenuButton<String>(
          key: ValueKey('friendMenu.${entry.friendshipId}'),
          onSelected: (_) async {
            if (!await confirmAction(context, message: s.removeFriendConfirm(name), action: s.removeFriend)) return;
            if (context.mounted) await _run(context, ref, () => actions.remove(entry.friendshipId));
          },
          itemBuilder: (_) => [PopupMenuItem(value: 'remove', child: Text(s.removeFriend))],
        ),
    };

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: entry.status == FriendStatus.friend
            ? () => Navigator.push(context, AppPageRoute(builder: (_) => FriendScreen(entry: entry)))
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              friendAvatar(entry.name, entry.avatarIndex, entry.avatarUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.titleSmall),
                    if (entry.status == FriendStatus.friend)
                      Text(
                        shared.isEmpty ? s.friendSharesNothing(name) : shared.join(kDotSeparator),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
