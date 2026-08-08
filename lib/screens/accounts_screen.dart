/// AccountsScreen — your accounts with balance, rate and interest.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';

import 'package:foliopod/models/account.dart';
import 'package:foliopod/pages/account_edit.dart';
import 'package:foliopod/pages/account_history.dart';
import 'package:foliopod/pages/record_event.dart';
import 'package:foliopod/services/app_provider.dart';
import 'package:foliopod/widgets/account_tile.dart';
import 'package:foliopod/widgets/account_total_bar.dart';
import 'package:foliopod/widgets/error_dialog.dart';
import 'package:foliopod/widgets/startup_overlay.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Account> _filter(List<Account> accounts) {
    if (_query.isEmpty) return accounts;
    final q = _query.toLowerCase();
    return accounts
        .where(
          (a) =>
              a.name.toLowerCase().contains(q) ||
              (a.institution?.toLowerCase().contains(q) ?? false) ||
              (a.note?.toLowerCase().contains(q) ?? false) ||
              a.type.label.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Saves to the Pod; reports failure via a modal dialog (errors need
  /// acknowledgement).
  Future<void> _saveOrError(AppProvider provider) =>
      savePodOrError(context, provider);

  Future<void> _addAccount(AppProvider provider) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountEdit(
        onSave: (account) async {
          provider.addAccount(account);
          await _saveOrError(provider);
        },
      ),
    );
  }

  /// Opens the account's transaction log; entries are edited there and
  /// account details are edited via the pencil in its header.
  /// 20260727 gjw
  Future<void> _showHistory(Account account) => showDialog<void>(
    context: context,
    builder: (_) => AccountHistory(accountId: account.id),
  );

  Future<void> _recordFor(AppProvider provider, Account account) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordEvent(
        account: account,
        onSave: (events) async {
          for (final event in events) {
            provider.recordEvent(account.id, event);
          }
          await _saveOrError(provider);
        },
      ),
    );
  }

  Future<void> _confirmDelete(AppProvider provider, Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
          'Delete "${account.name}" and its entire history? Consider '
          'marking it Closed instead to keep the history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    provider.deleteAccount(account.id);
    await _saveOrError(provider);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;

    if (provider.busy) {
      return StartupOverlay(
        phase: provider.startupPhase,
        child: const SizedBox.expand(),
      );
    }

    final open = _filter(provider.openAccounts);
    final closed = _filter(provider.closedAccounts);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search accounts…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const Gap(4),
              const MarkdownTooltip(
                message: '''

**Search tips**

- Plain text — searches name, institution, type and note
- Tap an account for its transaction log, where entries can be
  edited and the account's details changed
- Use the Record button on an account to record interest, deposits,
  rate changes and balance updates

''',
                child: Icon(Icons.help_outline, size: 18),
              ),
              MarkdownTooltip(
                message: '**Add account**\n\nAdd a new bank account.',
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => _addAccount(provider),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: open.isEmpty && closed.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty
                        ? 'No accounts yet — tap + to add your first '
                              'account.'
                        : 'No accounts match your search.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    for (final a in open) _tile(provider, a),
                    if (closed.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Text(
                          'Closed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      for (final a in closed) _tile(provider, a),
                    ],
                  ],
                ),
        ),
        AccountTotalBar(accounts: open),
      ],
    );
  }

  Widget _tile(AppProvider provider, Account account) => AccountTile(
    account: account,
    onTap: () => _showHistory(account),
    onRecord: () => _recordFor(provider, account),
    onDelete: () => _confirmDelete(provider, account),
  );
}
