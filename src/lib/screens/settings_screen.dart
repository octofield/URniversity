import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../providers/guest_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import 'trash_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTaps = 0;

  void _onVersionTap() {
    setState(() {
      _versionTaps++;
      if (_versionTaps >= 7) {
        _versionTaps = 0;
        final dev = ref.read(devModeProvider);
        if (dev.enabled) {
          ref.read(devModeProvider.notifier).disable();
        } else {
          ref.read(devModeProvider.notifier).enable();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final currentLang = ref.watch(languageProvider);
    final currentFmt = ref.watch(settingsProvider);
    final semSettings = ref.watch(semesterSettingsProvider);
    final defaultView = ref.watch(defaultTaskViewProvider);
    final showDayCounter = ref.watch(showDayCounterProvider);
    final dev = ref.watch(devModeProvider);
    final isGuest = ref.watch(guestModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          ListTile(
            title: Text(s.language),
            subtitle: Text(languageLabel(currentLang, s)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, ref, s, currentLang),
          ),
          ListTile(
            title: Text(s.dateFormat),
            subtitle: Text(formatDate(DateTime.now(), currentFmt)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDateFormatDialog(context, ref, s, currentFmt),
          ),
          ListTile(
            title: Text(s.defaultTaskView),
            subtitle: Text(_taskViewLabel(defaultView, s)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDefaultTaskViewDialog(context, ref, s, defaultView),
          ),
          ListTile(
            title: Text(s.semesterSettings),
            subtitle: Text(_semesterSettingsLabel(semSettings, s)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSemesterSettingsDialog(context, ref, s, semSettings),
          ),
          SwitchListTile(
            title: Text(s.showJournalDayCounter),
            value: showDayCounter,
            activeThumbColor: AppColors.primary,
            onChanged: (v) =>
                ref.read(showDayCounterProvider.notifier).state = v,
          ),
          ListTile(
            title: Text(s.feedbackTitle),
            leading: const Icon(Icons.feedback_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog(
              context: context,
              builder: (_) => _FeedbackDialog(s: s, isDevMode: ref.read(devModeProvider).enabled),
            ),
          ),
          ListTile(
            title: Text(s.trash),
            leading: const Icon(Icons.delete_outline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ),
          ),
          GestureDetector(
            onTap: _onVersionTap,
            behavior: HitTestBehavior.opaque,
            child: ListTile(
              title: Text(s.versionLabel),
              subtitle: const Text('alpha-1.0'),
              trailing: dev.enabled
                  ? const Icon(Icons.code, color: AppColors.primary)
                  : null,
            ),
          ),
          // Developer mode section — visible only after unlocking
          if (dev.enabled) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                s.developerMode,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: AppColors.primary),
              title: Text(s.devTimeOverride),
              subtitle: Text(
                dev.customTime != null
                    ? formatDate(dev.customTime!, DateDisplayFormat.yyyymmdd)
                    : '—',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: dev.customTime ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  ref.read(devModeProvider.notifier).setCustomTime(picked);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: AppColors.primary),
              title: Text(s.reset),
              onTap: () =>
                  ref.read(devModeProvider.notifier).setCustomTime(null),
            ),
          ],
          const Divider(),
          if (isGuest)
            ListTile(
              title: Text(s.exitGuestMode, style: const TextStyle(color: AppColors.error)),
              leading: const Icon(Icons.logout, color: AppColors.error),
              onTap: () => _confirmExitGuest(context, ref),
            )
          else ...[
            ListTile(
              title: Text(s.logout, style: const TextStyle(color: AppColors.error)),
              leading: const Icon(Icons.logout, color: AppColors.error),
              onTap: () => _confirmLogout(context),
            ),
            ListTile(
              title: Text(s.deleteAccount, style: const TextStyle(color: AppColors.error)),
              leading: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}

void _confirmExitGuest(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('退出訪客模式'),
      content: const Text('退出後所有訪客資料將會清除，無法復原。確定繼續？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(guestModeProvider.notifier).disable();
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('退出'),
        ),
      ],
    ),
  );
}

void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  final user = Supabase.instance.client.auth.currentUser;
  final isGoogle = user?.identities?.any((i) => i.provider == 'google') ?? false;

  if (isGoogle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除帳號'),
        content: const Text('此操作無法還原，所有資料將永久刪除。確定繼續？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uid = user!.id;
              await ref.read(profileProvider.notifier).deleteAllData(uid);
              await Supabase.instance.client.auth.signOut();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('確認刪除'),
          ),
        ],
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(email: user?.email ?? '', ref: ref),
    );
  }
}

void _confirmLogout(BuildContext context) {
  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: const Text('登出'),
      content: const Text('確定要登出嗎？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dlgCtx),
          child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(dlgCtx);
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          child: const Text('登出', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
}

String _semesterSettingsLabel(SemesterSettings settings, dynamic s) {
  final countLabel = switch (settings.count) {
    2 => s.twoSemesters,
    3 => s.threeSemesters,
    _ => s.fourSemesters,
  };
  final months = settings.startMonths.join(', ');
  return '$countLabel  ·  $months';
}

String _taskViewLabel(int view, dynamic s) {
  switch (view) {
    case 1:  return s.dailyTasks;
    case 2:  return s.weeklyTasks;
    default: return s.allTasks;
  }
}

void _showDefaultTaskViewDialog(BuildContext context, WidgetRef ref,
    dynamic s, int current) {
  showDialog(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(s.defaultTaskView),
      children: [
        for (final entry in [(0, s.allTasks), (1, s.dailyTasks), (2, s.weeklyTasks)])
          ListTile(
            title: Text(entry.$2),
            leading: Icon(
              entry.$1 == current ? Icons.radio_button_checked : Icons.radio_button_off,
              color: entry.$1 == current ? AppColors.primary : null,
            ),
            onTap: () {
              ref.read(defaultTaskViewProvider.notifier).state = entry.$1;
              Navigator.pop(ctx);
            },
          ),
      ],
    ),
  );
}

void _showLanguageDialog(BuildContext context, WidgetRef ref,
    dynamic s, AppLanguage current) {
  showDialog(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(s.language),
      children: AppLanguage.values.map((lang) {
        final isSelected = lang == current;
        return ListTile(
          title: Text(languageLabel(lang, s)),
          leading: Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected ? AppColors.primary : null,
          ),
          onTap: () {
            ref.read(languageProvider.notifier).setLanguage(lang);
            Navigator.pop(ctx);
          },
        );
      }).toList(),
    ),
  );
}

void _showDateFormatDialog(BuildContext context, WidgetRef ref,
    dynamic s, DateDisplayFormat current) {
  final exampleDate = DateTime.now();
  showDialog(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(s.dateFormat),
      children: DateDisplayFormat.values.map((format) {
        final isSelected = format == current;
        return ListTile(
          title: Text(dateFormatLabel(format, s)),
          subtitle: Text(formatDate(exampleDate, format)),
          leading: Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected ? AppColors.primary : null,
          ),
          onTap: () {
            ref.read(settingsProvider.notifier).setDateFormat(format);
            Navigator.pop(ctx);
          },
        );
      }).toList(),
    ),
  );
}

