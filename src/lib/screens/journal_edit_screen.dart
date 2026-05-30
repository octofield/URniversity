import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/journal.dart';
import '../providers/journal_provider.dart';
import '../providers/settings_provider.dart';

class JournalEditScreen extends ConsumerStatefulWidget {
  // null = add mode, non-null = edit mode
  final Journal? existingJournal;
  const JournalEditScreen({this.existingJournal, super.key});

  @override
  ConsumerState<JournalEditScreen> createState() => _JournalEditScreenState();
}

class _JournalEditScreenState extends ConsumerState<JournalEditScreen> {
  late DateTime _date;
  late TextEditingController _contentCtrl;

  bool get _isEdit => widget.existingJournal != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingJournal;
    final effectiveNow = ref.read(effectiveNowProvider);
    _date = existing?.date ?? effectiveNow;
    _contentCtrl = TextEditingController(text: existing?.content ?? '');
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final content = _contentCtrl.text.trim();
    if (_isEdit) {
      ref.read(journalProvider.notifier).update(
        widget.existingJournal!.copyWith(
          date: _date,
          content: content.isEmpty ? null : content,
        ),
      );
    } else {
      ref.read(journalProvider.notifier).add(
        _date,
        content: content.isEmpty ? null : content,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final dateStr =
        '${_date.year}/${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) setState(() => _date = picked);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              s.save,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal, AppSpacing.sm,
          AppSpacing.pageHorizontal, AppSpacing.lg,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: _contentCtrl,
            autofocus: true,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              fontSize: 16,
              height: 1.8,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: s.journalContent,
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}
