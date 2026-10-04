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

/// Asks before an action that is not destructive but should not happen on a
/// stray tap (e.g. postponing a task). Returns false when dismissed
Future<bool> confirmAction(BuildContext context, {required String message, required String action}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
