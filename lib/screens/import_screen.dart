/// ImportScreen — export accounts to JSON and import from a backup.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/services/app_provider.dart';
import 'package:foliopod/widgets/message_banner.dart';

/// Export a complete JSON backup of all accounts (with their full
/// histories), and import from a previously saved backup. Importing
/// merges by account id — accounts already present are skipped, so
/// re-importing the same backup is a no-op. 20260727 gjw
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _loading = false;
  String? _message;
  bool _error = false;

  void _setMessage(String msg, {bool error = false}) {
    setState(() {
      _message = msg;
      _error = error;
    });
  }

  String _ts() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  // ── JSON Export ───────────────────────────────────────────────────────────

  Future<void> _exportJson(AppProvider provider) async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final accounts = provider.allAccounts;
      final json = const JsonEncoder.withIndent(
        '  ',
      ).convert(accounts.map((a) => a.toJson()).toList());
      final bytes = utf8.encode(json);
      final fileName = 'foliopod_backup_${_ts()}.json';

      if (kIsWeb) {
        _setMessage('Export to file is not supported on web.', error: true);
        return;
      }

      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save JSON backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (savePath != null) {
        await File(savePath).writeAsBytes(bytes);
        _setMessage('Saved to $savePath');
      }
    } catch (e, st) {
      debugPrint('[Export JSON] error: $e\n$st');
      _setMessage('Export failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _importJson() async {
    final provider = context.read<AppProvider>();
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select FolioPod JSON backup',
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _setMessage('Could not read file.', error: true);
        setState(() => _loading = false);
        return;
      }

      final List<dynamic> raw = jsonDecode(utf8.decode(bytes));
      final imported = raw
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();

      if (imported.isEmpty) {
        _setMessage('No accounts found in "${file.name}".', error: true);
        setState(() => _loading = false);
        return;
      }

      final added = provider.importAccounts(imported);
      await provider.saveToPod();
      _setMessage(
        'Imported $added new account${added == 1 ? '' : 's'} '
        '(${imported.length - added} skipped as duplicates).',
      );
    } catch (e, st) {
      debugPrint('[Import] error: $e\n$st');
      _setMessage('Import failed: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final total = provider.allAccounts.length;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export & Import',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Gap(8),
            Text(
              'Save a complete JSON backup of all your accounts and their '
              'histories, or restore from a previously saved backup file. '
              'Importing merges with your current accounts — accounts '
              'already present are skipped.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (_message != null) ...[
              const Gap(12),
              MessageBanner(message: _message!, isError: _error),
            ],
            const Gap(16),
            Row(
              children: [
                MarkdownTooltip(
                  message:
                      '**Export JSON**\n\n'
                      'Save all $total account${total == 1 ? '' : 's'} with '
                      'their full histories to a FolioPod JSON backup file '
                      'on this device. Keep it somewhere safe so you can '
                      'restore everything later.',
                  child: FilledButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Export JSON'),
                    onPressed: _loading || total == 0
                        ? null
                        : () => _exportJson(provider),
                  ),
                ),
                const Gap(12),
                MarkdownTooltip(
                  message:
                      '**Import JSON**\n\n'
                      'Restore accounts from a FolioPod JSON backup file. '
                      'Accounts already present (matched by id) are '
                      'skipped, so re-importing a backup is safe.',
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload),
                    label: const Text('Import JSON'),
                    onPressed: _loading ? null : _importJson,
                  ),
                ),
                if (_loading) ...[
                  const Gap(16),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
