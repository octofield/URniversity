import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../l10n/app_strings.dart';

/// Shows the shared destructive-action confirmation. Returns false when the
/// dialog is dismissed without choosing
Future<bool> confirmDelete(BuildContext context, AppStrings s) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(s.deleteConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: Text(s.delete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
