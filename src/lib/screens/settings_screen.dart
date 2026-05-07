import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final currentLang = ref.watch(languageProvider);
    final currentFmt = ref.watch(settingsProvider);
    final semSettings = ref.watch(semesterSettingsProvider);

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
            title: Text(s.semesterSettings),
            subtitle: Text(_semesterSettingsLabel(semSettings, s)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSemesterSettingsDialog(context, ref, s, semSettings),
          ),
        ],
      ),
    );
  }
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
