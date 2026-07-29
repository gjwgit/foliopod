/// AccountHistory — an account's transaction log in a popup.
///
// Time-stamp: <2026-07-27>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';

import 'package:foliopod/constants/app.dart' show baseCurrency;
import 'package:foliopod/models/account.dart';
import 'package:foliopod/models/account_event.dart';
import 'package:foliopod/pages/account_edit.dart';
import 'package:foliopod/pages/event_edit.dart';
import 'package:foliopod/pages/record_event.dart';
import 'package:foliopod/services/app_provider.dart';
import 'package:foliopod/services/exchange_service.dart';
import 'package:foliopod/services/money_format.dart';
import 'package:foliopod/widgets/error_dialog.dart';
import 'package:foliopod/widgets/event_tile.dart';

/// Dialog showing every history entry for one account, most recent
/// first. Tap an entry to edit or delete it; the account's balance and
/// rate are recomputed by replaying the history. The header offers
/// recording a new entry and editing the account's details.
///
/// Watches the provider by [accountId] so the log refreshes in place as
/// entries are recorded, edited or deleted.
class AccountHistory extends StatelessWidget {
  final String accountId;
  const AccountHistory({super.key, required this.accountId});

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _record(BuildContext context, Account account) async {
    final provider = context.read<AppProvider>();
    final events = await showDialog<List<AccountEvent>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordEvent(account: account),
    );
    if (events == null || events.isEmpty || !context.mounted) return;
    for (final event in events) {
      provider.recordEvent(account.id, event);
    }
    await savePodOrError(context, provider);
  }

  Future<void> _editAccount(BuildContext context, Account account) async {
    final provider = context.read<AppProvider>();
    final updated = await showDialog<Account>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountEdit(account: account),
    );
    if (updated == null || !context.mounted) return;
    provider.updateAccount(updated);
    await savePodOrError(context, provider);
  }

  Future<void> _editEvent(
    BuildContext context,
    Account account,
    AccountEvent event,
  ) async {
    final provider = context.read<AppProvider>();
    final result = await showDialog<EventEditResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EventEdit(event: event),
    );
    if (result == null || !context.mounted) return;
    if (result.deleted) {
      provider.deleteEvent(account.id, event.id);
    } else if (result.event != null) {
      provider.updateEvent(account.id, result.event!);
    } else {
      return;
    }
    await savePodOrError(context, provider);
  }

  /// Normalised-to-AUD note for foreign-currency accounts, e.g.
  /// ` (≈ A\$1,900.00)`, or empty for AUD accounts or when no rate is
  /// available. 20260729 gjw
  String _audNote(Account account) {
    if (account.currency == baseCurrency) return '';
    final aud = ExchangeService.toAud(
      account.currentBalance,
      account.currency,
    );
    if (aud == null) return '';
    final rate = ExchangeService.rateFromAud(account.currency);
    final rateNote = rate != null
        ? ', A\$1 = ${currencySymbol(account.currency)}'
              '${rate.toStringAsFixed(4)}'
        : '';
    return ' (≈ A\$${formatMoney(aud)}$rateNote)';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final account = provider.allAccounts
        .where((a) => a.id == accountId)
        .firstOrNull;
    if (account == null) return const SizedBox.shrink();

    final events = account.events.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(account.name, overflow: TextOverflow.ellipsis)),
          MarkdownTooltip(
            message: '''

**Record**

Record interest credited, a deposit, an interest rate change, or a
balance update for this account.

''',
            child: IconButton(
              icon: const Icon(Icons.add_card_outlined, size: 20),
              onPressed: () => _record(context, account),
            ),
          ),
          MarkdownTooltip(
            message: '''

**Edit account**

Edit the account's details — name, institution, type, number and
note.

''',
            child: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editAccount(context, account),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SelectableText so the balance, rate and normalised value
            // can be copied; it carries its own selection handling, no
            // SelectionArea required. 20260729 gjw
            SelectableText(
              'Currently ${account.balanceStr}'
              '${_audNote(account)} at ${account.rateStr} — '
              '${account.interestFYStr} interest since 1 July. '
              'Tap an entry to edit it.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const Divider(),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        'No history yet.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, i) => EventTile(
                        event: events[i],
                        currency: account.currency,
                        onTap: () => _editEvent(context, account, events[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
