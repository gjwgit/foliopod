/// Reusable modal error dialog and save-to-Pod helper.
///
/// Errors need acknowledgement, so they are modal dialogs rather than
/// SnackBars (matching konapod's error_dialog.dart pattern).
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:foliopod/services/app_provider.dart';

/// Shows a modal error dialog with an OK button.
Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Saves the provider's accounts to the Pod; reports failure via a modal
/// error dialog. Shared by the screens and dialogs that mutate accounts.
Future<void> savePodOrError(BuildContext context, AppProvider provider) async {
  final err = await provider.saveToPod();
  if (err == null || !context.mounted) return;
  await showErrorDialog(
    context,
    title: 'Save failed',
    message: 'Could not save to your Pod.\n\n$err',
  );
}