void _showSemesterSettingsDialog(BuildContext context, WidgetRef ref,
    dynamic s, SemesterSettings current) {
  showDialog(
    context: context,
    builder: (ctx) => _SemesterSettingsDialog(s: s, current: current, ref: ref),
  );
}

class _SemesterSettingsDialog extends StatefulWidget {
  final dynamic s;
  final SemesterSettings current;
  final WidgetRef ref;

  const _SemesterSettingsDialog({required this.s, required this.current, required this.ref});

  @override
  State<_SemesterSettingsDialog> createState() => _SemesterSettingsDialogState();
}

class _SemesterSettingsDialogState extends State<_SemesterSettingsDialog> {
  late int _count;
  late List<int> _startMonths;

  @override
  void initState() {
    super.initState();
    _count = widget.current.count;
    _startMonths = List<int>.from(widget.current.startMonths);
  }

  void _setCount(int count) {
    setState(() {
      _count = count;
      const defaults = [8, 2, 6, 12];
      if (count > _startMonths.length) {
        for (int i = _startMonths.length; i < count; i++) {
          _startMonths.add(defaults[i % defaults.length]);
        }
      } else {
        _startMonths = _startMonths.sublist(0, count);
      }
    });
  }

  void _save() {
    final notifier = widget.ref.read(semesterSettingsProvider.notifier);
    notifier.setCount(_count);
    for (int i = 0; i < _count; i++) {
      notifier.setStartMonth(i, _startMonths[i]);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.semesterSettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.semesterCount, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 2, label: Text(s.twoSemesters)),
              ButtonSegment(value: 3, label: Text(s.threeSemesters)),
              ButtonSegment(value: 4, label: Text(s.fourSemesters)),
            ],
            selected: {_count},
            onSelectionChanged: (sel) => _setCount(sel.first),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < _count; i++)
            Row(
              children: [
                Expanded(child: Text('${s.semester} ${i + 1}  ${s.semesterStartMonth}')),
                DropdownButton<int>(
                  value: _startMonths[i],
                  items: [
                    for (int m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text('$m')),
                  ],
                  onChanged: (m) {
                    if (m != null) setState(() => _startMonths[i] = m);
                  },
                ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(onPressed: _save, child: Text(s.save)),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final String email;
  final WidgetRef ref;
  const _DeleteAccountDialog({required this.email, required this.ref});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();
  String? _errorMsg;
  bool _loading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: widget.email,
        password: _passwordCtrl.text,
      );
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await widget.ref.read(profileProvider.notifier).deleteAllData(uid);
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('刪除帳號'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('此操作無法還原，所有資料將永久刪除。\n請輸入密碼以確認。'),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '密碼',
              errorText: _errorMsg,
            ),
            onSubmitted: (_) => _loading ? null : _delete(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _loading ? null : _delete,
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('確認刪除'),
        ),
      ],
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  final dynamic s;
  final bool isDevMode;
  const _FeedbackDialog({required this.s, required this.isDevMode});

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  static DateTime? _lastSubmitTime;
  static const _cooldownMinutes = 5;
  static const _maxLength = 1000;
  static const _minLength = 10;

  String _type = 'bug';
  final _ctrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final msg = _ctrl.text.trim();
    final s = widget.s;
    if (msg.length < _minLength) {
      setState(() => _error = s.feedbackErrorMinLength);
      return;
    }
    final last = _lastSubmitTime;
    if (last != null && !widget.isDevMode) {
      final diff = DateTime.now().difference(last).inMinutes;
      if (diff < _cooldownMinutes) {
        setState(() => _error = s.feedbackErrorCooldown);
        return;
      }
    }

    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.from('feedbacks').insert({
        'type': _type,
        'message': msg.substring(0, msg.length.clamp(0, _maxLength)),
      });
      _lastSubmitTime = DateTime.now();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = s.feedbackErrorFailed; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final length = _ctrl.text.length;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.feedbackTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              s.feedbackAnonymousNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'bug', label: Text(s.feedbackBug), icon: const Icon(Icons.bug_report_outlined)),
                ButtonSegment(value: 'suggestion', label: Text(s.feedbackSuggestion), icon: const Icon(Icons.lightbulb_outline)),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              maxLines: 8,
              maxLength: _maxLength,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: _type == 'bug' ? s.feedbackBugHint : s.feedbackSuggestionHint,
                helperText: length < _minLength ? s.feedbackErrorMinLength : null,
                errorText: _error,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (length < _minLength || _loading) ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(s.feedbackSubmit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
