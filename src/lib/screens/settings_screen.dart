import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final currentLang = ref.watch(languageProvider);
    final currentFmt = ref.watch(settingsProvider);

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
        ],
      ),
    );
  }
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
            color: isSelected ? Theme.of(ctx).colorScheme.primary : null,
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
            color: isSelected ? Theme.of(ctx).colorScheme.primary : null,
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
